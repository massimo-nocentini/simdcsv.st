"
I am the input of a `SimdCSVReader`: units (bytes, or characters) in the collection `source`, of which those from `first` to `limit` have been read and not yet been given back as records.

- `first` is always the start of a record, `limit` is the last unit that is there, `isFinal` tells that nothing comes after it.
- `advanceTo:complete:` passes the records of an index; `needsMore` and `more` get more units when no complete record is left.
- `absolute:` makes a position in `source` a position in the data, counted from 1 at the first unit that was read.

`SimdCSVCollectionInput` reads a collection where it is, `SimdCSVStreamInput` reads a stream through a buffer. `SimdCSVInput class >> on:encoding:batch:max:` chooses:

| source | read as |
|---|---|
| ByteArray or String | in place |
| Symbol | in place, as a String |
| FileReference | a binary stream, closed at its end |
| ReadStream on a ByteArray or a String | in place, from its position |
| ZnCharacterReadStream that decodes UTF-8 and has not been peeked | the bytes of its wrapped stream |
| another binary stream | bytes |
| another stream | characters |
"
Class {
	#name : 'SimdCSVInput',
	#superclass : 'Object',
	#instVars : [
		'source',
		'first',
		'limit',
		'origin',
		'batchUnits',
		'maxUnits',
		'stream',
		'wide'
	],
	#category : 'SimdCSV-Reading',
	#package : 'SimdCSV',
	#tag : 'Reading'
}

{ #category : 'instance creation' }
SimdCSVInput class >> on: aSource encoding: aSymbol batch: batchUnits max: maxUnits [
	"An input that is open: its byte order mark has been read"

	| input |
	input := self inputOn: aSource encoding: aSymbol.
	input batchUnits: batchUnits maxUnits: maxUnits.
	^ input
]

{ #category : 'private' }
SimdCSVInput class >> inputOn: aSource encoding: aSymbol [
	(aSource isKindOf: AbstractFileReference) ifTrue: [
		aSource isDirectory ifTrue: [ ^ SimdCSVArgumentError signal: 'A directory is no source of CSV: ' , aSource printString ].
		^ SimdCSVStreamInput onFile: aSource ].
	(self isUnits: aSource) ifTrue: [ ^ SimdCSVCollectionInput on: aSource from: 1 to: aSource size ].
	(aSource respondsTo: #next:) ifFalse: [
		^ SimdCSVArgumentError signal: 'A source of CSV is a String, a ByteArray, a FileReference or a stream, not ' , aSource class name ].
	((aSource isMemberOf: ReadStream) and: [ self isUnits: aSource originalContents ]) ifTrue: [
		^ (SimdCSVCollectionInput on: aSource originalContents from: aSource position + 1 to: aSource size)
			  stream: aSource;
			  yourself ].
	(aSymbol == #utf8 and: [ self isFreshUTF8: aSource ]) ifTrue: [
		^ (SimdCSVStreamInput onBytes: aSource wrappedStream)
			  stream: aSource;
			  yourself ].
	^ (self isBinary: aSource)
		  ifTrue: [ SimdCSVStreamInput onBytes: aSource ]
		  ifFalse: [ SimdCSVStreamInput onCharacters: aSource ]
]

{ #category : 'private' }
SimdCSVInput class >> isBinary: aStream [
	^ (aStream respondsTo: #isBinary) and: [ aStream isBinary ]
]

{ #category : 'private' }
SimdCSVInput class >> isFreshUTF8: aStream [
	"Is aStream a character stream that would decode the bytes of its wrapped stream as UTF-8, from where that stream stands?"

	^ (aStream isMemberOf: ZnCharacterReadStream) and: [
		  (aStream encoder isMemberOf: ZnUTF8Encoder) and: [
			  (aStream instVarNamed: 'peeked') isNil and: [ self isBinary: aStream wrappedStream ] ] ]
]

{ #category : 'private' }
SimdCSVInput class >> isUnits: anObject [
	"Can the backends read anObject as it is (Symbols after asString)?"

	^ anObject isString or: [ anObject isMemberOf: ByteArray ]
]

{ #category : 'private' }
SimdCSVInput class >> wideCopyOf: aString to: limit [
	"A WideString of the size of aString with its characters up to limit"

	| answer |
	answer := WideString new: aString size.
	limit > 0 ifTrue: [ answer replaceFrom: 1 to: limit with: aString startingAt: 1 ].
	^ answer
]

{ #category : 'accessing' }
SimdCSVInput >> source [
	"The collection of the units"

	^ source
]

{ #category : 'accessing' }
SimdCSVInput >> first [
	"The position in the source of the first unit that is not passed"

	^ first
]

{ #category : 'accessing' }
SimdCSVInput >> limit [
	"The position in the source of the last unit that can be read now"

	^ limit
]

{ #category : 'accessing' }
SimdCSVInput >> absolute: position [
	"The position in the data of a position in the source, both from 1"

	^ origin + position
]

{ #category : 'accessing' }
SimdCSVInput >> stream: aStream [
	stream := aStream
]

{ #category : 'accessing' }
SimdCSVInput >> batchUnits: batch maxUnits: max [
	"A batch is read at a time, and more only for a record that is longer, up to max units. The two units more are the line end that shows that a record is complete."

	maxUnits := max + 2.
	batchUnits := batch min: maxUnits
]

{ #category : 'accessing' }
SimdCSVInput >> wide: aBoolean [
	"aBoolean: the separator is beyond U+00FF, which no unit of a ByteString can be: characters are then in a WideString"

	wide := aBoolean.
	(aBoolean and: [ source isString and: [ source isWideString not ] ]) ifTrue: [
		source := self class wideCopyOf: source to: source size ]
]

{ #category : 'testing' }
SimdCSVInput >> isBytes [
	^ source isString not
]

{ #category : 'testing' }
SimdCSVInput >> isFinal [
	"Is limit the end of the data?"

	^ self subclassResponsibility
]

{ #category : 'testing' }
SimdCSVInput >> needsMore [
	"Is there no complete record left?"

	^ self subclassResponsibility
]

{ #category : 'testing' }
SimdCSVInput >> hasUnits [
	^ first <= limit
]

{ #category : 'testing' }
SimdCSVInput >> atEnd [
	^ first > limit and: [ self isFinal ]
]

{ #category : 'reading' }
SimdCSVInput >> advanceTo: position complete: aBoolean [
	"The units before position are passed; aBoolean: no complete record is left up to limit"

	self subclassResponsibility
]

{ #category : 'reading' }
SimdCSVInput >> more [
	"Get more units after limit, or learn that there are none; answer false if a record longer than maxUnits is in the way"

	self subclassResponsibility
]

{ #category : 'reading' }
SimdCSVInput >> start: anEncoding [
	"Pass the byte order mark; answer false when it is one of UTF-16"

	[ self mayBeginMark: anEncoding ] whileTrue: [ self more ].
	self hasUnits ifFalse: [ ^ true ].
	self isBytes ifFalse: [
		(source basicAt: first) = 16rFEFF ifTrue: [ first := first + 1 ].
		^ true ].
	anEncoding == #utf8 ifFalse: [ ^ true ].
	(self startsWith: #[ 239 187 191 ]) ifTrue: [ first := first + 3 ].
	^ ((self startsWith: #[ 255 254 ]) or: [ self startsWith: #[ 254 255 ] ]) not
]

{ #category : 'private' }
SimdCSVInput >> mayBeginMark: anEncoding [
	"Must more units be read to know whether there is a byte order mark? A stream that is slow is not asked for three when the first is no part of a mark"

	| unit count |
	self isFinal ifTrue: [ ^ false ].
	self hasUnits ifFalse: [ ^ true ].
	(self isBytes and: [ anEncoding == #utf8 ]) ifFalse: [ ^ false ].
	unit := source basicAt: first.
	count := limit - first + 1.
	unit = 239 ifTrue: [ ^ count < 2 or: [ count < 3 and: [ (source basicAt: first + 1) = 187 ] ] ].
	^ count < 2 and: [ unit = 254 or: [ unit = 255 ] ]
]

{ #category : 'private' }
SimdCSVInput >> startsWith: bytes [
	limit - first + 1 < bytes size ifTrue: [ ^ false ].
	bytes withIndexDo: [ :byte :index |
		(source basicAt: first + index - 1) = byte ifFalse: [ ^ false ] ].
	^ true
]

{ #category : 'reading' }
SimdCSVInput >> readAll [
	"Read to the end of the data; answer false when it is longer than the limit"

	[ self isFinal ] whileFalse: [ self more ifFalse: [ ^ false ] ].
	^ true
]

{ #category : 'closing' }
SimdCSVInput >> close [
	stream ifNotNil: [ stream close ]
]
