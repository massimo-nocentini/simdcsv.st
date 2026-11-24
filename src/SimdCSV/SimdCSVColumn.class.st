"
I am a column of a `SimdCSVReader` or a `SimdCSVTable`: the type of its cells, how a text becomes a value, and where the value goes.

| type | code in the builder | value of a cell |
|---|---|---|
| `#string` | 1 | the String |
| `#integer` | 2 | an Integer |
| `#float` | 3 | a Float; also of nan, inf and infinity in any case, the infinities with a sign |
| `#floatComma` | 4 | a Float written with a decimal comma |
| `#symbol` | 1 | the text as a Symbol |
| `#boolean` | 1 | true or false, of these words in any case |
| `#ignored` | 0 | none, the column is not in the rows |

A column with a converter block is a `#string` column whose value is the value of the block. With `cached:` the block is asked once for each text, up to 10,000 texts: for columns with few different texts, such as dates, times and codes.

A value goes into the record by `accessor:` (the mutator selector, or a block of the record and the value), by `key:` (`at:put:`), or else to its place in an indexable record.
"
Class {
	#name : 'SimdCSVColumn',
	#superclass : 'Object',
	#instVars : [
		'name',
		'type',
		'position',
		'converter',
		'cache',
		'accessor',
		'key',
		'invalidBlock'
	],
	#category : 'SimdCSV-Reading',
	#package : 'SimdCSV',
	#tag : 'Reading'
}

{ #category : 'instance creation' }
SimdCSVColumn class >> type: aSymbol [
	^ self new type: aSymbol
]

{ #category : 'instance creation' }
SimdCSVColumn class >> converter: aBlockOrNil cached: aBoolean [
	^ self new converter: aBlockOrNil cached: aBoolean
]

{ #category : 'accessing' }
SimdCSVColumn class >> maxCachedTexts [
	^ 10000
]

{ #category : 'private' }
SimdCSVColumn class >> typeCodes [
	^ { (#string -> 1). (#integer -> 2). (#float -> 3). (#floatComma -> 4). (#symbol -> 1). (#boolean -> 1). (#ignored -> 0) } asDictionary
]

{ #category : 'initialization' }
SimdCSVColumn >> initialize [
	super initialize.
	type := #string
]

{ #category : 'accessing' }
SimdCSVColumn >> type [
	^ type
]

{ #category : 'accessing' }
SimdCSVColumn >> type: aSymbol [
	(self class typeCodes includesKey: aSymbol) ifFalse: [
		^ SimdCSVArgumentError signal: 'Not a type of a column: ' , aSymbol printString ].
	type := aSymbol.
	converter := cache := nil
]

{ #category : 'accessing' }
SimdCSVColumn >> converter: aBlockOrNil cached: aBoolean [
	type := #string.
	converter := aBlockOrNil.
	cache := (aBoolean and: [ aBlockOrNil notNil ]) ifTrue: [ Dictionary new ]
]

{ #category : 'accessing' }
SimdCSVColumn >> code [
	"The type code of primitiveRows"

	^ self class typeCodes at: type
]

{ #category : 'accessing' }
SimdCSVColumn >> name [
	^ name
]

{ #category : 'accessing' }
SimdCSVColumn >> name: aString [
	name := aString
]

{ #category : 'accessing' }
SimdCSVColumn >> position [
	"The number of my field in a record, from 1"

	^ position
]

{ #category : 'accessing' }
SimdCSVColumn >> position: anInteger [
	position := anInteger
]

{ #category : 'accessing' }
SimdCSVColumn >> accessor: aSymbolOrBlock [
	accessor := aSymbolOrBlock
]

{ #category : 'accessing' }
SimdCSVColumn >> key: anObject [
	key := anObject
]

{ #category : 'accessing' }
SimdCSVColumn >> invalidBlock [
	^ invalidBlock
]

{ #category : 'accessing' }
SimdCSVColumn >> invalidBlock: aBlock [
	invalidBlock := aBlock
]

{ #category : 'testing' }
SimdCSVColumn >> isIgnored [
	^ type == #ignored
]

{ #category : 'testing' }
SimdCSVColumn >> isNumber [
	"Are my cells numbers that the builder made, but for the odd ones?"

	^ type == #integer or: [ type == #float or: [ type == #floatComma ] ]
]

{ #category : 'testing' }
SimdCSVColumn >> isPlain [
	"Are my cells just the Strings of the builder?"

	^ type == #string and: [ converter isNil ]
]

{ #category : 'testing' }
SimdCSVColumn >> hasDestination [
	"Do my values go somewhere else than to a place in an indexable record?"

	^ accessor notNil or: [ key notNil ]
]

{ #category : 'converting' }
SimdCSVColumn >> valueOfEmpty [
	"The value of an empty cell when emptyFieldValue is #passNil"

	^ converter ifNotNil: [ :block | block value: nil ]
]

{ #category : 'converting' }
SimdCSVColumn >> valueOf: aString ifInvalid: aBlock [
	"The value of a text, or that of aBlock"

	converter ifNotNil: [ ^ self converted: aString ].
	type == #integer ifTrue: [ ^ (SimdCSVNumbers integerFrom: aString) ifNil: aBlock ].
	type == #float ifTrue: [ ^ (SimdCSVNumbers floatFrom: aString comma: false) ifNil: [ (self specialFloatFrom: aString) ifNil: aBlock ] ].
	type == #floatComma ifTrue: [ ^ (SimdCSVNumbers floatFrom: aString comma: true) ifNil: [ (self specialFloatFrom: aString) ifNil: aBlock ] ].
	type == #symbol ifTrue: [ ^ aString asSymbol ].
	type == #boolean ifTrue: [
		(aString sameAs: 'true') ifTrue: [ ^ true ].
		(aString sameAs: 'false') ifTrue: [ ^ false ].
		^ aBlock value ].
	^ aString
]

{ #category : 'private' }
SimdCSVColumn >> converted: aString [
	"A cached value may be nil"

	| value |
	cache ifNil: [ ^ converter value: aString ].
	^ cache at: aString ifAbsent: [
		  value := converter value: aString.
		  cache size < self class maxCachedTexts ifTrue: [ cache at: aString put: value ].
		  value ]
]

{ #category : 'private' }
SimdCSVColumn >> specialFloatFrom: aString [
	"nan, inf and infinity in any case, the infinities with a sign, spaces and tabs around; or nil"

	| text sign |
	aString size > 64 ifTrue: [ ^ nil ].
	text := aString trimBoth: [ :each | each = Character space or: [ each = Character tab ] ].
	text ifEmpty: [ ^ nil ].
	(text sameAs: 'nan') ifTrue: [ ^ Float nan ].
	sign := text first.
	(sign = $- or: [ sign = $+ ]) ifTrue: [ text := text allButFirst ].
	((text sameAs: 'inf') or: [ text sameAs: 'infinity' ]) ifFalse: [ ^ nil ].
	^ sign = $-
		  ifTrue: [ Float infinity negated ]
		  ifFalse: [ Float infinity ]
]

{ #category : 'storing' }
SimdCSVColumn >> store: aValue into: anObject [
	key ifNotNil: [ ^ anObject at: key put: aValue ].
	accessor isSymbol ifTrue: [ ^ anObject perform: accessor with: aValue ].
	^ accessor value: anObject value: aValue
]
