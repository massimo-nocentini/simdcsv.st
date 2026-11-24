"
I test `SimdCSVWriter`: the text of each kind of field, the three field writers, the declared fields, and that what was written reads back.
"
Class {
	#name : 'SimdCSVWriterTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SimdCSVWriterTest >> write: rows with: aBlock [
	"aBlock configures the writer"

	^ String streamContents: [ :stream |
		  | writer |
		  writer := SimdCSVWriter on: stream.
		  aBlock value: writer.
		  writer nextPutAll: rows ]
]

{ #category : 'tests' }
SimdCSVWriterTest >> testQuoted [
	self assert: (SimdCSV stringFrom: #( #( 'a' 'b,c' ) #( 'd"e' '' ) )) equals: (self lines: #( '"a","b,c"' '"d""e",""' )).
	self assert: (SimdCSV stringFrom: { { 1. nil. #x. $y } }) equals: (self lines: #( '"1",,"x","y"' )).
	self assert: (SimdCSV stringFrom: #(  )) equals: ''.
	self assert: (String streamContents: [ :stream | SimdCSV write: #( #( 1 ) ) to: stream ]) equals: (self lines: #( '"1"' ))
]

{ #category : 'tests' }
SimdCSVWriterTest >> testOptionalQuoted [
	self
		assert: (self write: { { 'a'. 'b,c'. 'd"e'. ''. nil. ' f '. 'g' , String lf. String cr } } with: [ :writer | writer fieldWriter: #optionalQuoted ])
		equals: 'a,"b,c","d""e","",, f ,"g' , String lf , '","' , String cr , '"' , String lf.
	self assert: (self write: #( #( 'a,b' 'c;d' ) ) with: [ :writer | writer fieldWriter: #optionalQuoted; separator: $; ]) equals: (self lines: #( 'a,b;"c;d"' )).
	self assert: (self write: #( #( 'a"' 'b''' ) ) with: [ :writer | writer fieldWriter: #optionalQuoted; quote: $' ]) equals: (self lines: #( 'a",''b''''''' ))
]

{ #category : 'tests' }
SimdCSVWriterTest >> testRaw [
	| raw |
	raw := [ :writer | writer fieldWriter: #raw ].
	self assert: (self write: { { 'a'. nil. 'b"c'. 7 } } with: raw) equals: (self lines: #( 'a,,b"c,7' )).
	{ 'a,b'. '"a'. ''. 'a' , String lf. String cr } do: [ :each |
		self assert: [ self write: { { 'x'. each } } with: raw ] signals: SimdCSVArgumentError ].
	self assert: [ self write: { { 'b"c' } } with: [ :writer | writer dialect: (SimdCSVDialect comma strictQuoting: true; yourself); fieldWriter: #raw ] ] signals: SimdCSVArgumentError.
	self assert: (self write: { { 'a,b'. '' } } with: [ :writer | writer fieldWriter: #raw; beUnchecked ]) equals: (self lines: #( 'a,b,' )).
	self assert: (self write: { { String cr } } with: [ :writer | writer dialect: (SimdCSVDialect comma lineEnd: #lf; yourself); fieldWriter: #raw ]) equals: String crlf
]

{ #category : 'tests' }
SimdCSVWriterTest >> testWithoutQuote [
	self assert: (self write: #( #( 'a' 'b"' ) ) with: [ :writer | writer quote: nil ]) equals: (self lines: #( 'a,b"' )).
	self assert: (self write: #( #( '"a' ) ) with: [ :writer | writer quote: nil; fieldWriter: #raw ]) equals: (self lines: #( '"a' )).
	self assert: (self write: { { nil } } with: [ :writer | writer quote: nil ]) equals: String lf.
	#( #quoted #optionalQuoted ) do: [ :each |
		self assert: [ self write: #( #( 'a' ) ) with: [ :writer | writer quote: nil; fieldWriter: each ] ] signals: SimdCSVArgumentError ]
]

{ #category : 'tests' }
SimdCSVWriterTest >> testBadArguments [
	self assert: [ self write: #(  ) with: [ :writer | writer fieldWriter: #object ] ] signals: SimdCSVArgumentError.
	self assert: [ self write: #(  ) with: [ :writer | writer lineEndConvention: #any ] ] signals: SimdCSVArgumentError.
	self assert: [ self write: #( #( 'a' ) ) with: [ :writer | writer separator: $" ] ] signals: SimdCSVArgumentError.
	self assert: [ self write: #( #( 'a' ) ) with: [ :writer | writer separator: Character cr ] ] signals: SimdCSVArgumentError.
	self assert: [ self write: #( #( 'a' ) ) with: [ :writer | writer dialect: (SimdCSVDialect comma lineEnd: #lf; yourself); lineEndConvention: #crlf ] ] signals: SimdCSVArgumentError
]

{ #category : 'tests' }
SimdCSVWriterTest >> testRecordsOfNoField [
	| text |
	self assert: [ SimdCSV stringFrom: #( #(  ) ) ] signals: SimdCSVArgumentError.
	text := String streamContents: [ :stream |
		        | writer |
		        writer := SimdCSVWriter on: stream.
		        writer nextPut: #( 'a' ).
		        self assert: [ writer nextPut: #(  ) ] signals: SimdCSVArgumentError.
		        writer fieldWriter: #raw.
		        self assert: [ writer nextPut: #( 'b' ',' ) ] signals: SimdCSVArgumentError.
		        writer nextPut: #( 'c' ) ].
	self assert: text equals: (self lines: #( '"a"' 'c' ))
]

{ #category : 'tests' }
SimdCSVWriterTest >> testOnlyEmptyField [
	self assert: (SimdCSV stringFrom: { { nil } }) equals: (self lines: #( '""' )).
	self assert: (self write: { { nil } } with: [ :writer | writer fieldWriter: #raw ]) equals: (self lines: #( '""' )).
	self assert: (self write: { { nil }. { '' } } with: [ :writer | writer dialect: (SimdCSVDialect comma keepQuotedEmpty: true; yourself) ]) equals: (self lines: #( '' '""' )).
	self assert: [ self write: { { nil } } with: [ :writer | writer dialect: (SimdCSVDialect comma keepQuotedEmpty: true; skipEmptyLines: true; yourself) ] ] signals: SimdCSVArgumentError
]

{ #category : 'tests' }
SimdCSVWriterTest >> testNumbers [
	self
		assert: (self write: { { 1. -2. 1.5. 1 / 4. 3.14s2. -2.50s3. Float nan. Float infinity. Float infinity negated. 100 factorial // 98 factorial } } with: [ :writer | writer fieldWriter: #optionalQuoted ])
		equals: (self lines: #( '1,-2,1.5,0.25,3.14,-2.500,nan,inf,-inf,9900' ))
]

{ #category : 'tests' }
SimdCSVWriterTest >> testFloatsReadBack [
	"The shortest text of a Float is read as the same Float"

	| random floats rows |
	random := self random.
	floats := { 0.1. 5.0e-324. 1.7976931348623157e308. 2.2250738585072014e-308. 1.0e23. 9007199254740993.0. 123456789012345680.0. -0.0. 1.0e-5. 1.0e100. 4.35. 0.3. 2.5e-8 } asOrderedCollection.
	(self largeSize: 3000) timesRepeat: [
		floats add: (random next - 0.5) * (10.0 raisedTo: (random nextInteger: 600) - 300).
		floats add: (random nextInteger: 100000) / 1000.0 ].
	floats := floats select: [ :each | each isFinite ].
	rows := (self reader: (SimdCSV stringFrom: (floats collect: [ :each | { each } ]))) addFloatField; upToEnd.
	self assert: rows size equals: floats size.
	rows with: floats do: [ :row :float |
		self assert: row first equals: float.
		self assert: row first printString equals: float printString ]
]

{ #category : 'tests' }
SimdCSVWriterTest >> testIntegersReadBack [
	| integers rows |
	integers := { 0. -1. 999999999999999999. 1000000000000000000. SmallInteger maxVal. SmallInteger minVal. 100 factorial. 100 factorial negated }.
	rows := (self reader: (SimdCSV stringFrom: (integers collect: [ :each | { each } ]))) addIntegerField; upToEnd.
	self assert: (rows collect: [ :row | row first ]) equals: integers
]

{ #category : 'tests' }
SimdCSVWriterTest >> testEmptyFieldValue [
	self assert: (self write: { { nil. #none. '' } } with: [ :writer | writer emptyFieldValue: #none ]) equals: (self lines: #( '"nil",,""' )).
	self assert: (self write: { { ''. 'a' } } with: [ :writer | writer emptyFieldValue: '' ]) equals: (self lines: #( ',"a"' ))
]

{ #category : 'tests' }
SimdCSVWriterTest >> testFields [
	| records |
	records := { (SimdCSVTestRecord x: 1 y: 'a' z: nil). (SimdCSVTestRecord x: 2 y: 'b,c' z: 2.5) }.
	self
		assert: (self write: records with: [ :writer |
				 writer
					 fieldWriter: #optionalQuoted;
					 writeHeader: #( #x 'y,' 'z' 'c' 'e' 'x2' );
					 addField: #x;
					 addFields: #( #y #z );
					 addConstantField: 'k';
					 addEmptyField;
					 addField: [ :each | each x * 2 ] ])
		equals: (self lines: #( 'x,"y,",z,c,e,x2' '1,a,,k,,2' '2,"b,c",2.5,k,,4' ))
]

{ #category : 'tests' }
SimdCSVWriterTest >> testNamedColumns [
	self
		assert: (self write: { ({ (#a -> 1). (#b -> 2) } asDictionary). ({ (#b -> 3) } asDictionary) } with: [ :writer | writer namedColumnsConfiguration: #( #a #b ) ])
		equals: (self lines: #( '"a","b"' '"1","2"' ',"3"' )).
	self assert: (self write: { ({ (#a -> 1) } asDictionary) } with: [ :writer | writer addFieldAt: #a; addFieldsAt: #( #b #a ) ]) equals: (self lines: #( '"1",,"1"' ))
]

{ #category : 'tests' }
SimdCSVWriterTest >> testLineEnds [
	self assert: (self write: #( #( 'a' ) ) with: [ :writer | writer lineEndConvention: #crlf ]) equals: '"a"' , String crlf.
	self assert: (self write: #( #( 'a' ) ) with: [ :writer | writer lineEndConvention: #cr ]) equals: '"a"' , String cr.
	self assert: (self write: #( #( 'a' ) ) with: [ :writer | writer lineEndConvention: #lf ]) equals: '"a"' , String lf
]

{ #category : 'tests' }
SimdCSVWriterTest >> testBinaryStream [
	| text wide |
	text := 'é' , (String with: (Character codePoint: 945)) , (String with: (Character codePoint: 16r1F600)).
	wide := { { text. 'b' }. { 'c'. nil } }.
	self assert: (SimdCSV bytesFrom: wide) equals: (SimdCSV stringFrom: wide) utf8Encoded.
	self assert: (self read: (SimdCSV bytesFrom: wide)) equals: wide.
	self assert: (self read: (SimdCSV stringFrom: wide)) equals: wide.
	self assert: (SimdCSV bytesFrom: #( #( 'é' ) ) dialect: (SimdCSVDialect comma encoding: #latin1; yourself)) equals: #[ 34 233 34 10 ].
	self assert: [ SimdCSV bytesFrom: wide dialect: (SimdCSVDialect comma encoding: #latin1; yourself) ] signals: SimdCSVArgumentError.
	self assert: [ SimdCSV bytesFrom: { { (String with: (Character codePoint: 256)) } } dialect: (SimdCSVDialect comma encoding: #latin1; yourself) ] signals: SimdCSVArgumentError
]

{ #category : 'tests' }
SimdCSVWriterTest >> testNarrowAfterWide [
	"The text of a record does not depend on the one before it"

	| parts |
	parts := OrderedCollection new.
	(SimdCSVWriter on: (SimdCSVTestWriteStream on: parts))
		nextPut: { (String with: (Character codePoint: 945)) };
		nextPut: #( 'a' ).
	self assert: parts last equals: (self lines: #( '"a"' )).
	self assert: parts last class equals: ByteString
]

{ #category : 'tests' }
SimdCSVWriterTest >> testWrittenAtOnce [
	"A record is written when nextPut: answers, in one piece; flush and close go to the stream"

	| parts stream writer |
	parts := OrderedCollection new.
	stream := SimdCSVTestWriteStream on: parts.
	writer := SimdCSVWriter on: stream.
	writer nextPut: #( 'a' 'b' ).
	self assert: parts asArray equals: { (self lines: #( '"a","b"' )) }.
	writer
		flush;
		close;
		close.
	self assert: stream calls asArray equals: #( #flush #close )
]

{ #category : 'tests' }
SimdCSVWriterTest >> testByteOrderMark [
	"A text that begins as a byte order mark does is quoted at the start of the output only"

	| mark rows |
	mark := String with: (Character codePoint: 16rFEFF).
	rows := { { mark , 'a'. mark }. { mark } }.
	self assert: (self write: rows with: [ :writer | writer fieldWriter: #optionalQuoted ]) equals: '"' , mark , 'a",' , mark , String lf , mark , String lf.
	self assert: [ self write: rows with: [ :writer | writer fieldWriter: #raw ] ] signals: SimdCSVArgumentError.
	#( #quoted #optionalQuoted ) do: [ :kind |
		| text |
		text := self write: rows with: [ :writer | writer fieldWriter: kind ].
		self assert: (self read: text) equals: rows.
		self assert: (self read: text utf8Encoded) equals: rows ].
	self assert: (self read: (SimdCSV stringFrom: { { mark } })) equals: { { mark } }
]

{ #category : 'helpers' }
SimdCSVWriterTest >> randomText: random [
	| alphabet |
	alphabet := 'ab,;"'' ' , String crlf , (String withAll: { Character tab. (Character codePoint: 233). (Character codePoint: 945). (Character codePoint: 16rFEFF). (Character codePoint: 0). (Character codePoint: 16r10FFFF) }).
	^ String new: (random nextInteger: 5) streamContents: [ :out | (random nextInteger: 5) timesRepeat: [ out nextPut: (alphabet at: (random nextInteger: alphabet size)) ] ]
]

{ #category : 'helpers' }
SimdCSVWriterTest >> randomRows: random empty: aBoolean [
	^ ((1 to: (random nextInteger: 5)) collect: [ :i |
		   ((1 to: (random nextInteger: 4)) collect: [ :k |
			    (random nextInteger: 4) caseOf: {
					    ([ 1 ] -> [ nil ]).
					    ([ 2 ] -> [
						    aBoolean
							    ifTrue: [ '' ]
							    ifFalse: [ 'x' ] ]) } otherwise: [ self randomText: random ] ]) asArray ]) asArray
]

{ #category : 'tests' }
SimdCSVWriterTest >> testRoundTrip [
	"With every dialect that quotes"

	| random |
	random := self random.
	(self largeSize: 1500) timesRepeat: [
		| dialect rows end kind string |
		dialect := SimdCSVDialect new.
		dialect
			separator: ({ $,. $;. Character tab } at: (random nextInteger: 3));
			quote: ({ $". $' } at: (random nextInteger: 2));
			lineEnd: (#( #any #lf ) at: (random nextInteger: 2));
			strictQuoting: (random nextInteger: 2) = 1;
			keepQuotedEmpty: (random nextInteger: 2) = 1;
			skipEmptyLines: (random nextInteger: 2) = 1.
		rows := self randomRows: random empty: dialect keepQuotedEmpty.
		(dialect keepQuotedEmpty and: [ dialect skipEmptyLines ]) ifTrue: [ rows := rows reject: [ :row | row = { nil } ] ].
		end := dialect lineEnd == #lf
			       ifTrue: [ #lf ]
			       ifFalse: [ #( #lf #crlf #cr ) at: (random nextInteger: 3) ].
		kind := #( #quoted #optionalQuoted ) at: (random nextInteger: 2).
		string := self write: rows with: [ :writer | writer dialect: dialect; lineEndConvention: end; fieldWriter: kind ].
		self assert: (SimdCSV rowsFrom: string dialect: dialect) equals: rows.
		self assert: (SimdCSV rowsFrom: string utf8Encoded dialect: dialect) equals: rows.
		self
			assert: (ByteArray streamContents: [ :stream |
					 (SimdCSVWriter on: stream)
						 dialect: dialect;
						 lineEndConvention: end;
						 fieldWriter: kind;
						 nextPutAll: rows ])
			equals: string utf8Encoded ]
]

{ #category : 'tests' }
SimdCSVWriterTest >> testRoundTripLatin1 [
	| dialect rows |
	dialect := SimdCSVDialect comma encoding: #latin1; yourself.
	rows := { (String withAll: ((0 to: 255) collect: [ :each | Character value: each ])). (String withAll: (#( 239 187 191 ) collect: [ :each | Character value: each ])) } collect: [ :each | { each. nil } ].
	self assert: (SimdCSV rowsFrom: (SimdCSV bytesFrom: rows dialect: dialect) dialect: dialect) equals: rows.
	rows := rows reversed.
	self assert: (SimdCSV rowsFrom: (SimdCSV bytesFrom: rows dialect: dialect) dialect: dialect) equals: rows
]

{ #category : 'tests' }
SimdCSVWriterTest >> testRawReadsBack [
	"What #raw does not refuse reads back"

	| random written |
	random := self random.
	written := 0.
	(self largeSize: 1500) timesRepeat: [
		| dialect rows string |
		dialect := SimdCSVDialect new.
		dialect
			quote: ({ $". nil } at: (random nextInteger: 2));
			lineEnd: (#( #any #lf ) at: (random nextInteger: 2));
			strictQuoting: (random nextInteger: 2) = 1;
			skipEmptyLines: (random nextInteger: 2) = 1.
		rows := { { (self randomText: random) } , (Array new: (random nextInteger: 2) - 1) }.
		string := [ self write: rows with: [ :writer | writer dialect: dialect; fieldWriter: #raw ] ]
			          on: SimdCSVArgumentError
			          do: [ nil ].
		string ifNotNil: [
			written := written + 1.
			self assert: (SimdCSV rowsFrom: string dialect: dialect) equals: rows.
			self assert: (SimdCSV rowsFrom: string utf8Encoded dialect: dialect) equals: rows ] ].
	self assert: written > 100
]
