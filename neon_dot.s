// AArch64 NEON dot product for signed int32_t inputs.
//
// int64_t neon_dot_product(const int32_t *a, const int32_t *b, size_t count)
//   x0 = a, x1 = b, x2 = count; result returned in x0.
//
// The main loop handles 16 int32_t elements with four independent signed
// 64-bit NEON accumulators.  SMLAL/SMLAL2 widen and multiply-accumulate the
// low and high halves independently, so accumulation is exact in int64_t.

    .text
    .align  2
    .global neon_dot_product
    .type   neon_dot_product, %function
neon_dot_product:
    movi    v0.2d, #0
    movi    v1.2d, #0
    movi    v2.2d, #0
    movi    v3.2d, #0

.Lvector16:
    cmp     x2, #16
    b.lo    .Lvector4

    ldp     q4, q5, [x0], #32
    ldp     q6, q7, [x1], #32
    smlal   v0.2d, v4.2s, v6.2s
    smlal2  v0.2d, v4.4s, v6.4s
    smlal   v1.2d, v5.2s, v7.2s
    smlal2  v1.2d, v5.4s, v7.4s

    ldp     q4, q5, [x0], #32
    ldp     q6, q7, [x1], #32
    smlal   v2.2d, v4.2s, v6.2s
    smlal2  v2.2d, v4.4s, v6.4s
    smlal   v3.2d, v5.2s, v7.2s
    smlal2  v3.2d, v5.4s, v7.4s
    sub     x2, x2, #16
    b       .Lvector16

.Lvector4:
    cmp     x2, #4
    b.lo    .Ltail

    ldr     q4, [x0], #16
    ldr     q5, [x1], #16
    smlal   v0.2d, v4.2s, v5.2s
    smlal2  v0.2d, v4.4s, v5.4s
    sub     x2, x2, #4
    b       .Lvector4

.Ltail:
    add     v0.2d, v0.2d, v1.2d
    add     v2.2d, v2.2d, v3.2d
    add     v0.2d, v0.2d, v2.2d
    umov    x3, v0.d[0]
    umov    x4, v0.d[1]
    add     x3, x3, x4

.Ltail_loop:
    cbz     x2, .Ldone
    ldr     w4, [x0], #4
    ldr     w5, [x1], #4
    smaddl  x3, w4, w5, x3
    sub     x2, x2, #1
    b       .Ltail_loop

.Ldone:
    mov     x0, x3
    ret

    .size neon_dot_product, .-neon_dot_product
    .section .note.GNU-stack,"",@progbits
