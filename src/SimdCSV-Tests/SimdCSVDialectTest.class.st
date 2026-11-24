"
I test the dialect and its word for the primitives.
"
Class {
	#name : 'SimdCSVDialectTest',
	#superclass : 'SimdCSVTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
SimdCSVDialectTest >> testCopy [
	| dialect copy |
	dialect := SimdCSVDialect new.
	copy := dialect copy separator: $;.
	self assert: dialect separator equals: $,.
	self assert: copy separator equals: $;
]

{ #category : 'tests' }
SimdCSVDialectTest >> testDefaults [
	| dialect |
	dialect := SimdCSVDialect new.
	self assert: dialect separator equals: $,.
	self assert: dialect quote equals: $".
	self assert: dialect lineEnd equals: #any.
	self deny: dialect strictQuoting.
	self deny: dialect strictFieldCount.
	self deny: dialect skipEmptyLines.
	self deny: dialect keepQuotedEmpty.
	self assert: dialect encoding equals: #utf8.
	self assert: dialect emptyFieldValue isNil.
	self assert: dialect hasHeader.
	self assert: dialect nullTexts isEmpty
]

{ #category : 'tests' }
SimdCSVDialectTest >> testInstanceCreation [
	self assert: SimdCSVDialect comma separator equals: $,.
	self assert: SimdCSVDialect semicolon separator equals: $;.
	self assert: SimdCSVDialect tab separator equals: Character tab
]

{ #category : 'tests' }
SimdCSVDialectTest >> testLatin1 [
	"The bytes of a String are characters; those of any other object are UTF-8 unless the encoding says otherwise"

	| latin1 |
	latin1 := SimdCSVDialect flagLatin1 bitShift: 29.
	self assert: ((self word: SimdCSVDialect new for: 'a') bitAnd: latin1) equals: latin1.
	self assert: ((self word: SimdCSVDialect new for: #a) bitAnd: latin1) equals: latin1.
	self assert: ((self word: SimdCSVDialect new for: #[ 1 ]) bitAnd: latin1) equals: 0.
	self assert: ((self word: (SimdCSVDialect new encoding: #latin1) for: #[ 1 ]) bitAnd: latin1) equals: latin1.
	self assert: ((self word: (SimdCSVDialect new encoding: #latin1) for: (WideString new: 1)) bitAnd: latin1) equals: 0.
	self assert: ((self word: SimdCSVDialect new for: (WordArray new: 1)) bitAnd: latin1) equals: 0
]

{ #category : 'tests' }
SimdCSVDialectTest >> testRefusedSettings [
	{
		[ SimdCSVDialect new separator: ',' ].
		[ SimdCSVDialect new separator: nil ].
		[ SimdCSVDialect new quote: 34 ].
		[ SimdCSVDialect new lineEnd: #crlf ].
		[ SimdCSVDialect new lineEnd: nil ].
		[ SimdCSVDialect new encoding: #utf16 ].
		[ SimdCSVDialect new strictQuoting: nil ].
		[ SimdCSVDialect new strictFieldCount: 1 ].
		[ SimdCSVDialect new skipEmptyLines: nil ].
		[ SimdCSVDialect new keepQuotedEmpty: nil ].
		[ SimdCSVDialect new hasHeader: nil ] } do: [ :each | self should: each raise: SimdCSVArgumentError ]
]

{ #category : 'tests' }
SimdCSVDialectTest >> testRefusedWords [
	"What the primitives would refuse signals SimdCSVArgumentError, with a text"

	| euro |
	euro := Character value: 16r20AC.
	{
		{ $". $". 'a' }.
		{ Character lf. $". 'a' }.
		{ Character cr. nil. 'a' }.
		{ $,. Character lf. 'a' }.
		{ $,. Character cr. 'a' }.
		{ $,. euro. (WideString new: 1) }.
		{ euro. $". 'a' }.
		{ euro. $". #[ 1 ] }.
		{ (Character value: 128). $". #[ 1 ] }.
		{ $,. (Character value: 128). #[ 1 ] }.
		{ (Character value: 256). $". 'a' }.
		{ $,. (Character value: 256). (WideString new: 1) }.
		{ $,. (Character value: 233). #[ 1 ] }.
		{ $,. $". nil }.
		{ $,. $". 42 }.
		{ $,. $". #( 1 ) } } do: [ :each |
		| dialect |
		dialect := SimdCSVDialect new
			           separator: each first;
			           quote: each second;
			           yourself.
		self should: [ self word: dialect for: each third ] raise: SimdCSVArgumentError.
		[ self word: dialect for: each third ]
			on: SimdCSVArgumentError
			do: [ :error | self assert: (error messageText beginsWith: 'SimdCSV: ') ] ]
]

{ #category : 'tests' }
SimdCSVDialectTest >> testSettings [
	| dialect |
	dialect := SimdCSVDialect new
		           hasHeader: false;
		           strictQuoting: true;
		           emptyFieldValue: 0;
		           nullTexts: (OrderedCollection with: 'NA');
		           yourself.
	self deny: dialect hasHeader.
	self assert: dialect strictQuoting.
	self deny: (dialect strictQuoting: false; strictQuoting).
	self assert: dialect emptyFieldValue equals: 0.
	self assert: dialect nullTexts equals: #( 'NA' ).
	dialect := SimdCSVDialect new separator: (Character value: 127); quote: (Character value: 255); yourself.
	self deny: (self backendObject measure: 'a' from: 1 to: 1 dialect: (self word: dialect for: (WideString with: $a))) simdCSVFailed
]

{ #category : 'tests' }
SimdCSVDialectTest >> testWord [
	| dialect |
	dialect := SimdCSVDialect new.
	self assert: (dialect wordFor: #[  ] final: false lines: false exact: false) equals: 44 + (34 bitShift: 21).
	self
		assert: (dialect wordFor: #[  ] final: true lines: true exact: true)
		equals: 44 + (34 bitShift: 21) + (32 + 64 + 128 bitShift: 29).
	dialect
		separator: Character tab;
		quote: nil;
		lineEnd: #lf;
		strictQuoting: true;
		strictFieldCount: true;
		skipEmptyLines: true;
		keepQuotedEmpty: true.
	self assert: (dialect wordFor: 'a' final: false lines: false exact: false) equals: 9 + (1 + 2 + 4 + 8 + 16 + 256 bitShift: 29)
]

{ #category : 'tests' }
SimdCSVDialectTest >> testWordIsTaken [
	"The primitives take every word that a dialect makes"

	{ $,. $;. Character tab. Character null. (Character value: 127). $a } do: [ :separator |
		{ nil. $". $'. Character null } do: [ :quote |
			separator = quote ifFalse: [
				| dialect |
				dialect := SimdCSVDialect new
					           separator: separator;
					           quote: quote;
					           yourself.
				{ 'a'. #[ 1 ]. (WideString new: 1) } do: [ :source |
					self deny: (self backendObject measure: source from: 1 to: 1 dialect: (self word: dialect for: source)) simdCSVFailed ] ] ] ].
	self deny: (self backendObject
			 measure: 'a'
			 from: 1
			 to: 1
			 dialect: (self
					  word: (SimdCSVDialect new
							   separator: (Character value: 255);
							   quote: (Character value: 254);
							   yourself)
					  for: 'a')) simdCSVFailed
]

{ #category : 'helpers' }
SimdCSVDialectTest >> word: aDialect for: aSource [
	^ aDialect wordFor: aSource final: false lines: false exact: false
]
