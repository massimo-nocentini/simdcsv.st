"
I am the facade of SimdCSV, on my class side only: CSV to Arrays, Dictionaries and tables, and back.

```smalltalk
SimdCSV rowsFrom: 'a,b' , String lf , '1,""x,y""'.
SimdCSV rowsFrom: bytes separator: $;.
SimdCSV rowsFrom: 'data.csv' asFileReference dialect: SimdCSVDialect tab.
SimdCSV rowsFrom: 'big.csv' asFileReference do: [ :row | row first ].
SimdCSV dictionariesFrom: source.
SimdCSV tableFrom: 'data.csv' asFileReference.
SimdCSV count: 'data.csv' asFileReference.
SimdCSV stringFrom: #( #( 'a' 'b' ) #( 1 2.5 ) ).
SimdCSV write: rows to: aStream.
SimdCSV write: rows to: 'new.csv' asFileReference.
```

A source is a String, a Symbol, a ByteArray, a FileReference or a stream. Each message has a form with `dialect:`, and one `SimdCSVDialect` governs all of them: a blank line is a record unless the dialect says `skipEmptyLines: true`, so that the size of `rowsFrom:`, `count:`, and the `rowCount` of `tableFrom:` and its header agree. A row is an Array of the Strings of its record, as many as it has, nil for an empty one.

Numbers, converters, names and records of other classes are the work of `SimdCSVReader`; columns that of `SimdCSVTable`; `SimdCSVWriter` writes.

`separatorOffsetsIn:` answers what simdcsv itself does: a `WordArray` of the 0-based offsets of the units that end the fields, the size for a last field without a line end.

The work is done by the `SimdCSVPlugin` of the VM, or without it in Smalltalk: `backend`, `pluginAvailable`, `pluginInfo` and `implementationName` tell.
"
Class {
	#name : 'SimdCSV',
	#superclass : 'Object',
	#category : 'SimdCSV-Core',
	#package : 'SimdCSV',
	#tag : 'Core'
}

{ #category : 'reading' }
SimdCSV class >> rowsFrom: aSource [
	"An Array of rows, each an Array of Strings"

	^ self rowsFrom: aSource dialect: SimdCSVDialect comma
]

{ #category : 'reading' }
SimdCSV class >> rowsFrom: aSource separator: aCharacter [
	"An Array of rows, whose fields are between aCharacter"

	^ self rowsFrom: aSource dialect: (self separated: aCharacter)
]

{ #category : 'reading' }
SimdCSV class >> rowsFrom: aSource dialect: aDialect [
	"An Array of rows"

	^ self read: aSource dialect: aDialect do: [ :reader | reader upToEnd ]
]

{ #category : 'reading' }
SimdCSV class >> rowsFrom: aSource do: aBlock [
	"Evaluate aBlock with each row; the memory that this takes does not grow with the source"

	self rowsFrom: aSource dialect: SimdCSVDialect comma do: aBlock
]

{ #category : 'reading' }
SimdCSV class >> rowsFrom: aSource separator: aCharacter do: aBlock [
	"Evaluate aBlock with each row"

	self rowsFrom: aSource dialect: (self separated: aCharacter) do: aBlock
]

{ #category : 'reading' }
SimdCSV class >> rowsFrom: aSource dialect: aDialect do: aBlock [
	"Evaluate aBlock with each row"

	self read: aSource dialect: aDialect do: [ :reader | reader do: aBlock ]
]

{ #category : 'reading' }
SimdCSV class >> dictionariesFrom: aSource [
	"An Array of Dictionaries from the names of the header, as Symbols, to the Strings of the fields that are not empty"

	^ self dictionariesFrom: aSource dialect: SimdCSVDialect comma
]

{ #category : 'reading' }
SimdCSV class >> dictionariesFrom: aSource dialect: aDialect [
	"An Array of Dictionaries. Without a header the names are column1 and so on, as many as the first record has fields"

	^ self read: aSource dialect: aDialect do: [ :reader |
		  aDialect hasHeader
			  ifTrue: [ reader namedColumnsConfiguration ]
			  ifFalse: [ reader numberedColumnsConfiguration ].
		  reader upToEnd ]
]

{ #category : 'reading' }
SimdCSV class >> tableFrom: aSource [
	"A SimdCSVTable"

	^ self tableFrom: aSource dialect: SimdCSVDialect comma
]

{ #category : 'reading' }
SimdCSV class >> tableFrom: aSource dialect: aDialect [
	"A SimdCSVTable"

	^ SimdCSVTable on: aSource dialect: aDialect
]

{ #category : 'reading' }
SimdCSV class >> count: aSource [
	"The number of the records, the header included"

	^ self count: aSource dialect: SimdCSVDialect comma
]

{ #category : 'reading' }
SimdCSV class >> count: aSource dialect: aDialect [
	"The number of the records, the header included. No object is made, and no UTF-8 is looked at"

	^ self read: aSource dialect: aDialect do: [ :reader | reader countRecords ]
]

{ #category : 'reading' }
SimdCSV class >> separatorOffsetsIn: aCollection [
	"A WordArray: for each field the 0-based offset of the unit that ends it, and the size of aCollection, a ByteArray or a String, for a last field without a line end. The unit is at the offset + 1; a byte order mark counts"

	^ self separatorOffsetsIn: aCollection dialect: SimdCSVDialect comma
]

{ #category : 'reading' }
SimdCSV class >> separatorOffsetsIn: aCollection dialect: aDialect [
	"A WordArray"

	| units word answer offsets |
	(aCollection isString or: [ aCollection isMemberOf: ByteArray ]) ifFalse: [
		^ SimdCSVArgumentError signal: 'A ByteArray or a String is expected, not an instance of ' , aCollection class name ].
	units := aCollection isSymbol
		         ifTrue: [ aCollection asString ]
		         ifFalse: [ aCollection ].
	(units isString and: [ units isWideString not and: [ aDialect separator asInteger > 255 ] ]) ifTrue: [
		units := SimdCSVInput wideCopyOf: units to: units size ].
	units size > SimdCSVTable maxInputUnits ifTrue: [
		^ SimdCSVResourceError new
			  kind: #inputUnits;
			  actual: units size;
			  limit: SimdCSVTable maxInputUnits;
			  unitName: (units isString
					   ifTrue: [ 'character' ]
					   ifFalse: [ 'byte' ]);
			  signal ].
	word := aDialect wordFor: units final: true lines: true exact: false.
	answer := SimdCSVBackend measure: units from: 1 to: units size dialect: word.
	answer first = SimdCSVBackend statusError ifTrue: [
		^ SimdCSVQuoteError new
			  code: (answer at: 6);
			  position: (answer at: 7);
			  record: (answer at: 2) + 1;
			  line: (answer at: 5) + 1;
			  unitName: (units isString
					   ifTrue: [ 'character' ]
					   ifFalse: [ 'byte' ]);
			  signal ].
	offsets := WordArray new: (answer at: 3).
	SimdCSVBackend index: units base: 1 from: 1 to: units size dialect: word into: offsets from: 1.
	^ offsets
]

{ #category : 'writing' }
SimdCSV class >> stringFrom: rows [
	"The CSV of rows, collections of fields"

	^ self stringFrom: rows dialect: SimdCSVDialect comma
]

{ #category : 'writing' }
SimdCSV class >> stringFrom: rows dialect: aDialect [
	^ String streamContents: [ :stream | self write: rows to: stream dialect: aDialect ]
]

{ #category : 'writing' }
SimdCSV class >> bytesFrom: rows [
	"The CSV of rows, as the bytes of UTF-8"

	^ self bytesFrom: rows dialect: SimdCSVDialect comma
]

{ #category : 'writing' }
SimdCSV class >> bytesFrom: rows dialect: aDialect [
	^ ByteArray streamContents: [ :stream | self write: rows to: stream dialect: aDialect ]
]

{ #category : 'writing' }
SimdCSV class >> write: rows to: aStream [
	"Write rows to a stream of characters, or of bytes in UTF-8, or to a new file"

	self write: rows to: aStream dialect: SimdCSVDialect comma
]

{ #category : 'writing' }
SimdCSV class >> write: rows to: aStream dialect: aDialect [
	"Write rows to a stream; or to a FileReference, whose file is replaced, as bytes"

	(aStream isKindOf: AbstractFileReference) ifTrue: [
		aStream ensureDelete.
		^ aStream binaryWriteStreamDo: [ :stream | self write: rows to: stream dialect: aDialect ] ].
	(SimdCSVWriter on: aStream)
		dialect: aDialect;
		nextPutAll: rows
]

{ #category : 'backend' }
SimdCSV class >> backend [
	"#plugin or #smalltalk"

	^ SimdCSVBackend backend
]

{ #category : 'backend' }
SimdCSV class >> implementationName [
	"The name of the kernel of the plugin, or smalltalk"

	^ SimdCSVBackend implementationName
]

{ #category : 'backend' }
SimdCSV class >> pluginAvailable [
	"Is there a SimdCSVPlugin that can be used?"

	^ SimdCSVBackend pluginAvailable
]

{ #category : 'backend' }
SimdCSV class >> pluginInfo [
	"What the plugin says of itself, nil without it"

	^ SimdCSVBackend pluginInfo
]

{ #category : 'private' }
SimdCSV class >> read: aSource dialect: aDialect do: aBlock [
	"The value of aBlock for a reader; a file is closed, a stream of the caller is not"

	| reader |
	reader := SimdCSVReader on: aSource.
	reader dialect: aDialect.
	^ [ aBlock value: reader ] ensure: [ (aSource isKindOf: AbstractFileReference) ifTrue: [ reader close ] ]
]

{ #category : 'private' }
SimdCSV class >> separated: aCharacter [
	^ SimdCSVDialect new
		  separator: aCharacter;
		  yourself
]
