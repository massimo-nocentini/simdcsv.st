"
`SimdCSV` - CSV for Pharo 12 to 15, with [simdcsv](https://github.com/geofflangdale/simdcsv) in the `SimdCSVPlugin` of the VM (`plugins/SimdCSVPlugin` and `docs/SimdCSV.md` of https://github.com/massimo-nocentini/pharo-vm).

A text is read in two steps:

- the index: the position of the unit that ends each field, 4 bytes a field, made by SIMD code;
- the rows: Arrays of Strings, Integers and Floats, made from the index in batches.

Without the plugin, `SimdCSVSmalltalk` answers the same in pure Smalltalk.

## Tags

- `Core`: the facade `SimdCSV`, `SimdCSVDialect` (separator, quote, line ends and the other choices) and `SimdCSVNumbers` (exact numbers from text).
- `Backends`: `SimdCSVBackend`, which chooses between `SimdCSVPrimitives` and `SimdCSVSmalltalk`, and `SimdCSVFailure`.
- `Errors`: `SimdCSVError` and its subclasses.
- `Reading`, `Table` and `Writing`: the reader, the table and the writer.

Nothing of Pharo or of NeoCSV is replaced, and every extension method begins with `simdCSV`.
"
Class {
	#name : 'ManifestSimdCSV',
	#superclass : 'PackageManifest',
	#category : 'SimdCSV-Manifest',
	#package : 'SimdCSV',
	#tag : 'Manifest'
}
