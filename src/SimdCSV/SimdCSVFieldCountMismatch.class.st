"
I am signalled with `strictFieldCount:` for a record with another count of fields: `expected` and `actual`. My `position` is the start of the record.
"
Class {
	#name : 'SimdCSVFieldCountMismatch',
	#superclass : 'SimdCSVParseError',
	#instVars : [
		'expected',
		'actual'
	],
	#category : 'SimdCSV-Errors',
	#package : 'SimdCSV',
	#tag : 'Errors'
}

{ #category : 'accessing' }
SimdCSVFieldCountMismatch >> actual [
	^ actual
]

{ #category : 'accessing' }
SimdCSVFieldCountMismatch >> actual: anObject [
	actual := anObject
]

{ #category : 'accessing' }
SimdCSVFieldCountMismatch >> expected [
	^ expected
]

{ #category : 'accessing' }
SimdCSVFieldCountMismatch >> expected: anObject [
	expected := anObject
]

{ #category : 'printing' }
SimdCSVFieldCountMismatch >> describeOn: aStream [
	aStream
		nextPutAll: 'Expected ';
		print: expected;
		nextPutAll: (expected = 1
				 ifTrue: [ ' field' ]
				 ifFalse: [ ' fields' ]);
		nextPutAll: ' but found ';
		print: actual;
		nextPutAll: ', '.
	self describeRecordOn: aStream
]
