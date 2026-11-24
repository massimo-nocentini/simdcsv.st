"
I read a stream through one buffer, a `ByteArray` of a batch (a String for a stream of characters).

- The buffer is as large as a file that is smaller than a batch, 4 KiB for another stream; whenever it was filled it is doubled, up to a batch.
- A file is read until the buffer is full or a read answers nothing. Another stream is read once at a time, 4 KiB first and twice as much each time up to a batch.
- A socket (a stream that understands isDataAvailable: SocketStream, ZdcSocketStream) is read as it comes: what has arrived, or one unit when nothing has, and the records that are complete are there before I wait for more. A connection that is closed is the end. Other streams that wait until they have what they were asked for (a pipe as standard input, the body of an HTTP answer) give 4 KiB, or their end, before the first record.
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
		'readSize',
		'live',
		'fileSize'
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
	^ (self new setInput: aFileReference binaryReadStream characters: false file: true)
		  fileSize: aFileReference size;
		  yourself
]

{ #category : 'initialization' }
SimdCSVStreamInput >> setInput: aStream characters: charactersBoolean file: fileBoolean [
	input := stream := aStream.
	characters := charactersBoolean.
	isFile := fileBoolean.
	live := isFile not and: [ aStream respondsTo: #isDataAvailable ].
	final := wide := false.
	exhausted := true.
	readSize := 4096.
	fileSize := 0.
	first := 1.
	limit := 0.
	origin := 0
]

{ #category : 'initialization' }
SimdCSVStreamInput >> fileSize: anInteger [
	"The size of the file, or 0 of a file that does not tell; it may grow"

	fileSize := anInteger
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
	| goal start |
	self makeRoom ifFalse: [ ^ false ].
	goal := isFile
		        ifTrue: [ source size ]
		        ifFalse: [ limit - first + 1 * 2 max: 1 ].
	start := limit.
	[ final or: [ limit - first + 1 >= goal or: [ limit = source size or: [ live and: [ limit > start and: [ self isDataAvailable not ] ] ] ] ] ]
		whileFalse: [ self read ].
	exhausted := false.
	^ true
]

{ #category : 'private' }
SimdCSVStreamInput >> makeRoom [
	"The unread units are moved to the start of the buffer, and the buffer is doubled when they fill it, or when the last read did and it is smaller than a batch; answer false when it cannot be"

	| tail |
	source ifNil: [
		source := self newBuffer: (fileSize + 1 max: 4096).
		^ true ].
	tail := limit - first + 1.
	(source size > (4 * batchUnits) and: [ tail <= batchUnits ])
		ifTrue: [ self moveTo: (self newBuffer: batchUnits) ]
		ifFalse: [
			(limit = source size and: [ source size < batchUnits ])
				ifTrue: [ self moveTo: (self newBuffer: source size * 2) ]
				ifFalse: [ first > 1 ifTrue: [ self moveTo: source ] ] ].
	limit < source size ifTrue: [ ^ true ].
	source size >= maxUnits ifTrue: [ ^ false ].
	self moveTo: (self newBufferUpTo: (source size * 2 min: maxUnits)).
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
	"A buffer of size, or of a batch when that is less"

	^ self newBufferUpTo: (size min: batchUnits)
]

{ #category : 'private' }
SimdCSVStreamInput >> newBufferUpTo: size [
	characters ifFalse: [ ^ ByteArray new: size ].
	^ (wide or: [ source notNil and: [ source isWideString ] ])
		  ifTrue: [ WideString new: size ]
		  ifFalse: [ ByteString new: size ]
]

{ #category : 'private' }
SimdCSVStreamInput >> read [
	"One read of what is wanted and fits; nothing is the end"

	| count start |
	count := source size - limit.
	isFile ifFalse: [
		count := count min: readSize.
		readSize := readSize * 2 min: batchUnits ].
	start := limit.
	live
		ifTrue: [ self readAvailable: count ]
		ifFalse: [ self readUnits: count ].
	limit = start ifTrue: [
		final := true.
		isFile ifTrue: [ stream close ] ]
]

{ #category : 'private' }
SimdCSVStreamInput >> readUnits: count [
	limit := limit + (characters
		          ifTrue: [ self readCharacters: count ]
		          ifFalse: [ self readBytes: count ])
]

{ #category : 'private' }
SimdCSVStreamInput >> readAvailable: count [
	"What a socket has, at most count units; when it has none, wait for one"

	| rest unit |
	rest := count.
	self isDataAvailable ifFalse: [
		unit := [ input next ]
			        on: ConnectionClosed
			        do: [ :closed | closed return: nil ].
		unit ifNil: [ ^ self ].
		self store: (characters
				 ifTrue: [ String with: unit ]
				 ifFalse: [ ByteArray with: unit ]).
		rest := rest - 1 ].
	[ rest > 0 and: [ self isDataAvailable ] ] whileTrue: [
		| some |
		some := self buffered min: rest.
		self readUnits: some.
		rest := rest - some ]
]

{ #category : 'private' }
SimdCSVStreamInput >> isDataAvailable [
	^ [ input isDataAvailable ]
		  on: ConnectionClosed
		  do: [ :closed | closed return: false ]
]

{ #category : 'private' }
SimdCSVStreamInput >> buffered [
	"The units that a socket with data gives without waiting, at least one: those in the buffer of its stream"

	(input respondsTo: #inBufferSize) ifTrue: [ ^ input inBufferSize max: 1 ].
	(input class allInstVarNames includes: 'readBuffer') ifFalse: [ ^ 1 ].
	^ (input instVarNamed: 'readBuffer') availableForReading max: 1
]

{ #category : 'private' }
SimdCSVStreamInput >> readBytes: count [
	"Answer how many"

	| bytes |
	(input respondsTo: #readInto:startingAt:count:) ifTrue: [ ^ input readInto: source startingAt: limit + 1 count: count ].
	bytes := (input next: count) ifNil: [ #[  ] ].
	source replaceFrom: limit + 1 to: limit + bytes size with: bytes startingAt: 1.
	^ bytes size
]

{ #category : 'private' }
SimdCSVStreamInput >> readCharacters: count [
	"Answer how many"

	| string |
	string := (input next: count) ifNil: [ '' ].
	string isString ifFalse: [ string := String withAll: string ].
	self put: string.
	^ string size
]

{ #category : 'private' }
SimdCSVStreamInput >> put: aCollection [
	"aCollection goes after limit. The buffer becomes a WideString with the first character beyond U+00FF"

	(characters and: [ aCollection isWideString and: [ source isWideString not ] ]) ifTrue: [ source := self class wideCopyOf: source to: limit ].
	source replaceFrom: limit + 1 to: limit + aCollection size with: aCollection startingAt: 1
]

{ #category : 'private' }
SimdCSVStreamInput >> store: aCollection [
	self put: aCollection.
	limit := limit + aCollection size
]
