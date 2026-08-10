.global _start       
.section .text       

_start:             
    ldr R0, =values
    ldm R0, {R1-R8}
    
.section .data       
values:              
    .word 1,2,3,4,5,6,7,8
