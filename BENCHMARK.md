# Building, running, and reporting results

The program prints output in this form. The scalar value must be marked
`verified equal`; elapsed times vary by CPU, compiler, thermal state, and
system load.

```text
elements: 1000003 (vector loop + 3-element tail)
dot product: 18046484 (verified equal)
C++ -O3: ... ns/dot
hand-written NEON: ... ns/dot
speedup: ...x
```

The benchmark averages nine trials of twenty calls. Pinning CPU frequency,
avoiding background load, and reporting compiler version are the submitter's
responsibility. Do not compare timings across different compiler options or
hardware as though they were a single result.

## Native AArch64 Linux

The following commands target Debian or Ubuntu running directly on AArch64.
`g++` is already an AArch64 compiler on this host; no cross compiler prefix is
needed.

```sh
sudo apt update
sudo apt install build-essential binutils gdb
# Optional if the installed gdb lacks AArch64 support:
sudo apt install gdb-multiarch

make clean
make all CXX=g++ OBJDUMP=objdump
./build/neon_dot_benchmark
make disasm CXX=g++ OBJDUMP=objdump
```

`make run` is intentionally not used in this case: that target invokes QEMU.
For a native debugging session, use GDB directly rather than the QEMU-remote
script:

```sh
gdb -q ./build/neon_dot_benchmark
(gdb) break neon_dot_product
(gdb) run
(gdb) info registers x0 x1 x2 v0 v1 v2 v3 v4
```

A successful run has the output shown at the top of this document, including
`dot product: 18046484 (verified equal)`. These are valid performance numbers
for the README result table.

## x86_64 Linux: cross compile and QEMU user mode

These commands use Debian or Ubuntu packages. `libc6-arm64-cross` supplies the
Linux AArch64 dynamic-loader and library sysroot used by `qemu-aarch64 -L`.

```sh
sudo apt update
sudo apt install make qemu-user gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  binutils-aarch64-linux-gnu libc6-arm64-cross gdb-multiarch

make clean
make all
make run
make disasm
make gdb GDB=gdb-multiarch
```

The expected program output is the same correctness line, followed by three
timing lines. **Do not submit QEMU timings as benchmark results.** QEMU
user-mode emulation does not reproduce the instruction timing, memory system,
or scheduling of the target CPU. It is useful here for build validation,
correctness verification, disassembly, and inspecting guest register state
only.

If the sysroot is installed somewhere else, pass its directory explicitly:

```sh
make run SYSROOT=/path/to/aarch64-linux-gnu
```

## macOS on Apple Silicon (native arm64)

Install a native compiler and LLVM tools with Homebrew:

```sh
brew install llvm make
export PATH="$(brew --prefix llvm)/bin:$PATH"
```

The checked-in Makefile defaults to `aarch64-linux-gnu-g++` and the assembly
contains ELF metadata directives, so it is Linux-oriented and cannot be used
unchanged for Mach-O. Build a temporary Mach-O-compatible copy with the
ELF-only directives removed, then invoke the native compiler directly:

```sh
mkdir -p build
sed -e '/^[[:space:]]*\.type /d' \
    -e '/^[[:space:]]*\.size /d' \
    -e '/^[[:space:]]*\.section \.note\.GNU-stack/d' \
    neon_dot.s > build/neon_dot_macos.s
clang++ -O3 -g -Wall -Wextra -Wpedantic -std=c++20 -c dot_benchmark.cpp -o build/dot_benchmark.o
clang -g -c build/neon_dot_macos.s -o build/neon_dot.o
clang++ -g build/dot_benchmark.o build/neon_dot.o -o build/neon_dot_benchmark
./build/neon_dot_benchmark
llvm-objdump --macho --disassemble --demangle build/neon_dot_benchmark > build/dot_benchmark.dis
```

The expected output includes the same verified scalar result. This is native
hardware and may be submitted to the results table. Use LLDB for a native
macOS debugging session; `gdb_neon.gdb` is specifically a QEMU-remote script.

```sh
lldb ./build/neon_dot_benchmark
(lldb) breakpoint set --name neon_dot_product
(lldb) run
(lldb) register read x0 x1 x2 v0 v1 v2 v3 v4
```

## macOS on Intel, or other x86 hosts

Use a Linux environment with QEMU user mode and the Linux cross toolchain.
Docker Desktop is one reproducible route on macOS Intel; it produces the same
correctness-only result as the x86_64 Linux section.

```sh
brew install --cask docker
# Start Docker Desktop once, then from the repository root:
docker run --rm --platform linux/amd64 -v "$PWD":/src -w /src ubuntu:24.04 \
  bash -lc 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y make qemu-user gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu libc6-arm64-cross && make clean && make run'
```

Successful output again contains `dot product: 18046484 (verified equal)`.
The timing values are QEMU emulation data and must not be reported as native
benchmark results. On non-macOS x86 systems, install the equivalent QEMU-user,
AArch64 cross-GCC/G++, binutils, and AArch64 Linux sysroot packages, then use
the commands in the x86_64 Linux section.

## Android arm64 via Termux (native hardware)

Termux executes the generated AArch64 code directly, requires no root access,
and is a practical way to obtain a real ARM64 result. Install Termux from a
current supported distribution, then run the following inside Termux:

```sh
pkg update
pkg install clang make binutils gdb

make clean
make all CXX=clang++ OBJDUMP=llvm-objdump
./build/neon_dot_benchmark
make disasm CXX=clang++ OBJDUMP=llvm-objdump
```

Do not use `make run` on-device because its command is for a Linux cross binary
under QEMU. Direct execution above is native and its output should include
`dot product: 18046484 (verified equal)`; those timings can be submitted as
native results. Android frequency governors and thermal throttling can strongly
affect the measurement, so capture the device model and conditions in the PR.

For a direct debug session:

```sh
gdb -q ./build/neon_dot_benchmark
(gdb) break neon_dot_product
(gdb) run
(gdb) info registers x0 x1 x2 v0 v1 v2 v3 v4
```

## Contributing benchmark results

1. Fork the repository and create a branch named
   `benchmark/<platform>-<cpu>-<compiler>`; for example,
   `benchmark/android-sd8gen2-clang`.
2. Follow the applicable native section above and run `make run` where that
   command is applicable, or the documented direct native executable command.
   Capture the complete program output and the compiler version
   (`g++ --version` or `clang++ --version`).
3. For a native run, add one row to the [README results table](README.md#results)
   with platform, CPU model, C++ ns/dot, NEON asm ns/dot, and the printed
   speedup multiplier.
4. Open a PR using the following description template:

```text
Platform / OS:
CPU model:
Compiler and version:
Build command:
Execution mode: native | QEMU user mode
Full benchmark output:

For QEMU only: correctness-only, not performance-representative
```

Only native hardware measurements belong in the main README results table.
QEMU-only PRs are welcome as validation reports, but should add their platform
to a separate `Correctness verified on` list in the PR description or an
appropriate follow-up documentation change, clearly marked
`correctness-only, not perf-representative`.
