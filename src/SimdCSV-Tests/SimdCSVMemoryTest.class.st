"
I test the memory that the reader takes with the plugin; I am skipped without it.
"
Class {
	#name : 'SimdCSVMemoryTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'building suites' }
SimdCSVMemoryTest class >> testParameters [
	^ ParametrizedTestMatrix new
		  forSelector: #backendName addOptions: #( #plugin );
		  yourself
]

{ #category : 'helpers' }
SimdCSVMemoryTest >> fullCollections [
	^ Smalltalk vm parameterAt: 7
]

{ #category : 'tests' }
SimdCSVMemoryTest >> testNoFullCollection [
	"do: over a large input makes no full garbage collection"

	| bytes line size collections count |
	size := self largeSize: 20000000.
	line := '1234,abcdefgh,"a, b",0.5,2026-11-24,xyz' , String lf.
	bytes := ByteArray new: size // line size * line size.
	1 to: bytes size by: line size do: [ :i | bytes replaceFrom: i to: i + line size - 1 with: line asByteArray startingAt: 1 ].
	count := 0.
	Smalltalk garbageCollect.
	collections := self fullCollections.
	(self reader: bytes) do: [ :row | count := count + 1 ].
	self assert: count equals: size // line size.
	self assert: self fullCollections equals: collections
]

{ #category : 'tests' }
SimdCSVMemoryTest >> testManyCommas [
	"A record of too many fields is refused before anything is built"

	| commas |
	commas := ByteArray new: 1000000 withAll: 44.
	self assert: (self assert: [ self read: commas ] signals: SimdCSVResourceError) kind equals: #fields
]

{ #category : 'tests' }
SimdCSVMemoryTest >> testWideHeaderAndBlankLines [
	"A header of many names pads each blank line to as many fields, some rows at a time"

	| text count reader free lowest |
	text := (String new: 65535 withAll: $,) , (String new: (self largeSize: 1000) withAll: Character lf).
	reader := self reader: text.
	self assert: reader readHeader size equals: 65536.
	count := 0.
	Smalltalk garbageCollect.
	free := lowest := Smalltalk vm parameterAt: 1.
	reader do: [ :row |
		count := count + 1.
		self assert: row size equals: 65536.
		lowest := lowest max: (Smalltalk vm parameterAt: 1) ].
	self assert: count equals: (self largeSize: 1000) - 1.
	self assert: lowest - free < (256 * 1048576)
]

{ #category : 'tests' }
SimdCSVMemoryTest >> testGrowth [
	"Records that do not fit the free memory are built after it has grown"

	| text row size |
	size := self largeSize: 20000000.
	text := (String new: size withAll: $x) , ',' , (String new: size withAll: $y).
	row := (self reader: text) next.
	self assert: (row collect: [ :each | each size ]) equals: { size. size }.
	self assert: row second last equals: $y
]
