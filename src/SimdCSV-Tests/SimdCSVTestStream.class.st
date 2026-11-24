"
I am a stream of bytes or of characters that answers at most as many units at a time as `sizes` says, a collection that is used again and again, and counts the reads.
"
Class {
	#name : 'SimdCSVTestStream',
	#superclass : 'Object',
	#instVars : [
		'collection',
		'sizes',
		'position',
		'reads',
		'failAt',
		'isClosed'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'instance creation' }
SimdCSVTestStream class >> on: aCollection [
	^ self on: aCollection sizes: #( 1000000 )
]

{ #category : 'instance creation' }
SimdCSVTestStream class >> on: aCollection sizes: sizes [
	^ self new setCollection: aCollection sizes: sizes
]

{ #category : 'initialization' }
SimdCSVTestStream >> setCollection: aCollection sizes: aSequence [
	collection := aCollection.
	sizes := aSequence.
	position := reads := 0.
	isClosed := false
]

{ #category : 'testing' }
SimdCSVTestStream >> isBinary [
	^ collection isString not
]

{ #category : 'testing' }
SimdCSVTestStream >> isClosed [
	^ isClosed
]

{ #category : 'accessing' }
SimdCSVTestStream >> reads [
	^ reads
]

{ #category : 'accessing' }
SimdCSVTestStream >> position [
	^ position
]

{ #category : 'accessing' }
SimdCSVTestStream >> failAt: anInteger [
	"The read of that number signals an Error, once"

	failAt := anInteger
]

{ #category : 'closing' }
SimdCSVTestStream >> close [
	isClosed := true
]

{ #category : 'private' }
SimdCSVTestStream >> countFor: anInteger [
	reads := reads + 1.
	reads = failAt ifTrue: [ ^ Error signal: 'read' ].
	^ (anInteger min: (sizes at: reads - 1 \\ sizes size + 1)) min: collection size - position
]

{ #category : 'reading' }
SimdCSVTestStream >> next: anInteger [
	| count |
	count := self countFor: anInteger.
	position := position + count.
	^ collection copyFrom: position - count + 1 to: position
]

{ #category : 'reading' }
SimdCSVTestStream >> readInto: aCollection startingAt: start count: anInteger [
	| count |
	count := self countFor: anInteger.
	aCollection replaceFrom: start to: start + count - 1 with: collection startingAt: position + 1.
	position := position + count.
	^ count
]
