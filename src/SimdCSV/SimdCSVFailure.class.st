"
I am the error code of a failed primitive of the `SimdCSVPlugin`, or of a call of `SimdCSVSmalltalk` that fails as the primitive would (`ec`: a Symbol, such as `#'bad argument'`, or nil when the module is missing).

Bad data is an answer with a status, never a failure.
"
Class {
	#name : 'SimdCSVFailure',
	#superclass : 'Object',
	#instVars : [
		'ec'
	],
	#category : 'SimdCSV-Backends',
	#package : 'SimdCSV',
	#tag : 'Backends'
}

{ #category : 'instance creation' }
SimdCSVFailure class >> on: errorCode [
	"The error code of a failed primitive of the plugin (nil when the module is missing)"

	^ self new
		ec: errorCode;
		yourself
]

{ #category : 'accessing' }
SimdCSVFailure >> ec [
	^ ec
]

{ #category : 'accessing' }
SimdCSVFailure >> ec: errorCode [
	ec := errorCode
]

{ #category : 'testing' }
SimdCSVFailure >> isNoMemory [
	"Whether the answer of the primitive could not be allocated (PrimErrNoMemory, 9)"

	^ ec == #'insufficient object memory' or: [ ec = 9 ]
]

{ #category : 'testing' }
SimdCSVFailure >> isNotFound [
	"Whether the module could not be loaded, or it has no such primitive"

	^ ec isNil or: [ ec == #'not found' ]
]

{ #category : 'printing' }
SimdCSVFailure >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(; print: ec; nextPut: $)
]

{ #category : 'testing' }
SimdCSVFailure >> simdCSVFailed [
	"Whether I am the answer of a failed primitive: yes"

	^ true
]
