# `?=` would retain make's built-in host CXX=g++, so use explicit cross-tool
# defaults. Command-line assignments (for example CXX=clang++) still override.
CXX      := aarch64-linux-gnu-g++
OBJDUMP  := aarch64-linux-gnu-objdump
QEMU     := qemu-aarch64
GDB      := gdb
SYSROOT  := /usr/aarch64-linux-gnu

BUILD    := build
TARGET   := $(BUILD)/neon_dot_benchmark
CXXFLAGS := -O3 -g -Wall -Wextra -Wpedantic -std=c++20

.PHONY: all run disasm gdb clean

all: $(TARGET)

$(BUILD):
	mkdir -p $@

$(BUILD)/dot_benchmark.o: dot_benchmark.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD)/neon_dot.o: neon_dot.s | $(BUILD)
	$(CXX) -g -c $< -o $@

$(TARGET): $(BUILD)/dot_benchmark.o $(BUILD)/neon_dot.o
	$(CXX) -g $^ -o $@

run: $(TARGET)
	$(QEMU) -L $(SYSROOT) $(TARGET)

disasm: $(TARGET)
	$(OBJDUMP) -d -C -S $(TARGET) > $(BUILD)/dot_benchmark.dis
	@echo "Wrote $(BUILD)/dot_benchmark.dis"

gdb: $(TARGET)
	@set -e; $(QEMU) -L $(SYSROOT) -g 1234 $(TARGET) & qemu_pid=$$!; trap 'kill $$qemu_pid 2>/dev/null || true' EXIT; sleep 0.2; $(GDB) -q $(TARGET) -x gdb_neon.gdb

clean:
	rm -rf $(BUILD)
