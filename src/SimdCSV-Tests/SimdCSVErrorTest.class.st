"
I test the places and the texts of the errors.
"
Class {
	#name : 'SimdCSVErrorTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
SimdCSVErrorTest >> testConversionError [
	| text error |
	text := self lines: #( 'trip_id,stop_sequence' 'x,1' '"y' 'z",12abc' ).
	error := self assert: [ (self reader: text) skipHeader; addField; addIntegerField; upToEnd ] signals: SimdCSVConversionError text: 'Not an integer: ''12abc'' in column stop_sequence (field 2), record 3, line 3, character 33'.
	self assert: error text equals: '12abc'.
	self assert: error type equals: #integer.
	self assert: error field equals: 2.
	self assert: error record equals: 3.
	self assert: error line equals: 3.
	self assert: error position equals: 33.
	self assert: error columnName equals: 'stop_sequence'.
	self assert: error isResumable.
	self assert: [ (self reader: text asByteArray) skipHeader; column: #stop_sequence as: #integer; upToEnd ] signals: SimdCSVConversionError text: 'Not an integer: ''12abc'' in column stop_sequence (field 2), record 3, line 3, byte 33'.
	self assert: [ (self reader: 'a,"x""y"' asByteArray) addIgnoredField; addFloatField; upToEnd ] signals: SimdCSVConversionError text: 'Not a float: ''x"y'' in field 2, record 1, line 1, byte 3'.
	self assert: [ (self reader: ';1.5' asByteArray) separator: $;; addFloatFieldRadixPointComma; addFloatFieldRadixPointComma; upToEnd ] signals: SimdCSVConversionError text: 'Not a float: ''1.5'' in field 2, record 1, line 1, byte 2'.
	self assert: [ (self reader: (self lines: #( 'a' 'yes' )) asByteArray) skipHeader; column: #a as: #boolean; upToEnd ] signals: SimdCSVConversionError text: 'Not a boolean: ''yes'' in column a (field 1), record 2, line 2, byte 3'
]

{ #category : 'tests' }
SimdCSVErrorTest >> testInvalidEncoding [
	| error |
	error := self assert: [ self read: #[ 97 10 34 10 34 44 98 195 40 ] ] signals: SimdCSVInvalidEncoding text: 'Invalid UTF-8 at byte 8 (record 2, line 2, field 2): try encoding: #latin1, or decode the file first'.
	self assert: error code equals: 4.
	self assert: [ self read: #[ 255 254 0 ] ] signals: SimdCSVInvalidEncoding text: 'Not UTF-8 but a UTF-16 or UTF-32 byte order mark at byte 1: decode the file first'.
	self assert: [ (self reader: #[ 255 44 97 ]) readHeader ] signals: SimdCSVInvalidEncoding text: 'Invalid UTF-8 at byte 1 (record 1, line 1, field 1): try encoding: #latin1, or decode the file first'
]

{ #category : 'tests' }
SimdCSVErrorTest >> testQuoteErrors [
	| text |
	text := self lines: #( 'a,b' '"c' 'd",e"f' ).
	self assert: [ (self reader: text asByteArray) beStrictQuoting; upToEnd ] signals: SimdCSVQuoteError text: 'Unexpected quote at byte 12 (record 2, line 2)'.
	self assert: [ (self reader: text) beStrictQuoting; upToEnd ] signals: SimdCSVQuoteError text: 'Unexpected quote at character 12 (record 2, line 2)'.
	self assert: [ (self reader: (self lines: #( '"a"' '"a" ,b' )) asByteArray) beStrictQuoting; upToEnd ] signals: SimdCSVQuoteError text: 'Text after a closing quote at byte 8 (record 2, line 2)'.
	self assert: [ (self reader: (self lines: #( 'a' 'b,"c' 'd' )) asByteArray) beStrictQuoting; upToEnd ] signals: SimdCSVQuoteError text: 'Unterminated quote opened at byte 5 (record 2, line 2)'.
	self assert: [ SimdCSV count: text asByteArray dialect: (SimdCSVDialect comma strictQuoting: true; yourself) ] signals: SimdCSVQuoteError text: 'Unexpected quote at byte 12 (record 2, line 2)'.
	self assert: [ SimdCSV tableFrom: text asByteArray dialect: (SimdCSVDialect comma strictQuoting: true; yourself) ] signals: SimdCSVQuoteError text: 'Unexpected quote at byte 12 (record 2, line 2)'
]

{ #category : 'tests' }
SimdCSVErrorTest >> testFieldCountMismatch [
	| text error |
	text := self lines: #( 'a,b,c' '1,"' '",3' '4,5,6,7' ).
	error := self assert: [ (self reader: text asByteArray) beStrict; upToEnd ] signals: SimdCSVFieldCountMismatch text: 'Expected 3 fields but found 4, record 3, line 4, byte 15'.
	self assert: error expected equals: 3.
	self assert: error actual equals: 4.
	self assert: [ SimdCSV tableFrom: text asByteArray dialect: (SimdCSVDialect comma strictFieldCount: true; yourself) ] signals: SimdCSVFieldCountMismatch text: 'Expected 3 fields but found 4, record 3, line 4, byte 15'.
	self assert: [ (self reader: text) addField; beStrict; upToEnd ] signals: SimdCSVFieldCountMismatch text: 'Expected 1 field but found 3, record 1, line 1, character 1'
]

{ #category : 'tests' }
SimdCSVErrorTest >> testRecordTooLong [
	| text error |
	text := self lines: #( 'a,b' 'c,"d' 'e","fghijklmnopqrstuvw' 'x,y' ).
	#( 1 4 100 ) do: [ :batch |
		error := self assert: [ (self reader: text asByteArray) batchBytes: batch; maxRecordBytes: 14; upToEnd ] signals: SimdCSVResourceError text: 'Record 2 starting at line 2 (byte 5) exceeds maxRecordBytes (14): possible unclosed quote opened at byte 13'.
		self assert: error quotePosition equals: 13.
		self assert: error limit equals: 14.
		self assert: [ (self reader: (SimdCSVTestStream on: text sizes: #( 3 ))) batchBytes: batch; maxRecordBytes: 14; upToEnd ] signals: SimdCSVResourceError text: 'Record 2 starting at line 2 (character 5) exceeds maxRecordBytes (14): possible unclosed quote opened at character 13'.
		self assert: [ (self reader: 'abcdefghij' asByteArray) batchBytes: batch; maxRecordBytes: 5; upToEnd ] signals: SimdCSVResourceError text: 'Record 1 starting at line 1 (byte 1) exceeds maxRecordBytes (5)'.
		self assert: [ (self reader: 'abcdefghij"k' asByteArray) batchBytes: batch; maxRecordBytes: 5; quote: nil; upToEnd ] signals: SimdCSVResourceError text: 'Record 1 starting at line 1 (byte 1) exceeds maxRecordBytes (5)' ]
]

{ #category : 'tests' }
SimdCSVErrorTest >> testTooManyFields [
	| text |
	text := 'a' , String lf , (String new: 1024 withAll: $,).
	self assert: [ (self reader: text asByteArray) maxFields: 1024; upToEnd ] signals: SimdCSVResourceError text: 'Record 2 has more than maxFields (1024) fields, line 2, byte 3'
]

{ #category : 'tests' }
SimdCSVErrorTest >> testTableLimits [
	[
	SimdCSVTable maxIndexBytes: 12.
	self assert: (SimdCSV tableFrom: 'a,b,c') columnCount equals: 3.
	self assert: [ SimdCSV tableFrom: 'a,b,c,d' ] signals: SimdCSVResourceError text: 'The index takes 16 bytes, more than maxIndexBytes (12)' ] ensure: [ SimdCSVTable maxIndexBytes: nil ].
	self assert: [ SimdCSVSmallTestTable on: 'a,b,c,d,e' ] signals: SimdCSVResourceError text: 'The input has 9 characters, more than 8'.
	self assert: (SimdCSVSmallTestTable on: 'a,b,c,d') columnCount equals: 4.
	self assert: (self assert: [ SimdCSVSmallTestTable on: (SimdCSVTestStream on: (ByteArray new: 100)) ] signals: SimdCSVResourceError) kind equals: #inputUnits.
	self assert: [
		SimdCSVSmallTestTable on: (FileSystem memory / 'a.csv' in: [ :file |
				 file writeStreamDo: [ :out | out nextPutAll: 'a,b,c,d,e' ].
				 file ]) ] signals: SimdCSVResourceError text: 'The input has 9 bytes, more than 8'
]

{ #category : 'tests' }
SimdCSVErrorTest >> testHeaderErrors [
	| text |
	text := self lines: #( 'a,b,a' '1,2,3' ).
	self assert: [ (self reader: text) namedColumnsConfiguration ] signals: SimdCSVHeaderError text: 'Duplicate column name a (fields 1 and 3): see renameDuplicates'.
	self assert: [ (self reader: text) skipHeader; selectColumns: #( #c ) ] signals: SimdCSVHeaderError text: 'No column is named c'.
	self assert: [ (SimdCSV tableFrom: text) column: #a ] signals: SimdCSVHeaderError text: 'Duplicate column name a (fields 1 and 3): see renameDuplicates'.
	self assert: [ (SimdCSV tableFrom: text) column: 'c' ] signals: SimdCSVHeaderError text: 'No column is named c'
]

{ #category : 'helpers' }
SimdCSVErrorTest >> place: position in: aString [
	"The line of the character at position, the naive way"

	| line |
	line := 1.
	1 to: position - 1 do: [ :i |
		| c next |
		c := aString at: i.
		next := aString at: i + 1 ifAbsent: [ nil ].
		(c = Character lf or: [ c = Character cr and: [ next ~= Character lf ] ]) ifTrue: [ line := line + 1 ] ].
	^ line
]

{ #category : 'tests' }
SimdCSVErrorTest >> testPlacesInRandomTexts [
	"The record, the line and the position of an error in a text of quoted line ends, blank lines and all the line ends, read in batches of every size"

	| random |
	random := self random.
	(self largeSize: 400) timesRepeat: [
		| text bad start record records error skip source reader mark table |
		skip := (random nextInteger: 2) = 1.
		records := random nextInteger: 12.
		bad := random nextInteger: records.
		record := 0.
		mark := (random nextInteger: 2) = 1.
		text := String streamContents: [ :out |
			        mark ifTrue: [ out nextPut: (Character codePoint: 16rFEFF) ].
			        1 to: records do: [ :i |
				        [ (random nextInteger: 3) = 1 ] whileTrue: [
					        out nextPutAll: String crlf.
					        skip ifFalse: [ record := record + 1 ] ].
				        record := record + 1.
				        i = bad ifTrue: [ start := { (out position + 1). record } ].
				        out nextPutAll: (i = bad
						         ifTrue: [ '1,x' ]
						         ifFalse: [
							         #( '1,2' '3,"' ) at: (random nextInteger: 2) ]).
				        (out contents last = $") ifTrue: [
					        (random nextInteger: 4) timesRepeat: [ out nextPutAll: ({ String lf. String cr. String crlf. 'a' } at: (random nextInteger: 4)) ].
					        out nextPut: $" ].
				        i = records ifFalse: [ out nextPutAll: ({ String lf. String cr. String crlf } at: (random nextInteger: 3)) ] ] ].
		source := (random nextInteger: 2) = 1
			          ifTrue: [ text ]
			          ifFalse: [ SimdCSVTestStream on: text sizes: { (random nextInteger: 5). (random nextInteger: 30) } ].
		reader := self reader: source.
		reader
			batchBytes: (random nextInteger: 40);
			addField;
			addIntegerField.
		skip ifTrue: [ reader skipEmptyLines ].
		error := [
		         reader upToEnd.
		         nil ]
			         on: SimdCSVConversionError
			         do: [ :each |
				         each text = 'x'
					         ifTrue: [ each ]
					         ifFalse: [ each resume: 0 ] ].
		self assert: error position equals: start first + 2.
		self assert: error line equals: (self place: start first in: text).
		self assert: error record equals: start second.
		table := SimdCSVTable on: text dialect: (SimdCSVDialect comma hasHeader: false; skipEmptyLines: skip; yourself).
		table columnCount = 2 ifTrue: [
			error := [
			         table column: 2 as: #integer.
			         nil ]
				         on: SimdCSVConversionError
				         do: [ :each |
					         each text = 'x'
						         ifTrue: [ each ]
						         ifFalse: [ each resume: 0 ] ].
			self assert: error position equals: start first + 2.
			self assert: error line equals: (self place: start first in: text).
			self assert: error record equals: start second ] ]
]
