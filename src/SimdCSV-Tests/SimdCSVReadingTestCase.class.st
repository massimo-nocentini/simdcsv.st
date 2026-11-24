"
I am the abstract test case of the reader, the table and the writer: sources of every kind for a text, and errors as objects.
"
Class {
	#name : 'SimdCSVReadingTestCase',
	#superclass : 'SimdCSVTestCase',
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'testing' }
SimdCSVReadingTestCase class >> isAbstract [
	^ self == SimdCSVReadingTestCase
]

{ #category : 'helpers' }
SimdCSVReadingTestCase >> lines: aCollection [
	"The lines, each ended by LF"

	^ String streamContents: [ :stream |
		  aCollection do: [ :each |
			  stream
				  nextPutAll: each;
				  lf ] ]
]

{ #category : 'helpers' }
SimdCSVReadingTestCase >> reader: aSource [
	^ SimdCSVReader on: aSource
]

{ #category : 'helpers' }
SimdCSVReadingTestCase >> read: aSource [
	^ (self reader: aSource) upToEnd
]

{ #category : 'helpers' }
SimdCSVReadingTestCase >> errorOf: aBlock [
	"The SimdCSVError that aBlock signals"

	| error |
	error := [
	         aBlock value.
	         nil ]
		         on: SimdCSVError
		         do: [ :each | each ].
	self assert: error notNil description: 'no error was signalled'.
	^ error
]

{ #category : 'asserting' }
SimdCSVReadingTestCase >> assert: aBlock signals: aClass [
	"Exactly aClass; answer the error"

	| error |
	error := self errorOf: aBlock.
	self assert: error class equals: aClass.
	^ error
]

{ #category : 'asserting' }
SimdCSVReadingTestCase >> assert: aBlock signals: aClass text: aString [
	"Exactly aClass, with that messageText; answer the error"

	| error |
	error := self assert: aBlock signals: aClass.
	self assert: error messageText equals: aString.
	^ error
]

{ #category : 'helpers' }
SimdCSVReadingTestCase >> sourcesOf: aString do: aBlock [
	"Evaluate aBlock with each kind of source of aString, and its name"

	| bytes file |
	bytes := aString utf8Encoded.
	aBlock value: aString value: 'String'.
	aBlock value: aString asWideString value: 'WideString'.
	aBlock value: bytes value: 'ByteArray'.
	aBlock value: aString readStream value: 'ReadStream of characters'.
	aBlock value: bytes readStream value: 'ReadStream of bytes'.
	aBlock value: (SimdCSVTestStream on: bytes) value: 'binary stream'.
	aBlock value: (SimdCSVTestStream on: aString) value: 'character stream'.
	aBlock value: (ZnCharacterReadStream on: bytes readStream) value: 'Zinc stream'.
	file := FileSystem memory / 'source.csv'.
	file binaryWriteStreamDo: [ :stream | stream nextPutAll: bytes ].
	aBlock value: file value: 'FileReference'.
	aBlock value: file readStream value: 'readStream of a file'
]

{ #category : 'asserting' }
SimdCSVReadingTestCase >> assertSourcesOf: aString read: aBlock equals: anObject [
	"aBlock, of a reader, answers anObject for each kind of source of aString"

	self sourcesOf: aString do: [ :source :name |
		| answer |
		answer := aBlock value: (self reader: source).
		self assert: answer = anObject description: [ name , ': got ' , answer printString , ' instead of ' , anObject printString ] ]
]
