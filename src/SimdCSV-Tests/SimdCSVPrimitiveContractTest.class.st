"
I test what the primitives refuse: every argument, every range, and the order of the checks.
"
Class {
	#name : 'SimdCSVPrimitiveContractTest',
	#superclass : 'SimdCSVTestCase',
	#instVars : [
		'source',
		'dest',
		'index',
		'rows',
		'word'
	],
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'running' }
SimdCSVPrimitiveContractTest >> setUp [
	super setUp.
	source := 'a,b' copy.
	dest := WordArray new: 3.
	index := WordArray withAll: #( 1 3 ).
	rows := Array new: 2.
	word := self wordFlags: (self flags: #( latin1 final ))
]

{ #category : 'helpers' }
SimdCSVPrimitiveContractTest >> index: aSource base: base from: start to: stop word: aWord into: anObject from: k [
	^ self backendObject index: aSource base: base from: start to: stop dialect: aWord into: anObject from: k
]

{ #category : 'helpers' }
SimdCSVPrimitiveContractTest >> rowsWith: aBlock [
	"The answer of a call for the rows of source, whose arguments aBlock changes, in a Dictionary by their names"

	| a |
	a := Dictionary new.
	a
		at: #source put: source;
		at: #base put: 1;
		at: #to put: 3;
		at: #word put: word;
		at: #index put: index;
		at: #from put: 1;
		at: #end put: 2;
		at: #types put: nil;
		at: #count put: 0;
		at: #dest put: rows;
		at: #destFrom put: 1;
		at: #wide put: WideString;
		at: #budget put: -1.
	aBlock value: a.
	^ self backendObject
		  rows: (a at: #source)
		  base: (a at: #base)
		  to: (a at: #to)
		  dialect: (a at: #word)
		  index: (a at: #index)
		  from: (a at: #from)
		  to: (a at: #end)
		  types: (a at: #types)
		  fieldCount: (a at: #count)
		  into: (a at: #dest)
		  from: (a at: #destFrom)
		  wideStringClass: (a at: #wide)
		  empty: nil
		  budget: (a at: #budget)
]

{ #category : 'asserting' }
SimdCSVPrimitiveContractTest >> assertRows: aDictionary fail: aSymbol [
	self assert: [ self rowsWith: [ :a | aDictionary associationsDo: [ :each | a at: each key put: each value ] ] ] fails: aSymbol
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testAnswersAreFresh [
	self
		deny: (self backendObject measure: source from: 1 to: 3 dialect: word)
		identicalTo: (self backendObject measure: source from: 1 to: 3 dialect: word)
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testDialect [
	"The dialect words that are refused"

	| check |
	check := [ :aSource :separator :quote :flags |
	         self
		         assert: [
			         self backendObject
				         measure: aSource
				         from: 1
				         to: 3
				         dialect: separator + (quote bitShift: 21) + (flags bitShift: 29) ]
		         fails: #'bad argument' ].
	check value: source value: 44 value: 44 value: 16.
	check value: source value: 10 value: 34 value: 16.
	check value: source value: 13 value: 34 value: 16.
	check value: source value: 13 value: 34 value: 18.
	check value: source value: 44 value: 10 value: 16.
	check value: source value: 44 value: 13 value: 16.
	check value: source value: 44 value: 13 value: 20.
	check value: source value: 128 value: 34 value: 0.
	check value: source value: 44 value: 128 value: 0.
	check value: source value: 256 value: 34 value: 16.
	check value: source value: 44 value: 34 value: 512.
	check value: source value: 44 value: 34 value: 65536.
	check value: source value: 44 value: 34 value: -1.
	check value: (self wide: source) value: 44 value: 34 value: 16.
	self assert: [ self backendObject measure: source from: 1 to: 3 dialect: nil ] fails: #'bad argument'.
	self assert: [ self backendObject measure: source from: 1 to: 3 dialect: SmallInteger maxVal + 1 ] fails: #'bad argument'.
	#( #( 44 34 0 ) #( 127 34 0 ) #( 44 127 0 ) #( 255 254 16 ) #( 44 44 4 ) #( 0 34 511 ) ) do: [ :each |
		self deny: (self backendObject
				 measure: source
				 from: 1
				 to: 3
				 dialect: each first + (each second bitShift: 21) + (each third bitShift: 29)) simdCSVFailed ].
	self deny: (self backendObject measure: (self wide: source) from: 1 to: 3 dialect: 16r1FFFFF + (255 bitShift: 21)) simdCSVFailed
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testIndexArguments [
	self assert: [ self index: nil base: 1 from: 1 to: 3 word: word into: dest from: 1 ] fails: #'bad argument'.
	self assert: [ self index: 42 base: 1 from: 1 to: 3 word: word into: dest from: 1 ] fails: #'bad argument'.
	self assert: [ self index: #( 1 2 3 ) base: 1 from: 1 to: 3 word: word into: dest from: 1 ] fails: #'bad argument'.
	self assert: [ self index: (Float64Array new: 3) base: 1 from: 1 to: 3 word: word into: dest from: 1 ] fails: #'bad argument'.
	self assert: [ self index: self class >> #setUp base: 1 from: 1 to: 3 word: word into: dest from: 1 ] fails: #'bad argument'.
	self assert: [ self index: source base: 1.0 from: 1 to: 3 word: word into: dest from: 1 ] fails: #'bad argument'.
	self assert: [ self index: source base: 1 from: nil to: 3 word: word into: dest from: 1 ] fails: #'bad argument'.
	self assert: [ self index: source base: 1 from: 1 to: '3' word: word into: dest from: 1 ] fails: #'bad argument'.
	self assert: [ self index: source base: 1 from: 1 to: 3 word: word into: dest from: $a ] fails: #'bad argument'.
	self assert: [ self index: source base: 1 from: 1 to: 3 word: word into: nil from: 1 ] fails: #'bad argument'.
	self assert: [ self index: source base: 1 from: 1 to: 3 word: word into: (ByteArray new: 8) from: 1 ] fails: #'bad argument'.
	self assert: [ self index: source base: 1 from: 1 to: 3 word: word into: (Array new: 8) from: 1 ] fails: #'bad argument'.
	self assert: [ self index: (self wide: source) base: 1 from: 1 to: 3 word: (self wordFlags: 32) into: nil from: 1 ] fails: #'bad argument'.
	source := self wide: source.
	self assert: [ self index: source base: 1 from: 1 to: 3 word: (self wordFlags: 32) into: source from: 1 ] fails: #'bad argument'
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testIndexRanges [
	#( #( 0 1 3 1 ) #( 2 1 3 1 ) #( 1 0 3 1 ) #( 1 5 3 1 ) #( 1 1 4 1 ) #( 1 1 3 0 ) #( 1 1 3 5 ) #( 1 1 -1 1 ) #( -1 -1 3 1 ) #( 5 5 4 1 )
	   #( 1 1 4611686018427387903 1 ) #( 1 1 3 4611686018427387903 ) ) do: [ :each |
		| max |
		max := each collect: [ :number | number min: SmallInteger maxVal ].
		self
			assert: [ self index: source base: max first from: max second to: max third word: word into: dest from: max fourth ]
			fails: #'bad index' ].
	self assert: (self index: source base: 4 from: 4 to: 3 word: word into: dest from: 4) equals: #( 0 0 0 4 0 0 0 0 0 ).
	self assert: (self index: source base: 1 from: 1 to: 3 word: word into: dest from: 4) first equals: 1
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testOrderOfTheChecks [
	"The source, the numbers, the dialect, the ranges, the classes, the immutable destination"

	self assert: [ self index: nil base: 9 from: 1 to: 3 word: 0 into: nil from: 9 ] fails: #'bad argument'.
	self assert: [ self index: source base: 9 from: 1 to: 3 word: 10 into: dest from: 9 ] fails: #'bad argument'.
	self assert: [ self index: source base: 9 from: 1 to: 3 word: word into: nil from: 1 ] fails: #'bad index'.
	self assertRows: { #base -> 9. #wide -> nil. #index -> nil. #dest -> nil } asDictionary fail: #'bad index'.
	dest beReadOnlyObject.
	self assert: [ self index: source base: 9 from: 1 to: 3 word: word into: dest from: 1 ] fails: #'bad index'
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testReadOnlyDestination [
	dest beReadOnlyObject.
	self assert: [ self index: source base: 1 from: 1 to: 3 word: word into: dest from: 1 ] fails: #'no modification'.
	rows beReadOnlyObject.
	self assertRows: Dictionary new fail: #'no modification'
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testReadOnlySource [
	source beReadOnlyObject.
	index beReadOnlyObject.
	self assert: (self index: source base: 1 from: 1 to: 3 word: word into: dest from: 1) first equals: 0.
	self assert: (self rowsWith: [ :a |  ]) equals: #( 0 1 3 0 0 0 0 0 0 ).
	self assert: rows first equals: #( 'a' 'b' )
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testRowsArguments [
	{
		(#source -> nil).
		(#source -> #( 1 2 3 )).
		(#source -> (Float64Array new: 3)).
		(#base -> nil).
		(#to -> 3.0).
		(#word -> 10).
		(#word -> nil).
		(#index -> nil).
		(#index -> (Array with: 1 with: 3)).
		(#index -> (ByteArray new: 2)).
		(#from -> nil).
		(#end -> nil).
		(#types -> (Array with: 1)).
		(#types -> 'a').
		(#types -> #[ 5 ]).
		(#types -> #[ 1 255 ]).
		(#count -> nil).
		(#dest -> nil).
		(#dest -> (OrderedCollection new: 2)).
		(#dest -> (WeakArray new: 2)).
		(#dest -> (ByteArray new: 2)).
		(#destFrom -> nil).
		(#wide -> nil).
		(#wide -> 42).
		(#wide -> ByteString).
		(#wide -> Array).
		(#wide -> BoxedFloat64).
		(#wide -> WideString class).
		(#wide -> (WideString new: 1)).
		(#budget -> nil).
		(#budget -> (SmallInteger maxVal + 1)) } do: [ :each |
		self assertRows: { each } asDictionary fail: #'bad argument' ].
	self assertRows: { (#types -> #[ 1 ]). (#count -> 2) } asDictionary fail: #'bad argument'.
	self assertRows: { (#types -> #[  ]). (#count -> 1) } asDictionary fail: #'bad argument'
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testRowsRanges [
	{
		(#base -> 0).
		(#base -> 5).
		(#to -> 4).
		(#to -> -1).
		(#from -> 0).
		(#from -> 4).
		(#end -> 3).
		(#end -> -1).
		(#count -> -1).
		(#count -> 16777217).
		(#count -> SmallInteger maxVal).
		(#destFrom -> 0).
		(#destFrom -> 4) } do: [ :each | self assertRows: { each } asDictionary fail: #'bad index' ].
	self assert: (self rowsWith: [ :a | a at: #destFrom put: 3 ]) equals: #( 1 0 1 0 0 0 0 0 0 ).
	self assert: (self rowsWith: [ :a | a at: #destFrom put: 3; at: #from put: 3 ]) equals: #( 0 0 3 0 0 0 0 0 0 )
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testMeasureArguments [
	self assert: [ self backendObject measure: nil from: 1 to: 3 dialect: word ] fails: #'bad argument'.
	self assert: [ self backendObject measure: source from: nil to: 3 dialect: word ] fails: #'bad argument'.
	self assert: [ self backendObject measure: source from: 0 to: 3 dialect: word ] fails: #'bad index'.
	self assert: [ self backendObject measure: source from: 1 to: 4 dialect: word ] fails: #'bad index'.
	self assert: [ self backendObject measure: source from: 5 to: 3 dialect: word ] fails: #'bad index'.
	self assert: (self backendObject measure: source from: 4 to: 3 dialect: word) equals: #( 0 0 0 4 0 0 0 )
]

{ #category : 'tests' }
SimdCSVPrimitiveContractTest >> testSources [
	"Every object of bytes or of 32-bit words is a source; a Symbol too"

	{ source. source asSymbol. source asByteArray. (self wide: source). (WordArray withAll: source asByteArray). (Bitmap withAll: source asByteArray) } do: [ :each |
		self
			assert: (self backendObject
					 measure: each
					 from: 1
					 to: 3
					 dialect: (self wordFlags: ((SimdCSVSmalltalk unitsOf: each) == #bytes
								  ifTrue: [ 48 ]
								  ifFalse: [ 32 ])))
			equals: #( 0 1 2 4 0 0 0 ) ]
]
