"
I test the measure, which counts the records, the fields and the lines without storing them.
"
Class {
	#name : 'SimdCSVMeasureTest',
	#superclass : 'SimdCSVTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
SimdCSVMeasureTest >> testAnswer [
	self
		assert: (self measure: 'a,b' , String lf , '1,"x,y"' flags: (self flags: #( final lines )))
		equals: #( 0 2 4 12 1 0 0 )
]

{ #category : 'tests' }
SimdCSVMeasureTest >> testEmpty [
	self assert: (self measure: '' flags: (self flags: #( final lines ))) equals: #( 0 0 0 1 0 0 0 )
]

{ #category : 'tests' }
SimdCSVMeasureTest >> testIsTheIndex [
	"The numbers are those of an index with room for every field"

	0 to: 31 do: [ :bits |
		| word names |
		names := #( strict lfOnly noQuote skipBlank final ).
		word := self wordFlags: (self flags: ((1 to: 5) select: [ :i | (bits bitAnd: (1 bitShift: i - 1)) ~= 0 ] thenCollect: [ :i | names at: i ]))
			        + SimdCSVDialect flagLines.
		self stringsOver: { $a. $,. $". Character lf. Character cr } upTo: (self exhaustiveLength: 4) do: [ :string |
			| index measure |
			index := (self index: string word: word) first.
			measure := self backendObject measure: string from: 1 to: string size dialect: word.
			measure = {
				index first.
				index third.
				index second.
				index fourth.
				(index at: 5).
				(index at: 8).
				(index at: 9) } ifFalse: [ self fail: string printString , ' with ' , bits printString , ' gives ' , measure printString ] ] ]
]

{ #category : 'tests' }
SimdCSVMeasureTest >> testLarge [
	"A megabyte of records, some with quoted separators and line ends"

	| line source count answer |
	line := 'abcdefgh,"x,y' , String crlf , 'z",12345' , String lf.
	count := self largeSize: 40000.
	source := ByteArray streamContents: [ :stream | count timesRepeat: [ stream nextPutAll: line asByteArray ] ].
	answer := self measure: source flags: (self flags: #( lines )).
	self assert: answer equals: {
			0.
			count.
			(3 * count).
			(source size + 1).
			(2 * count).
			0.
			0 }
]

{ #category : 'tests' }
SimdCSVMeasureTest >> testRange [
	self
		assert: (self backendObject measure: 'xx,yy,zz' from: 4 to: 5 dialect: (self wordFlags: (self flags: #( final ))))
		equals: #( 0 1 1 6 0 0 0 )
]

{ #category : 'tests' }
SimdCSVMeasureTest >> testStrict [
	self
		assert: (self measure: 'a' , String lf , 'b,"c"d' flags: (self flags: #( strict final lines )))
		equals: #( 2 1 1 3 1 2 8 )
]

{ #category : 'helpers' }
SimdCSVMeasureTest >> measure: aSource flags: flags [
	^ self backendObject measure: aSource from: 1 to: aSource size dialect: (self wordFlags: flags)
]
