"
I am a CSV text in memory with its index (4 bytes a field): rows and columns are made when they are asked for.

```smalltalk
| table |
table := SimdCSV tableFrom: 'stops.csv' asFileReference.
table columnNames.
table rowCount.
table rowAt: 7.
table at: 7 at: #city.
table columns: #( #lat #lon ) as: #( #float #float ).
table float64ArrayAt: #lat.
```

A column is a name or a number from 1. The names come from the first record, or are column and the number when the dialect says `hasHeader: false`; an empty name is so too. A name that is there twice is an error (`SimdCSVHeaderError`) when it is used; `renameDuplicates` makes the names unique.

## Rows

A row is a new Array of `columnCount` Strings, `emptyFieldValue` for the empty ones. Where the records have several widths (`isRagged`), a shorter one is padded and a longer one is cut to the width of the first; with `strictFieldCount: true` that is a `SimdCSVFieldCountMismatch` when I am made.

`at:at:` costs one call of the backend, `column:` one for each 4,096 rows: take columns for bulk.

## Columns

- `column:` answers the Strings, `column:as:` a typed column (`#integer`, `#float`, `#floatComma`, `#symbol`, `#boolean`), `columns:as:` several at once.
- `float64ArrayAt:` answers a `Float64Array`, not a number where the cell is empty.
- A text that is not of the type is given to the block of `ifInvalid:` with the number of the record (the header included) and the one of the field; without a block it is a `SimdCSVConversionError`. The texts of `nullTexts:` are empty cells.

## Limits

The text has at most 4,294,967,294 units, and the index at most `maxIndexBytes` (1 GiB, 256 MiB in WebAssembly; `maxIndexBytes:` on my class side). Beyond, I am not made: `SimdCSVResourceError`. A `SimdCSVReader` has no such limits.
"
Class {
	#name : 'SimdCSVTable',
	#superclass : 'Object',
	#instVars : [
		'dialect',
		'units',
		'base',
		'limit',
		'origin',
		'isBytes',
		'index',
		'recordCount',
		'columnCount',
		'recordEnds',
		'rawNames',
		'columnNames'
	],
	#classVars : [
		'MaxIndexBytes'
	],
	#category : 'SimdCSV-Table',
	#package : 'SimdCSV',
	#tag : 'Table'
}

{ #category : 'instance creation' }
SimdCSVTable class >> on: aSource [
	^ self on: aSource dialect: SimdCSVDialect comma
]

{ #category : 'instance creation' }
SimdCSVTable class >> on: aSource dialect: aDialect [
	"A table of the whole of aSource, a String, a ByteArray, a FileReference or a stream"

	^ self new setSource: aSource dialect: aDialect copy
]

{ #category : 'accessing' }
SimdCSVTable class >> maxIndexBytes [
	"The most bytes of an index"

	^ MaxIndexBytes ifNil: [
		  SimdCSVReader isConstrained
			  ifTrue: [ 268435456 ]
			  ifFalse: [ 1073741824 ] ]
]

{ #category : 'accessing' }
SimdCSVTable class >> maxIndexBytes: anIntegerOrNil [
	"nil is the default"

	MaxIndexBytes := anIntegerOrNil
]

{ #category : 'accessing' }
SimdCSVTable class >> maxInputUnits [
	"SC_MAX_SPAN: the most units of a text"

	^ 4294967294
]

{ #category : 'initialization' }
SimdCSVTable >> setSource: aSource dialect: aDialect [
	dialect := aDialect.
	self readUnits: aSource.
	self makeIndex.
	self makeNames
]

{ #category : 'private - building' }
SimdCSVTable >> readUnits: aSource [
	"All the units are in memory, from base to limit"

	| input isFile batch |
	isFile := aSource isKindOf: AbstractFileReference.
	batch := 1048576.
	isFile ifTrue: [
		aSource size > self class maxInputUnits ifTrue: [ self signalTooMany: aSource size ].
		batch := aSource size + 1 max: 4096 ].
	input := SimdCSVInput on: aSource encoding: dialect encoding batch: batch max: self class maxInputUnits.
	isBytes := input isBytes.
	[
	(input start: dialect encoding) ifFalse: [ ^ self signalByteOrderMark ].
	input readAll ifFalse: [ self signalTooMany: input limit - input first + 1 ] ] ensure: [ isFile ifTrue: [ input close ] ].
	units := input source.
	base := input first.
	limit := input limit.
	origin := (input absolute: base) - base.
	limit - base + 1 > self class maxInputUnits ifTrue: [ self signalTooMany: limit - base + 1 ]
]

{ #category : 'private - building' }
SimdCSVTable >> makeIndex [
	| answer fields |
	base > limit ifTrue: [
		index := WordArray new: 0.
		recordCount := columnCount := 0.
		^ self ].
	answer := SimdCSVBackend
		          measure: units
		          from: base
		          to: limit
		          dialect: (dialect wordFor: units final: true lines: true exact: false).
	answer first = SimdCSVBackend statusError ifTrue: [ ^ self signalQuoteError: answer ].
	recordCount := answer at: 2.
	fields := answer at: 3.
	fields * 4 > self class maxIndexBytes ifTrue: [
		^ SimdCSVResourceError new
			  kind: #indexBytes;
			  actual: fields * 4;
			  limit: self class maxIndexBytes;
			  signal ].
	index := WordArray new: fields.
	self fillIndex ifTrue: [ self makeRecordEnds ].
	columnCount := recordCount = 0
		               ifTrue: [ 0 ]
		               ifFalse: [ self lastSlotOf: 1 ].
	(self isRagged and: [ dialect strictFieldCount ]) ifTrue: [ self signalMismatch ]
]

{ #category : 'private - building' }
SimdCSVTable >> fillIndex [
	"Index in slices, so that other processes can run; answer whether the records have several widths"

	| slice from to stored answer min max |
	slice := self sliceUnits.
	from := base.
	stored := 0.
	min := max := nil.
	[ from <= limit ] whileTrue: [
		to := from + slice - 1 min: limit.
		answer := SimdCSVBackend
			          index: units
			          base: base
			          from: from
			          to: to
			          dialect: (dialect wordFor: units final: to = limit lines: false exact: false)
			          into: index
			          from: stored + 1.
		answer first = SimdCSVBackend statusOK ifFalse: [ ^ self signalChanged ].
		(answer at: 2) > 0 ifTrue: [
			min := min
				       ifNil: [ answer at: 6 ]
				       ifNotNil: [ min min: (answer at: 6) ].
			max := max
				       ifNil: [ answer at: 7 ]
				       ifNotNil: [ max max: (answer at: 7) ] ].
		stored := stored + (answer at: 2).
		slice := (answer at: 4) = from
			         ifTrue: [ slice * 2 ]
			         ifFalse: [ self sliceUnits ].
		from := answer at: 4 ].
	stored = index size ifFalse: [ ^ self signalChanged ].
	^ min ~= max
]

{ #category : 'private - building' }
SimdCSVTable >> sliceUnits [
	^ SimdCSVReader isConstrained
		  ifTrue: [ 4194304 ]
		  ifFalse: [ 16777216 ]
]

{ #category : 'private - building' }
SimdCSVTable >> makeRecordEnds [
	"The slot of the last field of each record: the one whose end is no separator"

	| separator record |
	separator := dialect separator asInteger.
	recordEnds := WordArray new: recordCount.
	record := 0.
	1 to: index size do: [ :slot |
		| position |
		position := base + (index at: slot).
		(position > limit or: [ (units basicAt: position) ~= separator ]) ifTrue: [
			record := record + 1.
			recordEnds at: record put: slot ] ]
]

{ #category : 'private - building' }
SimdCSVTable >> makeNames [
	| plain |
	rawNames := Array new: columnCount.
	(dialect hasHeader and: [ recordCount > 0 ]) ifTrue: [
		plain := dialect copy.
		plain
			keepQuotedEmpty: false;
			strictFieldCount: false.
		self
			recordsFrom: 1
			to: 1
			types: nil
			empty: nil
			dialect: plain
			do: [ :rows :count :odd :record | rawNames := rows first ] ].
	columnNames := SimdCSVReader namesFrom: rawNames rename: false
]

{ #category : 'accessing' }
SimdCSVTable >> columnNames [
	"An Array of Strings"

	^ columnNames
]

{ #category : 'accessing' }
SimdCSVTable >> renameDuplicates [
	"A name a that comes again is a_2, then a_3"

	columnNames := SimdCSVReader namesFrom: rawNames rename: true
]

{ #category : 'accessing' }
SimdCSVTable >> columnCount [
	"The width of the first record"

	^ columnCount
]

{ #category : 'accessing' }
SimdCSVTable >> rowCount [
	"The records, but for the header"

	^ recordCount - self headerCount max: 0
]

{ #category : 'accessing' }
SimdCSVTable >> size [
	^ self rowCount
]

{ #category : 'testing' }
SimdCSVTable >> isRagged [
	"Do the records, the header included, have several widths?"

	^ recordEnds notNil
]

{ #category : 'rows' }
SimdCSVTable >> rowAt: anInteger [
	"A new Array of the Strings of a row"

	| answer |
	self checkRow: anInteger.
	self rowsFrom: anInteger to: anInteger do: [ :row | answer := row ].
	^ answer
]

{ #category : 'rows' }
SimdCSVTable >> at: anInteger at: aColumn [
	"The String of a cell"

	| types position answer record |
	self checkRow: anInteger.
	position := self positionOf: aColumn.
	types := ByteArray new: columnCount.
	types at: position put: 1.
	record := anInteger + self headerCount.
	self
		recordsFrom: record
		to: record
		types: types
		empty: dialect emptyFieldValue
		dialect: dialect
		do: [ :rows :count :odd :first | answer := rows first first ].
	^ answer
]

{ #category : 'rows' }
SimdCSVTable >> rowsFrom: start to: stop [
	"An Array of rows"

	start > stop ifTrue: [ ^ #(  ) ].
	self
		checkRow: start;
		checkRow: stop.
	^ Array new: stop - start + 1 streamContents: [ :out | self rowsFrom: start to: stop do: [ :row | out nextPut: row ] ]
]

{ #category : 'rows' }
SimdCSVTable >> do: aBlock [
	"Each row"

	self rowCount = 0 ifTrue: [ ^ self ].
	self rowsFrom: 1 to: self rowCount do: aBlock
]

{ #category : 'rows' }
SimdCSVTable >> asArray [
	"An Array of all the rows"

	^ self rowsFrom: 1 to: self rowCount
]

{ #category : 'columns' }
SimdCSVTable >> column: aColumn [
	"An Array of the Strings of a column"

	^ self column: aColumn as: #string
]

{ #category : 'columns' }
SimdCSVTable >> column: aColumn as: aType [
	"An Array of the values of a column: #string, #integer, #float, #floatComma, #symbol or #boolean"

	^ self column: aColumn as: aType ifInvalid: nil
]

{ #category : 'columns' }
SimdCSVTable >> column: aColumn as: aType ifInvalid: aBlock [
	"The value of aBlock, of the text, the number of the record and the one of the field, for a text that is not of the type"

	^ (self columns: { aColumn } as: { aType } ifInvalid: aBlock) first
]

{ #category : 'columns' }
SimdCSVTable >> columns: someColumns as: someTypes [
	"An Array of columns, each an Array"

	^ self columns: someColumns as: someTypes ifInvalid: nil
]

{ #category : 'columns' }
SimdCSVTable >> columns: someColumns as: someTypes ifInvalid: aBlock [
	"An Array of columns, each an Array"

	| columns answer |
	columns := self columnsOf: someColumns as: someTypes ifInvalid: aBlock.
	answer := columns collect: [ :each | Array new: self rowCount ].
	self cellsOf: columns empty: self columnEmpty do: [ :column :number :row :cell | (answer at: number) at: row put: (cell == self columnEmpty
			 ifTrue: [ dialect emptyFieldValue ]
			 ifFalse: [ cell ]) ].
	^ answer
]

{ #category : 'columns' }
SimdCSVTable >> float64ArrayAt: aColumn [
	"The Floats of a column, not a number for the empty cells"

	^ self float64ArrayAt: aColumn ifInvalid: nil
]

{ #category : 'columns' }
SimdCSVTable >> float64ArrayAt: aColumn ifInvalid: aBlock [
	"The Floats of a column, not a number for the empty cells, and the value of aBlock for a text that is no Float (not a number when it is nil)"

	| columns answer |
	columns := self columnsOf: { aColumn } as: #( #float ) ifInvalid: aBlock.
	answer := Float64Array new: self rowCount.
	self cellsOf: columns empty: nil do: [ :column :number :row :cell |
		answer at: row put: (cell == SimdCSVReader emptyMark
				 ifTrue: [ Float nan ]
				 ifFalse: [ cell ifNil: [ Float nan ] ]) ].
	^ answer
]

{ #category : 'printing' }
SimdCSVTable >> printOn: aStream [
	super printOn: aStream.
	aStream
		nextPut: $(;
		print: self rowCount;
		nextPutAll: ' rows, ';
		print: columnCount;
		nextPutAll: ' columns)'
]

{ #category : 'private - cells' }
SimdCSVTable >> columnEmpty [
	"The cell that the builder makes of an empty field"

	^ SimdCSVReader emptyMark
]

{ #category : 'private - cells' }
SimdCSVTable >> columnsOf: someColumns as: someTypes ifInvalid: aBlock [
	"SimdCSVColumns, each another field"

	| columns |
	someColumns size = someTypes size ifFalse: [ ^ SimdCSVArgumentError signal: 'As many types as columns are expected' ].
	columns := someColumns asArray with: someTypes asArray collect: [ :each :type |
		           | position |
		           type == #ignored ifTrue: [ ^ SimdCSVArgumentError signal: 'A column that is taken has a type' ].
		           position := self positionOf: each.
		           (SimdCSVColumn type: type)
			           position: position;
			           name: (columnNames at: position);
			           invalidBlock: aBlock;
			           yourself ].
	(columns collect: [ :each | each position ]) asSet size = columns size ifFalse: [ ^ SimdCSVArgumentError signal: 'A column is taken twice' ].
	^ columns
]

{ #category : 'private - cells' }
SimdCSVTable >> cellsOf: columns empty: empty do: aBlock [
	"Evaluate aBlock with each column, its number in columns, the number of the row and the value of the cell, which is the mark of an empty cell for a text of nullTexts; empty is what the builder makes of an empty field"

	| types places |
	(self rowCount = 0 or: [ columns isEmpty ]) ifTrue: [ ^ self ].
	types := ByteArray new: columnCount.
	columns do: [ :each | types at: each position put: each code ].
	places := columns collect: [ :each | columns count: [ :other | other position <= each position ] ].
	self
		recordsFrom: 1 + self headerCount
		to: recordCount
		types: types
		empty: empty
		dialect: dialect
		do: [ :rows :count :odd :record |
			columns withIndexDo: [ :column :number |
				| place row plain |
				place := places at: number.
				row := record - self headerCount.
				plain := column isPlain or: [ odd = 0 and: [ column isNumber ] ].
				1 to: count do: [ :i |
					| cell |
					cell := (rows at: i) at: place.
					plain ifFalse: [ cell := self valueOf: cell in: column record: record + i - 1 ].
					aBlock value: column value: number value: row + i - 1 value: cell ] ] ]
]

{ #category : 'private - cells' }
SimdCSVTable >> valueOf: cell in: aColumn record: record [
	"The value of a cell of the builder"

	cell isString ifFalse: [ ^ cell ].
	(cell isEmpty or: [ dialect nullTexts includes: cell ]) ifTrue: [ ^ SimdCSVReader emptyMark ].
	^ aColumn valueOf: cell ifInvalid: [ self valueOfInvalid: cell in: aColumn record: record ]
]

{ #category : 'private - cells' }
SimdCSVTable >> valueOfInvalid: text in: aColumn record: record [
	| error |
	aColumn invalidBlock ifNotNil: [ :block | ^ block cull: text cull: record cull: aColumn position ].
	error := SimdCSVConversionError new.
	error
		text: text;
		type: aColumn type;
		columnName: aColumn name;
		field: aColumn position.
	self place: error record: record.
	error position: (self startOfSlot: (self firstSlotOf: record) + aColumn position - 1) + origin.
	^ error signal
]

{ #category : 'private - rows' }
SimdCSVTable >> headerCount [
	^ dialect hasHeader
		  ifTrue: [ 1 ]
		  ifFalse: [ 0 ]
]

{ #category : 'private - rows' }
SimdCSVTable >> checkRow: anInteger [
	(anInteger isInteger and: [ anInteger between: 1 and: self rowCount ]) ifFalse: [
		SubscriptOutOfBounds signalFor: anInteger lowerBound: 1 upperBound: self rowCount ]
]

{ #category : 'private - rows' }
SimdCSVTable >> positionOf: aColumn [
	"The number of a column, a number or a name"

	aColumn isInteger ifFalse: [ ^ SimdCSVReader positionOf: aColumn in: columnNames ].
	(aColumn between: 1 and: columnCount) ifFalse: [ SubscriptOutOfBounds signalFor: aColumn lowerBound: 1 upperBound: columnCount ].
	^ aColumn
]

{ #category : 'private - rows' }
SimdCSVTable >> rowsFrom: start to: stop do: aBlock [
	self
		recordsFrom: start + self headerCount
		to: stop + self headerCount
		types: nil
		empty: dialect emptyFieldValue
		dialect: dialect
		do: [ :rows :count :odd :record | 1 to: count do: [ :i | aBlock value: (rows at: i) ] ]
]

{ #category : 'private - rows' }
SimdCSVTable >> recordsFrom: start to: stop types: types empty: empty dialect: aDialect do: aBlock [
	"Evaluate aBlock with batches: an Array whose first elements are rows, the number of these, the number of their odd cells, and the number of the record of the first"

	| rows slot last record answer count |
	rows := Array new: (stop - start + 1 min: 4096).
	slot := self firstSlotOf: start.
	last := self lastSlotOf: stop.
	record := start.
	[ slot <= last ] whileTrue: [
		answer := SimdCSVBackend
			          rows: units
			          base: base
			          to: limit
			          dialect: (aDialect wordFor: units final: true lines: false exact: false)
			          index: index
			          from: slot
			          to: last
			          types: types
			          fieldCount: columnCount
			          into: rows
			          from: 1
			          empty: empty
			          budget: 4194304.
		count := answer at: 2.
		answer first = SimdCSVBackend statusError ifTrue: [ ^ self signalBuildError: answer record: record + count ].
		aBlock value: rows value: count value: (answer at: 4) value: record.
		record := record + count.
		slot := answer at: 3 ]
]

{ #category : 'private - positions' }
SimdCSVTable >> firstSlotOf: record [
	record = 1 ifTrue: [ ^ 1 ].
	^ (self lastSlotOf: record - 1) + 1
]

{ #category : 'private - positions' }
SimdCSVTable >> lastSlotOf: record [
	^ recordEnds
		  ifNil: [ index size // recordCount * record ]
		  ifNotNil: [ recordEnds at: record ]
]

{ #category : 'private - positions' }
SimdCSVTable >> startOfSlot: slot [
	"The position of the unit after the end of the field before slot; CRLF is one end"

	| position |
	slot = 1 ifTrue: [ ^ base ].
	position := base + (index at: slot - 1) + 1.
	(dialect lineEnd ~~ #lf and: [
		 position <= limit and: [ (units basicAt: position) = 10 and: [ (units basicAt: position - 1) = 13 ] ] ]) ifTrue: [ position := position + 1 ].
	^ position
]

{ #category : 'private - positions' }
SimdCSVTable >> startOfRecord: record [
	| position unit |
	position := self startOfSlot: (self firstSlotOf: record).
	dialect skipEmptyLines ifFalse: [ ^ position ].
	[
	unit := units basicAt: position.
	unit = 10 or: [ unit = 13 and: [ dialect lineEnd ~~ #lf ] ] ] whileTrue: [ position := position + 1 ].
	^ position
]

{ #category : 'private - positions' }
SimdCSVTable >> lineOf: position [
	"The line of the unit at position, from 1"

	| line anyEnd |
	line := 1.
	anyEnd := dialect lineEnd ~~ #lf.
	base to: position - 1 do: [ :i |
		| unit |
		unit := units basicAt: i.
		(unit = 10 or: [ anyEnd and: [ unit = 13 and: [ (units basicAt: i + 1) ~= 10 ] ] ]) ifTrue: [ line := line + 1 ] ].
	^ line
]

{ #category : 'private - errors' }
SimdCSVTable >> place: anError record: record [
	| start |
	start := self startOfRecord: record.
	self place: anError record: record start: start
]

{ #category : 'private - errors' }
SimdCSVTable >> place: anError record: record start: start [
	anError
		record: record;
		line: (self lineOf: start);
		position: start + origin;
		unitName: self unitName
]

{ #category : 'private - errors' }
SimdCSVTable >> unitName [
	^ isBytes
		  ifTrue: [ 'byte' ]
		  ifFalse: [ 'character' ]
]

{ #category : 'private - errors' }
SimdCSVTable >> signalBuildError: answer record: record [
	| error |
	(answer at: 5) = SimdCSVBackend codeInvalidUTF8 ifFalse: [ ^ self signalChanged ].
	error := SimdCSVInvalidEncoding new.
	self place: error record: record.
	error
		code: (answer at: 5);
		position: (answer at: 6) + origin;
		field: (answer at: 8).
	columnNames ifNotNil: [ error columnName: (columnNames at: error field ifAbsent: [ nil ]) ].
	^ error signal
]

{ #category : 'private - errors' }
SimdCSVTable >> signalQuoteError: answer [
	"As primitiveMeasure answered it"

	| error |
	error := SimdCSVQuoteError new.
	self place: error record: (answer at: 2) + 1 start: (answer at: 4).
	error
		code: (answer at: 6);
		position: (answer at: 7) + origin.
	^ error signal
]

{ #category : 'private - errors' }
SimdCSVTable >> signalMismatch [
	"The first record of another width than the first one"

	| record error |
	record := 2.
	[ (self lastSlotOf: record) - (self lastSlotOf: record - 1) = columnCount ] whileTrue: [ record := record + 1 ].
	error := SimdCSVFieldCountMismatch new.
	error
		expected: columnCount;
		actual: (self lastSlotOf: record) - (self lastSlotOf: record - 1);
		code: SimdCSVBackend codeFieldCount.
	self place: error record: record.
	^ error signal
]

{ #category : 'private - errors' }
SimdCSVTable >> signalByteOrderMark [
	^ SimdCSVInvalidEncoding new
		  isByteOrderMark: true;
		  code: SimdCSVBackend codeInvalidUTF8;
		  position: 1;
		  record: 1;
		  line: 1;
		  field: 1;
		  signal
]

{ #category : 'private - errors' }
SimdCSVTable >> signalTooMany: count [
	^ SimdCSVResourceError new
		  kind: #inputUnits;
		  actual: count;
		  limit: self class maxInputUnits;
		  unitName: (isBytes == false
				   ifTrue: [ 'character' ]
				   ifFalse: [ 'byte' ]);
		  signal
]

{ #category : 'private - errors' }
SimdCSVTable >> signalChanged [
	^ SimdCSVArgumentError signal: 'The source was changed while it was read'
]
