"
I test the index: the entries and the numbers of its answer, against literals and against `SimdCSVReference`.
"
Class {
	#name : 'SimdCSVIndexTest',
	#superclass : 'SimdCSVTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
SimdCSVIndexTest >> testAnswer [
	| result |
	result := self index: 'a,b
1,"x,y"' withUnixLineEndings flags: (self flags: #( final lines )).
	self assert: result first equals: #( 0 4 2 12 1 2 2 0 0 ).
	self assert: result second equals: #( 1 3 5 11 )
]

{ #category : 'tests' }
SimdCSVIndexTest >> testBase [
	"The entries are offsets from the base"

	| dest |
	dest := WordArray new: 4.
	self
		assert: (self backendObject
				 index: 'xx,yy,' , String lf , 'a,b'
				 base: 3
				 from: 8
				 to: 10
				 dialect: (self wordFlags: (self flags: #( final )))
				 into: dest
				 from: 2)
		equals: #( 0 2 1 11 0 2 2 0 0 ).
	self assert: dest first equals: 0.
	self assert: dest second equals: 6.
	self assert: dest third equals: 8
]

{ #category : 'tests' }
SimdCSVIndexTest >> testCapacity [
	"With every capacity the answer is the one of the automaton, and no slot outside of it is written"

	| flags |
	flags := { 0. self flags: #( final ). self flags: #( final strict lines ). self flags: #( skipBlank lines ). self flags: #( final skipBlank ) }.
	self stringsOver: { $a. $,. $". Character lf. Character cr } upTo: (self exhaustiveLength: 4) do: [ :string |
		flags do: [ :each |
			| word reference |
			word := self wordFlags: each.
			reference := SimdCSVReference on: string word: word.
			0 to: string size + 1 do: [ :capacity | self assert: string word: word capacity: capacity reference: reference ] ] ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testCapacityAroundAnIrregularUnit [
	"Events come in the order of the input: the limit before or after an irregular quote, at every distance of a block"

	| word |
	word := self wordFlags: (self flags: #( strict final lines )).
	#( 0 1 61 62 63 64 65 120 ) do: [ :offset |
		-2 to: 2 do: [ :delta |
			| string comma |
			string := String new: 140 withAll: $a.
			comma := offset + 3.
			string at: comma put: $,.
			string at: 5 + offset + delta put: $".
			(string at: comma) = $, ifTrue: [
				0 to: 3 do: [ :capacity |
					self
						assert: string
						word: word
						capacity: capacity
						reference: (SimdCSVReference on: string word: word) ] ] ] ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testChunks [
	"Chunked calls are one call: every split point, the index of a chunk from where the last one ended"

	| random |
	random := self random.
	1 to: (self exhaustiveLength: 4) * 20 do: [ :round |
		| string flags whole |
		string := self randomString: 1 + (random nextInteger: 40) with: random alphabet: 'ab,,"""' , String crlf , String lf.
		flags := (random nextInteger: 2) = 1
			         ifTrue: [ self flags: #( lines ) ]
			         ifFalse: [ self flags: #( lines skipBlank ) ].
		whole := SimdCSVReference on: string word: (self wordFlags: flags + SimdCSVDialect flagFinal).
		1 to: string size do: [ :split | self assert: string inChunksOf: split flags: flags reference: whole ] ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testEmpty [
	#( #( ) #( final ) #( final strict skipBlank lines ) ) do: [ :each |
		self assert: (self index: '' flags: (self flags: each)) equals: { #( 0 0 0 1 0 0 0 0 0 ). #(  ) } ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testExhaustive [
	"Every short String over a letter, the separator, the quote, LF and CR, with every combination of the flags, against the automaton"

	| names |
	names := #( strict lfOnly noQuote skipBlank final ).
	0 to: 31 do: [ :bits |
		| word |
		word := self wordFlags: (self flags: ((1 to: 5) select: [ :i | (bits bitAnd: (1 bitShift: i - 1)) ~= 0 ] thenCollect: [ :i | names at: i ]))
			        + SimdCSVDialect flagLines.
		self stringsOver: { $a. $,. $". Character lf. Character cr } upTo: (self exhaustiveLength: 5) do: [ :string |
			self assert: string word: word ] ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testExhaustiveLonger [
	"Longer Strings, with the flags of a reader and of a strict one"

	#( #( lines ) #( final lines ) #( strict final lines ) ) do: [ :names |
		| word |
		word := self wordFlags: (self flags: names).
		self stringsOver: { $a. $,. $". Character lf. Character cr } upTo: (self exhaustiveLength: 7) do: [ :string |
			self assert: string word: word ] ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testExhaustiveAtAnOffset [
	"The same after 60 and 125 units, so that the short String is at the end of a block"

	#( 60 125 ) do: [ :offset |
		| prefix |
		prefix := String new: offset withAll: $x.
		prefix at: offset put: $,.
		{ #( final lines ). #( strict lines ) } do: [ :names |
			| word |
			word := self wordFlags: (self flags: names).
			self stringsOver: { $a. $,. $". Character lf. Character cr } upTo: (self exhaustiveLength: 4) - 1 do: [ :string |
				self assert: prefix , string word: word ] ] ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testFinal [
	"Without FINAL the open record is not complete, nor one that ends with a CR in the last position"

	| lf cr |
	lf := String lf.
	cr := String cr.
	self assert: (self index: 'a' flags: 0) first equals: #( 0 0 0 1 0 0 0 0 0 ).
	self assert: (self index: 'a,' flags: 0) first equals: #( 0 0 0 1 0 0 0 0 0 ).
	self assert: (self index: 'a' , lf , 'b' flags: 0) first equals: #( 0 1 1 3 0 1 1 0 0 ).
	self assert: (self index: 'a' , cr flags: 0) first equals: #( 0 0 0 1 0 0 0 0 0 ).
	self assert: (self index: 'a' , cr , lf flags: 0) first equals: #( 0 1 1 4 0 1 1 0 0 ).
	self assert: (self index: 'a' , cr , 'b' flags: 0) first equals: #( 0 1 1 3 0 1 1 0 0 ).
	self assert: (self index: 'a' , cr flags: (self flags: #( final ))) first equals: #( 0 1 1 3 0 1 1 0 0 ).
	self assert: (self index: 'a,' flags: (self flags: #( final ))) equals: { #( 0 2 1 3 0 2 2 0 0 ). #( 1 2 ) }.
	self assert: (self index: cr , cr flags: (self flags: #( skipBlank ))) first equals: #( 0 0 0 2 0 0 0 0 0 )
]

{ #category : 'tests' }
SimdCSVIndexTest >> testIrregularQuotes [
	"Lenient: as Python's csv module, with no loss after the irregular quote"

	| flags |
	flags := self flags: #( final ).
	self assert: (self index: '"a"b,c' flags: flags) equals: { #( 0 2 1 7 0 2 2 0 0 ). #( 4 6 ) }.
	self assert: (self index: 'a"b,c"' flags: flags) equals: { #( 0 2 1 7 0 2 2 0 0 ). #( 3 6 ) }.
	self assert: (self index: '"a,b' flags: flags) equals: { #( 0 1 1 5 0 1 1 0 0 ). #( 4 ) }.
	self assert: (self index: ' "a,b"' flags: flags) equals: { #( 0 2 1 7 0 2 2 0 0 ). #( 3 6 ) }
]

{ #category : 'tests' }
SimdCSVIndexTest >> testIrregularQuotesEverywhere [
	"A quote in an unquoted field every n units, among regular quoted fields"

	| word |
	word := self wordFlags: (self flags: #( final lines )).
	#( 1 2 3 7 31 63 64 65 200 1000 ) do: [ :step |
		| string |
		string := String streamContents: [ :stream |
			          1 to: (self largeSize: 300) do: [ :i |
				          stream
					          nextPutAll: 'abc,"d,""e",f';
					          nextPutAll: (i \\ step = 0
							           ifTrue: [ '"g' ]
							           ifFalse: [ 'g' ]);
					          lf ] ].
		self assert: string word: word ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testLineEnds [
	"LF, CR and CRLF, mixed, are line ends; with LF_ONLY a CR is data"

	| string |
	string := 'a' , String cr , 'b' , String lf , 'c' , String crlf , 'd'.
	self assert: (self index: string flags: (self flags: #( final lines ))) equals: { #( 0 4 4 9 3 1 1 0 0 ). #( 1 3 5 8 ) }.
	self
		assert: (self index: string flags: (self flags: #( final lines lfOnly )))
		equals: { #( 0 3 3 9 2 1 1 0 0 ). #( 3 6 8 ) }
]

{ #category : 'tests' }
SimdCSVIndexTest >> testLines [
	"The line ends in quotes are counted, CRLF once"

	self
		assert: (self index: '"a' , String crlf , 'b' , String cr , 'c' , String lf , '"' , String crlf flags: (self flags: #( lines ))) first
		equals: #( 0 1 1 12 4 1 1 0 0 )
]

{ #category : 'tests' }
SimdCSVIndexTest >> testMore [
	"A record that does not fit is not stored; with no record, the first one has too many fields"

	| dest |
	dest := WordArray new: 3.
	self
		assert: (self backendObject
				 index: 'a,b' , String lf , 'c,d' , String lf
				 base: 1
				 from: 1
				 to: 8
				 dialect: (self wordFlags: (self flags: #( final lines )))
				 into: dest
				 from: 1)
		equals: #( 1 2 1 5 1 2 2 0 0 ).
	self
		assert: (self backendObject
				 index: 'a,b,c,d'
				 base: 1
				 from: 1
				 to: 7
				 dialect: (self wordFlags: (self flags: #( final )))
				 into: dest
				 from: 1)
		equals: #( 1 0 0 1 0 0 0 0 0 )
]

{ #category : 'tests' }
SimdCSVIndexTest >> testOtherDialects [
	"Other separators and quotes, NUL and the last byte too"

	| alphabet |
	{
		{ $;. $" }.
		{ Character tab. $' }.
		{ $,. Character null }.
		{ Character null. $" }.
		{ (Character value: 255). (Character value: 254) } } do: [ :pair |
		| word |
		alphabet := {
			            $a.
			            $,.
			            $".
			            pair first.
			            pair second.
			            Character lf }.
		word := self wordSeparator: pair first quote: pair second flags: (self flags: #( final lines latin1 )).
		self stringsOver: alphabet upTo: (self exhaustiveLength: 4) do: [ :string | self assert: string word: word ] ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testRandom [
	"Random Strings of any size, with the bytes of a WideString and of a ByteArray giving the same index"

	| random |
	random := self random.
	1 to: (self largeSize: 300) do: [ :round |
		| string flags word wide |
		string := self
			          randomString: (random nextInteger: 400)
			          with: random
			          alphabet: ((random nextInteger: 2) = 1
					           ifTrue: [ 'ab,,"' , String crlf ]
					           ifFalse: [ 'abcdefghijklmnopqrstuvwxyz,,,,"' , String lf ]).
		flags := self flags: #( final lines ).
		word := self wordFlags: flags.
		self assert: string word: word.
		wide := self wide: string.
		self assert: wide word: word.
		self assert: (self index: string asByteArray flags: flags) equals: (self index: string flags: flags).
		self assert: (self index: wide flags: flags) equals: (self index: string flags: flags) ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testSkipBlank [
	"A blank line makes no entry and no record, and next passes it"

	| string |
	string := String lf , String crlf , 'a' , String lf , String cr , String lf , String lf.
	self assert: (self index: string flags: (self flags: #( lines skipBlank ))) equals: { #( 0 1 1 9 5 1 1 0 0 ). #( 4 ) }.
	self assert: (self index: string flags: (self flags: #( lines ))) first equals: #( 0 5 5 9 5 1 1 0 0 ).
	self assert: (self index: ',' , String lf flags: (self flags: #( skipBlank ))) second equals: #( 0 1 )
]

{ #category : 'tests' }
SimdCSVIndexTest >> testStrict [
	"The first irregular unit is the error, after the complete records before it"

	| flags |
	flags := self flags: #( strict final lines ).
	self assert: (self index: 'a,b' , String lf , 'c"d' flags: flags) equals: { #( 2 2 1 5 1 2 2 1 6 ). #( 1 3 ) }.
	self assert: (self index: '"a"b' flags: flags) first equals: #( 2 0 0 1 0 0 0 2 4 ).
	self assert: (self index: 'x,"a' flags: flags) first equals: #( 2 0 0 1 0 0 0 3 3 ).
	self assert: (self index: '"a""b","c"' flags: flags) first equals: #( 0 2 1 11 0 2 2 0 0 ).
	self assert: (self index: 'x,"a' flags: (self flags: #( strict ))) first equals: #( 0 0 0 1 0 0 0 0 0 )
]

{ #category : 'tests' }
SimdCSVIndexTest >> testTails [
	"Every length, so that the last partial block has every size, with a quote that stays open"

	#( #( final lines ) #( final strict ) #( lines ) ) do: [ :names |
		| word |
		word := self wordFlags: (self flags: names).
		0 to: 200 do: [ :size |
			| string |
			string := (String new: size withAll: $x) , ',"' , (String new: size \\ 70 withAll: $y).
			self assert: string word: word.
			self assert: string , '"' , String lf word: word ] ]
]

{ #category : 'tests' }
SimdCSVIndexTest >> testWideUnits [
	"The units of a WideString, with a separator beyond U+00FF, and of a WordArray"

	| string words |
	string := self wide: 'a,b,c'.
	string at: 2 put: (Character value: 16r2502).
	self
		assert: (self index: string word: (self wordSeparator: (Character value: 16r2502) quote: $" flags: (self flags: #( final ))))
		equals: { #( 0 2 1 6 0 2 2 0 0 ). #( 1 5 ) }.
	words := WordArray withAll: #( 4294967295 44 10 ).
	self assert: (self index: words flags: 0) equals: { #( 0 2 1 4 0 2 2 0 0 ). #( 1 2 ) }
]

{ #category : 'asserting' }
SimdCSVIndexTest >> assert: aString inChunksOf: size flags: flags reference: whole [
	"Index aString as a reader does, with a window that grows by size units when it holds no complete record, and compare the concatenation with the index at once"

	| answer entries from to records lines dest isFinal expected |
	expected := whole indexCapacity: aString size + 1 base: 1.
	entries := OrderedCollection new.
	records := lines := 0.
	from := 1.
	to := size min: aString size.
	dest := WordArray new: aString size + 1.
	[
	isFinal := to = aString size.
	answer := self backendObject
		          index: aString
		          base: from
		          from: from
		          to: to
		          dialect: (self wordFlags: flags + (isFinal
						            ifTrue: [ SimdCSVDialect flagFinal ]
						            ifFalse: [ 0 ]))
		          into: dest
		          from: 1.
	1 to: answer second do: [ :i | entries add: (dest at: i) + from - 1 ].
	records := records + answer third.
	lines := lines + (answer at: 5).
	from := answer fourth.
	isFinal ] whileFalse: [ to := to + size min: aString size ].
	self assert: entries asArray equals: whole entries.
	self assert: {
			records.
			lines.
			from } equals: {
			expected third.
			(expected at: 5).
			expected fourth }
]

{ #category : 'asserting' }
SimdCSVIndexTest >> assert: aSource word: word [
	"The index of aSource is the one of the automaton"

	| reference answer |
	reference := SimdCSVReference on: aSource word: word.
	answer := self index: aSource word: word.
	(answer first = (reference indexCapacity: aSource size + 1 base: 1) and: [ answer second = reference entries ]) ifFalse: [
		self fail: aSource printString , ' with ' , (word bitShift: -29) printString , ' gives ' , answer printString ]
]

{ #category : 'asserting' }
SimdCSVIndexTest >> assert: aString word: word capacity: capacity reference: reference [
	| dest answer |
	dest := WordArray new: capacity + 2 withAll: 99999.
	answer := self backendObject
		          index: aString
		          base: 1
		          from: 1
		          to: aString size
		          dialect: word
		          into: dest
		          from: 3.
	(answer = (reference indexCapacity: capacity base: 1) and: [
		 (dest copyFrom: 3 to: answer second + 2) asArray = reference entries and: [ dest first = 99999 and: [ dest second = 99999 ] ] ])
		ifFalse: [
			self fail:
				aString printString , ' with ' , (word bitShift: -29) printString , ' and ' , capacity printString , ' slots gives '
				, answer printString ]
]

{ #category : 'helpers' }
SimdCSVIndexTest >> randomString: size with: aRandom alphabet: aString [
	| string |
	string := String new: size.
	1 to: size do: [ :i | string at: i put: (aString at: (aRandom nextInteger: aString size)) ].
	^ string
]

{ #category : 'tests' }
SimdCSVIndexTest >> testFinalCarriageReturnWithoutASlot [
	"A field that ends without a slot is MORE, even where its end is a CR in the last position, with which no record is complete"

	| bytes answer |
	bytes := self bytes: 'a' , String cr.
	answer := self backendObject index: bytes base: 1 from: 1 to: 2 dialect: (self wordFlags: 0) into: (WordArray new: 0) from: 1.
	self assert: answer equals: { SimdCSVBackend statusMore. 0. 0. 1. 0. 0. 0. 0. 0 }.
	answer := self backendObject index: bytes base: 1 from: 1 to: 2 dialect: (self wordFlags: 0) into: (WordArray new: 1) from: 1.
	self assert: answer equals: { SimdCSVBackend statusOK. 0. 0. 1. 0. 0. 0. 0. 0 }
]

{ #category : 'tests' }
SimdCSVIndexTest >> testNextAfterBlankLines [
	"With SKIP_BLANK next is after the blank lines, whatever the status"

	| flags bytes index |
	flags := self flags: #( skipBlank final strict ).
	index := [ :text :size |
	         bytes := self bytes: text.
	         self backendObject index: bytes base: 1 from: 1 to: bytes size dialect: (self wordFlags: flags) into: (WordArray new: size) from: 1 ].
	"MORE"
	self assert: (index value: 'a' , String lf , String lf , String lf , 'b' value: 1) equals: { SimdCSVBackend statusMore. 1. 1. 5. 0. 1. 1. 0. 0 }.
	"ERROR"
	self assert: (index value: 'a' , String lf , String lf , String lf , 'b"' value: 9) equals: { SimdCSVBackend statusError. 1. 1. 5. 0. 1. 1. 1. 6 }.
	"OK, the open record"
	flags := self flags: #( skipBlank ).
	self assert: (index value: 'a' , String lf , String lf , String lf , 'b' value: 9) equals: { SimdCSVBackend statusOK. 1. 1. 5. 0. 1. 1. 0. 0 }
]
