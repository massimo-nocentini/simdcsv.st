"
I test the messages of `SimdCSVReader`: sources, fields, columns by name, types, converters, header and enumeration.
"
Class {
	#name : 'SimdCSVReaderTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testEverySource [
	self
		assertSourcesOf: (self lines: #( 'a,b' '1,"x,y"' ',"z""z"' ))
		read: [ :reader | reader upToEnd ]
		equals: { #( 'a' 'b' ). #( '1' 'x,y' ). { nil. 'z"z' } }
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testEverySourceWithWideCharacters [
	| alpha snowman |
	alpha := String with: (Character codePoint: 945) with: $a.
	snowman := String with: (Character codePoint: 16r1F600).
	self
		assertSourcesOf: (self lines: { 'é,' , alpha. '"' , snowman , '",ü' })
		read: [ :reader | reader upToEnd ]
		equals: { { 'é'. alpha }. { snowman. 'ü' } }
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testNarrowestClass [
	self sourcesOf: 'a,é,' , (String with: (Character codePoint: 945)) do: [ :source :name |
		| row |
		row := (self reader: source) next.
		self assert: (row collect: [ :each | each class ]) equals: { ByteString. ByteString. WideString } ]
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testSymbolSource [
	self assert: (self read: #'a,b') equals: #( #( 'a' 'b' ) ).
	self assert: (self read: #'a,b') first first class equals: ByteString
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testPositionedReadStream [
	| stream |
	stream := 'xx,a,b' readStream.
	stream skip: 3.
	self assert: (self read: stream) equals: #( #( 'a' 'b' ) ).
	self assert: (self read: (ReadStream on: 'abcdef' from: 2 to: 4)) equals: #( #( 'bcd' ) ).
	stream := #[ 97 44 98 10 99 ] readStream.
	stream next.
	self assert: (self read: stream) equals: { { nil. 'b' }. { 'c' } }
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testReadStreamOnOtherCollections [
	self assert: (self read: #( $a $, $b ) readStream) equals: #( #( 'a' 'b' ) ).
	self assert: (self read: 'a,b' asSymbol readStream) equals: #( #( 'a' 'b' ) )
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testBadSources [
	self assert: [ (self reader: 3) next ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: #( 1 2 )) next ] signals: SimdCSVArgumentError
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testLatin1 [
	| bytes |
	bytes := #[ 233 44 128 44 255 ].
	self assert: ((self reader: bytes) encoding: #latin1; upToEnd) equals: { { (String with: (Character value: 233)). (String with: (Character value: 128)). (String with: (Character value: 255)) } }.
	self assert: [ (self reader: bytes) upToEnd ] signals: SimdCSVInvalidEncoding.
	self assert: [ (self reader: bytes) encoding: #utf16 ] signals: SimdCSVArgumentError
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testLatin1OfZincStream [
	"The bytes of a stream that decodes UTF-8 are not those of Latin-1: the characters are read"

	| stream |
	stream := ZnCharacterReadStream on: 'é,b' utf8Encoded readStream.
	self assert: ((self reader: stream) encoding: #latin1; upToEnd) equals: #( #( 'é' 'b' ) )
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testEncodingAfterFirstRecord [
	| reader |
	reader := self reader: (self lines: #( 'a' 'b' )).
	reader next.
	self assert: [ reader encoding: #latin1 ] signals: SimdCSVArgumentError.
	reader encoding: #utf8.
	self assert: reader next equals: #( 'b' )
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testClose [
	| stream reader |
	stream := SimdCSVTestStream on: 'a,b' asByteArray.
	self assert: (SimdCSVReader on: stream do: [ :each | each next ]) equals: #( 'a' 'b' ).
	self assert: stream isClosed.
	reader := self reader: (stream := SimdCSVTestStream on: (self lines: #( 'a' 'b' ))).
	reader next.
	reader close.
	self assert: stream isClosed.
	self assert: reader atEnd.
	self assert: reader recordNumber equals: 1.
	self assert: reader next isNil.
	self assert: reader upToEnd equals: #(  ).
	reader := self reader: (stream := SimdCSVTestStream on: 'a').
	reader close.
	self assert: stream isClosed.
	(self reader: 'a') close
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testCloseOfZincStream [
	| inner |
	inner := SimdCSVTestStream on: 'a,b' asByteArray.
	SimdCSVReader on: (ZnCharacterReadStream on: inner) do: [ :reader | reader next ].
	self assert: inner isClosed
]

{ #category : 'tests - sources' }
SimdCSVReaderTest >> testFileIsClosedAtEnd [
	| file reader |
	file := FileReference newTempFilePrefix: 'simdcsv' suffix: '.csv'.
	[
	file writeStreamDo: [ :stream | stream nextPutAll: (self lines: #( 'a,b' 'c,d' )) ].
	reader := self reader: file.
	self assert: reader upToEnd equals: #( #( 'a' 'b' ) #( 'c' 'd' ) ).
	reader close ] ensure: [ file ensureDelete ]
]

{ #category : 'tests - reading' }
SimdCSVReaderTest >> testNextAndAtEnd [
	| reader |
	reader := self reader: (self lines: #( 'a' 'b' )).
	self assert: reader recordNumber equals: 0.
	self deny: reader atEnd.
	self assert: reader recordNumber equals: 0.
	self assert: reader next equals: #( 'a' ).
	self assert: reader recordNumber equals: 1.
	self assert: reader next equals: #( 'b' ).
	self assert: reader recordNumber equals: 2.
	self assert: reader atEnd.
	self assert: reader next isNil.
	self assert: reader recordNumber equals: 2
]

{ #category : 'tests - reading' }
SimdCSVReaderTest >> testSkip [
	| reader |
	reader := self reader: (self lines: #( 'A,1' 'B,2' 'C,3' 'D,4' 'E,5' 'F,6' )).
	reader skip.
	self assert: reader next equals: #( 'B' '2' ).
	reader skip: 2.
	self assert: reader next equals: #( 'E' '5' ).
	reader skip.
	self assert: reader atEnd.
	reader skip.
	self assert: reader atEnd.
	self assert: reader recordNumber equals: 6
]

{ #category : 'tests - reading' }
SimdCSVReaderTest >> testSkipDoesNotFixTheWidth [
	| reader |
	reader := self reader: (self lines: #( 'a' 'b,c' 'd,e' 'f' )).
	reader beStrict.
	reader skip.
	self assert: reader next equals: #( 'b' 'c' ).
	self assert: reader next equals: #( 'd' 'e' ).
	self assert: [ reader next ] signals: SimdCSVFieldCountMismatch.
	reader skip.
	self assert: reader atEnd
]

{ #category : 'tests - reading' }
SimdCSVReaderTest >> testEnumeration [
	| text even |
	text := self lines: ((1 to: 10) collect: [ :each | each printString ]).
	even := [ :row | row first asInteger even ].
	self assert: ((self reader: text) collect: [ :row | row first asInteger ]) equals: (1 to: 10) asArray.
	self assert: ((self reader: text) select: even) equals: #( #( '2' ) #( '4' ) #( '6' ) #( '8' ) #( '10' ) ).
	self assert: ((self reader: text) reject: even) equals: #( #( '1' ) #( '3' ) #( '5' ) #( '7' ) #( '9' ) ).
	self assert: (Array streamContents: [ :out | (self reader: text) select: even thenDo: [ :row | out nextPut: row first ] ]) equals: #( '2' '4' '6' '8' '10' ).
	self assert: (Array streamContents: [ :out | (self reader: text) reject: even thenDo: [ :row | out nextPut: row first ] ]) equals: #( '1' '3' '5' '7' '9' ).
	self assert: (Array streamContents: [ :out | (self reader: text) do: [ :row | out nextPut: row first ] ]) equals: ((1 to: 10) collect: [ :each | each printString ]) asArray
]

{ #category : 'tests - reading' }
SimdCSVReaderTest >> testUpToEndOverSeveralBatches [
	"More records than a batch of rows"

	| text rows |
	text := self lines: ((1 to: 9001) collect: [ :each | each printString , ',' , (each * 7) printString ]).
	rows := self read: text.
	self assert: rows size equals: 9001.
	rows withIndexDo: [ :row :i | self assert: row equals: { i printString. (i * 7) printString } ].
	self assert: ((self reader: text) addIntegerField; addIntegerField; upToEnd) last equals: #( 9001 63007 ).
	self assert: ((self reader: text) batchBytes: 100; upToEnd) equals: rows
]

{ #category : 'tests - reading' }
SimdCSVReaderTest >> testRowsAreNotShared [
	| rows |
	rows := self read: (self lines: #( 'a,a' 'a,a' )).
	self deny: (rows first at: 1) == (rows first at: 2).
	self deny: rows first == rows last
]

{ #category : 'tests - dialect' }
SimdCSVReaderTest >> testSeparatorAndQuote [
	self assert: ((self reader: '1;"2;2";3') separator: $;; upToEnd) equals: #( #( '1' '2;2' '3' ) ).
	self assert: ((self reader: '1	2	3') separator: Character tab; upToEnd) equals: #( #( '1' '2' '3' ) ).
	self assert: ((self reader: '''a,''''b'',c') quote: $'; upToEnd) equals: #( #( 'a,''b' 'c' ) ).
	self assert: ((self reader: '"a,b"') quote: nil; upToEnd) equals: #( #( '"a' 'b"' ) ).
	self assert: [ (self reader: 'a') separator: $"; next ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: 'a') separator: 3 ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: 'a') separator: Character lf; next ] signals: SimdCSVArgumentError
]

{ #category : 'tests - dialect' }
SimdCSVReaderTest >> testDialectIsCopied [
	| dialect reader |
	dialect := SimdCSVDialect semicolon.
	reader := self reader: 'a;b'.
	reader dialect: dialect.
	dialect separator: $,.
	self assert: reader next equals: #( 'a' 'b' ).
	reader dialect separator: $,.
	self assert: reader dialect separator equals: $;
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testTypedFields [
	self
		assertSourcesOf: (self lines: #( '100,2.5,foo' '-1,1e3,"b,ar"' ',,' ))
		read: [ :reader | reader addIntegerField; addFloatField; addField; upToEnd ]
		equals: { { 100. 2.5. 'foo' }. { -1. 1000.0. 'b,ar' }. { nil. nil. nil } }
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testIndexableFields [
	self assert: ((self reader: '1,2.5,x,s,3,4.5,"1,5",y') addIntegerFields: 1; addFloatFields: 1; addPlainFields: 1; addSymbolFields: 1; addIgnoredFields: 2; addFloatFieldRadixPointComma; addFieldConverter: [ :each | each asUppercase ]; upToEnd) equals: #( #( 1 2.5 'x' #s 1.5 'Y' ) ).
	self assert: ((self reader: '1,2,3') addPlainField; addIgnoredField; addSymbolField; next) equals: #( '1' #'3' )
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testAccessors [
	| expected |
	expected := { SimdCSVTestRecord x: 1 y: 2.5 z: 'foo' }.
	self assert: ((self reader: '1,2.5,foo') recordClass: SimdCSVTestRecord; addIntegerField: #x:; addFloatField: #y:; addField: #z:; upToEnd) equals: expected.
	self assert: ((self reader: '1,9,2.5,foo') recordClass: SimdCSVTestRecord; addIntegerField: [ :record :value | record x: value ]; addIgnoredField; addFloatField: [ :record :value | record y: value ]; addField: [ :record :value | record z: value ]; upToEnd) equals: expected.
	self assert: ((self reader: 'a,b') recordClass: SimdCSVTestRecord; addFields: #( #x: #y: ); upToEnd) equals: { SimdCSVTestRecord x: 'a' y: 'b' z: nil }.
	self assert: ((self reader: '"1,5",b,c') recordClass: SimdCSVTestRecord; addFloatFieldRadixPointComma: #x:; addSymbolField: #y:; addField: #z: converter: [ :each | each asUppercase ]; upToEnd) equals: { SimdCSVTestRecord x: 1.5 y: #b z: 'C' }
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testKeys [
	| rows |
	rows := (self reader: '1,2.5,x,s,"1,5",y') recordClass: Dictionary; addIntegerFieldAt: #a; addFloatFieldAt: #b; addFieldAt: #c; addSymbolFieldAt: #d; addFloatFieldRadixPointCommaAt: #e; addFieldAt: #f converter: [ :each | each asUppercase ]; upToEnd.
	self assert: rows equals: { ({ (#a -> 1). (#b -> 2.5). (#c -> 'x'). (#d -> #s). (#e -> 1.5). (#f -> 'Y') } asDictionary) }.
	self assert: ((self reader: 'a,b') recordClass: Dictionary; addFieldsAt: #( #x #y ); upToEnd) equals: { ({ (#x -> 'a'). (#y -> 'b') } asDictionary) }
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testEmptyFieldsAreNotGiven [
	"Neither to accessors nor to converters"

	| rows calls |
	calls := 0.
	rows := (self reader: (self lines: #( ',,' '1,,3' ',"",4,9' '5' ))) recordClass: Dictionary; addIntegerFieldAt: #x; addFieldAt: #y converter: [ :each | calls := calls + 1 ]; addFieldAt: #z; upToEnd.
	self assert: rows equals: { Dictionary new. ({ (#x -> 1). (#z -> '3') } asDictionary). ({ (#z -> '4') } asDictionary). ({ (#x -> 5) } asDictionary) }.
	self assert: calls equals: 0.
	rows := (self reader: '1,,3') emptyFieldValue: #empty; recordClass: SimdCSVTestRecord; addIntegerField: #x:; addIntegerField: #y:; addIntegerField: #z:; upToEnd.
	self assert: rows equals: { SimdCSVTestRecord x: 1 y: nil z: 3 }
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testEmptyFieldValue [
	self assert: ((self reader: '"1",,3,"","5"') emptyFieldValue: #empty; upToEnd) equals: #( #( '1' #empty '3' #empty '5' ) ).
	self assert: ((self reader: '"1",,3,"","5"') emptyFieldValue: ''; upToEnd) equals: #( #( '1' '' '3' '' '5' ) ).
	self assert: ((self reader: ',2,') emptyFieldValue: 0; addIntegerField; addIntegerField; addIntegerField; addIntegerField; upToEnd) equals: #( #( 0 2 0 0 ) ).
	self assert: ((self reader: ',2,z') emptyFieldValue: ''; addIntegerField; addIntegerField; addFieldConverter: [ :each | each asUppercase ]; addFieldConverter: [ :each | each asUppercase ]; upToEnd) equals: #( #( '' 2 'Z' '' ) )
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testEmptyFieldValueEqualToAValue [
	"0 is the value of an empty field here, and a value of another one"

	self assert: ((self reader: ',0') emptyFieldValue: 0; recordClass: Dictionary; addIntegerFieldAt: #x; addIntegerFieldAt: #y; next) equals: ({ (#y -> 0) } asDictionary)
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testPassNil [
	| text |
	text := self lines: #( '1,' ',2' ).
	self assert: ((self reader: text) emptyFieldValue: #passNil; addFieldConverter: [ :each | each ifNil: [ 'none' ] ]; addField; upToEnd) equals: { { '1'. nil }. { 'none'. '2' } }.
	self assert: ((self reader: text) emptyFieldValue: #passNil; recordClass: Dictionary; addFieldAt: #x converter: [ :each | each ifNil: [ 'none' ] ]; addIntegerFieldAt: #y; addSymbolFieldAt: #z; upToEnd) equals: { ({ (#x -> '1'). (#y -> nil). (#z -> nil) } asDictionary). ({ (#x -> 'none'). (#y -> 2). (#z -> nil) } asDictionary) }.
	self assert: (self read: ',a') equals: { { nil. 'a' } }.
	self assert: ((self reader: ',a') emptyFieldValue: #passNil; upToEnd) equals: #( #( #passNil 'a' ) )
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testRecordClass [
	self assert: ((self reader: '1,2,3') recordClass: ByteArray; addIntegerFields: 3; upToEnd) equals: { #[ 1 2 3 ] }.
	self assert: ((self reader: '1,2') recordClass: OrderedCollection; upToEnd) equals: { (OrderedCollection with: '1' with: '2') }.
	self assert: ((self reader: '1,2') recordClass: OrderedCollection; addField; addIntegerField; next) equals: (OrderedCollection with: '1' with: 2)
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testFieldCount [
	self assert: ((self reader: (self lines: #( 'a' 'b,c,d' ))) fieldCount: 2; upToEnd) equals: { { 'a'. nil }. { 'b'. 'c' } }.
	self assert: [ (self reader: 'a') fieldCount: 0 ] signals: SimdCSVArgumentError.
	self assert: ((self reader: 'a') fieldCount: 2; fieldCount: nil; next) equals: #( 'a' )
]

{ #category : 'tests - fields' }
SimdCSVReaderTest >> testFieldsThatDoNotFit [
	self assert: [ (self reader: 'a') recordClassIsIndexable: false; next ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: 'a,b') addField: #x:; addField; next ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: 'a,b') addField; addField: #x:; next ] signals: SimdCSVArgumentError
]

{ #category : 'tests - types' }
SimdCSVReaderTest >> testOddIntegers [
	| big |
	big := '123456789012345678901234567890'.
	self assert: ((self reader: (self lines: { big. '7'. '-' , big. ' 8 '. '000000000000000000000000009' })) addIntegerField; upToEnd) equals: { { 123456789012345678901234567890 }. { 7 }. { -123456789012345678901234567890 }. { 8 }. { 9 } }
]

{ #category : 'tests - types' }
SimdCSVReaderTest >> testOddFloats [
	self assert: ((self reader: (self lines: #( '0.1234567890123456789' '5e-324' '1e400' '1' '.5' '-0' ))) addFloatField; upToEnd) equals: { { 0.12345678901234568 }. { 5.0e-324 }. { Float infinity }. { 1.0 }. { 0.5 }. { -0.0 } }.
	self assert: ((self reader: '1') addFloatField; next) first class equals: 1.0 class
]

{ #category : 'tests - types' }
SimdCSVReaderTest >> testSpecialFloats [
	| row |
	row := (self reader: 'nan,NaN,inf,+inf,-inf,Infinity, -INFINITY ') addFloatFields: 7; next.
	self assert: (row at: 1) isNaN.
	self assert: (row at: 2) isNaN.
	self assert: (row allButFirst: 2) equals: { Float infinity. Float infinity. Float infinity negated. Float infinity. Float infinity negated }.
	#( 'infinit' '+nan' '+' ' ' 'in' ) do: [ :text | self assert: [ (self reader: text) addFloatField; next ] signals: SimdCSVConversionError ].
	self assert: [ (self reader: 'nan') addIntegerField; next ] signals: SimdCSVConversionError
]

{ #category : 'tests - types' }
SimdCSVReaderTest >> testNullTexts [
	| text |
	text := self lines: #( 'NA,NA,NA' '1,-,x' '"NA",2,"NA"' ).
	self assert: ((self reader: text) nullTexts: #( 'NA' '-' ); addIntegerField; addFloatField; addField; upToEnd) equals: { { nil. nil. 'NA' }. { 1. nil. 'x' }. { nil. 2.0. 'NA' } }.
	self assert: ((self reader: text) nullTexts: #( 'NA' '-' ); emptyFieldValue: #none; addIntegerField; addFieldConverter: [ :each | each ]; addSymbolField; upToEnd) equals: #( #( #none #none #none ) #( 1 #none #x ) #( #none '2' #none ) ).
	self assert: ((self reader: text) nullTexts: #( 'NA' ); recordClass: Dictionary; addIntegerFieldAt: #x; addField: [ :record :value | record at: #y put: value ] converter: [ :each | each ]; addIgnoredField; upToEnd) equals: { Dictionary new. ({ (#x -> 1). (#y -> '-') } asDictionary). ({ (#y -> '2') } asDictionary) }
]

{ #category : 'tests - types' }
SimdCSVReaderTest >> testIfInvalid [
	| calls |
	calls := OrderedCollection new.
	self assert: ((self reader: (self lines: #( '1,a' 'x,2' 'y,3' ))) ifInvalid: [ :text :record :field |
			 calls add: {
					 text.
					 record.
					 field }.
			 -1 ]; addIntegerField; addFloatField; upToEnd) equals: { { 1. -1 }. { -1. 2.0 }. { -1. 3.0 } }.
	self assert: calls asArray equals: #( #( 'a' 1 2 ) #( 'x' 2 1 ) #( 'y' 3 1 ) ).
	self assert: ((self reader: 'x') addIntegerField; ifInvalid: [ nil ]; next) equals: { nil }.
	self assert: ((self reader: 'x') addIntegerField; ifInvalid: [ :text | text ]; next) equals: #( 'x' )
]

{ #category : 'tests - types' }
SimdCSVReaderTest >> testCachedConverter [
	| calls converter text rows |
	calls := 0.
	converter := [ :each |
	             calls := calls + 1.
	             each = 'b' ifFalse: [ each asUppercase ] ].
	text := self lines: #( 'a,x' 'b,x' 'a,y' 'b,x' ',x' ).
	rows := (self reader: text) addFieldConverter: converter cached: true; addField; upToEnd.
	self assert: (rows collect: [ :each | each first ]) equals: { 'A'. nil. 'A'. nil. nil }.
	self assert: calls equals: 2.
	rows := (self reader: text) recordClass: Dictionary; addField: [ :record :value | record at: #x put: value ] converter: converter cached: true; upToEnd.
	self assert: calls equals: 4.
	rows := (self reader: text) addFieldConverter: converter; addField; upToEnd.
	self assert: calls equals: 8
]

{ #category : 'tests - types' }
SimdCSVReaderTest >> testCacheIsBounded [
	| column |
	column := SimdCSVColumn converter: [ :each | each ] cached: true.
	1 to: 10010 do: [ :i | column valueOf: i printString ifInvalid: [ self fail ] ].
	self assert: (column instVarNamed: #cache) size equals: 10000.
	self assert: (column valueOf: '10005' ifInvalid: [ self fail ]) equals: '10005'
]

{ #category : 'tests - header' }
SimdCSVReaderTest >> testReadHeader [
	| reader |
	reader := self reader: (self lines: #( '"x","y","z"' '1,2' '1,2,3,4' )).
	self assert: reader header isNil.
	self assert: reader readHeader equals: #( 'x' 'y' 'z' ).
	self assert: reader header equals: #( 'x' 'y' 'z' ).
	self assert: reader recordNumber equals: 1.
	self assert: reader upToEnd equals: { { '1'. '2'. nil }. { '1'. '2'. '3' } }.
	self assert: (self reader: '') readHeader equals: #(  ).
	self assert: ((self reader: '') skipHeader; upToEnd) equals: #(  )
]

{ #category : 'tests - header' }
SimdCSVReaderTest >> testHeaderAfterFields [
	self assert: ((self reader: (self lines: #( 'x,y,z' '100,200,300' ))) addIntegerFields: 3; skipHeader; upToEnd) equals: #( #( 100 200 300 ) )
]

{ #category : 'tests - header' }
SimdCSVReaderTest >> testHeaderAfterFirstRecord [
	| reader |
	reader := self reader: (self lines: #( 'comment' 'x,y' '1,2,3' )).
	self assert: reader next equals: #( 'comment' ).
	self assert: reader readHeader equals: #( 'x' 'y' ).
	self assert: reader upToEnd equals: #( #( '1' '2' ) )
]

{ #category : 'tests - header' }
SimdCSVReaderTest >> testEmptyNames [
	self assert: (self reader: 'a,,column2,""') readHeader equals: #( 'a' 'column2_2' 'column2' 'column4' ).
	self assert: ((self reader: ',b') emptyFieldValue: #x; readHeader) equals: #( 'column1' 'b' ).
	self assert: ((self reader: '"",b') keepQuotedEmpty; readHeader) equals: #( 'column1' 'b' )
]

{ #category : 'tests - header' }
SimdCSVReaderTest >> testRenameDuplicates [
	| reader |
	reader := self reader: (self lines: #( 'a,b,a,a,a_2' '1,2,3,4,5' )).
	reader renameDuplicates.
	self assert: reader readHeader equals: #( 'a' 'b' 'a_3' 'a_4' 'a_2' ).
	reader := self reader: (self lines: #( 'a,a,a' '1,2,3' )).
	self assert: reader readHeader equals: #( 'a' 'a' 'a' ).
	reader renameDuplicates.
	self assert: reader header equals: #( 'a' 'a_2' 'a_3' ).
	reader selectColumns: #( 'a_3' 'a' ).
	self assert: reader next equals: #( '3' '1' )
]

{ #category : 'tests - header' }
SimdCSVReaderTest >> testNamedColumns [
	| reader |
	reader := self reader: (self lines: #( 'a,b' '1,2' '3' ',4,5' )).
	self assert: reader namedColumnsConfiguration equals: #( 'a' 'b' ).
	self assert: reader upToEnd equals: { ({ (#a -> '1'). (#b -> '2') } asDictionary). ({ (#a -> '3') } asDictionary). ({ (#b -> '4') } asDictionary) }.
	self assert: ((self reader: '') namedColumnsConfiguration; upToEnd) equals: #(  ).
	self assert: ((self reader: 'a,b') namedColumnsConfiguration; upToEnd) equals: #(  )
]

{ #category : 'tests - header' }
SimdCSVReaderTest >> testNamedColumnsWithDuplicates [
	"I stand on the header after the error"

	| reader error |
	reader := self reader: (self lines: #( 'a,b,a' '1,2,3' )).
	error := self assert: [ reader namedColumnsConfiguration ] signals: SimdCSVHeaderError.
	self assert: error kind equals: #duplicate.
	self assert: error columnName equals: 'a'.
	self assert: error field equals: 3.
	self assert: reader recordNumber equals: 0.
	reader renameDuplicates.
	reader namedColumnsConfiguration.
	self assert: reader next equals: ({ (#a -> '1'). (#b -> '2'). (#a_2 -> '3') } asDictionary)
]

{ #category : 'tests - header' }
SimdCSVReaderTest >> testNumberedColumns [
	| reader |
	reader := self reader: (self lines: #( '1,2' '3' )).
	self assert: reader numberedColumnsConfiguration equals: #( 'column1' 'column2' ).
	self assert: reader upToEnd equals: { ({ (#column1 -> '1'). (#column2 -> '2') } asDictionary). ({ (#column1 -> '3') } asDictionary) }.
	self assert: ((self reader: '') numberedColumnsConfiguration; upToEnd) equals: #(  )
]

{ #category : 'tests - columns' }
SimdCSVReaderTest >> testSelectColumns [
	| text |
	text := self lines: #( 'a,b,c' '1,2,3' '4,5' ).
	self assert: ((self reader: text) readHeader; yourself; selectColumns: #( #c 'a' ); upToEnd) equals: { { '3'. '1' }. { nil. '4' } }.
	self assert: ((self reader: text) skipHeader; selectColumns: #( 'a' 'c' ); upToEnd) equals: { { '1'. '3' }. { '4'. nil } }.
	self assert: ((self reader: text) namedColumnsConfiguration; yourself; selectColumns: #( 'c' 'a' ); upToEnd) equals: { ({ (#c -> '3'). (#a -> '1') } asDictionary). ({ (#a -> '4') } asDictionary) }.
	self assert: ((self reader: text) skipHeader; selectColumns: #( 'c' 'a' ); recordClass: Dictionary; upToEnd) first equals: ({ (#c -> '3'). (#a -> '1') } asDictionary).
	self assert: ((self reader: text) skipHeader; selectColumns: #( 'c' 'a' ); recordClass: OrderedCollection; next) equals: (OrderedCollection with: '3' with: '1').
	self assert: [ (self reader: text) skipHeader; selectColumns: #( 'a' 'a' ) ] signals: SimdCSVArgumentError.
	self assert: (self assert: [ (self reader: text) skipHeader; selectColumns: #( 'a' 'x' ) ] signals: SimdCSVHeaderError) kind equals: #missing.
	self assert: [ (self reader: text) selectColumns: #( 'a' ) ] signals: SimdCSVArgumentError
]

{ #category : 'tests - columns' }
SimdCSVReaderTest >> testTypedColumns [
	| text reader |
	text := self lines: #( 'a,b,c,d,e' '1,2.5,x,TRUE,"1,5"' 'z,,y,false,2' ).
	reader := self reader: text.
	reader
		skipHeader;
		column: #a as: #integer ifInvalid: [ :each | each asSymbol ];
		column: 'b' as: #float;
		column: #c as: #symbol;
		column: #d as: #boolean;
		column: #e as: #floatComma.
	self assert: reader upToEnd equals: { { 1. 2.5. #x. true. 1.5 }. { #z. nil. #y. false. 2.0 } }.
	reader := self reader: text.
	reader
		namedColumnsConfiguration;
		column: #b as: #float;
		column: #c converter: [ :each | each asUppercase ];
		selectColumns: #( #a #c );
		column: #d converter: [ :each | each size ] cached: true.
	self assert: reader upToEnd equals: { ({ (#a -> '1'). (#c -> 'X'). (#d -> 4) } asDictionary). ({ (#a -> 'z'). (#c -> 'Y'). (#d -> 5) } asDictionary) }.
	self assert: [ (self reader: text) skipHeader; column: #a as: #date ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: text) skipHeader; column: #d as: #boolean; column: #e as: #boolean; upToEnd ] signals: SimdCSVConversionError
]

{ #category : 'tests - columns' }
SimdCSVReaderTest >> testColumnsExcludeFields [
	| text |
	text := self lines: #( 'a,b' '1,2' ).
	self assert: [ (self reader: text) addField; addField; skipHeader; column: #a as: #integer ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: text) addField; skipHeader; selectColumns: #( #a ) ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: text) skipHeader; column: #a as: #integer; addField ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: text) skipHeader; selectColumns: #( #a ); addIgnoredField ] signals: SimdCSVArgumentError.
	self assert: [ (self reader: text) addField; namedColumnsConfiguration ] signals: SimdCSVArgumentError
]

{ #category : 'tests - columns' }
SimdCSVReaderTest >> testFieldAfterNamedColumns [
	self assert: ((self reader: (self lines: #( 'a,b' '1,2,3' ))) namedColumnsConfiguration; yourself; addIntegerFieldAt: #c; upToEnd) equals: { ({ (#a -> '1'). (#b -> '2'). (#c -> 3) } asDictionary) }
]

{ #category : 'tests - columns' }
SimdCSVReaderTest >> testDuplicateNamesAreUsable [
	"Only the use of such a name is an error"

	| reader |
	reader := self reader: (self lines: #( 'a,b,a' '1,2,3' '4,5,6' )).
	reader
		skipHeader;
		selectColumns: #( #b ).
	self assert: reader next equals: #( '2' ).
	self assert: (self assert: [ reader selectColumns: #( #a ) ] signals: SimdCSVHeaderError) kind equals: #duplicate.
	self assert: [ reader column: #a as: #integer ] signals: SimdCSVHeaderError.
	self assert: reader next equals: #( '5' )
]

{ #category : 'tests - limits' }
SimdCSVReaderTest >> testLimitArguments [
	| reader |
	reader := self reader: 'a'.
	self assert: [ reader maxFields: 1023 ] signals: SimdCSVArgumentError.
	self assert: [ reader maxRecordBytes: 0 ] signals: SimdCSVArgumentError.
	self assert: [ reader batchBytes: 0 ] signals: SimdCSVArgumentError.
	self assert: reader maxFields equals: 65536.
	self assert: reader maxRecordBytes equals: SimdCSVReader defaultMaxRecordBytes.
	self assert: reader next equals: #( 'a' )
]

{ #category : 'tests - facade' }
SimdCSVReaderTest >> testFacade [
	| text file |
	text := self lines: #( 'a;b' '1;"x;y"' '' ).
	self assert: (SimdCSV rowsFrom: 'a,b') equals: #( #( 'a' 'b' ) ).
	self assert: (SimdCSV rowsFrom: text separator: $;) equals: { { 'a'. 'b' }. { '1'. 'x;y' }. { nil } }.
	self assert: (SimdCSV rowsFrom: text dialect: SimdCSVDialect semicolon) size equals: 3.
	self assert: (SimdCSV count: text dialect: SimdCSVDialect semicolon) equals: 3.
	self assert: (SimdCSV tableFrom: text dialect: SimdCSVDialect semicolon) rowCount equals: 2.
	self assert: (Array streamContents: [ :out | SimdCSV rowsFrom: 'a,b' do: [ :row | out nextPut: row ] ]) equals: #( #( 'a' 'b' ) ).
	self assert: (Array streamContents: [ :out | SimdCSV rowsFrom: 'a;b' separator: $; do: [ :row | out nextPut: row ] ]) equals: #( #( 'a' 'b' ) ).
	self assert: (SimdCSV dictionariesFrom: (self lines: #( 'a,b' '1,2' ))) equals: { ({ (#a -> '1'). (#b -> '2') } asDictionary) }.
	self assert: (SimdCSV dictionariesFrom: (self lines: #( '1,2' )) dialect: (SimdCSVDialect comma hasHeader: false; yourself)) equals: { ({ (#column1 -> '1'). (#column2 -> '2') } asDictionary) }.
	file := FileSystem memory / 'a.csv'.
	file writeStreamDo: [ :stream | stream nextPutAll: text ].
	self assert: (SimdCSV rowsFrom: file separator: $;) size equals: 3.
	self assert: (SimdCSV count: file) equals: 3.
	self assert: (SimdCSV tableFrom: file) rowCount equals: 2
]

{ #category : 'tests - facade' }
SimdCSVReaderTest >> testCountAgrees [
	"rowsFrom:, count: and tableFrom: with one dialect"

	| random |
	random := self random.
	(self largeSize: 200) timesRepeat: [
		| text dialect |
		text := String new: (random nextInteger: 40) streamContents: [ :out |
			        (random nextInteger: 40) timesRepeat: [ out nextPut: ('ab,;"' , String crlf , String lf at: (random nextInteger: 8)) ] ].
		dialect := SimdCSVDialect comma.
		dialect
			skipEmptyLines: (random nextInteger: 2) = 1;
			lineEnd: (#( #any #lf ) at: (random nextInteger: 2)).
		self sourcesOf: text do: [ :source :name |
			| rows |
			rows := (SimdCSVReader on: text) dialect: dialect; upToEnd.
			self assert: ((SimdCSVReader on: source) dialect: dialect; batchBytes: (random nextInteger: 20); countRecords) equals: rows size.
			self assert: (SimdCSV tableFrom: text dialect: dialect) rowCount equals: (rows size - 1 max: 0) ] ]
]

{ #category : 'tests - facade' }
SimdCSVReaderTest >> testSeparatorOffsets [
	self assert: (SimdCSV separatorOffsetsIn: (self lines: #( 'a,b' '"c,d",e' )) , 'f') asArray equals: #( 1 3 9 11 13 ).
	self assert: (SimdCSV separatorOffsetsIn: 'a,b' asByteArray) asArray equals: #( 1 3 ).
	self assert: (SimdCSV separatorOffsetsIn: #'a,b') class equals: WordArray.
	self assert: (SimdCSV separatorOffsetsIn: 'a,b' asWideString) asArray equals: #( 1 3 ).
	self assert: (SimdCSV separatorOffsetsIn: '') asArray equals: #(  ).
	self assert: (SimdCSV separatorOffsetsIn: #[ 239 187 191 97 10 ]) asArray equals: #( 4 ).
	self assert: (SimdCSV separatorOffsetsIn: 'a;b' dialect: SimdCSVDialect semicolon) asArray equals: #( 1 3 ).
	self assert: [ SimdCSV separatorOffsetsIn: 'a' readStream ] signals: SimdCSVArgumentError.
	self assert: [ SimdCSV separatorOffsetsIn: 'a"' dialect: (SimdCSVDialect comma strictQuoting: true; yourself) ] signals: SimdCSVQuoteError text: 'Unexpected quote at character 2 (record 1, line 1)'
]

{ #category : 'tests - facade' }
SimdCSVReaderTest >> testBackendQuestions [
	self assert: SimdCSV backend equals: backendName.
	self assert: SimdCSV pluginAvailable equals: SimdCSVBackend pluginAvailable.
	self assert: SimdCSV pluginInfo equals: SimdCSVBackend pluginInfo.
	self assert: SimdCSV implementationName equals: SimdCSVBackend implementationName
]
