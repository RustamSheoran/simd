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

| Platform                 | CPU          | C++ -O3 ns/dot | NEON asm ns/dot | Speedup |
| ------------------------ | ------------ | -------------: | --------------: | ------: |
| macOS 26 (Apple Silicon) | Apple M1 Pro |         6696.1 |        379029.4 |  0.018x |
| macOS 26 (Apple Silicon) | Apple M1 Pro |       111734.3 |        338653.7 |  0.330x |
| macOS 26 (Apple Silicon) | Apple M1 Pro |       105768.1 |        134546.5 |  0.786x |
| macOS 26 (Apple Silicon) | Apple M1 Pro |       109388.7 |        108834.5 |  1.005x |
| macOS 26 (Apple Silicon) | Apple M1 Pro |       131919.2 |        125140.5 |  1.054x |

### Arch Linux host runs through QEMU user mode

These runs were recorded on the listed host CPU while `qemu-aarch64` executed
the AArch64 binary. They preserve the observed relative QEMU performance, but
are not native AArch64 hardware measurements.

| Platform                           | CPU                           | C++ -O3 ns/dot | NEON asm ns/dot | Speedup |
| ---------------------------------- | ----------------------------- | -------------: | --------------: | ------: |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1892028.1 |       1192696.9 |  1.586x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1890385.2 |       1189614.9 |  1.589x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1894452.1 |       1179819.6 |  1.606x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1900968.5 |       1180365.6 |  1.610x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1893079.8 |       1180052.0 |  1.604x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1892090.1 |       1181202.8 |  1.602x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1893200.4 |       1182791.8 |  1.601x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1889124.0 |       1178382.1 |  1.603x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1904831.6 |       1189383.4 |  1.602x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1888460.7 |       1189042.2 |  1.588x |
| Arch Linux x86_64 (QEMU user mode) | Intel Core i5-4430 @ 3.00 GHz |      1894778.4 |       1181641.7 |  1.604x |

### Windows 11 / WSL2 host runs through QEMU user mode

These runs were recorded on Windows 11 using WSL2, with `qemu-aarch64`
executing the AArch64 Linux binary. They preserve the observed relative
QEMU performance, but are not native AArch64 hardware measurements.

| Platform                           | CPU                      | C++ -O3 ns/dot | NEON asm ns/dot | Speedup |
| ---------------------------------- | ------------------------ | -------------: | --------------: | ------: |
| Windows 11 / WSL2 (QEMU user mode) | Ryzen 5 5500U @ 2.10 GHz |      1692338.4 |       1065585.8 |  1.588x |
| Windows 11 / WSL2 (QEMU user mode) | Ryzen 5 5500U @ 2.10 GHz |      1955312.8 |       1089406.0 |  1.795x |
| Windows 11 / WSL2 (QEMU user mode) | Ryzen 5 5500U @ 2.10 GHz |      1788839.9 |       1098340.8 |  1.629x |
| Windows 11 / WSL2 (QEMU user mode) | Ryzen 5 5500U @ 2.10 GHz |      1745037.9 |       1090407.4 |  1.600x |
| Windows 11 / WSL2 (QEMU user mode) | Ryzen 5 5500U @ 2.10 GHz |      1708918.4 |       1068312.1 |  1.600x |

See [BENCHMARK.md](BENCHMARK.md) for installation, build, execution, debugger,
and result-submission instructions.
