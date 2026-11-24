"
I am signalled for the names of the columns, `columnName` being the one at fault. My `kind` is:

- `#duplicate`: two columns have the name (the fields `otherField` and `field`), and columns are used by name; `renameDuplicates` of the reader makes them `a`, `a_2` and `a_3`;
- `#missing`: no column has the name.
"
Class {
	#name : 'SimdCSVHeaderError',
	#superclass : 'SimdCSVParseError',
	#instVars : [
		'kind',
		'otherField'
	],
	#category : 'SimdCSV-Errors',
	#package : 'SimdCSV',
	#tag : 'Errors'
}

{ #category : 'accessing' }
SimdCSVHeaderError >> kind [
	^ kind
]

{ #category : 'accessing' }
SimdCSVHeaderError >> kind: anObject [
	kind := anObject
]

{ #category : 'accessing' }
SimdCSVHeaderError >> otherField [
	^ otherField
]

{ #category : 'accessing' }
SimdCSVHeaderError >> otherField: anObject [
	otherField := anObject
]

{ #category : 'printing' }
SimdCSVHeaderError >> describeOn: aStream [
	kind == #missing ifTrue: [
		^ aStream
			  nextPutAll: 'No column is named ';
			  nextPutAll: columnName asString ].
	aStream
		nextPutAll: 'Duplicate column name ';
		nextPutAll: columnName asString.
	field ifNotNil: [
		otherField ifNotNil: [
			aStream
				nextPutAll: ' (fields ';
				print: otherField;
				nextPutAll: ' and ';
				print: field;
				nextPut: $) ] ].
	aStream nextPutAll: ': see renameDuplicates'
]
