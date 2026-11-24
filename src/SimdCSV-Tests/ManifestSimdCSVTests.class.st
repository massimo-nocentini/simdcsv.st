"
`SimdCSV-Tests` - the SUnit tests of the package `SimdCSV`.

The subclasses of `SimdCSVTestCase` run on both backends (`#plugin`, skipped without a `SimdCSVPlugin`, and `#smalltalk`); those of `SimdCSVSingleTestCase` run once.

- `SimdCSVIndexTest`, `SimdCSVMeasureTest` and `SimdCSVRowsTest`: the three primitives, against literals and against `SimdCSVReference`, a second automaton;
- `SimdCSVPrimitiveContractTest`: what they refuse;
- `SimdCSVDifferentialTest`: the plugin against `SimdCSVSmalltalk` on random calls;
- `SimdCSVBackendTest`: the choice of the backend, the retries and the growth of the memory, with `SimdCSVScriptedBackend`;
- `SimdCSVDialectTest` and `SimdCSVNumbersTest`;
- `SimdCSVPackageTest`: the comments, the names and the style of the packages.
"
Class {
	#name : 'ManifestSimdCSVTests',
	#superclass : 'PackageManifest',
	#category : 'SimdCSV-Tests-Manifest',
	#package : 'SimdCSV-Tests',
	#tag : 'Manifest'
}
