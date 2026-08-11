// AArch64 NEON dot product for signed int32_t inputs.
//
// int64_t neon_dot_product(const int32_t *a, const int32_t *b, size_t count)
//   x0 = a, x1 = b, x2 = count; result returned in x0.
//
// Each vector iteration handles four int32_t elements.  SMULL/SMULL2 widen
// the low and high halves independently, so the accumulation is exact in
// signed 64-bit lanes rather than wrapping at 32 bits.

    .text
    .align  2
    .global neon_dot_product
    .type   neon_dot_product, %function
neon_dot_product:
    movi    v0.2d, #0              // two signed 64-bit accumulators

.Lvector:
    cmp     x2, #4
    b.lo    .Ltail

    ldr     q1, [x0], #16          // a[0..3], then advance a
    ldr     q2, [x1], #16          // b[0..3], then advance b
    smull   v3.2d, v1.2s, v2.2s    // products for elements 0 and 1
    smull2  v4.2d, v1.4s, v2.4s    // products for elements 2 and 3
    add     v0.2d, v0.2d, v3.2d
    add     v0.2d, v0.2d, v4.2d
    sub     x2, x2, #4
    b       .Lvector

.Ltail:
    // Horizontally reduce the two 64-bit NEON accumulator lanes.
    umov    x3, v0.d[0]
    umov    x4, v0.d[1]
    add     x3, x3, x4

.Ltail_loop:
    cbz     x2, .Ldone
    ldr     w4, [x0], #4
    ldr     w5, [x1], #4
    smaddl  x3, w4, w5, x3         // signed 32 x signed 32 + 64-bit sum
    sub     x2, x2, #1
    b       .Ltail_loop

.Ldone:
    mov     x0, x3
    ret

    .size neon_dot_product, .-neon_dot_product
    .section .note.GNU-stack,"",@progbits
