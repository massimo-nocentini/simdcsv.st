"
I test the packages themselves: the class comments, the names, the extension methods, undeclared variables and the style of the tests of nil.
"
Class {
	#name : 'SimdCSVPackageTest',
	#superclass : 'SimdCSVSingleTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SimdCSVPackageTest >> packages [
	^ #( 'SimdCSV' 'SimdCSV-Tests' 'SimdCSV-NeoTests' ) select: [ :each | self packageOrganizer hasPackage: each ] thenCollect: [ :each |
		  self packageOrganizer packageNamed: each ]
]

{ #category : 'helpers' }
SimdCSVPackageTest >> ownClasses [
	^ self packages flatCollect: [ :each | each definedClasses ]
]

{ #category : 'helpers' }
SimdCSVPackageTest >> methods [
	^ self packages flatCollect: [ :each | each methods ]
]

{ #category : 'tests' }
SimdCSVPackageTest >> testClassComments [
	"Every class has a comment, in Markdown without HTML, footnotes or tabs at the start, whose code spans say more than nil or false"

	self ownClasses do: [ :class |
		| comment |
		comment := class comment.
		self assert: (class hasComment and: [ comment isNotEmpty ]) description: class name , ' has no comment'.
		self deny: (comment beginsWith: 'Please comment') description: class name.
		self assert: comment first isSeparator not description: class name.
		self assert: (comment occurrencesOf: $`) even description: class name , ': a code span is not closed'.
		#( '[^' '<br' '<b>' '<p>' '<code' '`nil`' '`false`' ) do: [ :each |
			self deny: (comment includesSubstring: each) description: class name , ': ' , each ] ]
]

{ #category : 'tests' }
SimdCSVPackageTest >> testCommentTables [
	"A cell of a table is plain text or code, not both"

	self ownClasses do: [ :class |
		class comment lines do: [ :line |
			(line beginsWith: '|') ifTrue: [
				(line findTokens: '|') do: [ :cell |
					| text |
					text := cell trimBoth.
					self
						assert: ((text includes: $`) not or: [ (text beginsWith: '`') and: [ (text endsWith: '`') and: [ (text occurrencesOf: $`) = 2 ] ] ])
						description: class name , ': ' , line ] ] ] ]
]

{ #category : 'tests' }
SimdCSVPackageTest >> testExtensionsAreOurs [
	"Nothing of Pharo is overridden: an extension method begins with simdCSV"

	| own |
	own := self ownClasses asIdentitySet.
	(self packages flatCollect: [ :each | each extensionMethods ]) do: [ :method |
		((own includes: method methodClass instanceSide) or: [ method selector beginsWith: 'simdCSV' ]) ifFalse: [
			self fail: method printString ] ]
]

{ #category : 'tests' }
SimdCSVPackageTest >> testClassNames [
	self ownClasses do: [ :class |
		self assert: ((class name beginsWith: 'SimdCSV') or: [ class name beginsWith: 'ManifestSimdCSV' ]) description: class name ]
]

{ #category : 'tests' }
SimdCSVPackageTest >> testNilStyle [
	"nil is tested with ifNil: and ifNotNil:, never compared, and isNil and notNil do not choose a branch"

	self methods do: [ :method |
		method ast allChildren do: [ :node |
			(node class name endsWith: 'MessageNode') ifTrue: [
				(#( #ifTrue: #ifFalse: #ifTrue:ifFalse: #ifFalse:ifTrue: ) includes: node selector) ifTrue: [
					| receiver |
					receiver := node receiver.
					((receiver class name endsWith: 'MessageNode') and: [
						 (#( #isNil #notNil #isNotNil ) includes: receiver selector) or: [
							 (#( #== #= #~~ #~= ) includes: receiver selector) and: [ receiver arguments first sourceCode = 'nil' ] ] ])
						ifTrue: [ self fail: method printString , ': ' , node sourceCode ] ] ] ] ]
]

{ #category : 'tests' }
SimdCSVPackageTest >> testNoUndeclared [
	self methods do: [ :method | self deny: method usesUndeclareds description: [ method printString ] ]
]

{ #category : 'tests' }
SimdCSVPackageTest >> testNoNeo [
	"Neither the core nor its tests name a class of NeoCSV"

	#( 'SimdCSV' 'SimdCSV-Tests' ) do: [ :name |
		(self packageOrganizer packageNamed: name) methods do: [ :method |
			self
				deny: (method literals anySatisfy: [ :each |
						 (each isKindOf: Association) and: [ each key asString beginsWith: 'Neo' ] ])
				description: [ method printString ] ] ]
]
