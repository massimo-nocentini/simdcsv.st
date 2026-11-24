"
I test that the records do not depend on how the units come: batches of every size, short reads, one unit at a time; and what is read, copied and looked at meanwhile.
"
Class {
	#name : 'SimdCSVStreamingTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SimdCSVStreamingTest >> sample [
	"Every kind of field and of line end"

	^ 'a,bc,"d"' , String lf , '"e,f","g""h",' , String crlf , ',' , String cr , '"i' , String crlf , 'j",k"l,"m"n' , String crlf , String cr , String lf , String lf
	  , '0123456789012345678901234567890123456789,"' , (String new: 70 withAll: $x) , '",' , String lf , 'last,"one'
]

{ #category : 'helpers' }
SimdCSVStreamingTest >> wideSample [
	^ self sample , String lf , 'é,' , (String with: (Character codePoint: 945)) , ',"' , (String with: (Character codePoint: 16r1F600)) , '"' , String crlf , 'z'
]

{ #category : 'helpers' }
SimdCSVStreamingTest >> read: aSource batch: size [
	^ (self reader: aSource) batchBytes: size; upToEnd
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testBatchSizes [
	| rows bytes |
	{ self sample. self wideSample } do: [ :text |
		bytes := text utf8Encoded.
		rows := self read: text.
		self assert: rows size equals: (self read: bytes) size.
		1 to: 300 do: [ :size |
			self assert: (self read: text batch: size) equals: rows.
			self assert: (self read: bytes batch: size) equals: rows.
			self assert: (self read: (SimdCSVTestStream on: bytes) batch: size) equals: rows.
			self assert: (self read: (SimdCSVTestStream on: text) batch: size) equals: rows ] ]
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testReadSizes [
	| rows bytes |
	{ self sample. self wideSample } do: [ :text |
		bytes := text utf8Encoded.
		rows := self read: text.
		1 to: 300 do: [ :size |
			self assert: (self read: (SimdCSVTestStream on: bytes sizes: { size }) batch: 4096) equals: rows.
			self assert: (self read: (SimdCSVTestStream on: text sizes: { size }) batch: 4096) equals: rows.
			self assert: (self read: (SimdCSVTestStream on: bytes sizes: { 1. size. 3 }) batch: 50) equals: rows ] ]
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testSkipEmptyLinesInBatches [
	| text rows |
	text := String lf , String crlf , 'a,b' , String cr , String cr , String crlf , String lf , '"c' , String lf , String lf , '",d' , String crlf , String crlf , String cr.
	rows := (self reader: text) skipEmptyLines; upToEnd.
	self assert: rows equals: { { 'a'. 'b' }. { 'c' , String lf , String lf. 'd' } }.
	1 to: 30 do: [ :size |
		self assert: ((self reader: text) skipEmptyLines; batchBytes: size; upToEnd) equals: rows.
		self assert: ((self reader: (SimdCSVTestStream on: text asByteArray sizes: { size })) skipEmptyLines; upToEnd) equals: rows.
		self assert: ((self reader: (SimdCSVTestStream on: text asByteArray sizes: { size })) skipEmptyLines; batchBytes: 7; countRecords) equals: 2 ]
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testByteOrderMarkInPieces [
	1 to: 4 do: [ :size |
		self assert: (self read: (SimdCSVTestStream on: #[ 239 187 191 97 44 98 ] sizes: { size })) equals: #( #( 'a' 'b' ) ).
		self assert: (self read: (SimdCSVTestStream on: #[ 239 187 191 ] sizes: { size })) equals: #(  ).
		self assert: (self read: #[ 239 187 191 97 44 98 ] batch: size) equals: #( #( 'a' 'b' ) ) ].
	self assert: [ self read: (SimdCSVTestStream on: #[ 239 187 ] sizes: #( 1 )) ] signals: SimdCSVInvalidEncoding
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testCRLFInPieces [
	"One line end, whatever comes between CR and LF"

	| bytes |
	bytes := ('a' , String crlf , 'b' , String crlf) asByteArray.
	self assert: (self read: (SimdCSVTestStream on: bytes sizes: #( 1 ))) equals: #( #( 'a' ) #( 'b' ) ).
	self assert: (self read: (SimdCSVTestStream on: bytes sizes: #( 2 1 ))) equals: #( #( 'a' ) #( 'b' ) ).
	self assert: (self read: (SimdCSVTestStream on: ('a' , String cr) asByteArray sizes: #( 2 ))) equals: #( #( 'a' ) ).
	self assert: (self read: (SimdCSVTestStream on: ('a' , String cr , 'b') asByteArray sizes: #( 2 ))) equals: #( #( 'a' ) #( 'b' ) )
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testRandomTexts [
	| random |
	random := self random.
	(self largeSize: 300) timesRepeat: [
		| text rows sizes |
		text := String streamContents: [ :out |
			        (random nextInteger: 120) timesRepeat: [ out nextPut: ('abc,,"' , String crlf , String lf at: (random nextInteger: 9)) ] ].
		rows := self read: text.
		sizes := (1 to: 3) collect: [ :each | random nextInteger: 20 ].
		self assert: (self read: (SimdCSVTestStream on: text asByteArray sizes: sizes) batch: (random nextInteger: 60)) equals: rows.
		self assert: (self read: (SimdCSVTestStream on: text sizes: sizes) batch: (random nextInteger: 60)) equals: rows.
		self assert: (self read: text asWideString batch: (random nextInteger: 60)) equals: rows ]
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testOneUnitAtATimeIsLinear [
	"The units that are indexed are at most four times those of the text"

	| text counter |
	text := String streamContents: [ :out |
		        1 to: 400 do: [ :i |
			        out
				        nextPutAll: (String new: i * 7 \\ 61 withAll: $a);
				        nextPut: $,;
				        print: i;
				        lf ].
		        out
			        nextPut: $";
			        nextPutAll: (String new: 3000 withAll: $b);
			        nextPut: $" ].
	{ text asByteArray. text } do: [ :units |
		counter := SimdCSVTestCountingBackend on: self backendObject.
		SimdCSVBackend testHook: #backend value: counter.
		self assert: (self read: (SimdCSVTestStream on: units sizes: #( 1 ))) size equals: 401.
		self assert: counter units <= (4 * text size) description: [ counter units printString , ' of ' , text size printString ] ]
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testLongRecordIsLinear [
	"The window of a source in place, and the buffer of a stream, grow twofold"

	| text counter |
	text := '"' , (String new: (self largeSize: 100000) withAll: $a) , '",b'.
	{ text. text asByteArray. SimdCSVTestStream on: text asByteArray } do: [ :source |
		counter := SimdCSVTestCountingBackend on: self backendObject.
		SimdCSVBackend testHook: #backend value: counter.
		self assert: (self read: source batch: 10) first last equals: 'b'.
		self assert: counter units <= (4 * text size) ]
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testNoReadIsWanted [
	"A stream is not read before a record is asked for, and no more than that record needs"

	| stream reader |
	stream := SimdCSVTestStream on: (self lines: #( 'a,b' 'c,d' 'e,f' 'g,h' )) asByteArray sizes: #( 8 ).
	reader := self reader: stream.
	reader
		separator: $,;
		addField;
		addField.
	self assert: stream reads equals: 0.
	self assert: reader next equals: #( 'a' 'b' ).
	self assert: reader next equals: #( 'c' 'd' ).
	self assert: stream reads equals: 1.
	self assert: reader next equals: #( 'e' 'f' ).
	self assert: reader next equals: #( 'g' 'h' ).
	self assert: stream reads equals: 2.
	self assert: reader atEnd.
	self assert: stream reads equals: 3
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testSmallFirstReads [
	"4 KiB, then twice as much up to a batch; a file gives batches at once"

	| stream reader file |
	stream := SimdCSVTestStream on: (String streamContents: [ :out | 5000 timesRepeat: [ out nextPutAll: '1234,678'; lf ] ]) asByteArray.
	reader := self reader: stream.
	reader
		batchBytes: 16384;
		next.
	self assert: stream position equals: 4096.
	reader skip: 455.
	self assert: stream position equals: 4096 + 8192.
	reader upToEnd.
	self assert: stream reads equals: 5.
	file := FileSystem memory / 'a.csv'.
	file binaryWriteStreamDo: [ :out | out next: 45000 putAll: (ByteArray new: 45000 withAll: 97) startingAt: 1 ].
	reader := self reader: file.
	reader batchBytes: 100000.
	self assert: reader next first size equals: 45000
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testBytePath [
	"The stream of readStream of a file is read as bytes, also when its encoder is the default one; another encoder, another class and a peeked character are not"

	| file reader stream bytePath |
	file := FileSystem memory / 'a.csv'.
	file writeStreamDo: [ :out | out nextPutAll: self wideSample ].
	bytePath := [ :source |
	            reader := self reader: source.
	            self assert: reader upToEnd equals: (self read: self wideSample).
	            (reader instVarNamed: #input) isBytes ].
	self assert: (bytePath value: file readStream).
	self assert: (bytePath value: file binaryReadStream).
	self assert: (bytePath value: file).
	stream := file readStream.
	stream peek.
	self deny: (bytePath value: stream).
	self deny: (bytePath value: file readStream contents readStream).
	self deny: (bytePath value: (SimdCSVTestStream on: self wideSample)).
	stream := ZnCharacterReadStream on: ('a,é' encodeWith: 'latin1') readStream encoding: 'latin1'.
	reader := self reader: stream.
	self assert: reader next equals: #( 'a' 'é' ).
	self deny: (reader instVarNamed: #input) isBytes
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testZincStreamThatWasRead [
	"The bytes begin where the characters were read to"

	| stream |
	stream := (FileSystem memory / 'a.csv') in: [ :file |
		          file writeStreamDo: [ :out | out nextPutAll: 'é#a,ü' ].
		          file readStream ].
	stream next: 2.
	self assert: (self read: stream) equals: #( #( 'a' 'ü' ) ).
	stream := ZnCharacterReadStream on: 'é#a,ü' utf8Encoded readStream.
	self assert: (stream peekFor: $é).
	self assert: (stream peekFor: $x) not.
	self assert: (self read: stream) equals: #( #( '#a' 'ü' ) )
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testBufferIsGivenBack [
	"A buffer that a long record made is replaced"

	| text reader |
	text := (self lines: #( 'a' 'b' )) , (String new: 1000 withAll: $x) , String lf , (self lines: (Array new: 2000 withAll: 'c')) , 'h'.
	{ text. text asByteArray } do: [ :units |
		reader := self reader: (SimdCSVTestStream on: units sizes: #( 8 )).
		reader batchBytes: 16.
		self assert: reader next equals: #( 'a' ).
		self assert: (reader instVarNamed: #input) source size equals: 16.
		self assert: reader next equals: #( 'b' ).
		self assert: reader next first size equals: 1000.
		self assert: (reader instVarNamed: #input) source size >= 1000.
		self assert: reader upToEnd last equals: #( 'h' ).
		self assert: (reader instVarNamed: #input) source size equals: 16 ]
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testMaxRecordBytes [
	"A record of that size is read, one that is longer by more than a line end is not, whatever the source is"

	#( 1 3 10 1000 ) do: [ :batch |
		#( 1 2 5 17 64 ) do: [ :limit |
			self sourcesOf: (String new: limit withAll: $a) , String crlf , 'b' do: [ :source :name |
				self assert: ((self reader: source) batchBytes: batch; maxRecordBytes: limit; upToEnd) size equals: 2 ].
			self sourcesOf: (String new: limit + 3 withAll: $a) , String crlf , 'b' do: [ :source :name |
				self assert: (self assert: [ (self reader: source) batchBytes: batch; maxRecordBytes: limit; upToEnd ] signals: SimdCSVResourceError) kind equals: #recordBytes ] ] ]
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testWideAfterNarrow [
	"The buffer of characters becomes wide when it must"

	| text |
	text := (self lines: #( 'a,b' 'c,d' )) , (String with: (Character codePoint: 945)) , ',e' , String lf , 'f,g'.
	1 to: 20 do: [ :size |
		| rows |
		rows := self read: (SimdCSVTestStream on: text sizes: { size }).
		self assert: rows equals: (self read: text).
		self assert: rows last first class equals: ByteString ]
]

{ #category : 'tests' }
SimdCSVStreamingTest >> testStreamsOfOtherProtocols [
	"A binary stream without readInto:startingAt:count: is read with next:"

	| stream |
	stream := SimdCSVTestNextStream on: #[ 97 44 98 10 99 ].
	self assert: (self read: stream) equals: #( #( 'a' 'b' ) #( 'c' ) )
]
