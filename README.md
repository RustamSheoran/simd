# Hand-written AArch64 NEON dot product

This project compares a hand-written AArch64 NEON implementation of a signed
`int32_t` dot product with an equivalent C++ loop compiled at `-O3`. It uses
two deterministic arrays of 1,000,003 elements, verifies that both paths
produce the same signed 64-bit scalar result, and times only repeated
dot-product calls. The assembly is deliberately written in a `.s` file rather
than with NEON intrinsics: controlling the ABI registers, loads, widening
operations, accumulator layout, and scalar tail is a design choice of this
experiment, not a replacement for portable production code.

## Files

### `neon_dot.s`

The AArch64 ELF assembly implementation exports
`int64_t neon_dot_product(const int32_t *, const int32_t *, size_t)`. It takes
the two array pointers and element count in `x0`–`x2`, loads 16 bytes from each
array into `q1` and `q2`, and returns the signed 64-bit sum in `x0`. The routine
uses only caller-saved general-purpose and SIMD registers, so no stack frame or
callee-saved-register spill is required.

### `dot_benchmark.cpp`

This is the executable harness and C++ `-O3` baseline. It initializes aligned,
bounded input arrays deterministically, computes each implementation once for
the correctness check, then measures nine trials of twenty dot products. Setup,
correctness reporting, and result consumption are outside each timed interval.
The baseline is a normal scalar-looking C++ loop; the compiler is free to
vectorize it for the selected target.

### `Makefile`

The Makefile defaults to a Debian-style AArch64 Linux cross toolchain and
builds `build/neon_dot_benchmark`. `run` executes that Linux binary under QEMU
user mode; `disasm` writes a source-interleaved disassembly to
`build/dot_benchmark.dis`; and `gdb` starts QEMU's remote stub and runs the
provided GDB command file. Compiler, disassembler, QEMU, debugger, and sysroot
can all be overridden on the command line.

### `gdb_neon.gdb`

This GDB command file connects to the QEMU remote target, stops at
`neon_dot_product`, prints the ABI arguments, then stops after the first
32-element vector iteration. It displays `v0` through `v7` alongside the
next instructions, plus `v16` through `v19`, allowing the loads, widened
products, and all accumulator state to be checked against the source.

## Technical notes

`smlal` widens and multiply-accumulates the low two 32-bit lanes, while
`smlal2` handles the high two. The main loop unrolls to 32 elements and uses
eight independent two-lane 64-bit accumulators (`v0`–`v3`, `v16`–`v19`),
reducing branch overhead and the accumulator dependency chain. At loop exit,
those accumulators are reduced into `x3`, and the remaining zero to three
elements use scalar `smaddl`. The count is deliberately 1,000,003 rather than
a multiple of four so every benchmark run exercises the tail path.

## Results

Native hardware results only; QEMU user-mode runs are correctness checks, not
performance data.

| Platform | CPU | C++ -O3 ns/dot | NEON asm ns/dot | Speedup |
| --- | --- | ---: | ---: | ---: |
| | | | | |

See [BENCHMARK.md](BENCHMARK.md) for installation, build, execution, debugger,
and result-submission instructions.
