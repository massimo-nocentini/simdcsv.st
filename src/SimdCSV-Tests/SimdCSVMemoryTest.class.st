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

{ #category : 'helpers' }
SimdCSVMemoryTest >> liveBytes [
	"The bytes of the objects that are left after a full garbage collection"

	| free |
	free := Smalltalk garbageCollect.
	^ (Smalltalk vm parameterAt: 1) - free
]

{ #category : 'tests' }
SimdCSVMemoryTest >> testWideHeaderAndBlankLines [
	"A header of many names pads each blank line to as many fields: no more than a batch of the rows is alive"

	| text count reader before most |
	text := (String new: 65535 withAll: $,) , (String new: (self largeSize: 1000) withAll: Character lf).
	reader := self reader: text.
	self assert: reader readHeader size equals: 65536.
	count := most := 0.
	before := self liveBytes.
	reader do: [ :row |
		count := count + 1.
		self assert: row size equals: 65536.
		count \\ 50 = 0 ifTrue: [ most := most max: self liveBytes - before ] ].
	self assert: count equals: (self largeSize: 1000) - 1.
	self assert: most < (16 * 1048576) description: [ most printString ]
]

{ #category : 'tests' }
SimdCSVMemoryTest >> testGrowth [
	"A record that does not fit the free memory is built after the memory has grown, once"

	| bytes grown row size |
	grown := 0.
	SimdCSVBackend testHook: #grow value: [ :count |
		grown := grown + 1.
		Smalltalk growMemoryByAtLeast: count ].
	size := Smalltalk garbageCollect // 3 max: 1048576.
	bytes := ByteArray new: size withAll: 120.
	bytes replaceFrom: 1 to: 2 with: #[ 206 177 ] startingAt: 1.
	row := (self reader: bytes)
		       maxRecordBytes: size;
		       next.
	self assert: grown equals: 1.
	self assert: row first class equals: WideString.
	self assert: row first size equals: size - 1.
	self assert: row first first codePoint equals: 945.
	self assert: row first last equals: $x
]
