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

These steps target Debian or Ubuntu running directly on AArch64. The native
`g++` already emits AArch64 code; a cross-compiler prefix is not required.

1. Check that this is an AArch64 host and whether the required tools exist:

   ```sh
   uname -m
   command -v make g++ objdump gdb
   ```

   `uname -m` should print `aarch64` (or `arm64`). Each `command -v` lookup
   should print a path.

2. If any tool is missing, install the native toolchain and debugger. Repeating
   this command is safe when they are already installed:

   ```sh
   sudo apt update
   sudo apt install build-essential binutils gdb
   ```

   Install `gdb-multiarch` only if the supplied `gdb` does not support
   AArch64:

   ```sh
   sudo apt install gdb-multiarch
   ```

3. Remove an old build and compile the native executable:

   ```sh
   make clean
   make all CXX=g++ OBJDUMP=objdump
   ```

4. Run it directly on the CPU:

   ```sh
   ./build/neon_dot_benchmark
   ```

   The output must contain `dot product: 18046484 (verified equal)`. These are
   native timings and may be entered in the README results table.

5. Generate and inspect the disassembly:

   ```sh
   make disasm CXX=g++ OBJDUMP=objdump
   less build/dot_benchmark.dis
   ```

6. For native register inspection, start GDB directly. Do not use `make gdb`,
   which is for QEMU remote debugging:

   ```sh
   gdb -q ./build/neon_dot_benchmark
   (gdb) break neon_dot_product
   (gdb) run
   (gdb) info registers x0 x1 x2 v0 v1 v2 v3 v4
   ```

## x86_64 Linux: cross compile and QEMU user mode

These steps use Debian or Ubuntu packages. `libc6-arm64-cross` provides the
AArch64 Linux dynamic-loader and library sysroot used by `qemu-aarch64 -L`.

1. Confirm that the host is x86_64 and check every required program:

   ```sh
   uname -m
   command -v make qemu-aarch64 aarch64-linux-gnu-g++ aarch64-linux-gnu-objdump gdb-multiarch
   ```

   The first command should normally print `x86_64`. A missing program produces
   no path in the second command.

2. If any item is missing, install the complete cross-build and debugging set:

   ```sh
   sudo apt update
   sudo apt install make qemu-user gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
     binutils-aarch64-linux-gnu libc6-arm64-cross gdb-multiarch
   ```

3. Remove old outputs, then cross-compile the AArch64 Linux executable:

   ```sh
   make clean
   make all
   ```

4. Run it through QEMU user mode:

   ```sh
   make run
   ```

   It must print `dot product: 18046484 (verified equal)`.

5. Generate the AArch64 disassembly and inspect it:

   ```sh
   make disasm
   less build/dot_benchmark.dis
   ```

6. Inspect guest registers using QEMU's GDB stub:

   ```sh
   make gdb GDB=gdb-multiarch
   ```

   The command file stops at entry and after the first vector iteration.

**Do not submit QEMU timings as benchmark results.** QEMU user-mode emulation
does not reproduce the target CPU's instruction timing, memory system, or
scheduling. It is useful only for build validation, correctness verification,
disassembly, and guest register inspection. If the sysroot is elsewhere, run:

```sh
make run SYSROOT=/path/to/aarch64-linux-gnu
```

## macOS on Apple Silicon (native arm64)

1. Verify that the host is Apple Silicon and check for Homebrew:

   ```sh
   uname -m
   command -v brew make
   ```

   `uname -m` must print `arm64`. If `brew` has no path, install Homebrew:

   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Check for the compiler and disassembler provided by Homebrew:

   ```sh
   brew list --versions llvm
   ```

   If LLVM is absent, install it:

   ```sh
   brew install llvm
   ```

3. Put the Homebrew LLVM tools first in `PATH` for this terminal, then verify
   that the selected compiler is available:

   ```sh
   export PATH="$(brew --prefix llvm)/bin:$PATH"
   command -v clang clang++ llvm-objdump lldb
   ```

4. The checked-in Makefile targets AArch64 Linux and the assembly contains
   ELF-only metadata directives. Create a temporary Mach-O-compatible assembly
   source with those metadata lines removed:

   ```sh
   rm -rf build
   mkdir -p build
   sed -e '/^[[:space:]]*\.type /d' \
       -e '/^[[:space:]]*\.size /d' \
       -e '/^[[:space:]]*\.section \.note\.GNU-stack/d' \
       neon_dot.s > build/neon_dot_macos.s
   ```

5. Compile and link the native ARM64 executable:

   ```sh
   clang++ -O3 -g -Wall -Wextra -Wpedantic -std=c++20 -c dot_benchmark.cpp -o build/dot_benchmark.o
   clang -g -c build/neon_dot_macos.s -o build/neon_dot.o
   clang++ -g build/dot_benchmark.o build/neon_dot.o -o build/neon_dot_benchmark
   ```

6. Run it directly and check the result:

   ```sh
   ./build/neon_dot_benchmark
   ```

   It must include `dot product: 18046484 (verified equal)`. This is native
   hardware and may be submitted to the results table.

7. Disassemble the Mach-O executable:

   ```sh
   llvm-objdump --macho --disassemble --demangle build/neon_dot_benchmark > build/dot_benchmark.dis
   less build/dot_benchmark.dis
   ```

8. Use LLDB for native register inspection; `gdb_neon.gdb` is a QEMU-remote
   command file and is not used here:

   ```sh
   lldb ./build/neon_dot_benchmark
   (lldb) breakpoint set --name neon_dot_product
   (lldb) run
   (lldb) register read x0 x1 x2 v0 v1 v2 v3 v4
   ```

## macOS on Intel, or other x86 hosts

Docker Desktop provides a reproducible Linux environment with QEMU user mode.

1. Verify the host architecture and whether Docker is installed:

   ```sh
   uname -m
   command -v docker
   ```

   Intel Macs normally print `x86_64`. If Docker is missing, install it:

   ```sh
   brew install --cask docker
   ```

2. Start Docker Desktop, then verify that its daemon is available:

   ```sh
   docker version
   ```

3. From the repository root, start an x86_64 Ubuntu container. It installs the
   cross toolchain inside the container, builds the project, and runs QEMU:

   ```sh
   docker run --rm --platform linux/amd64 -v "$PWD":/src -w /src ubuntu:24.04 \
     bash -lc 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y make qemu-user gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu libc6-arm64-cross && make clean && make all && make run'
   ```

   The output must contain `dot product: 18046484 (verified equal)`. It is a
   QEMU correctness result only, not native performance data. On other x86
   hosts, use the equivalent QEMU-user, AArch64 cross-GCC/G++, binutils, and
   AArch64 Linux sysroot packages, then follow the x86_64 Linux steps above.

## Android arm64 via Termux (native hardware)

Termux executes the generated AArch64 code directly and requires no root
access. Install Termux from a current supported distribution, then work inside
the Termux shell.

1. Confirm that the phone is 64-bit ARM and check the package manager:

   ```sh
   uname -m
   command -v pkg
   ```

   The architecture should be `aarch64`. If `pkg` is not found, this is not a
   Termux shell.

2. Check the required programs:

   ```sh
   command -v clang clang++ make llvm-objdump gdb
   ```

3. If any program is missing, refresh the Termux package metadata and install
   the complete set. Repeating the command is safe:

   ```sh
   pkg update
   pkg install clang make binutils gdb
   ```

4. Remove old outputs and compile with Termux's native Clang:

   ```sh
   make clean
   make all CXX=clang++ OBJDUMP=llvm-objdump
   ```

5. Run the binary directly on the Android device:

   ```sh
   ./build/neon_dot_benchmark
   ```

   It must include `dot product: 18046484 (verified equal)`. This is a native
   ARM64 run, so its timings may be submitted as results.

6. Generate the disassembly:

   ```sh
   make disasm CXX=clang++ OBJDUMP=llvm-objdump
   less build/dot_benchmark.dis
   ```

7. Inspect registers with GDB:

   ```sh
   gdb -q ./build/neon_dot_benchmark
   (gdb) break neon_dot_product
   (gdb) run
   (gdb) info registers x0 x1 x2 v0 v1 v2 v3 v4
   ```

Do not use `make run` on-device because that target starts QEMU for an AArch64
Linux cross binary. Android frequency governors and thermal throttling can
strongly affect timings, so record device conditions in the PR.

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
