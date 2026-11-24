"
I am the stream of a socket: the chunks that arrive, one after another, are there when one waits for them, and I count the waits (`waits`). `next` waits for one unit; `readInto:startingAt:count:` and `next:` would wait until they have what they are asked for, and are an error when that has not arrived. After the last chunk the connection is closed (`ConnectionClosed`, or nil).
"
Class {
	#name : 'SimdCSVTestSocket',
	#superclass : 'Object',
	#instVars : [
		'chunks',
		'buffer',
		'waits',
		'signalsClosed'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'instance creation' }
SimdCSVTestSocket class >> on: aCollection [
	"Chunks, all of bytes or all of characters"

	^ self new setChunks: aCollection
]

{ #category : 'initialization' }
SimdCSVTestSocket >> setChunks: aCollection [
	chunks := aCollection asOrderedCollection.
	buffer := aCollection first copyEmpty.
	waits := 0.
	signalsClosed := true
]

{ #category : 'accessing' }
SimdCSVTestSocket >> signalsClosed: aBoolean [
	signalsClosed := aBoolean
]

{ #category : 'accessing' }
SimdCSVTestSocket >> waits [
	^ waits
]

{ #category : 'testing' }
SimdCSVTestSocket >> isBinary [
	^ buffer isString not
]

{ #category : 'testing' }
SimdCSVTestSocket >> isDataAvailable [
	buffer ifNotEmpty: [ ^ true ].
	(chunks isEmpty and: [ signalsClosed ]) ifTrue: [ ConnectionClosed signal ].
	^ false
]

{ #category : 'reading' }
SimdCSVTestSocket >> next [
	buffer ifEmpty: [
		waits := waits + 1.
		chunks ifEmpty: [
			signalsClosed ifTrue: [ ConnectionClosed signal ].
			^ nil ].
		buffer := chunks removeFirst ].
	^ (self next: 1) first
]

{ #category : 'reading' }
SimdCSVTestSocket >> next: count [
	| answer |
	count > buffer size ifTrue: [ ^ Error signal: 'It would wait for more than has arrived' ].
	answer := buffer first: count.
	buffer := buffer allButFirst: count.
	^ answer
]

{ #category : 'reading' }
SimdCSVTestSocket >> readInto: aCollection startingAt: start count: count [
	aCollection replaceFrom: start to: start + count - 1 with: (self next: count) startingAt: 1.
	^ count
]
