"
I am signalled with strict quoting (`strictQuoting:` of the dialect, `beStrictQuoting` of the reader). My `code` says why:

- 1: a quote inside an unquoted field;
- 2: text after a closing quote;
- 3: a quote that is never closed; my `position` is the one of the opening quote.
"
Class {
	#name : 'SimdCSVQuoteError',
	#superclass : 'SimdCSVParseError',
	#category : 'SimdCSV-Errors',
	#package : 'SimdCSV',
	#tag : 'Errors'
}

{ #category : 'printing' }
SimdCSVQuoteError >> describeOn: aStream [
	aStream nextPutAll: (#( 'Unexpected quote at ' 'Text after a closing quote at ' 'Unterminated quote opened at ' ) at: code).
	self describePlaceOn: aStream.
	aStream nextPut: $)
]
