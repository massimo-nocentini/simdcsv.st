"
I am signalled for a bad argument of a message of SimdCSV: a source that is neither bytes nor characters, a dialect that says two things at once, a configuration message that the reader cannot take, or a call that the primitive refused (`ec`, its error code, a Symbol, or nil).
"
Class {
	#name : 'SimdCSVArgumentError',
	#superclass : 'SimdCSVError',
	#instVars : [
		'ec'
	],
	#category : 'SimdCSV-Errors',
	#package : 'SimdCSV',
	#tag : 'Errors'
}

{ #category : 'signalling' }
SimdCSVArgumentError class >> signalFailure: aFailure [
	"Signal what a SimdCSVFailure means"

	^ self new
		  ec: aFailure ec;
		  signal
]

{ #category : 'accessing' }
SimdCSVArgumentError >> ec [
	^ ec
]

{ #category : 'accessing' }
SimdCSVArgumentError >> ec: anObject [
	ec := anObject
]

{ #category : 'printing' }
SimdCSVArgumentError >> describeOn: aStream [
	aStream
		nextPutAll: 'SimdCSV: primitive failed: ';
		print: ec
]
