"
I test the rows that are built from an index: texts, numbers, empty cells, widths, errors and the checks of the index.
"
Class {
	#name : 'SimdCSVRowsTest',
	#superclass : 'SimdCSVTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SimdCSVRowsTest >> rows: aSource flags: flags types: types fieldCount: fieldCount [
	"{ the answer. the rows } of the whole aSource"

	^ self rows: aSource word: (self wordFlags: flags) types: types fieldCount: fieldCount empty: nil
]

{ #category : 'helpers' }
SimdCSVRowsTest >> rows: aSource word: word types: types fieldCount: fieldCount empty: emptyValue [
	| index dest answer indexWord |
	dest := Array new: aSource size + 1 withAll: #unused.
	indexWord := word bitOr: (SimdCSVDialect flagFinal bitShift: 29).
	indexWord := indexWord bitAnd: (SimdCSVDialect flagStrict bitShift: 29) bitInvert.
	index := WordArray new: aSource size + 1.
	answer := self backendObject index: aSource base: 1 from: 1 to: aSource size dialect: indexWord into: index from: 1.
	answer := self backendObject
		          rows: aSource
		          base: 1
		          to: aSource size
		          dialect: word
		          index: index
		          from: 1
		          to: answer second
		          types: types
		          fieldCount: fieldCount
		          into: dest
		          from: 1
		          wideStringClass: WideString
		          empty: emptyValue
		          budget: -1.
	answer simdCSVFailed ifTrue: [ self fail: answer printString ].
	self assert: (dest allButFirst: answer second) asSet asArray equals: #( #unused ).
	^ {
		  answer.
		  (dest first: answer second) }
]

{ #category : 'helpers' }
SimdCSVRowsTest >> cellsOf: aSource [
	"The only row of aSource, of Latin-1 or 32-bit units"

	^ (self
		   rows: aSource
		   flags: ((SimdCSVSmalltalk unitsOf: aSource) == #bytes
				    ifTrue: [ SimdCSVDialect flagLatin1 ]
				    ifFalse: [ 0 ])
		   types: nil
		   fieldCount: 0) second first
]

{ #category : 'helpers' }
SimdCSVRowsTest >> cells: aString type: code [
	"The cells of the fields of aString, a field a line, typed code, and the count of the odd ones"

	| result |
	result := self rows: aString asByteArray flags: 0 types: (ByteArray with: code) fieldCount: 1.
	self assert: result first first equals: 0.
	^ {
		  (result second collect: [ :each | each first ]).
		  result first fourth }
]

{ #category : 'tests' }
SimdCSVRowsTest >> testAnswer [
	| result |
	result := self rows: 'a,b,c' , String lf , '1,,"x,""y"""' , String crlf , 'last' flags: 0 types: nil fieldCount: 0.
	self assert: result first equals: #( 0 3 8 0 0 0 0 0 0 ).
	self assert: result second equals: #( #( 'a' 'b' 'c' ) #( '1' nil 'x,"y"' ) #( 'last' ) )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testBadIndex [
	"Every entry is checked: an index that does not fit the source gives BAD_INDEX, and never an access out of bounds"

	| source |
	source := 'ab,cd' , String lf , 'ef,gh' , String lf.
	self assert: source entries: #( 2 5 8 11 ) is: #( 0 2 5 0 0 0 0 0 0 ).
	self assert: source entries: #( 2 5 8 ) is: #( 2 1 3 0 6 7 2 0 0 ).
	self assert: source entries: #( 2 4 8 11 ) is: #( 2 0 1 0 6 1 1 0 0 ).
	self assert: source entries: #( 2 5 5 11 ) is: #( 2 1 3 0 6 7 2 0 0 ).
	self assert: source entries: #( 2 1 8 11 ) is: #( 2 0 1 0 6 1 1 0 0 ).
	self assert: source entries: #( 2 5 8 13 ) is: #( 2 1 3 0 6 7 2 0 0 ).
	self assert: source entries: #( 2 5 8 12 ) is: #( 0 2 5 0 0 0 0 0 0 ).
	self assert: source entries: #( 4294967295 5 8 11 ) is: #( 2 0 1 0 6 1 1 0 0 ).
	self assert: source entries: #( 2 5 8 11 12 ) is: #( 2 2 5 0 6 13 3 0 0 )
]

{ #category : 'asserting' }
SimdCSVRowsTest >> assert: aString entries: anArray is: expected [
	self
		assert: (self backendObject
				 rows: aString
				 base: 1
				 to: aString size
				 dialect: (self wordFlags: SimdCSVDialect flagLatin1)
				 index: (WordArray withAll: anArray)
				 from: 1
				 to: anArray size
				 types: nil
				 fieldCount: 0
				 into: (Array new: 10)
				 from: 1
				 wideStringClass: WideString
				 empty: nil
				 budget: -1)
		equals: expected
]

{ #category : 'tests' }
SimdCSVRowsTest >> testBase [
	"The base of the index is an argument, and the first record starts there"

	| dest |
	dest := Array new: 3.
	self
		assert: (self backendObject
				 rows: 'zz,a,b' , String lf , 'c'
				 base: 4
				 to: 8
				 dialect: (self wordFlags: SimdCSVDialect flagLatin1)
				 index: (WordArray withAll: #( 1 3 5 ))
				 from: 1
				 to: 3
				 types: nil
				 fieldCount: 0
				 into: dest
				 from: 2
				 wideStringClass: WideString
				 empty: nil
				 budget: -1)
		equals: #( 0 2 4 0 0 0 0 0 0 ).
	self assert: dest equals: #( nil #( 'a' 'b' ) #( 'c' ) )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testDestinationFull [
	"MORE, and the next call goes on at the entry answered; a record that starts inside of the index is found after the line end before it"

	| source index dest answer flags all word |
	source := ('a,b' , String crlf , 'c,d' , String cr , 'e,f' , String lf , String lf , 'g,h') asByteArray.
	#( 0 8 ) do: [ :extra |
		flags := extra.
		word := self wordFlags: flags.
		index := (self index: source word: (self wordFlags: flags + SimdCSVDialect flagFinal)) second.
		index := WordArray withAll: index.
		all := (self rows: source flags: flags types: nil fieldCount: 0) second.
		1 to: 4 do: [ :room |
			| next rows |
			rows := OrderedCollection new.
			next := 1.
			[
			dest := Array new: room.
			answer := self backendObject
				          rows: source
				          base: 1
				          to: source size
				          dialect: word
				          index: index
				          from: next
				          to: index size
				          types: nil
				          fieldCount: 0
				          into: dest
				          from: 1
				          wideStringClass: WideString
				          empty: nil
				          budget: -1.
			rows addAll: (dest first: answer second).
			next := answer third.
			answer first = 1 ] whileTrue: [ self assert: answer second equals: room ].
			self assert: answer first equals: 0.
			self assert: next equals: index size + 1.
			self assert: rows asArray equals: all ] ]
]

{ #category : 'tests' }
SimdCSVRowsTest >> testEmptyFields [
	| source result |
	source := ',"",a' asByteArray.
	self assert: (self rows: source flags: 0 types: nil fieldCount: 0) second equals: #( #( nil nil 'a' ) ).
	result := self rows: source word: (self wordFlags: (self flags: #( keepQuotedEmpty ))) types: nil fieldCount: 0 empty: 'none'.
	self assert: result second equals: #( #( 'none' '' 'a' ) ).
	self assert: (result second first at: 2) class equals: ByteString.
	result := self rows: source word: (self wordFlags: (self flags: #( keepQuotedEmpty ))) types: #[ 2 2 1 ] fieldCount: 0 empty: 0.
	self assert: result equals: {
			#( 0 1 4 0 0 0 0 0 0 ).
			#( #( 0 0 'a' ) ) }.
	self assert: (self rows: '"' asByteArray flags: 0 types: nil fieldCount: 0) second equals: #( #( nil ) )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testEmptyRange [
	"No entry, no row, and nothing is looked at"

	self
		assert: (self backendObject
				 rows: 'abc'
				 base: 1
				 to: 3
				 dialect: (self wordFlags: SimdCSVDialect flagLatin1)
				 index: (WordArray withAll: #( 99 99 ))
				 from: 3
				 to: 2
				 types: nil
				 fieldCount: 0
				 into: #(  ) copy
				 from: 1
				 wideStringClass: WideString
				 empty: nil
				 budget: -1)
		equals: #( 0 0 3 0 0 0 0 0 0 )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testExactCount [
	| source |
	source := 'a,b' , String lf , 'c' , String lf , 'd,e,f' , String lf.
	self
		assert: (self rows: source flags: (self flags: #( exactCount latin1 )) types: nil fieldCount: 2)
		equals: {
				#( 2 1 3 0 5 5 2 1 0 ).
				#( #( 'a' 'b' ) ) }.
	self
		assert: (self rows: (source copyWithout: $c) flags: (self flags: #( exactCount latin1 skipBlank )) types: nil fieldCount: 2)
		equals: {
				#( 2 1 3 0 5 6 2 3 0 ).
				#( #( 'a' 'b' ) ) }.
	self assert: (self rows: source flags: (self flags: #( exactCount latin1 )) types: nil fieldCount: 0) second size equals: 3
]

{ #category : 'tests' }
SimdCSVRowsTest >> testExhaustive [
	"The texts of every short String are those of the automaton"

	0 to: 3 do: [ :bits |
		| flags word |
		flags := self flags: ((1 to: 2) select: [ :i | (bits bitAnd: i) ~= 0 ] thenCollect: [ :i | #( skipBlank noQuote ) at: i ]).
		word := self wordFlags: flags + SimdCSVDialect flagFinal + SimdCSVDialect flagLatin1.
		self stringsOver: { $a. $,. $". Character lf. Character cr } upTo: (self exhaustiveLength: 5) do: [ :string |
			| expected result |
			expected := (SimdCSVReference on: string word: word) records collect: [ :record |
				            record collect: [ :units |
					            units ifNotEmpty: [ String withAll: (units collect: [ :each | Character value: each ]) ] ifEmpty: [ nil ] ] ].
			result := self rows: string word: word types: nil fieldCount: 0 empty: nil.
			result second = expected ifFalse: [
				self fail: string printString , ' with ' , bits printString , ' gives ' , result printString ] ] ]
]

{ #category : 'tests' }
SimdCSVRowsTest >> testFieldCount [
	"Rows of n fields: missing ones empty, extra ones skipped, and not looked at"

	| source |
	source := 'a,b,c' , String lf , 'd' , String lf , 'e,f' , String lf.
	self
		assert: (self rows: source asByteArray word: (self wordFlags: 0) types: nil fieldCount: 2 empty: 0) second
		equals: #( #( 'a' 'b' ) #( 'd' 0 ) #( 'e' 'f' ) ).
	self
		assert: (self rows: source asByteArray flags: 0 types: #[ 0 1 0 1 ] fieldCount: 4) second
		equals: #( #( 'b' nil ) #( nil nil ) #( 'f' nil ) ).
	self assert: (self rows: source asByteArray flags: 0 types: #[ 0 ] fieldCount: 1) second equals: #( #(  ) #(  ) #(  ) ).
	self
		assert: (self rows: source asByteArray flags: 0 types: #[ 0 1 ] fieldCount: 0) second
		equals: #( #( 'b' 'c' ) #(  ) #( 'f' ) ).
	self
		assert: (self rows: #[ 97 44 255 ] flags: 0 types: nil fieldCount: 1)
		equals: {
				#( 0 1 3 0 0 0 0 0 0 ).
				#( #( 'a' ) ) }
]

{ #category : 'tests' }
SimdCSVRowsTest >> testFloats [
	self
		assert: (self cells: ('1.5,0,-0.25,+3,.5,7.,1e3,1.5E-3,9007199254740992,1e22,1e37' copyReplaceAll: ',' with: String lf) type: 3)
		equals: {
				{ 1.5. 0.0. -0.25. 3.0. 0.5. 7.0. 1000.0. 0.0015. 9007199254740992.0. 1.0e22. 1.0e37 }.
				0 }.
	self assert: (self cells: ' 1.5 ' type: 3) first first equals: 1.5.
	self assert: (self cells: '-0' type: 3) first first hex equals: Float negativeZero hex.
	self assert: (self cells: '-0.000' type: 3) first first hex equals: Float negativeZero hex.
	self
		assert: (self cells: ('9007199254740993,1e38,1e23x,1.5e,e5,.,1..2,--1,1 2,nan,inf,1e-23,12345678901234567890' copyReplaceAll: ',' with: String lf) type: 3)
		equals: {
				#( '9007199254740993' '1e38' '1e23x' '1.5e' 'e5' '.' '1..2' '--1' '1 2' 'nan' 'inf' '1e-23' '12345678901234567890' ).
				13 }
]

{ #category : 'tests' }
SimdCSVRowsTest >> testFloatsWithComma [
	| result |
	result := self
		          rows: '1,5;1.5;-2,25e2;3' asByteArray
		          word: (self wordSeparator: $; quote: $" flags: 0)
		          types: #[ 4 4 4 4 ]
		          fieldCount: 0
		          empty: nil.
	self assert: result second first equals: #( 1.5 '1.5' -225.0 3.0 ).
	self assert: result first fourth equals: 1
]

{ #category : 'tests' }
SimdCSVRowsTest >> testFloatsAreBoxedWhenTheyMustBe [
	"Floats outside of the range of the immediate ones are equal to the literals too"

	| cells |
	cells := (self cells: ('1e-22,123456789e22,3e37' copyReplaceAll: ',' with: String lf) type: 3) first.
	self assert: cells equals: { 1.0e-22. 1.23456789e30. 3.0e37 }
]

{ #category : 'tests' }
SimdCSVRowsTest >> testIntegers [
	self
		assert: (self cells: ('0,12,-12,+7,000000000000000000000000012,999999999999999999,-999999999999999999' copyReplaceAll: ',' with: String lf) , String lf , ' 5	' type: 2)
		equals: #( #( 0 12 -12 7 12 999999999999999999 -999999999999999999 5 ) 0 ).
	self
		assert: (self cells: ('1000000000000000000,12abc,1.0,-,+,1-,0x10,1 2' copyReplaceAll: ',' with: String lf) , String lf , ' ' type: 2)
		equals: #( #( '1000000000000000000' '12abc' '1.0' '-' '+' '1-' '0x10' '1 2' ' ' ) 9 )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testInvalidUTF8 [
	"The first byte of the bad sequence, of a field that is built"

	{
		#[ 16r80 ] -> 0.
		#[ 16rC0 16r80 ] -> 0.
		#[ 16rC1 16rBF ] -> 0.
		#[ 16rE0 16r9F 16rBF ] -> 0.
		#[ 16rED 16rA0 16r80 ] -> 0.
		#[ 16rF0 16r8F 16rBF 16rBF ] -> 0.
		#[ 16rF4 16r90 16r80 16r80 ] -> 0.
		#[ 16rF5 16r80 16r80 16r80 ] -> 0.
		#[ 16rFF ] -> 0.
		#[ 16rC3 ] -> 0.
		#[ 16rE2 16r82 ] -> 0.
		#[ 16rE2 16r28 16rA1 ] -> 0.
		#[ 16rF0 16r9F 16r98 ] -> 0.
		#[ 16rC3 16rA9 16r80 ] -> 2.
		#[ 16r61 16rE2 16r82 16rAC 16rC3 16r28 ] -> 4 } do: [ :each |
		| source result |
		source := 'ok,ok' asByteArray , #[ 10 ] , 'x,' asByteArray , each key , ',y' asByteArray.
		result := self rows: source flags: 0 types: nil fieldCount: 0.
		self assert: result equals: {
				{
					2.
					1.
					3.
					0.
					4.
					(9 + each value).
					2.
					2.
					0 }.
				#( #( 'ok' 'ok' ) ) }.
		self assert: (self rows: source flags: 0 types: #[ 1 0 1 ] fieldCount: 0) first first equals: 0 ]
]

{ #category : 'tests' }
SimdCSVRowsTest >> testInvalidUTF8AfterEscapedQuotes [
	"The position is the one in the source"

	self
		assert: (self rows: '"a""b""' asByteArray , #[ 16rC3 16rA9 16r80 34 ] flags: 0 types: nil fieldCount: 0) first
		equals: #( 2 0 1 0 4 10 1 1 0 ).
	self
		assert: (self rows: '"a"b' asByteArray , #[ 16r80 ] flags: 0 types: nil fieldCount: 0) first
		equals: #( 2 0 1 0 4 5 1 1 0 ).
	self
		assert: (self rows: '1,x' asByteArray , #[ 16rFF ] flags: 0 types: #[ 2 2 ] fieldCount: 0) first
		equals: #( 2 0 1 0 4 4 1 2 0 )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testLatin1 [
	| cell |
	cell := (self rows: #[ 99 97 102 233 ] flags: SimdCSVDialect flagLatin1 types: nil fieldCount: 0) second first first.
	self assert: cell equals: 'café'.
	self assert: cell class equals: ByteString
]

{ #category : 'tests' }
SimdCSVRowsTest >> testNumbersInQuotes [
	"The text of a quoted number; with an escaped quote it is no number"

	| result |
	result := self rows: '"12","1.5","1""2","-7' asByteArray flags: 0 types: #[ 2 3 2 2 ] fieldCount: 0.
	self assert: result first equals: #( 0 1 5 1 0 0 0 0 0 ).
	self assert: result second first equals: #( 12 1.5 '1"2' -7 ).
	self assert: (self rows: '"1"2' asByteArray flags: 0 types: #[ 2 ] fieldCount: 0) second first equals: #( '12' )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testOddOfAFailedRow [
	"The odd cells of the rows stored are counted, not those of the record in error"

	self
		assert: (self rows: 'x' asByteArray , #[ 10 ] , 'y,' asByteArray , #[ 255 ] flags: 0 types: #[ 2 2 ] fieldCount: 0) first
		equals: #( 2 1 2 1 4 5 2 2 0 )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testQuotedTexts [
	self assert: (self cellsOf: '"a","b""c","","""","a"b,c"d,"e' , String lf , ',f') equals: {
			'a'.
			'b"c'.
			nil.
			'"'.
			'ab'.
			'c"d'.
			('e' , String lf , ',f') }
]

{ #category : 'tests' }
SimdCSVRowsTest >> testQuotedTextsAfterTheClosingQuote [
	"Literal, quotes too"

	self assert: (self cellsOf: '"a"b"c","d"e""f,""x,""" "y') equals: #( 'ab"c"' 'de""f' 'x' '" y' )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testSkipBlank [
	| source |
	source := (String lf , String crlf , 'a,b' , String lf , String lf , 'c' , String cr , String lf , String lf) asByteArray.
	self assert: (self rows: source flags: (self flags: #( skipBlank )) types: nil fieldCount: 0) second equals: #( #( 'a' 'b' ) #( 'c' ) ).
	self
		assert: (self rows: source flags: 0 types: nil fieldCount: 0) second
		equals: #( #( nil ) #( nil ) #( 'a' 'b' ) #( nil ) #( 'c' ) #( nil ) )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testStringsAreNotShared [
	| rows |
	rows := (self rows: 'ab,ab' , String lf , 'ab,ab' flags: SimdCSVDialect flagLatin1 types: nil fieldCount: 0) second.
	self assert: (rows first first ~~ rows first second and: [ rows first first ~~ rows second first ])
]

{ #category : 'tests' }
SimdCSVRowsTest >> testTypesBeyond [
	"Fields beyond the types are Strings"

	self
		assert: (self rows: '1,2,3' asByteArray flags: 0 types: #[ 2 ] fieldCount: 0) second
		equals: #( #( 1 '2' '3' ) ).
	self assert: (self rows: '1,2' asByteArray flags: 0 types: #[  ] fieldCount: 0) second equals: #( #( '1' '2' ) )
]

{ #category : 'tests' }
SimdCSVRowsTest >> testUTF8 [
	"The narrowest class of each cell"

	| text row |
	text := 'ascii,café,' , (String with: (Character value: 16r20AC)) , ',"x""' , (String with: (Character value: 16r1F600)) , '",'
	        , (String with: (Character value: 255)) , ',' , (String with: (Character value: 256)).
	row := (self rows: text utf8Encoded flags: 0 types: nil fieldCount: 0) second first.
	self assert: row equals: {
			'ascii'.
			'café'.
			(String with: (Character value: 16r20AC)).
			('x"' , (String with: (Character value: 16r1F600))).
			(String with: (Character value: 255)).
			(String with: (Character value: 256)) }.
	self
		assert: (row collect: [ :each | each class ]) asArray
		equals: {
				ByteString.
				ByteString.
				WideString.
				WideString.
				ByteString.
				WideString }
]

{ #category : 'tests' }
SimdCSVRowsTest >> testUTF8CodePoints [
	"A code point of every length and at the limits"

	#( 16r7F 16r80 16r7FF 16r800 16rFFF 16r1000 16rD7FF 16rE000 16rFFFF 16r10000 16r3FFFF 16r40000 16r10FFFF ) do: [ :each |
		| string |
		string := String with: (Character value: each).
		self assert: (self rows: string utf8Encoded flags: 0 types: nil fieldCount: 0) second equals: { { string } } ]
]

{ #category : 'tests' }
SimdCSVRowsTest >> testWideSource [
	| source row |
	source := (self wide: 'a,"b""c",12,1.5') , (String with: $, with: (Character value: 16r20AC)).
	row := (self rows: source flags: 0 types: #[ 1 1 2 3 2 ] fieldCount: 0) second first.
	self assert: row equals: {
			'a'.
			'b"c'.
			12.
			1.5.
			(String with: (Character value: 16r20AC)) }.
	self assert: row first class equals: ByteString.
	self assert: row last class equals: WideString
]

{ #category : 'tests' }
SimdCSVRowsTest >> testWideStringClass [
	"The class of the wide cells is an argument: any class of 32-bit words"

	| dest |
	dest := Array new: 1.
	self backendObject
		rows: (String with: (Character value: 16r20AC))
		base: 1
		to: 1
		dialect: (self wordFlags: 0)
		index: (WordArray with: 1)
		from: 1
		to: 1
		types: nil
		fieldCount: 0
		into: dest
		from: 1
		wideStringClass: WordArray
		empty: nil
		budget: -1.
	self assert: dest first first equals: (WordArray with: 16r20AC)
]
