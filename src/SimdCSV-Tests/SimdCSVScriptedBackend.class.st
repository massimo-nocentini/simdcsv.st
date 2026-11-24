"
I am a backend that answers what it was given, in order, and counts its calls.
"
Class {
	#name : 'SimdCSVScriptedBackend',
	#superclass : 'Object',
	#instVars : [
		'answers',
		'calls'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'instance creation' }
SimdCSVScriptedBackend class >> answering: aCollection [
	^ self new
		  setAnswers: aCollection;
		  yourself
]

{ #category : 'initialization' }
SimdCSVScriptedBackend >> setAnswers: aCollection [
	answers := aCollection asOrderedCollection.
	calls := 0
]

{ #category : 'accessing' }
SimdCSVScriptedBackend >> calls [
	^ calls
]

{ #category : 'private' }
SimdCSVScriptedBackend >> next [
	calls := calls + 1.
	^ answers removeFirst
]

{ #category : 'backend' }
SimdCSVScriptedBackend >> index: source base: base from: start to: stop dialect: word into: aWordArray from: destFrom [
	^ self next
]

{ #category : 'backend' }
SimdCSVScriptedBackend >> measure: source from: start to: stop dialect: word [
	^ self next
]

{ #category : 'backend' }
SimdCSVScriptedBackend >> rows: source base: base to: stop dialect: word index: anIndex from: indexFrom to: indexTo types: types fieldCount: fieldCount into: anArray from: destFrom wideStringClass: wideClass empty: emptyValue budget: budget [
	^ self next
]
