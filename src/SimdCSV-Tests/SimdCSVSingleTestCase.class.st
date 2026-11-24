"
I am the abstract test case of the tests that run once, on no backend in particular.
"
Class {
	#name : 'SimdCSVSingleTestCase',
	#superclass : 'SimdCSVTestCase',
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'testing' }
SimdCSVSingleTestCase class >> isAbstract [
	^ self == SimdCSVSingleTestCase
]

{ #category : 'building suites' }
SimdCSVSingleTestCase class >> testParameters [
	"The tests run once"

	^ ParametrizedTestMatrix new
		  forSelector: #backendName addOptions: #( #none );
		  yourself
]

{ #category : 'accessing' }
SimdCSVSingleTestCase >> backendObject [
	"The hook #backend is not set"

	^ nil
]
