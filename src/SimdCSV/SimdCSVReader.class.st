"
I read records from CSV: Arrays of Strings, or objects whose fields are typed, converted and named.

```smalltalk
(SimdCSVReader on: 'data.csv' asFileReference)
	separator: $;;
	skipHeader;
	recordClass: StopTime;
	addField: #tripId:;
	addField: #arrivalTime: converter: [ :text | Time readFrom: text ] cached: true;
	addIntegerField: #sequence:;
	addIgnoredField;
	upToEnd
```

I have the protocol of `NeoCSVReader`, so that its users need only change the name of the class, and the messages below.

## Sources

`on:` takes a String, a ByteArray, a FileReference or a stream; `on:do:` also closes it. Bytes are UTF-8 (or `encoding: #latin1`). A collection, and a `ReadStream` on one, is read in place; a file (a FileReference, or the stream of its `readStream`) is read as bytes, which is the fast way. I read ahead by a batch (`batchBytes:`), so that the position of a stream is unspecified once I have begun. A socket is read as it comes; another stream that waits until it has what it is asked for, such as a pipe or the body of an HTTP answer, gives 4 KiB, or its end, before the first record.

## Fields

- Nothing declared: a record is an Array of the Strings of its fields, as many as it has. `readHeader`, `skipHeader` and `fieldCount:` fix the width: a shorter record is padded, a longer one is cut.
- By position: `addField`, `addIntegerField`, `addFloatField`, `addSymbolField`, `addIgnoredField` and the others, in the order of the fields. The forms with an accessor (a selector or a block) and those with `At:` make instances of `recordClass:`.
- By name, after `readHeader` or `namedColumnsConfiguration`: `selectColumns:` takes the columns of those names, in that order; `column:as:` and `column:converter:` change the type of a column, and take it too when it was not selected. With `recordClass:` Dictionary the keys are Symbols.

The types are `#string`, `#integer`, `#float`, `#floatComma`, `#symbol` and `#boolean`. A converter is a block of the text; with `cached: true` it is evaluated once for each of the first 10,000 texts.

An empty field is never given to an accessor or a converter; `emptyFieldValue:` (nil) is its value, and with `#passNil` the converters get nil. A typed or converted field whose text is one of `nullTexts:` is an empty one. A text that is not of the type of its column is given to the block of `ifInvalid:` (the text, the number of the record and the one of the field), whose value is the cell; without a block it is a `SimdCSVConversionError`.

## Records and errors

Accessors, converters and conversions run when a record is reached by `next` or `do:`, never ahead; I have passed a record when the block of `do:` is called. An error of the text is signalled when its record is reached, after all those before it. I then stand on that record: `next` signals again, `skipFailedRecord` passes it (the whole input after a `SimdCSVResourceError`), and does nothing when no error was signalled for the next record. At the end, `next` answers nil.

```smalltalk
[ reader do: [ :record | self handle: record ] ]
	on: SimdCSVParseError
	do: [ :error |
		reader skipFailedRecord.
		error retry ]
```

(`upToEnd` would lose the records before the error.)

`recordNumber` is the number of the record read last, the header included. Configuration messages may come at any time, also after a first `next`; they act from the next record on, but for `encoding:`. One process may use me at a time.

## Limits

A record has at most `maxRecordBytes:` units (64 MiB; 16 MiB in WebAssembly and in a VM whose old space is bounded, that is with its parameter 67; up to two more, the size of a line end, pass) and `maxFields:` fields (65,536). A limit that was passed may be raised: the record is then read.

## Semantics

Compared with NeoCSV, where strict means `beStrict` (field counts) or `beStrictQuoting` (quotes):

| case | NeoCSV | lenient (default) | strict |
|---|---|---|---|
| line ends | LF, CR, CRLF, mixed | same (lineEnd: #lf is LF only) | same |
| last line end | optional | optional | optional |
| empty input | no records | no records | no records |
| blank line, nothing declared | the first record fixes the width | a record of one empty field | same; beStrict: mismatch with another width |
| blank line, width declared | record of nils | record of nils; skipEmptyLines drops it | mismatch unless the width is 1 |
| records of several widths, nothing declared | cut and padded to the first | own widths, nothing lost | beStrict: mismatch |
| short or long record, width declared | nil or cut, desync on a quoted newline | nil or cut, no desync | beStrict: mismatch |
| empty field, quoted or not | both emptyFieldValue | both; keepQuotedEmpty: an empty String for the quoted one | same |
| doubled quotes, separators and line ends in quotes | yes | yes | yes |
| quote inside an unquoted field | literal | literal | beStrictQuoting: SimdCSVQuoteError |
| text after a closing quote | an extra field | part of the field | beStrictQuoting: SimdCSVQuoteError |
| unterminated quote | accepted | accepted to the end, up to maxRecordBytes | beStrictQuoting: SimdCSVQuoteError |
| spaces | data | data | data; around a quoted field an error of beStrictQuoting |
| byte order mark | kept | skipped (not in Latin-1) | same |
| NUL and controls | data | data | data |
| invalid UTF-8 | the error of Zinc | SimdCSVInvalidEncoding, in the fields that are built | same |
| integer field 12abc | 12 | SimdCSVConversionError | same |
| float field 1e3 or 1 | an Integer | a Float | same |
| duplicate names, Dictionary | the last wins | SimdCSVHeaderError, or renameDuplicates | same |
| empty name in the header | does not understand asSymbol | column and its number | same |
| addField and the like after a first next | works | works | works |
| stream position while reading | exact | read ahead; a socket as it comes | same |

Strings are never shared between cells (`emptyFieldValue` is), and each has the narrowest class.

## Not provided

`unsupportedNeoSelectors` on my class side lists what NeoCSVReader has and I do not: `emptyFieldInput:` (`nullTexts:` does a part of it), `resetStream`, `skipLine`, `skipRecord` (`skip` is the same), `addFieldAccessor:` and the private messages.
"
Class {
	#name : 'SimdCSVReader',
	#superclass : 'Object',
	#instVars : [
		'source',
		'input',
		'started',
		'ended',
		'dialect',
		'index',
		'base',
		'indexLimit',
		'indexFinal',
		'indexTo',
		'slot',
		'indexRecords',
		'indexLines',
		'lineBase',
		'rows',
		'rowCount',
		'rowNext',
		'rowSlot',
		'recordsDone',
		'pendingError',
		'indexError',
		'failed',
		'needsWork',
		'recordClass',
		'recordClassIsIndexable',
		'fieldCount',
		'columns',
		'namedColumns',
		'selection',
		'typedColumns',
		'rawHeader',
		'header',
		'renameDuplicates',
		'invalidBlock',
		'maxRecordBytes',
		'maxFields',
		'batchBytes',
		'planned',
		'width',
		'types',
		'rowColumns',
		'order',
		'objectMode',
		'alwaysWork',
		'hasNumbers',
		'passNil',
		'plain',
		'nullTexts',
		'emptyMark',
		'builderEmpty',
		'firstWidth',
		'firstWidthRecord',
		'positions',
		'selected',
		'rowGoal',
		'indexGoal',
		'placeRow',
		'placeSlot',
		'linesStart',
		'linesStop',
		'linesCount'
	],
	#classVars : [
		'EmptyMark'
	],
	#category : 'SimdCSV-Reading',
	#package : 'SimdCSV',
	#tag : 'Reading'
}

{ #category : 'instance creation' }
SimdCSVReader class >> on: aSource [
	"A reader of a String, a ByteArray, a FileReference or a stream"

	^ self new
		  on: aSource;
		  yourself
]

{ #category : 'instance creation' }
SimdCSVReader class >> on: aSource do: aBlock [
	"The value of aBlock for a reader of aSource, which is closed"

	| reader |
	reader := self on: aSource.
	^ [ aBlock value: reader ] ensure: [ reader close ]
]

{ #category : 'accessing' }
SimdCSVReader class >> defaultMaxRecordBytes [
	^ self isConstrained
		  ifTrue: [ 16777216 ]
		  ifFalse: [ 67108864 ]
]

{ #category : 'accessing' }
SimdCSVReader class >> defaultMaxFields [
	^ 65536
]

{ #category : 'accessing' }
SimdCSVReader class >> emptyMark [
	"The cell of an empty field, where no value of a cell can be that of a field"

	^ EmptyMark ifNil: [ EmptyMark := Object new ]
]

{ #category : 'testing' }
SimdCSVReader class >> isConstrained [
	"Is the object memory small, as in WebAssembly, or bounded?"

	^ SimdCSVBackend isBounded
]

{ #category : 'accessing' }
SimdCSVReader class >> unsupportedNeoSelectors [
	"The selectors of NeoCSVReader that I do not have; most are private"

	^ #( #addFieldAccessor: #applyAccessor:on:with: #emptyFieldInput: #handleEndOfRecord #handleSeparator #nextChar #peekChar
	     #peekEndOfLine #peekFor: #peekQuote #peekSeparator #readAtEndOrEndOfLine #readEndOfLine #readEndOfQuotedField #readField
	     #readFirstRecord #readNextRecord #readNextRecordAsArray #readNextRecordAsObject #readNextRecordWithFieldAccessors:
	     #readNextRecordWithoutFieldAccessors: #readQuote #readQuotedField #readSeparator #readUnquotedField #recordClassNew
	     #recordClassNew: #recordClassStreamContents: #resetStream #skipField #skipLine #skipRecord #stringStreamContents: )
]

{ #category : 'initialization' }
SimdCSVReader >> initialize [
	super initialize.
	dialect := SimdCSVDialect comma.
	recordClass := Array.
	recordClassIsIndexable := true.
	started := ended := failed := needsWork := renameDuplicates := namedColumns := planned := false.
	maxRecordBytes := self class defaultMaxRecordBytes.
	maxFields := self class defaultMaxFields.
	batchBytes := SimdCSVBackend batchBytes.
	indexTo := indexRecords := indexLines := lineBase := 0.
	slot := 1.
	rowCount := recordsDone := 0.
	rowNext := 1
]

{ #category : 'initialization' }
SimdCSVReader >> on: aSource [
	source := aSource
]

{ #category : 'initialization' }
SimdCSVReader >> close [
	"Close the stream that I read; there are no more records"

	self goToEnd.
	input
		ifNotNil: [ input close ]
		ifNil: [ (source respondsTo: #close) ifTrue: [ source close ] ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> dialect [
	"A copy"

	^ dialect copy
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> dialect: aDialect [
	"Read as aDialect says, which I copy"

	self checkEncoding: aDialect encoding.
	self changeDialect: [ dialect := aDialect copy ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> separator: aCharacter [
	"The Character between the fields, a comma by default"

	aCharacter = dialect separator ifTrue: [ ^ self ].
	self changeDialect: [ dialect separator: aCharacter ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> quote: aCharacterOrNil [
	"The Character around quoted fields, a double quote by default, or nil when there are none"

	aCharacterOrNil = dialect quote ifTrue: [ ^ self ].
	self changeDialect: [ dialect quote: aCharacterOrNil ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> beStrictQuoting [
	"Signal SimdCSVQuoteError for a quote inside an unquoted field, text after a closing quote and an unterminated quote"

	dialect strictQuoting ifTrue: [ ^ self ].
	self changeDialect: [ dialect strictQuoting: true ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> skipEmptyLines [
	"A blank line is no record"

	dialect skipEmptyLines ifTrue: [ ^ self ].
	self changeDialect: [ dialect skipEmptyLines: true ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> beStrict [
	"Signal SimdCSVFieldCountMismatch for a record whose fields are not as many as the declared ones, or as those of the first record"

	dialect strictFieldCount ifTrue: [ ^ self ].
	self changeConfiguration: [ dialect strictFieldCount: true ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> keepQuotedEmpty [
	"A quoted empty field is an empty String, not emptyFieldValue"

	dialect keepQuotedEmpty ifTrue: [ ^ self ].
	self changeConfiguration: [ dialect keepQuotedEmpty: true ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> encoding: aSymbol [
	"#utf8 or #latin1: what the bytes are; before the first record"

	self checkEncoding: aSymbol.
	self changeConfiguration: [ dialect encoding: aSymbol ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> emptyFieldValue: anObject [
	"The value of empty and of missing fields, nil by default. With #passNil the converters get nil for them, and their value is used"

	anObject == dialect emptyFieldValue ifTrue: [ ^ self ].
	self changeConfiguration: [ dialect emptyFieldValue: anObject ]
]

{ #category : 'configuration - dialect' }
SimdCSVReader >> nullTexts: aCollection [
	"The texts, such as NA, that are empty fields in a typed or converted column"

	self changeConfiguration: [ dialect nullTexts: aCollection ]
]

{ #category : 'configuration - limits' }
SimdCSVReader >> maxRecordBytes [
	^ maxRecordBytes
]

{ #category : 'configuration - limits' }
SimdCSVReader >> maxRecordBytes: anInteger [
	"The longest record, in bytes (characters for characters)"

	(anInteger between: 1 and: 4294967290) ifFalse: [ ^ SimdCSVArgumentError signal: 'maxRecordBytes: is from 1 to 4294967290' ].
	maxRecordBytes := anInteger.
	self limitsChanged
]

{ #category : 'configuration - limits' }
SimdCSVReader >> maxFields [
	^ maxFields
]

{ #category : 'configuration - limits' }
SimdCSVReader >> maxFields: anInteger [
	"The most fields of a record"

	(anInteger between: 1024 and: 16777216) ifFalse: [ ^ SimdCSVArgumentError signal: 'maxFields: is from 1024 to 16777216' ].
	maxFields := anInteger.
	self forgetError: #fields
]

{ #category : 'configuration - limits' }
SimdCSVReader >> batchBytes: anInteger [
	"The units that are read and indexed at a time, 1 MiB by default"

	(anInteger between: 1 and: 1073741824) ifFalse: [ ^ SimdCSVArgumentError signal: 'batchBytes: is from 1 to 1073741824' ].
	batchBytes := anInteger.
	self limitsChanged
]

{ #category : 'configuration - records' }
SimdCSVReader >> recordClass: anObject [
	"The class of the records: Array, another class of indexable collections, or with fields declared any class"

	anObject == recordClass ifTrue: [ ^ self ].
	self changeConfiguration: [ recordClass := anObject ]
]

{ #category : 'configuration - records' }
SimdCSVReader >> recordClassIsIndexable: aBoolean [
	"Are the records collections of their fields? The messages that add a field set this"

	aBoolean == recordClassIsIndexable ifTrue: [ ^ self ].
	self changeConfiguration: [ recordClassIsIndexable := aBoolean ]
]

{ #category : 'configuration - records' }
SimdCSVReader >> fieldCount: anInteger [
	"The width of the records, nil for each its own; declared fields come before it"

	anInteger ifNotNil: [
		(anInteger between: 1 and: 16777216) ifFalse: [ ^ SimdCSVArgumentError signal: 'fieldCount: is from 1 to 16777216, or nil' ] ].
	anInteger = fieldCount ifTrue: [ ^ self ].
	self changeConfiguration: [ fieldCount := anInteger ]
]

{ #category : 'configuration - records' }
SimdCSVReader >> ifInvalid: aBlock [
	"The block of the text, the number of the record and the number of the field whose value is the cell, for a text that is not of the type of its column; for each typed column without a block of its own"

	aBlock == invalidBlock ifTrue: [ ^ self ].
	self changeConfiguration: [ invalidBlock := aBlock ]
]

{ #category : 'configuration - header' }
SimdCSVReader >> header [
	"The names of the columns, nil before readHeader"

	^ header
]

{ #category : 'configuration - header' }
SimdCSVReader >> readHeader [
	"Read a record as the names of the columns, which fix the width of the records, and answer the names. An empty name is column and its number"

	^ self readHeaderUnique: false
]

{ #category : 'configuration - header' }
SimdCSVReader >> skipHeader [
	"Read the header"

	self readHeader
]

{ #category : 'configuration - header' }
SimdCSVReader >> namedColumnsConfiguration [
	"Read the header, and read each record as a Dictionary from the names of the columns, as Symbols, to the values of the fields that are not empty. Answer the header"

	| names |
	self refuseWithFields.
	names := self readHeaderUnique: true.
	self changeConfiguration: [
		recordClass := Dictionary.
		recordClassIsIndexable := false.
		namedColumns := true ].
	^ names
]

{ #category : 'configuration - header' }
SimdCSVReader >> numberedColumnsConfiguration [
	"Without a header: read each record as a Dictionary, from the names column1 and so on, as many as the next record has fields. Answer the names"

	self refuseWithFields.
	self configurationChanged.
	self hasIndexedRecord ifFalse: [
		rawHeader := #(  ).
		^ self header: rawHeader ].
	rawHeader := Array new: (self lastSlotFrom: slot) - slot + 1.
	self header: (self namesFrom: rawHeader).
	self changeConfiguration: [
		fieldCount := header size.
		recordClass := Dictionary.
		recordClassIsIndexable := false.
		namedColumns := true ].
	^ header
]

{ #category : 'configuration - header' }
SimdCSVReader >> renameDuplicates [
	"A name a that comes again in the header is a_2, then a_3"

	self changeConfiguration: [ renameDuplicates := true ].
	rawHeader ifNotNil: [ self header: (self namesFrom: rawHeader) ]
]

{ #category : 'configuration - columns' }
SimdCSVReader >> selectColumns: names [
	"Take the columns of these names only, in this order"

	| columnPositions |
	self refuseWithFields.
	columnPositions := names asArray collect: [ :each | self positionOfColumn: each ].
	columnPositions asSet size = columnPositions size ifFalse: [ ^ SimdCSVArgumentError signal: 'A column is selected twice' ].
	self changeConfiguration: [
		selection := columnPositions asOrderedCollection.
		selected := columnPositions asSet ]
]

{ #category : 'configuration - columns' }
SimdCSVReader >> column: aName as: aType [
	"The type of a column: #string, #integer, #float, #floatComma, #symbol or #boolean"

	self column: aName as: aType ifInvalid: nil
]

{ #category : 'configuration - columns' }
SimdCSVReader >> column: aName as: aType ifInvalid: aBlock [
	"The type of a column, and the block for the texts that are not of it"

	self setColumn: aName to: ((SimdCSVColumn type: aType)
			 invalidBlock: aBlock;
			 yourself)
]

{ #category : 'configuration - columns' }
SimdCSVReader >> column: aName converter: aBlock [
	"The block that makes the value of a cell of its text"

	self column: aName converter: aBlock cached: false
]

{ #category : 'configuration - columns' }
SimdCSVReader >> column: aName converter: aBlock cached: aBoolean [
	"The block that makes the value of a cell of its text, once for each text when cached"

	self setColumn: aName to: (SimdCSVColumn converter: aBlock cached: aBoolean)
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addField [
	"The next field, as a String of an indexable record"

	self addIndexable: (SimdCSVColumn type: #string)
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addField: accessor [
	"The next field, whose String is given to accessor: a selector of the record, or a block of the record and the value"

	self add: (SimdCSVColumn type: #string) accessor: accessor
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addField: accessor converter: aBlock [
	"The next field, whose String is converted by aBlock and given to accessor"

	self addField: accessor converter: aBlock cached: false
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addField: accessor converter: aBlock cached: aBoolean [
	"The next field, whose String is converted by aBlock, once for each text when cached, and given to accessor"

	self add: (SimdCSVColumn converter: aBlock cached: aBoolean) accessor: accessor
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFieldAt: key [
	"The next field, whose String is put at key"

	self add: (SimdCSVColumn type: #string) at: key
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFieldAt: key converter: aBlock [
	"The next field, whose String is converted by aBlock and put at key"

	self add: (SimdCSVColumn converter: aBlock cached: false) at: key
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFieldConverter: aBlock [
	"The next field of an indexable record, whose String is converted by aBlock"

	self addFieldConverter: aBlock cached: false
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFieldConverter: aBlock cached: aBoolean [
	"The next field of an indexable record, whose String is converted by aBlock, once for each text when cached"

	self addIndexable: (SimdCSVColumn converter: aBlock cached: aBoolean)
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFields: accessors [
	accessors do: [ :each | self addField: each ]
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFieldsAt: keys [
	keys do: [ :each | self addFieldAt: each ]
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addPlainField [
	self addField
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addPlainFields: count [
	count timesRepeat: [ self addPlainField ]
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addIgnoredField [
	"The next field, which is not in the records"

	self addColumn: (SimdCSVColumn type: #ignored)
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addIgnoredFields: count [
	count timesRepeat: [ self addIgnoredField ]
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addIntegerField [
	self addIndexable: (SimdCSVColumn type: #integer)
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addIntegerField: accessor [
	self add: (SimdCSVColumn type: #integer) accessor: accessor
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addIntegerFieldAt: key [
	self add: (SimdCSVColumn type: #integer) at: key
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addIntegerFields: count [
	count timesRepeat: [ self addIntegerField ]
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFloatField [
	self addIndexable: (SimdCSVColumn type: #float)
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFloatField: accessor [
	self add: (SimdCSVColumn type: #float) accessor: accessor
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFloatFieldAt: key [
	self add: (SimdCSVColumn type: #float) at: key
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFloatFields: count [
	count timesRepeat: [ self addFloatField ]
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFloatFieldRadixPointComma [
	"The next field of an indexable record, a Float with a decimal comma"

	self addIndexable: (SimdCSVColumn type: #floatComma)
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFloatFieldRadixPointComma: accessor [
	self add: (SimdCSVColumn type: #floatComma) accessor: accessor
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addFloatFieldRadixPointCommaAt: key [
	self add: (SimdCSVColumn type: #floatComma) at: key
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addSymbolField [
	self addIndexable: (SimdCSVColumn type: #symbol)
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addSymbolField: accessor [
	self add: (SimdCSVColumn type: #symbol) accessor: accessor
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addSymbolFieldAt: key [
	self add: (SimdCSVColumn type: #symbol) at: key
]

{ #category : 'configuration - fields' }
SimdCSVReader >> addSymbolFields: count [
	count timesRepeat: [ self addSymbolField ]
]

{ #category : 'reading' }
SimdCSVReader >> atEnd [
	"Is there no record left, nor an error in the place of one?"

	rowNext <= rowCount ifTrue: [ ^ false ].
	[ slot > indexTo ] whileTrue: [
		pendingError ifNotNil: [ ^ false ].
		self indexMore ifFalse: [ ^ true ] ].
	^ false
]

{ #category : 'reading' }
SimdCSVReader >> next [
	"The next record, nil at the end; or signal the error that stands in its place"

	| record |
	self hasRecord ifFalse: [ ^ nil ].
	rowNext > rowCount ifTrue: [ ^ self signalPending ].
	record := rows at: rowNext.
	needsWork ifTrue: [
		failed := true.
		record := self recordFrom: record ].
	failed := false.
	rows at: rowNext put: nil.
	rowNext := rowNext + 1.
	^ record
]

{ #category : 'reading' }
SimdCSVReader >> skip [
	"Pass a record without reading its fields; nothing at the end. No row is built for it"

	rowNext <= rowCount
		ifTrue: [ rowNext := rowNext + 1 ]
		ifFalse: [
			self hasIndexedRecord ifFalse: [ ^ self ].
			self passIndexedRecord ].
	failed := false.
	self recordNumber = firstWidthRecord ifTrue: [
		firstWidth := firstWidthRecord := nil.
		self configurationChanged ]
]

{ #category : 'reading' }
SimdCSVReader >> skip: count [
	count timesRepeat: [ self skip ]
]

{ #category : 'reading' }
SimdCSVReader >> skipFailedRecord [
	"Pass the record whose error was signalled: up to its end as the lenient rules see it, or to the end of the input when it has none or is beyond a limit. Nothing when no error was signalled since a record was passed: what comes next is not lost unseen"

	failed ifFalse: [ ^ self ].
	rowNext <= rowCount ifTrue: [ ^ self skip ].
	failed := false.
	pendingError ifNil: [ ^ self ].
	pendingError first == #build ifTrue: [ ^ self passIndexedRecord ].
	pendingError first == #index ifTrue: [ ^ self passQuoteError ].
	self goToEnd
]

{ #category : 'reading' }
SimdCSVReader >> recordNumber [
	"The number of the record that was read last, the header included, from 1; 0 before"

	^ recordsDone + rowNext - 1
]

{ #category : 'enumerating' }
SimdCSVReader >> do: aBlock [
	[ self hasRecord ] whileTrue: [ aBlock value: self next ]
]

{ #category : 'enumerating' }
SimdCSVReader >> collect: aBlock [
	"An Array"

	^ Array streamContents: [ :out | self do: [ :each | out nextPut: (aBlock value: each) ] ]
]

{ #category : 'enumerating' }
SimdCSVReader >> select: aBlock [
	"An Array"

	^ Array streamContents: [ :out | self select: aBlock thenDo: [ :each | out nextPut: each ] ]
]

{ #category : 'enumerating' }
SimdCSVReader >> select: filter thenDo: aBlock [
	self do: [ :each | (filter value: each) ifTrue: [ aBlock value: each ] ]
]

{ #category : 'enumerating' }
SimdCSVReader >> reject: aBlock [
	"An Array"

	^ Array streamContents: [ :out | self reject: aBlock thenDo: [ :each | out nextPut: each ] ]
]

{ #category : 'enumerating' }
SimdCSVReader >> reject: filter thenDo: aBlock [
	self do: [ :each | (filter value: each) ifFalse: [ aBlock value: each ] ]
]

{ #category : 'enumerating' }
SimdCSVReader >> upToEnd [
	"An Array of the records that are left"

	| batches size answer start |
	batches := OrderedCollection new.
	size := 0.
	[ self hasRecord ] whileTrue: [
		| batch |
		batch := self nextBatch.
		size := size + batch size.
		batches add: batch ].
	answer := Array new: size.
	start := 1.
	batches do: [ :batch |
		answer replaceFrom: start to: start + batch size - 1 with: batch startingAt: 1.
		start := start + batch size ].
	^ answer
]

{ #category : 'private - records' }
SimdCSVReader >> nextBatch [
	"An Array of the records of the rows that are built, at least one; or signal the error in the place of the next one"

	| batch |
	rowNext > rowCount ifTrue: [ ^ { self next } ].
	batch := rows copyFrom: rowNext to: rowCount.
	needsWork
		ifTrue: [ 1 to: batch size do: [ :i | batch at: i put: self next ] ]
		ifFalse: [
			failed := false.
			rowNext := rowCount + 1 ].
	^ batch
]

{ #category : 'enumerating' }
SimdCSVReader >> countRecords [
	"The number of the records that are left, which I pass; or signal the error of the first one that cannot be told from the next"

	| answer before |
	self changeDialect: [ ].
	before := recordsDone.
	[ self findUnits ] whileTrue: [
		pendingError ifNotNil: [ ^ self signalPending ].
		answer := SimdCSVBackend
			          measure: input source
			          from: input first
			          to: input limit
			          dialect: (dialect wordFor: input source final: input isFinal lines: true exact: false).
		recordsDone := recordsDone + (answer at: 2).
		lineBase := lineBase + (answer at: 5).
		input advanceTo: (answer at: 4) complete: true.
		answer first = SimdCSVBackend statusError ifTrue: [ self indexErrorCode: (answer at: 6) at: (answer at: 7) ] ].
	^ recordsDone - before
]

{ #category : 'private - configuration' }
SimdCSVReader >> checkEncoding: aSymbol [
	(started and: [ aSymbol ~~ dialect encoding ]) ifTrue: [ SimdCSVArgumentError signal: 'The encoding is set before the first record is read' ]
]

{ #category : 'private - configuration' }
SimdCSVReader >> configurationChanged [
	"The records that are built but not delivered are built again, a few first: the configuration may change before each record"

	| delivered |
	planned := false.
	delivered := rowNext - 1.
	rowCount > delivered ifTrue: [
		slot := self slotOfRow: delivered.
		rowGoal := 16 ].
	recordsDone := recordsDone + delivered.
	rowCount := 0.
	rowNext := 1.
	(firstWidthRecord notNil and: [ firstWidthRecord > recordsDone ]) ifTrue: [ firstWidth := firstWidthRecord := nil ].
	(pendingError notNil and: [ pendingError first == #build ]) ifTrue: [ pendingError := nil ].
	pendingError ifNil: [ failed := false ]
]

{ #category : 'private - configuration' }
SimdCSVReader >> changeConfiguration: aBlock [
	self configurationChanged.
	aBlock value
]

{ #category : 'private - configuration' }
SimdCSVReader >> changeDialect: aBlock [
	"What is indexed but not delivered is indexed again, from the start of the next record, a little first"

	| start |
	self configurationChanged.
	slot <= indexTo ifTrue: [
		start := self startOfSlot: slot.
		lineBase := lineBase + (self linesFrom: base to: start - 1).
		indexLines := 0.
		indexGoal := 4096.
		input advanceTo: start complete: false ].
	lineBase := lineBase + indexLines.
	indexTo := indexLines := 0.
	slot := 1.
	indexError := linesStart := nil.
	(pendingError notNil and: [ pendingError first ~~ #byteOrderMark ]) ifTrue: [
		pendingError := nil.
		failed := false ].
	started ifTrue: [ input advanceTo: input first complete: false ].
	aBlock value
]

{ #category : 'private - configuration' }
SimdCSVReader >> limitsChanged [
	input ifNotNil: [ input batchUnits: batchBytes maxUnits: maxRecordBytes ].
	self forgetError: #recordBytes
]

{ #category : 'private - configuration' }
SimdCSVReader >> forgetError: aSymbol [
	"The limit that was passed has changed: what stands there is looked at again"

	(pendingError notNil and: [ pendingError first == aSymbol ]) ifFalse: [ ^ self ].
	pendingError := nil.
	failed := false
]

{ #category : 'private - configuration' }
SimdCSVReader >> refuseWithFields [
	columns ifNotNil: [ SimdCSVArgumentError signal: 'Columns by name exclude the fields added by position' ]
]

{ #category : 'private - configuration' }
SimdCSVReader >> addColumn: aColumn [
	(selection notNil or: [ typedColumns notNil ]) ifTrue: [
		^ SimdCSVArgumentError signal: 'Fields added by position exclude the columns by name' ].
	self changeConfiguration: [
		columns ifNil: [
			columns := OrderedCollection new.
			namedColumns ifTrue: [
				header withIndexDo: [ :each :position |
					columns add: ((SimdCSVColumn type: #string)
							 key: each asSymbol;
							 position: position;
							 yourself) ] ] ].
		columns add: aColumn.
		aColumn position: columns size ]
]

{ #category : 'private - configuration' }
SimdCSVReader >> addIndexable: aColumn [
	self addColumn: aColumn.
	recordClassIsIndexable := true
]

{ #category : 'private - configuration' }
SimdCSVReader >> add: aColumn accessor: accessor [
	aColumn accessor: accessor.
	self addColumn: aColumn.
	recordClassIsIndexable := false
]

{ #category : 'private - configuration' }
SimdCSVReader >> add: aColumn at: key [
	aColumn key: key.
	self addColumn: aColumn.
	recordClassIsIndexable := false
]

{ #category : 'private - configuration' }
SimdCSVReader >> setColumn: aName to: aColumn [
	| position |
	self refuseWithFields.
	position := self positionOfColumn: aName.
	aColumn
		name: (header at: position);
		position: position.
	self changeConfiguration: [
		typedColumns ifNil: [ typedColumns := Dictionary new ].
		typedColumns at: position put: aColumn.
		(selection notNil and: [ (selected includes: position) not ]) ifTrue: [
			selection add: position.
			selected add: position ] ]
]

{ #category : 'private - header' }
SimdCSVReader >> positionOfColumn: aName [
	"The position of the only column of that name"

	header ifNil: [ ^ SimdCSVArgumentError signal: 'Columns have names after readHeader or namedColumnsConfiguration' ].
	positions ifNil: [ positions := self class positionsIn: header ].
	^ self class positionOf: aName in: header positions: positions
]

{ #category : 'private - header' }
SimdCSVReader class >> positionOf: aName in: names [
	"The position of aName in names, which must have it once"

	^ self positionOf: aName in: names positions: (self positionsIn: names)
]

{ #category : 'private - header' }
SimdCSVReader class >> positionOf: aName in: names positions: aDictionary [
	"The position of aName in names, which must have it once; aDictionary is their positionsIn:"

	| name position |
	name := aName asString.
	position := aDictionary at: name ifAbsent: [
		            ^ SimdCSVHeaderError new
			              kind: #missing;
			              columnName: name;
			              signal ].
	position = 0 ifTrue: [
		position := names indexOf: name.
		self signalDuplicateOf: name at: position in: names ].
	^ position
]

{ #category : 'private - header' }
SimdCSVReader class >> positionsIn: names [
	"A Dictionary from each name to its position, or to 0 when it is there more than once"

	| answer |
	answer := Dictionary new: names size.
	names withIndexDo: [ :name :position |
		answer at: name put: ((answer includesKey: name)
				 ifTrue: [ 0 ]
				 ifFalse: [ position ]) ].
	^ answer
]

{ #category : 'private - header' }
SimdCSVReader class >> signalDuplicateOf: name at: position in: names [
	| other |
	other := names indexOf: name startingAt: position + 1.
	other = 0 ifFalse: [
		SimdCSVHeaderError new
			kind: #duplicate;
			columnName: name;
			otherField: position;
			field: other;
			signal ]
]

{ #category : 'private - header' }
SimdCSVReader class >> checkUnique: names [
	names asSet size = names size ifFalse: [
		names withIndexDo: [ :name :position | self signalDuplicateOf: name at: position in: names ] ]
]

{ #category : 'private - header' }
SimdCSVReader class >> namesFrom: cells rename: aBoolean [
	"The names of a header: an empty cell (nil) is column and its number, made unique, and when asked the duplicates are too"

	| names used numbers seen |
	names := cells copy.
	used := Set new: cells size.
	cells do: [ :each | each ifNotNil: [ used add: each ] ].
	numbers := Dictionary new.
	names withIndexDo: [ :name :position |
		name ifNil: [ names at: position put: (used add: (self unique: 'column' , position printString in: used numbers: numbers)) ] ].
	aBoolean ifFalse: [ ^ names ].
	seen := Set new: cells size.
	names withIndexDo: [ :name :position |
		(seen includes: name)
			ifTrue: [ names at: position put: (used add: (self unique: name in: used numbers: numbers)) ]
			ifFalse: [ seen add: name ] ].
	^ names
]

{ #category : 'private - header' }
SimdCSVReader class >> unique: aName in: names numbers: aDictionary [
	"aName, or the first of aName_2, aName_3 and so on that is not in names; aDictionary has the last number that was tried for a name"

	| name number |
	name := aName.
	number := aDictionary at: aName ifAbsent: [ 1 ].
	[ names includes: name ] whileTrue: [
		number := number + 1.
		name := aName , '_' , number printString ].
	aDictionary at: aName put: number.
	^ name
]

{ #category : 'private - header' }
SimdCSVReader >> namesFrom: cells [
	^ self class namesFrom: cells rename: renameDuplicates
]

{ #category : 'private - header' }
SimdCSVReader >> header: names [
	positions := nil.
	^ header := names
]

{ #category : 'private - header' }
SimdCSVReader >> readHeaderUnique: aBoolean [
	"aBoolean: the names must be unique, else I do not pass the header"

	| cells names |
	self configurationChanged.
	cells := self peekStrings.
	cells ifNil: [
		rawHeader := #(  ).
		^ self header: rawHeader ].
	names := self namesFrom: cells.
	aBoolean ifTrue: [ self class checkUnique: names ].
	self passIndexedRecord.
	rawHeader := cells.
	self header: names.
	fieldCount := names size.
	^ names
]

{ #category : 'private - header' }
SimdCSVReader >> peekStrings [
	"The Strings of the next record, nil for the empty ones, which is not passed; or nil at the end"

	| row plain answer |
	self hasIndexedRecord ifFalse: [ ^ nil ].
	row := Array new: 1.
	plain := dialect copy.
	plain keepQuotedEmpty: false.
	answer := SimdCSVBackend
		          rows: input source
		          base: base
		          to: indexLimit
		          dialect: (plain wordFor: input source final: indexFinal lines: false exact: false)
		          index: index
		          from: slot
		          to: (self lastSlotFrom: slot)
		          types: nil
		          fieldCount: 0
		          into: row
		          from: 1
		          empty: nil
		          budget: -1.
	answer first = SimdCSVBackend statusError ifTrue: [
		self buildErrorFrom: answer.
		^ self signalPending ].
	^ row first
]

{ #category : 'private - header' }
SimdCSVReader >> hasIndexedRecord [
	"Is there a next record? No row is built"

	[ slot > indexTo ] whileTrue: [
		pendingError ifNotNil: [ ^ self signalPending ].
		self indexMore ifFalse: [ ^ false ] ].
	^ true
]

{ #category : 'private - positions' }
SimdCSVReader >> lastSlotFrom: aSlot [
	"The slot of the last field of the record that begins at aSlot"

	| units separator last |
	units := input source.
	separator := dialect separator asInteger.
	last := aSlot.
	[
	| position |
	position := base + (index at: last).
	position <= indexLimit and: [ (units basicAt: position) = separator and: [ last < indexTo ] ] ] whileTrue: [ last := last + 1 ].
	^ last
]

{ #category : 'private - positions' }
SimdCSVReader >> slotAfter: count from: aSlot [
	"The slot where the record begins that follows count records from aSlot on"

	| next |
	next := aSlot.
	count timesRepeat: [ next := (self lastSlotFrom: next) + 1 ].
	^ next
]

{ #category : 'private - positions' }
SimdCSVReader >> slotOfRow: count [
	"The slot where the record begins that follows count rows of those that are built. I go on from the one I was asked last"

	count < placeRow ifTrue: [
		placeRow := 0.
		placeSlot := rowSlot ].
	placeSlot := self slotAfter: count - placeRow from: placeSlot.
	placeRow := count.
	^ placeSlot
]

{ #category : 'private - positions' }
SimdCSVReader >> startOfSlot: aSlot [
	"The position in the source of the unit after the end of the field before aSlot"

	aSlot = 1 ifTrue: [ ^ base ].
	^ self positionAfterEnd: base + (index at: aSlot - 1)
]

{ #category : 'private - positions' }
SimdCSVReader >> positionAfterEnd: position [
	"The position after the unit at position, which ends a field: CRLF is one end"

	^ (self isCRLFAt: position)
		  ifTrue: [ position + 2 ]
		  ifFalse: [ position + 1 ]
]

{ #category : 'private - positions' }
SimdCSVReader >> isCRLFAt: position [
	| units |
	dialect lineEnd == #lf ifTrue: [ ^ false ].
	units := input source.
	^ position < indexLimit and: [ (units basicAt: position) = 13 and: [ (units basicAt: position + 1) = 10 ] ]
]

{ #category : 'private - positions' }
SimdCSVReader >> skipBlanksFrom: position to: limit [
	"The start of the record at or after position"

	| units start unit |
	dialect skipEmptyLines ifFalse: [ ^ position ].
	units := input source.
	start := position.
	[
	start <= limit and: [
		unit := units basicAt: start.
		unit = 10 or: [ unit = 13 and: [ dialect lineEnd ~~ #lf ] ] ] ] whileTrue: [ start := start + 1 ].
	^ start
]

{ #category : 'private - positions' }
SimdCSVReader >> linesFrom: start to: stop [
	"The number of line ends from start to stop, where a record or a blank line ends, CRLF being one. I go on from the one I was asked last"

	| units count from |
	units := input source.
	count := 0.
	from := start.
	(linesStart = start and: [ linesStop <= stop ]) ifTrue: [
		count := linesCount.
		from := linesStop + 1 ].
	from to: stop do: [ :position |
		| unit |
		unit := units basicAt: position.
		(unit = 10 or: [ unit = 13 and: [ dialect lineEnd ~~ #lf and: [ position = stop or: [ (units basicAt: position + 1) ~= 10 ] ] ] ]) ifTrue: [ count := count + 1 ] ].
	linesStart := start.
	linesStop := stop.
	linesCount := count.
	^ count
]

{ #category : 'private - positions' }
SimdCSVReader >> openQuotePosition [
	"The position of the quote that is still open at the end of what was read, from the start of the next record on, or nil"

	| units separator quote anyEnd open state |
	dialect quote ifNil: [ ^ nil ].
	units := input source.
	separator := dialect separator asInteger.
	quote := dialect quote asInteger.
	anyEnd := dialect lineEnd ~~ #lf.
	state := #start.
	input first to: input limit do: [ :position |
		| unit |
		unit := units basicAt: position.
		state == #quoted
			ifTrue: [ unit = quote ifTrue: [ state := #after ] ]
			ifFalse: [
				(unit = separator or: [ unit = 10 or: [ anyEnd and: [ unit = 13 ] ] ])
					ifTrue: [ state := #start ]
					ifFalse: [
						(unit = quote and: [ state ~~ #unquoted ])
							ifTrue: [
								state == #start ifTrue: [ open := position ].
								state := #quoted ]
							ifFalse: [ state := #unquoted ] ] ] ].
	^ state == #quoted ifTrue: [ open ]
]

{ #category : 'private - indexing' }
SimdCSVReader >> findUnits [
	"Is there something to index, or an error in the place of it?"

	linesStart := nil.
	ended ifTrue: [ ^ false ].
	started ifFalse: [
		self start ifFalse: [
			pendingError := #( #byteOrderMark ).
			^ true ] ].
	pendingError ifNotNil: [ ^ true ].
	input wide: dialect separator asInteger > 255.
	[ input atEnd ] whileFalse: [
		(input needsMore and: [ input more not ]) ifTrue: [
			pendingError := #( #recordBytes ).
			^ true ].
		input hasUnits ifTrue: [ ^ true ] ].
	^ false
]

{ #category : 'private - indexing' }
SimdCSVReader >> start [
	"Open the source; answer false when it is UTF-16"

	| answer |
	input ifNil: [ input := SimdCSVInput on: source encoding: dialect encoding batch: batchBytes max: maxRecordBytes ].
	answer := input start: dialect encoding.
	started := true.
	^ answer
]

{ #category : 'private - indexing' }
SimdCSVReader >> indexMore [
	"The index is used up: index the next records. Answer whether there are any, or an error in their place"

	indexError ifNotNil: [
		pendingError := indexError.
		indexError := nil.
		^ true ].
	lineBase := lineBase + indexLines.
	indexTo := indexLines := 0.
	slot := 1.
	[ self findUnits ] whileTrue: [
		(pendingError notNil or: [ self indexWindow ]) ifTrue: [ ^ true ] ].
	^ false
]

{ #category : 'private - indexing' }
SimdCSVReader >> indexWindow [
	"Index what the input has, or after a change of the dialect a little of it; answer whether that gave records or an error"

	| answer stored status to |
	[
	to := input limit.
	indexGoal ifNotNil: [
		to := input first + indexGoal - 1 min: to.
		indexGoal := indexGoal * 2 ].
	indexFinal := input isFinal and: [ to = input limit ].
	self prepareIndexFor: to - input first + 1.
	answer := SimdCSVBackend
		          index: input source
		          base: input first
		          from: input first
		          to: to
		          dialect: (dialect wordFor: input source final: indexFinal lines: true exact: false)
		          into: index
		          from: 1.
	status := answer first.
	stored := answer at: 2.
	to < input limit and: [ stored = 0 and: [ status = SimdCSVBackend statusOK ] ] ] whileTrue.
	to = input limit ifTrue: [ indexGoal := nil ].
	base := input first.
	indexLimit := to.
	indexRecords := answer at: 3.
	input advanceTo: (answer at: 4) complete: (status = SimdCSVBackend statusOK and: [ to = input limit ]).
	stored = 0
		ifTrue: [ lineBase := lineBase + (answer at: 5) ]
		ifFalse: [
			indexTo := stored.
			indexLines := answer at: 5 ].
	status = SimdCSVBackend statusError ifTrue: [
		self indexErrorCode: (answer at: 8) at: (answer at: 9).
		stored > 0 ifTrue: [
			indexError := pendingError.
			pendingError := nil ].
		^ true ].
	(status = SimdCSVBackend statusMore and: [ stored = 0 ]) ifTrue: [
		pendingError := #( #fields ).
		^ true ].
	^ stored > 0
]

{ #category : 'private - indexing' }
SimdCSVReader >> indexErrorCode: code at: position [
	pendingError := {
		                #index.
		                code.
		                position }
]

{ #category : 'private - indexing' }
SimdCSVReader >> prepareIndexFor: count [
	"An index of at most maxFields slots, which is as many as count units can need, or else maxFields"

	| needed |
	needed := count + 1 min: maxFields.
	(index notNil and: [ index size between: needed and: maxFields ]) ifTrue: [ ^ self ].
	index := WordArray new: ((needed max: 64) * 2 min: maxFields)
]

{ #category : 'private - indexing' }
SimdCSVReader >> passQuoteError [
	"Pass a record of irregular quotes, up to its end as the lenient rules see it, which is looked for in a window that grows"

	| lenient answer next to size |
	lenient := dialect copy.
	lenient strictQuoting: false.
	size := 4096.
	[
	to := input first + size - 1 min: input limit.
	self prepareIndexFor: to - input first + 1.
	answer := SimdCSVBackend
		          index: input source
		          base: input first
		          from: input first
		          to: to
		          dialect: (lenient wordFor: input source final: (input isFinal and: [ to = input limit ]) lines: false exact: false)
		          into: index
		          from: 1.
	(answer at: 2) = 0 ] whileTrue: [
		answer first = SimdCSVBackend statusMore ifTrue: [ ^ self goToEnd ].
		(to = input limit and: [ input isFinal or: [ input more not ] ]) ifTrue: [ ^ self goToEnd ].
		size := size * 2 ].
	base := input first.
	indexLimit := to.
	indexTo := answer at: 2.
	next := self positionAfterEnd: base + (index at: (self lastSlotFrom: 1)).
	next := next min: indexLimit + 1.
	linesStart := nil.
	lineBase := lineBase + indexLines + (self linesFrom: base to: next - 1).
	indexTo := indexLines := 0.
	slot := 1.
	pendingError := linesStart := nil.
	recordsDone := recordsDone + rowNext.
	rowCount := 0.
	rowNext := 1.
	input advanceTo: next complete: false
]

{ #category : 'private - indexing' }
SimdCSVReader >> passIndexedRecord [
	"Pass the record at slot, whose rows are not built"

	slot := (self lastSlotFrom: slot) + 1.
	pendingError := nil.
	recordsDone := recordsDone + rowNext.
	rowCount := 0.
	rowNext := 1
]

{ #category : 'private - indexing' }
SimdCSVReader >> goToEnd [
	"No record is left"

	ended := true.
	recordsDone := recordsDone + rowNext - 1.
	rowCount := indexTo := 0.
	rowNext := slot := 1.
	failed := false.
	pendingError := indexError := rows := index := nil
]

{ #category : 'private - building' }
SimdCSVReader >> hasRecord [
	"Is there a record that is built, or an error in its place?"

	[ rowNext > rowCount ] whileTrue: [
		pendingError ifNotNil: [ ^ true ].
		slot <= indexTo
			ifTrue: [ self buildRows ]
			ifFalse: [ self indexMore ifFalse: [ ^ false ] ] ].
	^ true
]

{ #category : 'private - building' }
SimdCSVReader >> buildRows [
	"Build the next batch of rows from the index"

	| answer |
	recordsDone := recordsDone + rowCount.
	rowCount := 0.
	rowNext := 1.
	self plan.
	self prepareRows.
	answer := SimdCSVBackend
		          rows: input source
		          base: base
		          to: indexLimit
		          dialect: (dialect wordFor: input source final: indexFinal lines: false exact: dialect strictFieldCount)
		          index: index
		          from: slot
		          to: indexTo
		          types: types
		          fieldCount: width
		          into: rows
		          from: 1
		          empty: builderEmpty
		          budget: self rowBudget.
	rowSlot := placeSlot := slot.
	placeRow := 0.
	slot := answer at: 3.
	rowCount := answer at: 2.
	needsWork := alwaysWork or: [ (answer at: 4) > 0 and: [ hasNumbers ] ].
	answer first = SimdCSVBackend statusError ifTrue: [ self buildErrorFrom: answer ]
]

{ #category : 'private - building' }
SimdCSVReader >> buildErrorFrom: answer [
	"The error of the record at slot, as primitiveRows answered it"

	pendingError := {
		                #build.
		                (answer at: 5).
		                (answer at: 6).
		                (answer at: 8) }
]

{ #category : 'private - building' }
SimdCSVReader >> maxRows [
	"The most rows of a batch"

	^ 4096
]

{ #category : 'private - building' }
SimdCSVReader >> prepareRows [
	"An Array for the rows of a batch: as many as there are records, at most maxRows; after a change of the configuration a few, and twice as many each time"

	| size |
	size := indexRecords min: (rowGoal ifNil: [ self maxRows ]).
	(rows notNil and: [
		 rowGoal
			 ifNil: [ rows size >= size ]
			 ifNotNil: [ rows size = size ] ]) ifFalse: [ rows := Array new: size ].
	rowGoal ifNotNil: [ rowGoal := rowGoal * 2 < self maxRows ifTrue: [ rowGoal * 2 ] ]
]

{ #category : 'private - building' }
SimdCSVReader >> rowBudget [
	"The bytes of objects after which no further record of a batch is begun"

	^ 4194304
]

{ #category : 'private - building' }
SimdCSVReader >> plan [
	"What the builder is asked, from the configuration"

	| empty converters |
	planned ifTrue: [ ^ self ].
	self planColumns.
	self planWidth.
	emptyMark := self class emptyMark.
	nullTexts := dialect nullTexts.
	passNil := rowColumns notNil and: [ dialect emptyFieldValue == #passNil ].
	empty := self emptyValue.
	converters := rowColumns notNil and: [ rowColumns anySatisfy: [ :each | (each isPlain or: [ each isNumber ]) not ] ].
	hasNumbers := rowColumns notNil and: [ rowColumns anySatisfy: [ :each | each isNumber ] ].
	builderEmpty := (empty isNil or: [ objectMode not and: [ converters not ] ])
		                ifTrue: [ empty ]
		                ifFalse: [ emptyMark ].
	alwaysWork := objectMode or: [ converters or: [ order notNil or: [ recordClass ~~ Array ] ] ].
	planned := true
]

{ #category : 'private - building' }
SimdCSVReader >> emptyValue [
	"The value of an empty field in an indexable record, but for the value of a converter with #passNil"

	^ passNil ifFalse: [ dialect emptyFieldValue ]
]

{ #category : 'private - building' }
SimdCSVReader >> planColumns [
	"objectMode, rowColumns (those of the row, in its order), types, order (where the values of a row go) and width, the last for declared fields"

	| used byHeader |
	types := order := rowColumns := width := nil.
	byHeader := columns isNil and: [ namedColumns or: [ selection notNil or: [ typedColumns notNil ] ] ].
	byHeader ifTrue: [
		self planHeaderColumns.
		^ self ].
	objectMode := recordClassIsIndexable not.
	columns ifNil: [
		objectMode ifTrue: [ SimdCSVArgumentError signal: 'A record that is not indexable needs fields' ].
		^ self ].
	used := (columns reject: [ :each | each isIgnored ]) asArray.
	(used allSatisfy: [ :each | each hasDestination = objectMode ]) ifFalse: [
		SimdCSVArgumentError signal: (objectMode
				 ifTrue: [ 'A field has no accessor, but the records are not indexable' ]
				 ifFalse: [ 'A field has an accessor, but the records are indexable' ]) ].
	header ifNotNil: [ used do: [ :each | each name: (header at: each position ifAbsent: [ nil ]) ] ].
	self planRowColumns: used fieldCount: columns size
]

{ #category : 'private - building' }
SimdCSVReader >> planHeaderColumns [
	| places used |
	objectMode := (recordClass includesBehavior: SequenceableCollection) not.
	places := (selection ifNil: [ 1 to: header size ]) asArray.
	used := places collect: [ :each |
		        (typedColumns ifNotNil: [ typedColumns at: each ifAbsent: [ nil ] ]) ifNil: [
			        (SimdCSVColumn type: #string)
				        name: (header at: each);
				        position: each;
				        yourself ] ].
	objectMode ifTrue: [
		self class checkUnique: (used collect: [ :each | each name ]).
		used do: [ :each | each key: each name asSymbol ] ].
	self planRowColumns: used fieldCount: header size
]

{ #category : 'private - building' }
SimdCSVReader >> planRowColumns: used fieldCount: count [
	"Records have count fields, and the values are those of the columns used, in that order"

	rowColumns := used sorted: [ :a :b | a position <= b position ].
	rowColumns = used ifFalse: [
		| places |
		places := IdentityDictionary new: used size.
		used withIndexDo: [ :each :place | places at: each put: place ].
		order := rowColumns collect: [ :each | places at: each ] ].
	plain := rowColumns collect: [ :each | each isPlain ].
	types := ByteArray new: count.
	rowColumns do: [ :each | types at: each position put: each code ].
	width := count
]

{ #category : 'private - building' }
SimdCSVReader >> planWidth [
	"The width that the builder is given: that of the declared fields, the header or fieldCount:, with beStrict that of the first record, else 0"

	width ifNotNil: [ ^ self ].
	width := fieldCount ifNil: [ 0 ].
	(width = 0 and: [ dialect strictFieldCount ]) ifFalse: [ ^ self ].
	firstWidth ifNil: [
		firstWidth := (self lastSlotFrom: slot) - slot + 1.
		firstWidthRecord := recordsDone + 1 ].
	width := firstWidth
]

{ #category : 'private - records' }
SimdCSVReader >> recordFrom: row [
	"The record of a row"

	| values |
	objectMode ifTrue: [ ^ self objectFrom: row ].
	rowColumns ifNil: [ ^ recordClass withAll: row ].
	values := Array new: row size.
	1 to: row size do: [ :i |
		| value |
		value := self valueOf: (row at: i) at: i.
		value == emptyMark ifTrue: [
			value := passNil
				         ifTrue: [ (rowColumns at: i) valueOfEmpty ]
				         ifFalse: [ dialect emptyFieldValue ] ].
		values
			at: (order
					 ifNil: [ i ]
					 ifNotNil: [ order at: i ])
			put: value ].
	^ recordClass == Array
		  ifTrue: [ values ]
		  ifFalse: [ recordClass withAll: values ]
]

{ #category : 'private - records' }
SimdCSVReader >> objectFrom: row [
	"An instance of recordClass that was given the values of its fields, but for the empty ones"

	| record |
	record := recordClass new.
	1 to: row size do: [ :i |
		| value |
		value := self valueOf: (row at: i) at: i.
		value == emptyMark
			ifFalse: [ (rowColumns at: i) store: value into: record ]
			ifTrue: [
				passNil ifTrue: [
					| column |
					column := rowColumns at: i.
					column store: column valueOfEmpty into: record ] ] ].
	^ record
]

{ #category : 'private - records' }
SimdCSVReader >> valueOf: cell at: i [
	"The value of a cell of the builder, the one numbered i of its row, or the mark of an empty one"

	| column |
	cell == builderEmpty ifTrue: [ ^ emptyMark ].
	((plain at: i) or: [ cell isString not ]) ifTrue: [ ^ cell ].
	(cell isEmpty or: [ nullTexts notEmpty and: [ nullTexts includes: cell ] ]) ifTrue: [ ^ emptyMark ].
	column := rowColumns at: i.
	^ column hasConverter
		  ifTrue: [ column converted: cell ]
		  ifFalse: [ column valueOf: cell ifInvalid: [ self valueOfInvalid: cell in: column ] ]
]

{ #category : 'private - records' }
SimdCSVReader >> valueOfInvalid: text in: aColumn [
	"The value of the block of ifInvalid:, or the one that the handler of the error resumes with"

	| block error recordSlot start |
	block := aColumn invalidBlock ifNil: [ invalidBlock ].
	block ifNotNil: [ ^ block cull: text cull: self recordNumber + 1 cull: aColumn position ].
	recordSlot := self slotOfRow: rowNext - 1.
	start := self skipBlanksFrom: (self startOfSlot: recordSlot) to: indexLimit.
	error := SimdCSVConversionError new.
	error
		text: text;
		type: aColumn type;
		columnName: aColumn name;
		field: aColumn position.
	self place: error start: start.
	aColumn position > 1 ifTrue: [ error position: (input absolute: (self startOfSlot: recordSlot + aColumn position - 1)) ].
	^ error signal
]

{ #category : 'private - errors' }
SimdCSVReader >> place: anError start: start [
	"The place of the next record, which begins at start"

	| line |
	line := (rowNext <= rowCount or: [ pendingError first == #build ])
		        ifTrue: [ lineBase + (self linesFrom: base to: start - 1) ]
		        ifFalse: [ lineBase + indexLines + (self linesFrom: input first to: start - 1) ].
	anError
		record: self recordNumber + 1;
		line: line + 1;
		position: (input absolute: start);
		unitName: (input isBytes
				 ifTrue: [ 'byte' ]
				 ifFalse: [ 'character' ])
]

{ #category : 'private - errors' }
SimdCSVReader >> signalPending [
	"Signal the error in the place of the next record"

	| kind |
	failed := true.
	kind := pendingError first.
	kind == #build ifTrue: [ ^ self signalBuildError ].
	kind == #index ifTrue: [ ^ self signalQuoteError ].
	kind == #byteOrderMark ifTrue: [
		^ SimdCSVInvalidEncoding new
			  isByteOrderMark: true;
			  code: SimdCSVBackend codeInvalidUTF8;
			  position: 1;
			  record: 1;
			  line: 1;
			  field: 1;
			  signal ].
	^ self signalResourceError: kind
]

{ #category : 'private - errors' }
SimdCSVReader >> signalBuildError [
	| code error start |
	code := pendingError at: 2.
	code = SimdCSVBackend codeBadIndex ifTrue: [ ^ SimdCSVArgumentError signal: 'The source was changed while it was read' ].
	start := self skipBlanksFrom: (self startOfSlot: slot) to: indexLimit.
	code = SimdCSVBackend codeFieldCount
		ifTrue: [
			error := SimdCSVFieldCountMismatch new.
			error
				expected: width;
				actual: (pendingError at: 4).
			self place: error start: start ]
		ifFalse: [
			error := SimdCSVInvalidEncoding new.
			self place: error start: start.
			error
				position: (input absolute: (pendingError at: 3));
				field: (pendingError at: 4).
			header ifNotNil: [ error columnName: (header at: error field ifAbsent: [ nil ]) ] ].
	error code: code.
	^ error signal
]

{ #category : 'private - errors' }
SimdCSVReader >> signalQuoteError [
	| error |
	error := SimdCSVQuoteError new.
	self place: error start: (self skipBlanksFrom: input first to: input limit).
	error
		code: (pendingError at: 2);
		position: (input absolute: (pendingError at: 3)).
	^ error signal
]

{ #category : 'private - errors' }
SimdCSVReader >> signalResourceError: kind [
	| error |
	error := SimdCSVResourceError new.
	self place: error start: (self skipBlanksFrom: input first to: input limit).
	error kind: kind.
	kind == #fields
		ifTrue: [ error limit: maxFields ]
		ifFalse: [
			error limit: maxRecordBytes.
			self openQuotePosition ifNotNil: [ :position | error quotePosition: (input absolute: position) ] ].
	^ error signal
]
