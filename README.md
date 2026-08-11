# AArch64 SIMD experiments

## Hand-written NEON dot-product benchmark

`neon_dot.s` implements a signed `int32_t` dot product manually using AArch64
NEON. It loads two 128-bit vectors at a time, uses `smull`/`smull2` to process
four elements per iteration, accumulates in two 64-bit lanes, and finishes any
remaining elements with scalar `smaddl`. The benchmark uses 1,000,003 elements
on purpose, exercising its three-element tail.

Build and run it on an AArch64 host, or cross-build and execute it through
QEMU:

```sh
make run
```

Input initialization happens once before timing. The output verifies the
assembly result against an equivalent ordinary C++ loop compiled with `-O3`,
then reports the mean of nine trials (twenty dot products each). Since QEMU
does not model target timing like real hardware, use native AArch64 for useful
performance numbers.

Inspect the linked machine code (including the compiler's `cpp_dot_product`)
with:

```sh
make disasm
less build/dot_benchmark.dis
```

To break at the assembly routine and inspect the arguments and NEON registers,
run:

```sh
make gdb GDB=gdb-multiarch
```

If your installed `gdb` already supports AArch64, the `GDB=...` override is not
needed. The commands used are also kept in `gdb_neon.gdb` for interactive use.
