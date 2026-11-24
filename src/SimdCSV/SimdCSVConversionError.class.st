"
I am signalled for a cell that is not of the type of its column: `text` is the field and `type` a Symbol (`#integer`, `#float`, `#floatComma`, `#boolean`). I am resumable, and the value of `resume:` is the cell.

```smalltalk
[ reader upToEnd ]
	on: SimdCSVConversionError
	do: [ :error | error resume: nil ]
```
"
Class {
	#name : 'SimdCSVConversionError',
	#superclass : 'SimdCSVParseError',
	#instVars : [
		'text',
		'type'
	],
	#category : 'SimdCSV-Errors',
	#package : 'SimdCSV',
	#tag : 'Errors'
}

{ #category : 'accessing' }
SimdCSVConversionError >> text [
	^ text
]

{ #category : 'accessing' }
SimdCSVConversionError >> text: anObject [
	text := anObject
]

{ #category : 'accessing' }
SimdCSVConversionError >> type [
	^ type
]

{ #category : 'accessing' }
SimdCSVConversionError >> type: anObject [
	type := anObject
]

{ #category : 'testing' }
SimdCSVConversionError >> isResumable [
	"The value of resume: is the cell"

	^ true
]

{ #category : 'printing' }
SimdCSVConversionError >> typeName [
	"The type in words"

	type == #integer ifTrue: [ ^ 'an integer' ].
	type == #floatComma ifTrue: [ ^ 'a float' ].
	^ 'a ' , type asString
]

{ #category : 'printing' }
SimdCSVConversionError >> describeOn: aStream [
	aStream
		nextPutAll: 'Not ';
		nextPutAll: self typeName;
		nextPutAll: ': ';
		print: text.
	columnName
		ifNil: [
			aStream
				nextPutAll: ' in field ';
				print: field ]
		ifNotNil: [
			aStream
				nextPutAll: ' in column ';
				nextPutAll: columnName asString;
				nextPutAll: ' (field ';
				print: field;
				nextPut: $) ].
	aStream nextPutAll: ', '.
	self describeRecordOn: aStream
]
