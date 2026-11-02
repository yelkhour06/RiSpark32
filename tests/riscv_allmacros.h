#ifndef _ENV_RISPARK32_TEST_H
#define _ENV_RISPARK32_TEST_H


#define RVTEST_RV32U
#define TESTNUM x28

#define RVTEST_PASS			\
	la    a0, 2f; 			\
	li    a2,0x10000000;	      	\
1:					\
	lb    a1,0(a0); 	      	\
	sb    a1,0(a2); 	      	\
	addi	a0,a0,1;		\
	bne	a1,zero,1b;		\
	li	a0,0x10000004;		\
	sw	zero,0(a0);		\
	j 	3f; 			\
2:					\
	.asciz TEST_NAME;		\
	.balign 4, 0;			\
3:	
	
	
#define RVTEST_FAIL			\
	la    a0, 2f; 			\
	li    a2,0x10000000;	      	\
1:					\
	lb    a1,0(a0); 	      	\
	sb    a1,0(a2); 	      	\
	addi	a0,a0,1;		\
	bne	a1,zero,1b;		\
	li	a0,0x10000008;		\
	sw	zero,0(a0);		\
	ebreak;				\
	j 	3f; 			\
2:					\
	.asciz TEST_NAME;		\
	.balign 4, 0;			\
3:	
			

#define RVTEST_CODE_END			\
	.endm;
	


#define RVTEST_DATA_BEGIN .balign 4, 0;
#define RVTEST_DATA_END 		\
	.text		


//rest next .text after end of .data

#endif
