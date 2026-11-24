"
I test the table of the class comment of `SimdCSVReader`, a test for each of its rows, with every kind of source.
"
Class {
	#name : 'SimdCSVSemanticsTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SimdCSVSemanticsTest >> assert: aString rows: rows [
	self assertSourcesOf: aString read: [ :reader | reader upToEnd ] equals: rows
]

{ #category : 'helpers' }
SimdCSVSemanticsTest >> assert: aString with: aBlock rows: rows [
	"aBlock configures the reader"

	self
		assertSourcesOf: aString
		read: [ :reader |
			aBlock value: reader.
			reader upToEnd ]
		equals: rows
]

{ #category : 'helpers' }
SimdCSVSemanticsTest >> assert: aString with: aBlock signals: aClass [
	"aBlock configures the reader"

	self sourcesOf: aString do: [ :source :name |
		| reader |
		reader := self reader: source.
		aBlock value: reader.
		self assert: [ reader upToEnd ] signals: aClass ]
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testLineEnds [
	| rows |
	rows := #( #( 'a' 'b' ) #( 'c' 'd' ) #( 'e' 'f' ) ).
	{ String lf. String cr. String crlf } do: [ :end |
		self assert: 'a,b' , end , 'c,d' , end , 'e,f' , end rows: rows.
		self assert: 'a,b' , end , 'c,d' , end , 'e,f' , end with: [ :reader | reader beStrict; beStrictQuoting ] rows: rows ].
	self assert: 'a,b' , String cr , 'c,d' , String crlf , 'e,f' , String lf rows: rows.
	self
		assert: 'a,b' , String crlf , 'c' , String cr , 'd' , String lf
		with: [ :reader | reader dialect: (SimdCSVDialect comma lineEnd: #lf; yourself) ]
		rows: { { 'a'. 'b' , String cr }. { 'c' , String cr , 'd' } }
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testLastLineEnd [
	{ ''. String lf. String cr. String crlf } do: [ :end |
		self assert: 'a,b' , end rows: #( #( 'a' 'b' ) ).
		self assert: '"a","b"' , end with: [ :reader | reader beStrict; beStrictQuoting ] rows: #( #( 'a' 'b' ) ) ].
	self assert: 'a,' rows: { { 'a'. nil } }
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testEmptyInput [
	self assert: '' rows: #(  ).
	self assert: '' with: [ :reader | reader beStrict; beStrictQuoting ] rows: #(  ).
	self assert: '' with: [ :reader | reader addIntegerField; addField ] rows: #(  )
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testBlankLineNothingDeclared [
	self assert: String lf , '1,2,3' rows: { { nil }. { '1'. '2'. '3' } }.
	self assert: (self lines: #( 'a' '' 'b' )) rows: { { 'a' }. { nil }. { 'b' } }.
	self assert: String lf with: [ :reader | reader beStrict ] rows: { { nil } }.
	self assert: String lf , '1,2,3' with: [ :reader | reader beStrict ] signals: SimdCSVFieldCountMismatch.
	self assert: (self lines: #( 'a' '' 'b' )) with: [ :reader | reader beStrict ] rows: { { 'a' }. { nil }. { 'b' } }
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testBlankLineWidthDeclared [
	| text |
	text := self lines: #( '' '1,2' '' '3,4' '' ).
	self assert: text with: [ :reader | reader addIntegerField; addIntegerField ] rows: { { nil. nil }. { 1. 2 }. { nil. nil }. { 3. 4 }. { nil. nil } }.
	self assert: text with: [ :reader | reader addIntegerField; addIntegerField; skipEmptyLines ] rows: #( #( 1 2 ) #( 3 4 ) ).
	self assert: text with: [ :reader | reader addIntegerField; addIntegerField; skipEmptyLines; beStrict ] rows: #( #( 1 2 ) #( 3 4 ) ).
	self assert: text with: [ :reader | reader addIntegerField; addIntegerField; beStrict ] signals: SimdCSVFieldCountMismatch.
	self assert: (self lines: #( '1' '' '2' )) with: [ :reader | reader addIntegerField; beStrict ] rows: { { 1 }. { nil }. { 2 } }.
	self assert: String crlf , String cr , 'a' , String cr , String lf , String lf , 'b' with: [ :reader | reader skipEmptyLines ] rows: #( #( 'a' ) #( 'b' ) )
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testWidthsNothingDeclared [
	| text |
	text := self lines: #( 'a,b' '1,2,3' '4' ).
	self assert: text rows: #( #( 'a' 'b' ) #( '1' '2' '3' ) #( '4' ) ).
	self assert: text with: [ :reader | reader beStrict ] signals: SimdCSVFieldCountMismatch
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testShortAndLongRecords [
	| text |
	text := 'a,b' , String lf , '1' , String lf , '2,3,"x' , String lf , 'y",5' , String lf , '6,7' , String lf.
	self assert: text with: [ :reader | reader readHeader ] rows: { { '1'. nil }. { '2'. '3' }. { '6'. '7' } }.
	self assert: text with: [ :reader | reader skipHeader; addIntegerField; addIntegerField ] rows: { { 1. nil }. { 2. 3 }. { 6. 7 } }.
	self assert: text with: [ :reader | reader skipHeader; beStrict ] signals: SimdCSVFieldCountMismatch.
	self assert: 'a,b,c' with: [ :reader | reader addField; addField; beStrict ] signals: SimdCSVFieldCountMismatch.
	self assert: 'a,b,c' with: [ :reader | reader addField; addIgnoredField; addField; beStrict ] rows: #( #( 'a' 'c' ) )
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testEmptyFields [
	self assert: 'a,,"",b' rows: { { 'a'. nil. nil. 'b' } }.
	self assert: 'a,,"",b' with: [ :reader | reader emptyFieldValue: #empty; beStrict; beStrictQuoting ] rows: #( #( 'a' #empty #empty 'b' ) ).
	self assert: 'a,,"",b' with: [ :reader | reader keepQuotedEmpty ] rows: { { 'a'. nil. ''. 'b' } }.
	self assert: 'a,,"",b' with: [ :reader | reader keepQuotedEmpty; beStrict; beStrictQuoting ] rows: { { 'a'. nil. ''. 'b' } }.
	self assert: ',"",""' with: [ :reader | reader keepQuotedEmpty; addField; addIntegerField; addFieldConverter: [ :each | 1 / 0 ] ] rows: { { nil. nil. nil } }
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testQuotedFields [
	| text rows |
	text := '"a""b","c,d","e' , String crlf , 'f","""",""""""'.
	rows := { { 'a"b'. 'c,d'. 'e' , String crlf , 'f'. '"'. '""' } }.
	self assert: text rows: rows.
	self assert: text with: [ :reader | reader beStrict; beStrictQuoting ] rows: rows
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testQuoteInUnquotedField [
	self assert: 'a"b,c""d,e"' rows: #( #( 'a"b' 'c""d' 'e"' ) ).
	self assert: 'a"b,c' with: [ :reader | reader beStrict ] rows: #( #( 'a"b' 'c' ) ).
	self assert: 'a"b,c' with: [ :reader | reader beStrictQuoting ] signals: SimdCSVQuoteError
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testTextAfterQuote [
	self assert: '"a"b,c' rows: #( #( 'ab' 'c' ) ).
	self assert: '"a"b"c",d' rows: #( #( 'ab"c"' 'd' ) ).
	self assert: '"a"b,c' with: [ :reader | reader beStrictQuoting ] signals: SimdCSVQuoteError
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testUnterminatedQuote [
	| text |
	text := 'a,"b' , String lf , 'c,d' , String lf.
	self assert: text rows: { { 'a'. 'b' , String lf , 'c,d' , String lf } }.
	self assert: '"' rows: { { nil } }.
	self assert: 'a,"' with: [ :reader | reader keepQuotedEmpty ] rows: #( #( 'a' '' ) ).
	self assert: text with: [ :reader | reader beStrictQuoting ] signals: SimdCSVQuoteError.
	self assert: text with: [ :reader | reader maxRecordBytes: 6; batchBytes: 4 ] signals: SimdCSVResourceError
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testSpaces [
	self assert: ' a , b' rows: #( #( ' a ' ' b' ) ).
	self assert: ' "a",b' rows: #( #( ' "a"' 'b' ) ).
	self assert: '"a" ,b' rows: #( #( 'a ' 'b' ) ).
	self assert: ' a , ,b' with: [ :reader | reader beStrictQuoting ] rows: #( #( ' a ' ' ' 'b' ) ).
	self assert: ' "a",b' with: [ :reader | reader beStrictQuoting ] signals: SimdCSVQuoteError.
	self assert: '"a" ,b' with: [ :reader | reader beStrictQuoting ] signals: SimdCSVQuoteError.
	self assert: ' 1 ,	2.5 ' with: [ :reader | reader addIntegerField; addFloatField ] rows: #( #( 1 2.5 ) )
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testByteOrderMark [
	| mark latin1 |
	mark := String with: (Character codePoint: 16rFEFF).
	self assert: mark , 'a,b' rows: #( #( 'a' 'b' ) ).
	self assert: mark , '"a",b' with: [ :reader | reader beStrict; beStrictQuoting ] rows: #( #( 'a' 'b' ) ).
	self assert: mark rows: #(  ).
	self assert: 'a' , mark rows: { { 'a' , mark } }.
	latin1 := String withAll: (#( 239 187 191 97 ) collect: [ :each | Character value: each ]).
	self assert: ((self reader: #[ 239 187 191 97 ]) encoding: #latin1; next) equals: { latin1 }.
	self assert: (self read: latin1) equals: { { latin1 } }.
	{ #[ 255 254 97 0 ]. #[ 254 255 0 97 ]. #[ 255 254 ] } do: [ :bytes |
		self assert: [ self read: bytes ] signals: SimdCSVInvalidEncoding.
		self assert: [ self read: bytes readStream ] signals: SimdCSVInvalidEncoding.
		self assert: [ self read: (SimdCSVTestStream on: bytes sizes: #( 1 )) ] signals: SimdCSVInvalidEncoding.
		self assert: ((self reader: bytes) encoding: #latin1; next) size equals: 1 ]
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testControls [
	| text |
	text := String withAll: (((0 to: 31) asArray collect: [ :each | Character value: each ]) copyWithoutAll: { Character lf. Character cr }).
	self assert: text , ',b' rows: { { text. 'b' } }.
	self assert: text , ',b' with: [ :reader | reader beStrict; beStrictQuoting ] rows: { { text. 'b' } }
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testInvalidUTF8 [
	"Only in the fields that are built"

	| bytes |
	bytes := #[ 97 44 98 10 99 44 195 40 10 100 44 101 10 ].
	{ bytes. bytes readStream. (SimdCSVTestStream on: bytes sizes: #( 1 2 )). (ZnCharacterReadStream on: bytes readStream) } do: [ :source |
		| reader |
		reader := self reader: source.
		self assert: reader next equals: #( 'a' 'b' ).
		self assert: [ reader next ] signals: SimdCSVInvalidEncoding.
		reader skipFailedRecord.
		self assert: reader next equals: #( 'd' 'e' ) ].
	self assert: ((self reader: bytes) addField; addIgnoredField; upToEnd) equals: #( #( 'a' ) #( 'c' ) #( 'd' ) ).
	self assert: ((self reader: bytes) addField; upToEnd) equals: #( #( 'a' ) #( 'c' ) #( 'd' ) ).
	self assert: (SimdCSV count: bytes) equals: 3
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testInteger [
	self assert: (self lines: #( '12' '-3' '+4' '007' )) with: [ :reader | reader addIntegerField ] rows: #( #( 12 ) #( -3 ) #( 4 ) #( 7 ) ).
	#( '12abc' '1.5' '0x10' '1 2' '-' ) do: [ :text | self assert: text with: [ :reader | reader addIntegerField ] signals: SimdCSVConversionError ]
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testFloat [
	| rows |
	rows := self read: ''.
	self assert: rows equals: #(  ).
	rows := (self reader: (self lines: #( '1e3' '1' '1.50' '.5' '5.' ))) addFloatField; upToEnd.
	self assert: rows equals: #( #( 1000.0 ) #( 1.0 ) #( 1.5 ) #( 0.5 ) #( 5.0 ) ).
	self assert: (rows allSatisfy: [ :row | row first isFloat ]).
	#( '1,5' 'e3' '.' '1e' ) do: [ :text | self assert: '"' , text , '"' with: [ :reader | reader addFloatField ] signals: SimdCSVConversionError ]
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testDuplicateNames [
	| text |
	text := self lines: #( 'a,a' '1,2' ).
	self assert: [ (self reader: text) namedColumnsConfiguration ] signals: SimdCSVHeaderError.
	self assert: [ SimdCSV dictionariesFrom: text ] signals: SimdCSVHeaderError.
	self assert: text with: [ :reader | reader renameDuplicates; namedColumnsConfiguration ] rows: { ({ (#a -> '1'). (#a_2 -> '2') } asDictionary) }
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testEmptyName [
	self assert: (self lines: #( 'a,' '1,2' )) with: [ :reader | reader namedColumnsConfiguration ] rows: { ({ (#a -> '1'). (#column2 -> '2') } asDictionary) }
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testFieldsAfterFirstNext [
	self sourcesOf: (self lines: #( '1,2' '3,4' '5,6' )) do: [ :source :name |
		| reader |
		reader := self reader: source.
		self assert: reader next equals: #( '1' '2' ).
		reader addIntegerField; addIntegerField.
		self assert: reader next equals: #( 3 4 ).
		self assert: reader upToEnd equals: #( #( 5 6 ) ) ]
]

{ #category : 'tests' }
SimdCSVSemanticsTest >> testReadAhead [
	"The position of a stream is beyond the records that were answered"

	| stream |
	stream := SimdCSVTestStream on: (self lines: #( 'a' 'b' 'c' )).
	(self reader: stream) next.
	self assert: stream position equals: 6
]
