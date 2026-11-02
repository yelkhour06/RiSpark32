# 0 "dhrystone/start.S"
# 0 "<built-in>"
# 0 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3 4
# 0 "<command-line>" 2
# 1 "dhrystone/start.S"
 .section .text
 .global _start
 .global main

_start:

 #initialize reg used in irq routine
 addi x2, zero, 0
 addi x3, zero, 0
  
 #Enable timer irq
 #li x1, 0x01000000
 #li x2, 0x75
 #csrrw zero, 0x4, x2
 #li x2, 0x1
 #csrrw zero, 0x0, x2
 #addi x1, zero, 0x0
 #addi x2, zero, 0x0


 lui a0,0x10000000>>12
 addi a1,zero,'S'
 addi a2,zero,'T'
 addi a3,zero,'A'
 addi a4,zero,'R'
 addi a5,zero,'\n'
 sw a1,0(a0)
 sw a2,0(a0)
 sw a3,0(a0)
 sw a4,0(a0)
 sw a2,0(a0)
 sw a5,0(a0)


 lui a0,0
 auipc a0,0
 slli a0,a0,0
 slli a0,a0,31
 addi a1,zero,0
 sll a0,a0,a1
 addi a1,zero,31
 sll a0,a0,a1


 lui sp,(64*1024)>>12


 jal ra,main


 lui a0,0x10000000>>12
 addi a1,zero,'D'
 addi a2,zero,'O'
 addi a3,zero,'N'
 addi a4,zero,'E'
 addi a5,zero,'\n'
 sw a1,0(a0)
 sw a2,0(a0)
 sw a3,0(a0)
 sw a4,0(a0)
 sw a5,0(a0)


 ebreak
