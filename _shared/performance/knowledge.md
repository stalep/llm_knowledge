## Parallel arrays outperform object arrays for interpreter dispatch
For bytecode interpreters, storing opcodes and arguments as separate `int[]` arrays (parallel arrays) rather than an array of `Instruction` objects keeps the CPU cache hot during sequential dispatch. The opcode array is compact and accessed linearly, avoiding pointer chasing and object header overhead.
Observed: 2026-04-13 (jjq bytecode VM)

## Compile-time pattern fusion can yield 10x+ speedups in interpreters
Detecting common multi-instruction patterns (e.g., iterate-then-collect) at compile time and fusing them into single opcodes eliminates per-element overhead (backtracking, stack manipulation). In jjq, fused `reduce` was 15.8x faster than the unfused version. The key enabler is recognizing idiomatic patterns in the AST before lowering to bytecode.
Observed: 2026-04-13 (jjq fused opcodes)

## Hybrid number representations avoid BigDecimal allocation overhead
For JSON processing where most numbers are small integers, using a long fast-path with BigDecimal fallback avoids the allocation cost of BigDecimal for the common case. The hybrid approach (long | BigDecimal | double) covers integers, arbitrary precision, and IEEE 754 special values.
Observed: 2026-04-13 (jjq JqNumber)
