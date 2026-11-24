"
I am signalled for a limit of the reader or of the table, `limit`, which a message of the same name changes. My `kind` is:

- `#recordBytes`: a record does not fit `maxRecordBytes`; `quotePosition` is the position of the quote that is still open there, or nil;
- `#fields`: a record has more than `maxFields` fields;
- `#indexBytes`: the index of a table would take `actual` bytes, more than `maxIndexBytes`;
- `#inputUnits`: the input of a table has `actual` units, more than an index spans.

`record`, `line` and `position` are the place of the record of the first two kinds; `unitName` says what `position` counts, byte or character.
"
Class {
	#name : 'SimdCSVResourceError',
	#superclass : 'SimdCSVError',
	#instVars : [
		'kind',
		'limit',
		'actual',
		'record',
		'line',
		'position',
		'quotePosition',
		'unitName'
	],
	#category : 'SimdCSV-Errors',
	#package : 'SimdCSV',
	#tag : 'Errors'
}

{ #category : 'accessing' }
SimdCSVResourceError >> actual [
	^ actual
]

{ #category : 'accessing' }
SimdCSVResourceError >> actual: anObject [
	actual := anObject
]

{ #category : 'accessing' }
SimdCSVResourceError >> kind [
	^ kind
]

{ #category : 'accessing' }
SimdCSVResourceError >> kind: anObject [
	kind := anObject
]

{ #category : 'accessing' }
SimdCSVResourceError >> limit [
	^ limit
]

{ #category : 'accessing' }
SimdCSVResourceError >> limit: anObject [
	limit := anObject
]

{ #category : 'accessing' }
SimdCSVResourceError >> line [
	^ line
]

{ #category : 'accessing' }
SimdCSVResourceError >> line: anObject [
	line := anObject
]

{ #category : 'accessing' }
SimdCSVResourceError >> position [
	^ position
]

{ #category : 'accessing' }
SimdCSVResourceError >> position: anObject [
	position := anObject
]

{ #category : 'accessing' }
SimdCSVResourceError >> quotePosition [
	^ quotePosition
]

{ #category : 'accessing' }
SimdCSVResourceError >> quotePosition: anObject [
	quotePosition := anObject
]

{ #category : 'accessing' }
SimdCSVResourceError >> record [
	^ record
]

{ #category : 'accessing' }
SimdCSVResourceError >> record: anObject [
	record := anObject
]

{ #category : 'accessing' }
SimdCSVResourceError >> unitName [
	"What position counts: byte or character"

	^ unitName ifNil: [ 'byte' ]
]

{ #category : 'accessing' }
SimdCSVResourceError >> unitName: aString [
	unitName := aString
]

{ #category : 'printing' }
SimdCSVResourceError >> describeOn: aStream [
	kind == #recordBytes ifTrue: [ ^ self describeRecordBytesOn: aStream ].
	kind == #fields ifTrue: [ ^ self describeFieldsOn: aStream ].
	kind == #indexBytes ifTrue: [
		^ aStream
			  nextPutAll: 'The index takes ';
			  print: actual;
			  nextPutAll: ' bytes, more than maxIndexBytes (';
			  print: limit;
			  nextPut: $) ].
	aStream
		nextPutAll: 'The input has ';
		print: actual;
		space;
		nextPutAll: self unitName;
		nextPutAll: 's, more than ';
		print: limit
]

{ #category : 'printing' }
SimdCSVResourceError >> describeFieldsOn: aStream [
	aStream
		nextPutAll: 'Record ';
		print: record;
		nextPutAll: ' has more than maxFields (';
		print: limit;
		nextPutAll: ') fields, line ';
		print: line;
		nextPutAll: ', ';
		nextPutAll: self unitName;
		space;
		print: position
]

{ #category : 'printing' }
SimdCSVResourceError >> describeRecordBytesOn: aStream [
	aStream
		nextPutAll: 'Record ';
		print: record;
		nextPutAll: ' starting at line ';
		print: line;
		nextPutAll: ' (';
		nextPutAll: self unitName;
		space;
		print: position;
		nextPutAll: ') exceeds maxRecordBytes (';
		print: limit;
		nextPut: $).
	quotePosition ifNotNil: [
		aStream
			nextPutAll: ': possible unclosed quote opened at ';
			nextPutAll: self unitName;
			space;
			print: quotePosition ]
]
