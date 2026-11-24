"
I am the abstract class of the errors of a text:

- `position`: the 1-based position of the unit, counted from the first unit the reader read, a byte order mark included;
- `unitName`: what is counted, byte or character;
- `line`: the 1-based line of the record's start;
- `record`: the 1-based number of the record, the header included;
- `field`: the 1-based number of the field in its record, or nil;
- `code`: the code of the primitive, 1 to 6, or nil;
- `columnName`: the name of the column, or nil.

My `messageText` is made of them.
"
Class {
	#name : 'SimdCSVParseError',
	#superclass : 'SimdCSVError',
	#instVars : [
		'position',
		'unitName',
		'line',
		'record',
		'field',
		'code',
		'columnName'
	],
	#category : 'SimdCSV-Errors',
	#package : 'SimdCSV',
	#tag : 'Errors'
}

{ #category : 'testing' }
SimdCSVParseError class >> isAbstract [
	^ self == SimdCSVParseError
]

{ #category : 'accessing' }
SimdCSVParseError >> code [
	^ code
]

{ #category : 'accessing' }
SimdCSVParseError >> code: anObject [
	code := anObject
]

{ #category : 'accessing' }
SimdCSVParseError >> columnName [
	^ columnName
]

{ #category : 'accessing' }
SimdCSVParseError >> columnName: anObject [
	columnName := anObject
]

{ #category : 'accessing' }
SimdCSVParseError >> field [
	^ field
]

{ #category : 'accessing' }
SimdCSVParseError >> field: anObject [
	field := anObject
]

{ #category : 'accessing' }
SimdCSVParseError >> line [
	^ line
]

{ #category : 'accessing' }
SimdCSVParseError >> line: anObject [
	line := anObject
]

{ #category : 'accessing' }
SimdCSVParseError >> position [
	^ position
]

{ #category : 'accessing' }
SimdCSVParseError >> position: anObject [
	position := anObject
]

{ #category : 'accessing' }
SimdCSVParseError >> record [
	^ record
]

{ #category : 'accessing' }
SimdCSVParseError >> record: anObject [
	record := anObject
]

{ #category : 'accessing' }
SimdCSVParseError >> unitName [
	"What position counts: byte or character"

	^ unitName ifNil: [ 'byte' ]
]

{ #category : 'accessing' }
SimdCSVParseError >> unitName: aString [
	unitName := aString
]

{ #category : 'printing' }
SimdCSVParseError >> describePlaceOn: aStream [
	"The unit, then the record and the line"

	aStream
		nextPutAll: self unitName;
		space;
		print: position;
		nextPutAll: ' (record ';
		print: record;
		nextPutAll: ', line ';
		print: line
]

{ #category : 'printing' }
SimdCSVParseError >> describeRecordOn: aStream [
	"The record, the line and the unit"

	aStream
		nextPutAll: 'record ';
		print: record;
		nextPutAll: ', line ';
		print: line;
		nextPutAll: ', ';
		nextPutAll: self unitName;
		space;
		print: position
]
