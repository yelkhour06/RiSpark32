 .section .text


##########
.section .irq_vector, "ax"	   # Define a section for IRQ routines, allocatable + executable
    .align  2			   # Align to 4 bytes (2^2)
    .global _irq_vector_start
_irq_vector_start:    

    #irq entry
    addi sp, sp, -2*4
    sw t0, 0(sp)
    sw t1, 1*4(sp)

    li t0, 0x10000000
    li t1, 0x30
    sw t1, 0(t0)
    
    #irq exit
    lw t0, 0(sp)
    lw t1, 1*4(sp)
    addi sp, sp, 2*4
    mret

