"
I am a record of three values, `x`, `y` and `z`, for the tests of the reader.
"
Class {
	#name : 'SimdCSVTestRecord',
	#superclass : 'Object',
	#instVars : [
		'x',
		'y',
		'z'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'instance creation' }
SimdCSVTestRecord class >> x: x y: y z: z [
	^ self new
		  x: x;
		  y: y;
		  z: z;
		  yourself
]

{ #category : 'accessing' }
SimdCSVTestRecord >> x [
	^ x
]

{ #category : 'accessing' }
SimdCSVTestRecord >> x: anObject [
	x := anObject
]

{ #category : 'accessing' }
SimdCSVTestRecord >> y [
	^ y
]

{ #category : 'accessing' }
SimdCSVTestRecord >> y: anObject [
	y := anObject
]

{ #category : 'accessing' }
SimdCSVTestRecord >> z [
	^ z
]

{ #category : 'accessing' }
SimdCSVTestRecord >> z: anObject [
	z := anObject
]

{ #category : 'comparing' }
SimdCSVTestRecord >> = anObject [
	^ self class = anObject class and: [ x = anObject x and: [ y = anObject y and: [ z = anObject z ] ] ]
]

{ #category : 'comparing' }
SimdCSVTestRecord >> hash [
	^ x hash bitXor: y hash
]

{ #category : 'printing' }
SimdCSVTestRecord >> printOn: aStream [
	super printOn: aStream.
	aStream print: {
			x.
			y.
			z }
]
