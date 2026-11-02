##########
.section .text

.global _start

.macro INITIALIZE
	add x1, zero, 0
	add x2, zero, 0
	add x3, zero, 0
	add x4, zero, 0
	add x5, zero, 0
	add x6, zero, 0
	add x7, zero, 0
	add x8, zero, 0
	add x9, zero, 0
	add x10, zero, 0
	add x11, zero, 0
	add x12, zero, 0
	add x13, zero, 0
	add x14, zero, 0
	add x15, zero, 0
	add x16, zero, 0
	add x17, zero, 0
	add x18, zero, 0
	add x19, zero, 0
	add x20, zero, 0
	add x21, zero, 0
	add x22, zero, 0
	add x23, zero, 0
	add x24, zero, 0
	addi x25, zero, 0
	addi x26, zero, 0
	addi x27, zero, 0
	addi x28, zero, 0
	addi x29, zero, 0
	addi x30, zero, 0
	//addi x31, zero, 0
	li x31, 0x10000000
.endm

.macro PRINT_HEX reg_value reg_dest reg_tmp reg_tmp2 reg_tmp3
	addi \reg_tmp, \reg_value, 0
	andi \reg_tmp, \reg_tmp, 0xFF    //print only 8 lsb
	li \reg_tmp2, 0
	li \reg_tmp3, 10
	bltu \reg_tmp, \reg_tmp3, print_less_than_10
	
        fing_nb_10:
	 sub  \reg_tmp, \reg_tmp, \reg_tmp3
	 addi \reg_tmp2, \reg_tmp2, 1
	 bgeu \reg_tmp, \reg_tmp3, fing_nb_10
	
	print_less_than_10:
	
	 addi \reg_tmp2, \reg_tmp2, 0x30   //0x30 = 0 in Ascii
	 sb \reg_tmp2,0(\reg_dest)

         addi \reg_tmp, \reg_tmp, 0x30
	 sb \reg_tmp,0(\reg_dest)

	 addi \reg_tmp, zero, 0xA          //0xA = EOL in Ascii
	 sb \reg_tmp,0(\reg_dest)	
.endm

.macro INIT_LOOP start_nb end_nb reg_index reg_end
	li \reg_index, \start_nb
	li \reg_end, \end_nb
.endm	

.macro LOOP section_loop reg_index reg_end
	addi \reg_index, \reg_index, 1
	bltu \reg_index, \reg_end, \section_loop	
.endm
    
.macro FIND_FIRST_NULL ok_section end_section reg_start reg_end reg_tmp
	5:	
	  addi \reg_start, \reg_start, 1
	  lbu \reg_tmp, 0(\reg_start)
	  beq \reg_start, \reg_end, \end_section	  
	  beq  \reg_tmp, zero, \ok_section
	  bne  \reg_tmp, zero, 5b
.endm

.macro DEBUG_V value
	 addi x6, zero, \value
	 andi x6, x6, 0xFF	 
	 PRINT_HEX x6 x31 x7 x8 x9	 
.endm	 

.macro DEBUG_R reg
	 PRINT_HEX \reg x31 x7 x8 x9
.endm

.macro DEBUG_RData reg
	 lbu x6, 0(\reg)
	 PRINT_HEX x6 x31 x7 x8 x9
.endm


.macro FILL_MUL ok_section reg_start reg_end tmp_reg tmp_reg2
          andi \tmp_reg, \reg_start, 0xFF
	1:	  
	  sb \tmp_reg2, 0(\reg_start)
	  add \reg_start, \reg_start, \tmp_reg
	  bgeu  \reg_start, \reg_end, \ok_section	  
	  bltu  \reg_start, \reg_end, 1b	
.endm

.macro READ_PRINT_MEM reg_start reg_start_hex reg_end data_start reg_print
        1:
	  addi \reg_start, \reg_start, 1
	  lbu \data_start, 0(\reg_start)
	  addi \data_start, \data_start, 0x30
	  sb \data_start, 0(\reg_print)
	  addi \data_start, zero, 0xA
	  sb \data_start, 0(\reg_print)
	  bltu \reg_start, \reg_end, 1b
.endm




/****************************************************************/
_start:	

li x31,   0x10000000	 //print 
	   
init_memory:
           //INIT_LOOP 0 99 x1 x2
	   //li x3, 0x100
	   //1:	   
	   //  sb zero, 0(x3)
	   //  addi x3, x3, 1
           //  LOOP 1b x1 x2
	   la x3, array
	   addi x3, x3, 0x100
	   andi x3, x3, 0x100

main_loop:	   
	   //li x20, 0x100+99       //end of work memory					
	   //li x10, 0x100+1       //index of work memory > 1	
	   addi x20, x3, 99
	   addi x10, x3, 1
	   
	   addi x22, zero, 1
	   addi x11, x10, 0
           search_nul:
	   		addi x10, x11, 0
	                FIND_FIRST_NULL null_found end x10 x20 x1
	   
	   null_found:
			DEBUG_R x10
			addi x11, x10, 0
			FILL_MUL search_nul x10 x20 x1 x22			
						
	   end:	
			ebreak 		



.section .data

.balign 512
array:
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
