"
I am the abstract class of the errors of SimdCSV:

- `SimdCSVParseError`: the text is not what the dialect or the reader says, with a subclass for each kind;
- `SimdCSVResourceError`: a limit of the reader or of the table;
- `SimdCSVArgumentError`: a bad argument of a message of SimdCSV.

My `messageText` is made of my fields when none was given.
"
Class {
	#name : 'SimdCSVError',
	#superclass : 'Error',
	#category : 'SimdCSV-Errors',
	#package : 'SimdCSV',
	#tag : 'Errors'
}

{ #category : 'testing' }
SimdCSVError class >> isAbstract [
	^ self == SimdCSVError
]

{ #category : 'accessing' }
SimdCSVError >> messageText [
	"The text that was given, else the one made of my fields"

	^ messageText ifNil: [ self defaultMessageText ]
]

{ #category : 'printing' }
SimdCSVError >> defaultMessageText [
	"What the fields say"

	^ String streamContents: [ :stream | self describeOn: stream ]
]

{ #category : 'printing' }
SimdCSVError >> describeOn: aStream [
	aStream nextPutAll: self class name
]
