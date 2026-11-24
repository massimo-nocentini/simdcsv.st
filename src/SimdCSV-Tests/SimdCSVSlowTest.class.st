"
I am slow, and run only when the environment variable `SIMDCSV_SLOW_TESTS` is `yes`: 100 MB of text, and the comparison with the csv module of Python.
"
Class {
	#name : 'SimdCSVSlowTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'running' }
SimdCSVSlowTest >> setUp [
	super setUp.
	(OSEnvironment current at: 'SIMDCSV_SLOW_TESTS' ifAbsent: [ '' ]) = 'yes' ifFalse: [ self skip: 'SIMDCSV_SLOW_TESTS is not yes' ]
]

{ #category : 'accessing' }
SimdCSVSlowTest class >> defaultTimeLimit [
	^ 3600 seconds
]

{ #category : 'tests' }
SimdCSVSlowTest >> testLargeText [
	"100 MB in place, with the plugin"

	| bytes line count total |
	backendName == #plugin ifFalse: [ ^ self skip: 'the plugin only' ].
	total := 2500000.
	line := '1234,abcdefgh,"a, b",0.5,2026-11-24,xy' , String lf.
	bytes := ByteArray new: total * line size.
	1 to: bytes size by: line size do: [ :i | bytes replaceFrom: i to: i + line size - 1 with: line asByteArray startingAt: 1 ].
	self assert: (SimdCSV count: bytes) equals: total.
	count := 0.
	(self reader: bytes) addIntegerField; addIgnoredFields: 2; addFloatField; do: [ :row |
		row = #( 1234 0.5 ) ifFalse: [ self fail ].
		count := count + 1 ].
	self assert: count equals: total.
	self assert: (SimdCSV tableFrom: bytes) rowCount equals: total - 1
]

{ #category : 'tests' }
SimdCSVSlowTest >> testPythonReadsTheSame [
	"The rows of random texts, as the csv module of Python reads them: lenient quotes, every line end. A blank line has no field there and an empty one here, which are written alike"

	| random directory texts expected rows |
	random := self random.
	directory := FileLocator temp / ('simdcsv-' , UUID new asString36).
	directory ensureCreateDirectory.
	[
	texts := (1 to: 2000) collect: [ :i |
		         String streamContents: [ :out | (random nextInteger: 40) timesRepeat: [ out nextPut: ('ab,,"" ' , String crlf , String lf at: (random nextInteger: 10)) ] ] ].
	directory / 'in.txt' writeStreamDo: [ :out |
		texts do: [ :text |
			text do: [ :each | out print: each asInteger; space ].
			out lf ] ].
	directory / 'read.py' writeStreamDo: [ :out |
		out nextPutAll: 'import csv, io, sys
for line in open(sys.argv[1], newline="\n"):
    text = "".join(chr(int(c)) for c in line.split())
    print(" ".join(",".join("".join("%02x" % ord(c) for c in f) for f in row) + ";" for row in csv.reader(io.StringIO(text, newline=""))))
' ].
	(Smalltalk at: #LibC) runCommand: 'python3 -I ' , (directory / 'read.py') fullName , ' ' , (directory / 'in.txt') fullName , ' > ' , (directory / 'out.txt') fullName.
	expected := (directory / 'out.txt') contents lines.
	self assert: expected size equals: texts size.
	texts with: expected do: [ :text :line |
		rows := self read: text.
		self
			assert: (String streamContents: [ :out |
					 rows
						 do: [ :row |
							 row
								 do: [ :field | (field ifNil: [ '' ]) do: [ :each | out nextPutAll: (each asInteger printPaddedWith: $0 to: 2 base: 16) asLowercase ] ]
								 separatedBy: [ out nextPut: $, ].
							 out nextPut: $; ]
						 separatedBy: [ out space ] ])
			equals: line ] ] ensure: [ directory ensureDeleteAll ]
]
