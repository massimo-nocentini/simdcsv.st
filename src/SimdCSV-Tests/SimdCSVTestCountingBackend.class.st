"
I am a backend that passes its calls on to another one, and counts the calls, the units that were indexed and the rows that were built.
"
Class {
	#name : 'SimdCSVTestCountingBackend',
	#superclass : 'Object',
	#instVars : [
		'backend',
		'units',
		'indexCalls',
		'rowCalls',
		'rowsBuilt'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'instance creation' }
SimdCSVTestCountingBackend class >> on: aBackend [
	^ self new setBackend: aBackend
]

{ #category : 'initialization' }
SimdCSVTestCountingBackend >> setBackend: aBackend [
	backend := aBackend.
	units := indexCalls := rowCalls := rowsBuilt := 0
]

{ #category : 'accessing' }
SimdCSVTestCountingBackend >> indexCalls [
	^ indexCalls
]

{ #category : 'accessing' }
SimdCSVTestCountingBackend >> rowCalls [
	^ rowCalls
]

{ #category : 'accessing' }
SimdCSVTestCountingBackend >> rowsBuilt [
	^ rowsBuilt
]

{ #category : 'accessing' }
SimdCSVTestCountingBackend >> units [
	^ units
]

{ #category : 'calls' }
SimdCSVTestCountingBackend >> index: source base: base from: start to: stop dialect: word into: aWordArray from: destFrom [
	indexCalls := indexCalls + 1.
	units := units + stop - start + 1.
	^ backend index: source base: base from: start to: stop dialect: word into: aWordArray from: destFrom
]

{ #category : 'calls' }
SimdCSVTestCountingBackend >> measure: source from: start to: stop dialect: word [
	units := units + stop - start + 1.
	^ backend measure: source from: start to: stop dialect: word
]

{ #category : 'calls' }
SimdCSVTestCountingBackend >> rows: source base: base to: stop dialect: word index: anIndex from: indexFrom to: indexTo types: types fieldCount: fieldCount into: anArray from: destFrom wideStringClass: wideClass empty: emptyValue budget: budget [
	| answer |
	rowCalls := rowCalls + 1.
	answer := backend
		  rows: source
		  base: base
		  to: stop
		  dialect: word
		  index: anIndex
		  from: indexFrom
		  to: indexTo
		  types: types
		  fieldCount: fieldCount
		  into: anArray
		  from: destFrom
		  wideStringClass: wideClass
		  empty: emptyValue
		  budget: budget.
	rowsBuilt := rowsBuilt + (answer at: 2).
	^ answer
]
