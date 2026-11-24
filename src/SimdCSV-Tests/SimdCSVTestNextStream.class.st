"
I am a binary stream that only knows `next:`, and answers nil at its end.
"
Class {
	#name : 'SimdCSVTestNextStream',
	#superclass : 'Object',
	#instVars : [
		'collection',
		'position'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'instance creation' }
SimdCSVTestNextStream class >> on: aCollection [
	^ self new setCollection: aCollection
]

{ #category : 'initialization' }
SimdCSVTestNextStream >> setCollection: aCollection [
	collection := aCollection.
	position := 0
]

{ #category : 'testing' }
SimdCSVTestNextStream >> isBinary [
	^ true
]

{ #category : 'reading' }
SimdCSVTestNextStream >> next: anInteger [
	| count |
	count := (anInteger min: 2) min: collection size - position.
	count = 0 ifTrue: [ ^ nil ].
	position := position + count.
	^ collection copyFrom: position - count + 1 to: position
]
