"
I test the memory that the reader takes with the plugin; I am skipped without it.

Where the test is that old space cannot grow, the VM parameter 67 is the size of the heap meanwhile. On WebAssembly that is as it is, and the test is of lane 79.
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

	| bytes grown row size free |
	grown := 0.
	SimdCSVBackend testHook: #grow value: [ :count |
		grown := grown + 1.
		[ Smalltalk growMemoryByAtLeast: count ]
			on: OutOfMemory
			do: [ :error | error return ] ].
	free := Smalltalk garbageCollect.
	size := (free // 3 max: 1048576) min: (self largeSize: 268435456).
	bytes := ByteArray new: size withAll: 120.
	bytes replaceFrom: 1 to: 2 with: #[ 206 177 ] startingAt: 1.
	row := (self reader: bytes)
		       maxRecordBytes: size;
		       next.
	self assert: grown equals: (size * 4 > free
			 ifTrue: [ 1 ]
			 ifFalse: [ 0 ]).
	self assert: row first class equals: WideString.
	self assert: row first size equals: size - 1.
	self assert: row first first codePoint equals: 945.
	self assert: row first last equals: $x
]

{ #category : 'helpers' }
SimdCSVMemoryTest >> withFree: freeBytes garbage: garbageBytes do: aBlock [
	"Evaluate aBlock in a heap that cannot grow, with about freeBytes free bytes and as many bytes of garbage more. The headroom (25) is low meanwhile: the VM would try to grow the memory at each scavenge, and log it"

	| vm limit headroom ballast count |
	vm := Smalltalk vm.
	limit := (vm parameterAt: 67) ifNil: [ 0 ].
	headroom := vm parameterAt: 25.
	Smalltalk garbageCollect.
	garbageBytes + freeBytes > (vm parameterAt: 54) ifTrue: [ Smalltalk growMemoryByAtLeast: garbageBytes + freeBytes ].
	[
	vm
		parameterAt: 67 put: (vm parameterAt: 1);
		parameterAt: 25 put: 1000000.
	ballast := OrderedCollection new.
	[ (vm parameterAt: 54) > (freeBytes + 1100000) ] whileTrue: [ ballast addLast: (ByteArray new: 1000000) ].
	count := garbageBytes // 1000000.
	ballast := ballast allButFirst: (count min: ballast size).
	aBlock value ] ensure: [
		ballast := nil.
		vm
			parameterAt: 67 put: limit;
			parameterAt: 25 put: headroom ]
]

{ #category : 'tests' }
SimdCSVMemoryTest >> testBoundedReading [
	"What is read and not kept does not fill an old space that cannot grow. (After 260 MB with 10 MB free there was an OutOfMemory.)"

	| line bytes count |
	self class isSmall ifTrue: [ ^ self ].
	line := '1234,abcdefgh,"a, b",0.5,2026-11-24,xyz,,some longer text here for the row' , String lf.
	bytes := ByteArray new: 20000000 // line size * line size.
	1 to: bytes size by: line size do: [ :i | bytes replaceFrom: i to: i + line size - 1 with: line asByteArray startingAt: 1 ].
	count := 0.
	self withFree: 10000000 garbage: 0 do: [
		20 timesRepeat: [ (self reader: bytes) do: [ :row | count := count + 1 ] ].
		self assert: (Smalltalk vm parameterAt: 54) > 4000000 ].
	self assert: count equals: bytes size // line size * 20
]

{ #category : 'tests' }
SimdCSVMemoryTest >> testBoundedRecord [
	"A record of many fields that fits after a collection is built; one that does not fit is an OutOfMemory, which leaves the memory as it was. (There were 500 free bytes left.)"

	| bytes reader |
	self class isSmall ifTrue: [ ^ self ].
	bytes := ByteArray new: 39000000 withAll: 120.
	600 to: bytes size - 1 by: 600 do: [ :i | bytes at: i put: 44 ].
	reader := [
	          (self reader: bytes)
		          maxRecordBytes: 67108864;
		          yourself ].
	self withFree: 10000000 garbage: 80000000 do: [
		| row |
		row := reader value next.
		self assert: row size equals: 65000.
		self assert: row first size equals: 599 ].
	self withFree: 10000000 garbage: 0 do: [
		| free each |
		each := reader value.
		self should: [ each next ] raise: OutOfMemory.
		each := nil.
		free := Smalltalk vm parameterAt: 54.
		self assert: free > 5000000 description: [ free printString ].
		self assert: ((1 to: 20000) collect: [ :i | Object new ]) size equals: 20000 ]
]
