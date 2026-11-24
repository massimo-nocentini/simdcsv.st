"
I test `SimdCSVTable`: rows, cells, columns and names, against the reader.
"
Class {
	#name : 'SimdCSVTableTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SimdCSVTableTest >> sample [
	^ self lines: #( 'id,name,amount,"date, time"' '1,"x,y",2.5,a' '2,,1e3,b' '3,"z""",,c' )
]

{ #category : 'helpers' }
SimdCSVTableTest >> table [
	^ SimdCSV tableFrom: self sample
]

{ #category : 'helpers' }
SimdCSVTableTest >> dialect: aBlock [
	| dialect |
	dialect := SimdCSVDialect comma.
	aBlock value: dialect.
	^ dialect
]

{ #category : 'tests' }
SimdCSVTableTest >> testSources [
	self sourcesOf: self sample do: [ :source :name |
		| table |
		table := SimdCSV tableFrom: source.
		self assert: table asArray equals: ((self reader: self sample) skipHeader; upToEnd).
		self assert: table columnNames equals: #( 'id' 'name' 'amount' 'date, time' ) ]
]

{ #category : 'tests' }
SimdCSVTableTest >> testSizes [
	| table |
	table := self table.
	self assert: table rowCount equals: 3.
	self assert: table size equals: 3.
	self assert: table columnCount equals: 4.
	self deny: table isRagged.
	self assert: table printString equals: 'a SimdCSVTable(3 rows, 4 columns)'
]

{ #category : 'tests' }
SimdCSVTableTest >> testRows [
	| table rows |
	table := self table.
	self assert: (table rowAt: 1) equals: #( '1' 'x,y' '2.5' 'a' ).
	self assert: (table rowAt: 3) equals: { '3'. 'z"'. nil. 'c' }.
	self assert: (table rowsFrom: 2 to: 3) equals: { (table rowAt: 2). (table rowAt: 3) }.
	self assert: (table rowsFrom: 2 to: 1) equals: #(  ).
	self assert: table asArray equals: ((1 to: 3) collect: [ :each | table rowAt: each ]) asArray.
	rows := OrderedCollection new.
	table do: [ :row | rows add: row ].
	self assert: rows asArray equals: table asArray.
	#( 0 4 -1 nil 1.5 ) do: [ :each | self should: [ table rowAt: each ] raise: SubscriptOutOfBounds ].
	self should: [ table rowsFrom: 1 to: 4 ] raise: SubscriptOutOfBounds
]

{ #category : 'tests' }
SimdCSVTableTest >> testCells [
	| table |
	table := self table.
	self assert: (table at: 1 at: #name) equals: 'x,y'.
	self assert: (table at: 1 at: 'name') equals: 'x,y'.
	self assert: (table at: 3 at: 2) equals: 'z"'.
	self assert: (table at: 2 at: 2) isNil.
	self assert: (table at: 2 at: 'date, time') equals: 'b'.
	self should: [ table at: 1 at: 5 ] raise: SubscriptOutOfBounds.
	self should: [ table at: 1 at: 0 ] raise: SubscriptOutOfBounds.
	self should: [ table at: 4 at: 1 ] raise: SubscriptOutOfBounds.
	self assert: [ table at: 1 at: #x ] signals: SimdCSVHeaderError
]

{ #category : 'tests' }
SimdCSVTableTest >> testColumns [
	| table |
	table := self table.
	self assert: (table column: #id) equals: #( '1' '2' '3' ).
	self assert: (table column: 2) equals: { 'x,y'. nil. 'z"' }.
	self assert: (table column: #id as: #integer) equals: #( 1 2 3 ).
	self assert: (table column: #amount as: #float) equals: { 2.5. 1000.0. nil }.
	self assert: (table column: 4 as: #symbol) equals: #( #a #b #c ).
	self assert: (table columns: #( #amount #id #name ) as: #( #float #integer #string )) equals: { { 2.5. 1000.0. nil }. #( 1 2 3 ). { 'x,y'. nil. 'z"' } }.
	self assert: (table columns: #( #amount #id ) as: #( #floatComma #symbol ) ifInvalid: [ :text | text size ]) equals: { { 3. 1000.0. nil }. #( #'1' #'2' #'3' ) }.
	self assert: (table columns: #(  ) as: #(  )) equals: #(  ).
	self assert: [ table columns: #( #id #id ) as: #( #integer #float ) ] signals: SimdCSVArgumentError.
	self assert: [ table columns: #( #id ) as: #( #integer #float ) ] signals: SimdCSVArgumentError.
	self assert: [ table column: #id as: #ignored ] signals: SimdCSVArgumentError.
	self assert: [ table column: #id as: #date ] signals: SimdCSVArgumentError
]

{ #category : 'tests' }
SimdCSVTableTest >> testInvalidCells [
	| table seen error |
	table := SimdCSV tableFrom: (self lines: #( 'a,b' '1,x' '"' '",y' '3,nan' )) asByteArray.
	error := self assert: [ table column: #b as: #float ] signals: SimdCSVConversionError text: 'Not a float: ''x'' in column b (field 2), record 2, line 2, byte 7'.
	seen := OrderedCollection new.
	self assert: ((table column: #b as: #float ifInvalid: [ :text :record :field |
			 seen add: {
					 text.
					 record.
					 field }.
			 0 ]) first: 2) equals: #( 0 0 ).
	self assert: seen asArray equals: #( #( 'x' 2 2 ) #( 'y' 3 2 ) ).
	self assert: [ table column: #b as: #boolean ] signals: SimdCSVConversionError text: 'Not a boolean: ''x'' in column b (field 2), record 2, line 2, byte 7'.
	self assert: ([ table column: #b as: #float ] on: SimdCSVConversionError do: [ :each | each resume: each record ]) second equals: 3
]

{ #category : 'tests' }
SimdCSVTableTest >> testFloat64Array [
	| table floats |
	table := self table.
	floats := table float64ArrayAt: #amount.
	self assert: floats class equals: Float64Array.
	self assert: (floats first: 2) asArray equals: #( 2.5 1000.0 ).
	self assert: floats third isNaN.
	self assert: [ table float64ArrayAt: #name ] signals: SimdCSVConversionError.
	floats := table float64ArrayAt: #name ifInvalid: [ :text | text size ].
	self assert: floats first equals: 3.0.
	self assert: floats second isNaN.
	self assert: (table float64ArrayAt: #name ifInvalid: [ nil ]) first isNaN.
	self assert: (table float64ArrayAt: #id) asArray equals: #( 1.0 2.0 3.0 ).
	table := SimdCSV tableFrom: (self lines: #( 'a' 'NA' '-inf' '0.12345678901234567890' )) dialect: (self dialect: [ :dialect | dialect nullTexts: #( 'NA' ) ]).
	floats := table float64ArrayAt: 1.
	self assert: floats first isNaN.
	self assert: floats second equals: Float infinity negated.
	self assert: floats third equals: 0.12345678901234568
]

{ #category : 'tests' }
SimdCSVTableTest >> testEmptyCells [
	| table |
	table := SimdCSV tableFrom: (self lines: #( 'a,b' ',""' 'NA,x' )) dialect: (self dialect: [ :dialect |
			         dialect
				         emptyFieldValue: #none;
				         nullTexts: #( 'NA' ) ]).
	self assert: table asArray equals: #( #( #none #none ) #( 'NA' 'x' ) ).
	self assert: (table column: 1) equals: #( #none 'NA' ).
	self assert: (table column: 1 as: #integer) equals: #( #none #none ).
	self assert: (table column: 2 as: #symbol) equals: #( #none #x ).
	self assert: (table at: 1 at: 2) equals: #none.
	table := SimdCSV tableFrom: (self lines: #( 'a,b' ',""' )) dialect: (self dialect: [ :dialect | dialect keepQuotedEmpty: true ]).
	self assert: (table rowAt: 1) equals: { nil. '' }.
	self assert: (table column: 2) equals: #( '' ).
	self assert: (table column: 2 as: #float) equals: { nil }
]

{ #category : 'tests' }
SimdCSVTableTest >> testRagged [
	| text table |
	text := self lines: #( 'a,b' '1' '2,3,4' '"' '"' '' '5,6' ).
	table := SimdCSV tableFrom: text.
	self assert: table isRagged.
	self assert: table rowCount equals: 5.
	self assert: table asArray equals: { { '1'. nil }. { '2'. '3' }. { String lf. nil }. { nil. nil }. { '5'. '6' } }.
	self assert: (table rowAt: 2) equals: #( '2' '3' ).
	self assert: (table at: 5 at: #b) equals: '6'.
	self assert: (table at: 1 at: #b) isNil.
	self assert: (table column: #b as: #integer) equals: { nil. 3. nil. nil. 6 }.
	self assert: [ SimdCSV tableFrom: text dialect: (self dialect: [ :dialect | dialect strictFieldCount: true ]) ] signals: SimdCSVFieldCountMismatch.
	self assert: (SimdCSV tableFrom: text dialect: (self dialect: [ :dialect | dialect skipEmptyLines: true ])) rowCount equals: 4
]

{ #category : 'tests' }
SimdCSVTableTest >> testWithoutHeader [
	| table |
	table := SimdCSV tableFrom: (self lines: #( '1,2' '3,4' )) dialect: (self dialect: [ :dialect | dialect hasHeader: false ]).
	self assert: table rowCount equals: 2.
	self assert: table columnNames equals: #( 'column1' 'column2' ).
	self assert: (table column: 'column2') equals: #( '2' '4' ).
	self assert: (table at: 1 at: 1) equals: '1'
]

{ #category : 'tests' }
SimdCSVTableTest >> testNames [
	| table |
	table := SimdCSV tableFrom: (self lines: #( 'a,,a,"",a_2' '1,2,3,4,5' )).
	self assert: table columnNames equals: #( 'a' 'column2' 'a' 'column4' 'a_2' ).
	self assert: (table column: #column4) equals: #( '4' ).
	self assert: (table column: 3) equals: #( '3' ).
	self assert: [ table at: 1 at: #a ] signals: SimdCSVHeaderError.
	table renameDuplicates.
	self assert: table columnNames equals: #( 'a' 'column2' 'a_3' 'column4' 'a_2' ).
	self assert: (table column: #a_3) equals: #( '3' )
]

{ #category : 'tests' }
SimdCSVTableTest >> testEmptyTable [
	| table |
	table := SimdCSV tableFrom: ''.
	self assert: table rowCount equals: 0.
	self assert: table columnCount equals: 0.
	self assert: table asArray equals: #(  ).
	self assert: table columnNames equals: #(  ).
	self assert: [ table column: #a ] signals: SimdCSVHeaderError.
	table := SimdCSV tableFrom: 'a,b'.
	self assert: table rowCount equals: 0.
	self assert: table asArray equals: #(  ).
	self assert: (table column: #b) equals: #(  ).
	self assert: (table float64ArrayAt: #b) size equals: 0.
	table := SimdCSV tableFrom: String lf dialect: (self dialect: [ :dialect | dialect skipEmptyLines: true ]).
	self assert: table rowCount equals: 0
]

{ #category : 'tests' }
SimdCSVTableTest >> testByteOrderMark [
	| table |
	table := SimdCSV tableFrom: #[ 239 187 191 97 10 255 10 ].
	self assert: table columnNames equals: #( 'a' ).
	self assert: [ table rowAt: 1 ] signals: SimdCSVInvalidEncoding text: 'Invalid UTF-8 at byte 6 (record 2, line 2, field 1): try encoding: #latin1, or decode the file first'.
	self assert: [ SimdCSV tableFrom: #[ 255 254 97 0 ] ] signals: SimdCSVInvalidEncoding.
	self assert: ((SimdCSV tableFrom: #[ 97 10 255 10 ] dialect: (self dialect: [ :dialect | dialect encoding: #latin1 ])) at: 1 at: 1) equals: (String with: (Character value: 255))
]

{ #category : 'tests' }
SimdCSVTableTest >> testFileIsNotModified [
	| file bytes |
	file := FileReference newTempFilePrefix: 'simdcsv' suffix: '.csv'.
	bytes := self sample asByteArray.
	[
	file binaryWriteStreamDo: [ :stream | stream nextPutAll: bytes ].
	self assert: (SimdCSV tableFrom: file) rowCount equals: 3.
	self assert: file binaryReadStream contents equals: bytes ] ensure: [ file ensureDelete ]
]

{ #category : 'tests' }
SimdCSVTableTest >> testMoreRowsThanABatch [
	| table count |
	count := 9001.
	table := SimdCSV tableFrom: (self lines: ((0 to: count) collect: [ :i | i printString , ',' , (i / 4) asFloat printString ])).
	self assert: table rowCount equals: count.
	self assert: (table column: 1 as: #integer) equals: (1 to: count) asArray.
	self assert: (table float64ArrayAt: 2) sum equals: (1 to: count) sum / 4.0.
	self assert: table asArray last equals: { count printString. (count / 4) asFloat printString }.
	self assert: (table rowAt: 5000) first equals: '5000'
]

{ #category : 'tests' }
SimdCSVTableTest >> testRandomTables [
	"Rows and columns are those of the reader"

	| random |
	random := self random.
	(self largeSize: 300) timesRepeat: [
		| text dialect rows table width |
		text := String streamContents: [ :out |
			        (random nextInteger: 100) timesRepeat: [ out nextPut: ('abc,,"' , String crlf , String lf at: (random nextInteger: 9)) ] ].
		dialect := self dialect: [ :each |
			           each
				           hasHeader: false;
				           skipEmptyLines: (random nextInteger: 2) = 1;
				           lineEnd: (#( #any #lf ) at: (random nextInteger: 2)) ].
		rows := (self reader: text) dialect: dialect; upToEnd.
		table := SimdCSV tableFrom: text asByteArray dialect: dialect.
		width := rows
			         ifEmpty: [ 0 ]
			         ifNotEmpty: [ rows first size ].
		self assert: table columnCount equals: width.
		self assert: table isRagged equals: (rows anySatisfy: [ :row | row size ~= width ]).
		rows := rows collect: [ :row | (1 to: width) collect: [ :i | row at: i ifAbsent: [ nil ] ] ].
		rows := rows collect: [ :row | row asArray ].
		self assert: table asArray equals: rows.
		1 to: width do: [ :i | self assert: (table column: i) equals: (rows collect: [ :row | row at: i ]) ] ]
]
