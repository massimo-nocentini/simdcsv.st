"
I am a table that is indexed a few units at a time.
"
Class {
	#name : 'SimdCSVSlicedTestTable',
	#superclass : 'SimdCSVTable',
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'private - building' }
SimdCSVSlicedTestTable >> sliceUnits [
	^ 3
]
