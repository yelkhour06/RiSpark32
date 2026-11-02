#include "headertest.S"

##########
.section .irq_vector, "ax"      # Define a section for IRQ routines, allocatable + executable
    .align  2                   # Align to 4 bytes (2^2)
    .global _irq_vector_start
    
    
_irq_vector_start:    
    
    addi sp, sp, -8
    sw x3, 0(sp)
    sw x4, 4(sp)
    
    //li x3, PRINT_REG
    //addi x4, zero, ASCII_BASE0
    //sw x4, 0(x3)
    //addi x4, zero, ASCII_EOL
    //sw x4, 0(x3)
    
    /* clear GPO0 */
    csrrw zero, 0xC, zero


    lw x3, 0(sp)
    lw x4, 0(sp)
    
    addi sp, sp, 8

    mret
