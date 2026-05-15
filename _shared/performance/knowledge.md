## Parallel arrays outperform object arrays for interpreter dispatch
For bytecode interpreters, storing opcodes and arguments as separate `int[]` arrays (parallel arrays) rather than an array of `Instruction` objects keeps the CPU cache hot during sequential dispatch. The opcode array is compact and accessed linearly, avoiding pointer chasing and object header overhead.
Observed: 2026-04-13 (jjq bytecode VM)

## Compile-time pattern fusion can yield 10x+ speedups in interpreters
Detecting common multi-instruction patterns (e.g., iterate-then-collect) at compile time and fusing them into single opcodes eliminates per-element overhead (backtracking, stack manipulation). In jjq, fused `reduce` was 15.8x faster than the unfused version. The key enabler is recognizing idiomatic patterns in the AST before lowering to bytecode.
Observed: 2026-04-13 (jjq fused opcodes)

## Runtime reflection introspection forces transitive class loading at startup

When a framework uses runtime reflection to introspect field types (e.g., picocli scanning @Option
fields via `Class.getDeclaredFields()` + `Field.getType()`), the JVM must load the field's VALUE type
class even if that field is never accessed. A compile-time annotation processor that generates
field accessors via anonymous inner classes (e.g., `((MyCommand) inst).field = (Type) val`) only
forces loading of the declaring class, not field value types of unrelated commands.

In a CLI with 18 subcommands and ~100 option fields, this caused picocli to load 18 extra domain
classes and 160 extra JDK classes (reflection infrastructure: generics parsing, type variable
resolution, method repositories) vs an annotation-processor approach. Net effect: 2x slower
startup (220ms vs 110ms on JDK 25).

Observed: 2026-04-23 (jbang picocli vs aesh comparison)

## Hybrid number representations avoid BigDecimal allocation overhead
For JSON processing where most numbers are small integers, using a long fast-path with BigDecimal fallback avoids the allocation cost of BigDecimal for the common case. The hybrid approach (long | BigDecimal | double) covers integers, arbitrary precision, and IEEE 754 special values.
Observed: 2026-04-13 (jjq JqNumber)
