"
I say how a CSV text is written. One dialect governs the reader, the table, the writer and every selector of `SimdCSV`.

- `separator:`, the Character between the fields; a comma by default.
- `quote:`, the Character around a quoted field, or nil for a text without quoting; `$""` by default.
- `lineEnd:`, `#any` (LF, CR and CRLF end a record, mixed as they come; the default) or `#lf` (only LF does).
- `strictQuoting:`, whether a quote inside an unquoted field, text after a closing quote and an unterminated quote are errors; not by default.
- `strictFieldCount:`, whether a record with another count of fields is an error; not by default.
- `skipEmptyLines:`, whether a blank line is no record; by default it is a record of one empty field.
- `keepQuotedEmpty:`, whether a quoted empty field is an empty String; by default it is `emptyFieldValue`.
- `encoding:`, `#utf8` (the default) or `#latin1`, what the bytes of a ByteArray, a file or a binary stream are; a String has no encoding.
- `emptyFieldValue:`, the value of an empty field; nil by default.
- `hasHeader:`, whether the first record names the columns (the table and `dictionariesFrom:`); it does by default.
- `nullTexts:`, the texts that mean `emptyFieldValue` in a typed or converted column; none by default.

```smalltalk
SimdCSVDialect semicolon
	lineEnd: #lf;
	strictQuoting: true;
	yourself
```

Without strict quoting I am as lenient as the csv module of Python: `""a""b` is the text ab, and `a""b` is literal.

`wordFor:final:lines:exact:` answers me as the dialect word of the primitives (bits 0 to 20 the separator, 21 to 28 the quote, 29 to 44 the flags), or signals `SimdCSVArgumentError`.
"
Class {
	#name : 'SimdCSVDialect',
	#superclass : 'Object',
	#instVars : [
		'separator',
		'quote',
		'lineEnd',
		'strictQuoting',
		'strictFieldCount',
		'skipEmptyLines',
		'keepQuotedEmpty',
		'encoding',
		'emptyFieldValue',
		'hasHeader',
		'nullTexts'
	],
	#category : 'SimdCSV-Core',
	#package : 'SimdCSV',
	#tag : 'Core'
}

{ #category : 'instance creation' }
SimdCSVDialect class >> comma [
	"Fields separated by commas"

	^ self new
		separator: $,;
		yourself
]

{ #category : 'instance creation' }
SimdCSVDialect class >> semicolon [
	"Fields separated by semicolons"

	^ self new
		separator: $;;
		yourself
]

{ #category : 'instance creation' }
SimdCSVDialect class >> tab [
	"Fields separated by tabs"

	^ self new
		separator: Character tab;
		yourself
]

{ #category : 'flags' }
SimdCSVDialect class >> flagStrict [
	"SC_F_STRICT"

	^ 1
]

{ #category : 'flags' }
SimdCSVDialect class >> flagLfOnly [
	"SC_F_LF_ONLY"

	^ 2
]

{ #category : 'flags' }
SimdCSVDialect class >> flagNoQuote [
	"SC_F_NO_QUOTE"

	^ 4
]

{ #category : 'flags' }
SimdCSVDialect class >> flagSkipBlank [
	"SC_F_SKIP_BLANK"

	^ 8
]

{ #category : 'flags' }
SimdCSVDialect class >> flagLatin1 [
	"SC_F_LATIN1: the bytes are characters"

	^ 16
]

{ #category : 'flags' }
SimdCSVDialect class >> flagFinal [
	"SC_F_FINAL: the range ends the data"

	^ 32
]

{ #category : 'flags' }
SimdCSVDialect class >> flagLines [
	"SC_F_LINES: count the physical line ends"

	^ 64
]

{ #category : 'flags' }
SimdCSVDialect class >> flagExactCount [
	"SC_F_EXACT_COUNT: another count of fields is an error"

	^ 128
]

{ #category : 'flags' }
SimdCSVDialect class >> flagKeepQuotedEmpty [
	"SC_F_KEEP_QUOTED_EMPTY"

	^ 256
]

{ #category : 'initialization' }
SimdCSVDialect >> initialize [
	super initialize.
	separator := $,.
	quote := $".
	lineEnd := #any.
	strictQuoting := strictFieldCount := skipEmptyLines := keepQuotedEmpty := false.
	encoding := #utf8.
	hasHeader := true.
	nullTexts := #(  )
]

{ #category : 'accessing' }
SimdCSVDialect >> strictQuoting [
	"Refuse irregular quotes?"

	^ strictQuoting
]

{ #category : 'accessing' }
SimdCSVDialect >> strictQuoting: aBoolean [
	strictQuoting := self boolean: aBoolean
]

{ #category : 'accessing' }
SimdCSVDialect >> strictFieldCount [
	"Refuse a record with another count of fields?"

	^ strictFieldCount
]

{ #category : 'accessing' }
SimdCSVDialect >> strictFieldCount: aBoolean [
	strictFieldCount := self boolean: aBoolean
]

{ #category : 'accessing' }
SimdCSVDialect >> skipEmptyLines [
	"Is a blank line no record?"

	^ skipEmptyLines
]

{ #category : 'accessing' }
SimdCSVDialect >> skipEmptyLines: aBoolean [
	skipEmptyLines := self boolean: aBoolean
]

{ #category : 'accessing' }
SimdCSVDialect >> keepQuotedEmpty [
	"Is a quoted empty field an empty String, not emptyFieldValue?"

	^ keepQuotedEmpty
]

{ #category : 'accessing' }
SimdCSVDialect >> keepQuotedEmpty: aBoolean [
	keepQuotedEmpty := self boolean: aBoolean
]

{ #category : 'accessing' }
SimdCSVDialect >> hasHeader [
	"Does the first record name the columns?"

	^ hasHeader
]

{ #category : 'accessing' }
SimdCSVDialect >> hasHeader: aBoolean [
	hasHeader := self boolean: aBoolean
]

{ #category : 'accessing' }
SimdCSVDialect >> separator [
	^ separator
]

{ #category : 'accessing' }
SimdCSVDialect >> separator: aCharacter [
	aCharacter isCharacter ifFalse: [ ^ self refuse: 'the separator is a Character, not ' , aCharacter printString ].
	separator := aCharacter
]

{ #category : 'accessing' }
SimdCSVDialect >> quote [
	"The Character around a quoted field, or nil without quoting"

	^ quote
]

{ #category : 'accessing' }
SimdCSVDialect >> quote: aCharacterOrNil [
	aCharacterOrNil ifNotNil: [
		aCharacterOrNil isCharacter ifFalse: [
			^ self refuse: 'the quote is a Character or nil, not ' , aCharacterOrNil printString ] ].
	quote := aCharacterOrNil
]

{ #category : 'accessing' }
SimdCSVDialect >> lineEnd [
	"#any (LF, CR and CRLF) or #lf"

	^ lineEnd
]

{ #category : 'accessing' }
SimdCSVDialect >> lineEnd: aSymbol [
	(#( #any #lf ) includes: aSymbol) ifFalse: [ ^ self refuse: 'the line end is #any or #lf, not ' , aSymbol printString ].
	lineEnd := aSymbol
]

{ #category : 'accessing' }
SimdCSVDialect >> encoding [
	"#utf8 or #latin1: what the bytes of a source that is no String are"

	^ encoding
]

{ #category : 'accessing' }
SimdCSVDialect >> encoding: aSymbol [
	(#( #utf8 #latin1 ) includes: aSymbol) ifFalse: [
		^ self refuse: 'the encoding is #utf8 or #latin1, not ' , aSymbol printString , ': decode the text first' ].
	encoding := aSymbol
]

{ #category : 'accessing' }
SimdCSVDialect >> emptyFieldValue [
	^ emptyFieldValue
]

{ #category : 'accessing' }
SimdCSVDialect >> emptyFieldValue: anObject [
	emptyFieldValue := anObject
]

{ #category : 'accessing' }
SimdCSVDialect >> nullTexts [
	^ nullTexts
]

{ #category : 'accessing' }
SimdCSVDialect >> nullTexts: aCollection [
	nullTexts := aCollection asArray
]

{ #category : 'private' }
SimdCSVDialect >> boolean: aBoolean [
	aBoolean isBoolean ifFalse: [ ^ self refuse: 'a Boolean is expected, not ' , aBoolean printString ].
	^ aBoolean
]

{ #category : 'private' }
SimdCSVDialect >> refuse: aString [
	^ SimdCSVArgumentError signal: 'SimdCSV: ' , aString
]

{ #category : 'primitives' }
SimdCSVDialect >> flagsFinal: isFinal lines: withLines exact: isExact latin1: isLatin1 [
	"The flags of the dialect word"

	| flags class |
	class := self class.
	flags := 0.
	strictQuoting ifTrue: [ flags := flags + class flagStrict ].
	lineEnd == #lf ifTrue: [ flags := flags + class flagLfOnly ].
	quote ifNil: [ flags := flags + class flagNoQuote ].
	skipEmptyLines ifTrue: [ flags := flags + class flagSkipBlank ].
	isLatin1 ifTrue: [ flags := flags + class flagLatin1 ].
	isFinal ifTrue: [ flags := flags + class flagFinal ].
	withLines ifTrue: [ flags := flags + class flagLines ].
	isExact ifTrue: [ flags := flags + class flagExactCount ].
	keepQuotedEmpty ifTrue: [ flags := flags + class flagKeepQuotedEmpty ].
	^ flags
]

{ #category : 'primitives' }
SimdCSVDialect >> wordFor: aSource final: isFinal lines: withLines exact: isExact [
	"The dialect word of the primitives for aSource (a ByteArray, a String or any other object of bytes or of 32-bit words), or SimdCSVArgumentError.  isFinal: the range of the call ends the data; withLines: count the line ends; isExact: another count of fields is an error.  The bytes of a ByteString are characters, the bytes of any other byte object what the encoding says"

	| units isLatin1 separatorValue quoteValue |
	units := SimdCSVSmalltalk unitsOf: aSource.
	units ifNil: [ ^ self refuse: 'a source of bytes or characters is expected, not an instance of ' , aSource class name ].
	isLatin1 := units == #bytes and: [ aSource isString or: [ encoding == #latin1 ] ].
	separatorValue := separator asInteger.
	quoteValue := quote
		              ifNil: [ 0 ]
		              ifNotNil: [ quote asInteger ].
	self validateSeparator: separatorValue quote: quoteValue units: units latin1: isLatin1.
	^ separatorValue + (quoteValue bitShift: 21)
	  + ((self flagsFinal: isFinal lines: withLines exact: isExact latin1: isLatin1) bitShift: 29)
]

{ #category : 'primitives' }
SimdCSVDialect >> validateSeparator: separatorValue quote: quoteValue units: units latin1: isLatin1 [
	"Signal SimdCSVArgumentError for a dialect that the primitives refuse"

	(separatorValue = 10 or: [ separatorValue = 13 ]) ifTrue: [ ^ self refuse: 'the separator is a line end' ].
	quote ifNotNil: [
		separatorValue = quoteValue ifTrue: [ ^ self refuse: 'the separator is the quote' ].
		(quoteValue = 10 or: [ quoteValue = 13 ]) ifTrue: [ ^ self refuse: 'the quote is a line end' ].
		quoteValue > 255 ifTrue: [ ^ self refuse: 'the quote is beyond U+00FF' ] ].
	units == #bytes ifFalse: [ ^ self ].
	separatorValue > 255 ifTrue: [ ^ self refuse: 'the separator is beyond U+00FF, which no byte of the source can be' ].
	(isLatin1 not and: [ separatorValue > 127 or: [ quoteValue > 127 ] ]) ifTrue: [
		^ self refuse: 'the separator and the quote of UTF-8 bytes are ASCII' ]
]

{ #category : 'printing' }
SimdCSVDialect >> printOn: aStream [
	super printOn: aStream.
	aStream
		nextPut: $(;
		print: separator;
		space;
		print: quote;
		space;
		print: lineEnd;
		space;
		print: encoding;
		nextPut: $)
]
