## JMH annotation processing on Java 21+ with maven-compiler-plugin 3.14
The `jmh-generator-annprocess` dependency with `<scope>provided</scope>` is not enough to trigger annotation processing on recent Java/compiler-plugin versions. You must explicitly configure `<annotationProcessorPaths>` in the maven-compiler-plugin. Without this, classes compile fine but the `META-INF/BenchmarkList` file is never generated, causing a runtime error.
Observed: 2026-04-30

## PairDistanceCalculator scaling is quadratic and measurable
`getCandidateChangePoint()` at size=50 takes ~40us, at size=100 takes ~191us (4.7x for 2x size). The windowed path (`computeChangePoints`) scales linearly with series length for fixed window size: 100→500 gives ~6x time. The O(n²) cost is contained within each window.
Observed: 2026-04-30
