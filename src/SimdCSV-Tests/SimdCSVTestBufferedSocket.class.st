"
I am the stream of a socket that tells how many units have arrived, as a `SocketStream`.
"
Class {
	#name : 'SimdCSVTestBufferedSocket',
	#superclass : 'SimdCSVTestSocket',
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'accessing' }
SimdCSVTestBufferedSocket >> inBufferSize [
	^ buffer size
]
