"
I am signalled for bytes that are not UTF-8, in a field that is built (an ignored column is not looked at): my `position` is the first byte of the bad sequence.

With `isByteOrderMark`, the text begins with the byte order mark of UTF-16 or UTF-32: it must be decoded first.
"
Class {
	#name : 'SimdCSVInvalidEncoding',
	#superclass : 'SimdCSVParseError',
	#instVars : [
		'isByteOrderMark'
	],
	#category : 'SimdCSV-Errors',
	#package : 'SimdCSV',
	#tag : 'Errors'
}

{ #category : 'accessing' }
SimdCSVInvalidEncoding >> isByteOrderMark [
	"Whether the text begins with a byte order mark that is not the one of UTF-8"

	^ isByteOrderMark ifNil: [ false ]
]

{ #category : 'accessing' }
SimdCSVInvalidEncoding >> isByteOrderMark: aBoolean [
	isByteOrderMark := aBoolean
]

{ #category : 'printing' }
SimdCSVInvalidEncoding >> describeOn: aStream [
	self isByteOrderMark ifTrue: [
		^ aStream
			  nextPutAll: 'Not UTF-8 but a UTF-16 or UTF-32 byte order mark at ';
			  nextPutAll: self unitName;
			  space;
			  print: position;
			  nextPutAll: ': decode the file first' ].
	aStream nextPutAll: 'Invalid UTF-8 at '.
	self describePlaceOn: aStream.
	aStream
		nextPutAll: ', field ';
		print: field;
		nextPutAll: '): try encoding: #latin1, or decode the file first'
]
