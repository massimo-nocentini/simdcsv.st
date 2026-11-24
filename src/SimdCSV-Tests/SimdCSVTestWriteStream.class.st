"
I am a character stream that keeps what it is given, piece by piece.
"
Class {
	#name : 'SimdCSVTestWriteStream',
	#superclass : 'Object',
	#instVars : [
		'parts',
		'calls'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'instance creation' }
SimdCSVTestWriteStream class >> on: aCollection [
	^ self new setParts: aCollection
]

{ #category : 'initialization' }
SimdCSVTestWriteStream >> setParts: aCollection [
	parts := aCollection.
	calls := OrderedCollection new
]

{ #category : 'accessing' }
SimdCSVTestWriteStream >> calls [
	^ calls
]

{ #category : 'writing' }
SimdCSVTestWriteStream >> nextPutAll: aString [
	parts add: aString
]

{ #category : 'writing' }
SimdCSVTestWriteStream >> flush [
	calls add: #flush
]

{ #category : 'closing' }
SimdCSVTestWriteStream >> close [
	calls add: #close
]
