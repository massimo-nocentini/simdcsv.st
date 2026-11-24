"
I read a `ByteArray` or a `String` in place: my window, `first` to `limit`, is a batch of it, or more when a record does not fit a batch. Nothing is copied.
"
Class {
	#name : 'SimdCSVCollectionInput',
	#superclass : 'SimdCSVInput',
	#instVars : [
		'end',
		'stalled'
	],
	#category : 'SimdCSV-Reading',
	#package : 'SimdCSV',
	#tag : 'Reading'
}

{ #category : 'instance creation' }
SimdCSVCollectionInput class >> on: aCollection from: start to: stop [
	^ self new setSource: aCollection from: start to: stop
]

{ #category : 'initialization' }
SimdCSVCollectionInput >> setSource: aCollection from: start to: stop [
	source := aCollection isSymbol
		          ifTrue: [ aCollection asString ]
		          ifFalse: [ aCollection ].
	first := start.
	limit := start - 1.
	end := stop.
	origin := 1 - start.
	stalled := true
]

{ #category : 'testing' }
SimdCSVCollectionInput >> isFinal [
	^ limit >= end
]

{ #category : 'testing' }
SimdCSVCollectionInput >> needsMore [
	^ limit < end and: [ stalled or: [ first > limit ] ]
]

{ #category : 'reading' }
SimdCSVCollectionInput >> advanceTo: position complete: aBoolean [
	stalled := position = first.
	stalled ifTrue: [
		stalled := aBoolean.
		^ self ].
	first := position.
	limit := first + batchUnits - 1 min: end
]

{ #category : 'reading' }
SimdCSVCollectionInput >> more [
	| window |
	window := limit - first + 1.
	window >= maxUnits ifTrue: [ ^ false ].
	window := window < batchUnits
		          ifTrue: [ batchUnits ]
		          ifFalse: [ window * 2 min: maxUnits ].
	limit := first + window - 1 min: end.
	stalled := false.
	^ true
]

{ #category : 'reading' }
SimdCSVCollectionInput >> readAll [
	limit := end.
	^ limit - first + 1 <= maxUnits
]
