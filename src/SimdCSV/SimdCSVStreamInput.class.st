"
I read a stream through one buffer, a `ByteArray` of a batch (a String for a stream of characters).

- A file is read until the buffer is full or a read answers nothing. Another stream is read once at a time, 4 KiB first and twice as much each time up to a batch, so that a slow stream (a socket, a pipe) is read as it comes.
- The unread tail is moved to the start of the buffer only when no complete record is left in it, and is looked at again only when it has doubled: a stream that answers a byte at a time costs linear time too.
- A record that does not fit doubles the buffer, up to the maximum. A buffer of more than four batches is replaced as soon as its tail fits a batch.
- The end is the read that answers nothing. A file is closed there.
"
Class {
	#name : 'SimdCSVStreamInput',
	#superclass : 'SimdCSVInput',
	#instVars : [
		'input',
		'characters',
		'isFile',
		'final',
		'exhausted',
		'readSize'
	],
	#category : 'SimdCSV-Reading',
	#package : 'SimdCSV',
	#tag : 'Reading'
}

{ #category : 'instance creation' }
SimdCSVStreamInput class >> onBytes: aBinaryStream [
	^ self new setInput: aBinaryStream characters: false file: false
]

{ #category : 'instance creation' }
SimdCSVStreamInput class >> onCharacters: aStream [
	^ self new setInput: aStream characters: true file: false
]

{ #category : 'instance creation' }
SimdCSVStreamInput class >> onFile: aFileReference [
	^ self new setInput: aFileReference binaryReadStream characters: false file: true
]

{ #category : 'initialization' }
SimdCSVStreamInput >> setInput: aStream characters: charactersBoolean file: fileBoolean [
	input := stream := aStream.
	characters := charactersBoolean.
	isFile := fileBoolean.
	final := false.
	exhausted := true.
	readSize := 4096.
	first := 1.
	limit := 0.
	origin := 0
]

{ #category : 'testing' }
SimdCSVStreamInput >> isBytes [
	^ characters not
]

{ #category : 'testing' }
SimdCSVStreamInput >> isFinal [
	^ final
]

{ #category : 'testing' }
SimdCSVStreamInput >> needsMore [
	^ final not and: [ exhausted or: [ first > limit ] ]
]

{ #category : 'reading' }
SimdCSVStreamInput >> advanceTo: position complete: aBoolean [
	first := position.
	exhausted := aBoolean
]

{ #category : 'reading' }
SimdCSVStreamInput >> more [
	| goal |
	self makeRoom ifFalse: [ ^ false ].
	goal := isFile
		        ifTrue: [ source size ]
		        ifFalse: [ limit - first + 1 * 2 max: 1 ].
	[ final or: [ limit - first + 1 >= goal or: [ limit = source size ] ] ] whileFalse: [ self read ].
	exhausted := false.
	^ true
]

{ #category : 'private' }
SimdCSVStreamInput >> makeRoom [
	"The unread units are moved to the start of the buffer, and the buffer is doubled when they fill it; answer false when it cannot be"

	| tail |
	source ifNil: [
		source := self newBuffer: batchUnits.
		^ true ].
	tail := limit - first + 1.
	(source size > (4 * batchUnits) and: [ tail <= batchUnits ])
		ifTrue: [ self moveTo: (self newBuffer: batchUnits) ]
		ifFalse: [ first > 1 ifTrue: [ self moveTo: source ] ].
	limit < source size ifTrue: [ ^ true ].
	source size >= maxUnits ifTrue: [ ^ false ].
	self moveTo: (self newBuffer: (source size * 2 min: maxUnits)).
	^ true
]

{ #category : 'private' }
SimdCSVStreamInput >> moveTo: aBuffer [
	"Copying upwards, the replacement may overlap when aBuffer is the source"

	| tail |
	tail := limit - first + 1.
	tail > 0 ifTrue: [ aBuffer replaceFrom: 1 to: tail with: source startingAt: first ].
	origin := origin + first - 1.
	source := aBuffer.
	first := 1.
	limit := tail
]

{ #category : 'private' }
SimdCSVStreamInput >> newBuffer: size [
	characters ifFalse: [ ^ ByteArray new: size ].
	^ (source notNil and: [ source isWideString ])
		  ifTrue: [ WideString new: size ]
		  ifFalse: [ ByteString new: size ]
]

{ #category : 'private' }
SimdCSVStreamInput >> read [
	"One read of what is wanted and fits; nothing is the end"

	| count |
	count := source size - limit.
	isFile ifFalse: [
		count := count min: readSize.
		readSize := readSize * 2 min: batchUnits ].
	count := characters
		         ifTrue: [ self readCharacters: count ]
		         ifFalse: [ self readBytes: count ].
	limit := limit + count.
	count = 0 ifTrue: [
		final := true.
		isFile ifTrue: [ stream close ] ]
]

{ #category : 'private' }
SimdCSVStreamInput >> readBytes: count [
	| bytes |
	(input respondsTo: #readInto:startingAt:count:) ifTrue: [ ^ input readInto: source startingAt: limit + 1 count: count ].
	bytes := (input next: count) ifNil: [ #[  ] ].
	source replaceFrom: limit + 1 to: limit + bytes size with: bytes startingAt: 1.
	^ bytes size
]

{ #category : 'private' }
SimdCSVStreamInput >> readCharacters: count [
	"The buffer becomes a WideString with the first character beyond U+00FF"

	| string wide |
	string := (input next: count) ifNil: [ '' ].
	string isString ifFalse: [ string := String withAll: string ].
	(string isWideString and: [ source isWideString not ]) ifTrue: [
		wide := WideString new: source size.
		limit > 0 ifTrue: [ wide replaceFrom: 1 to: limit with: source startingAt: 1 ].
		source := wide ].
	source replaceFrom: limit + 1 to: limit + string size with: string startingAt: 1.
	^ string size
]
