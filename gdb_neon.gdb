# Run via `make gdb` (or `make gdb GDB=gdb-multiarch`).  QEMU pauses at start,
# this script breaks on the first assembly dot-product call and shows its state.
set pagination off
set sysroot /usr/aarch64-linux-gnu
set architecture aarch64
target remote :1234
break neon_dot_product
continue
printf "\nAt entry (x0=a, x1=b, x2=count):\n"
info registers x0 x1 x2 x3 x4 x5

# Stop after ldr/ldr, smull/smull2, both NEON adds, and the decrement.
tbreak *(neon_dot_product + 40)
continue
printf "\nAfter the first four-element vector iteration:\n"
info registers x0 x1 x2 x3 x4 x5
info registers v0 v1 v2 v3 v4
x/12i $pc
detach
quit
