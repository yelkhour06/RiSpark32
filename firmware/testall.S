.section .text
//.balign 16


#undef RVTEST_CODE_BEGIN
#define TEST_NAME "addi"
#define RVTEST_CODE_BEGIN .macro test_addi
#define fail  fail_addi
#define pass  pass_addi
#include "../tests/addi.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "add"
#define RVTEST_CODE_BEGIN .macro test_add
#define fail  fail_add
#define pass  pass_add
#include "../tests/add.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "andi"
#define RVTEST_CODE_BEGIN .macro test_andi
#define fail  fail_andi
#define pass  pass_andi
#include "../tests/andi.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "and"
#define RVTEST_CODE_BEGIN .macro test_and
#define fail  fail_and
#define pass  pass_and
#include "../tests/and.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "ori"
#define RVTEST_CODE_BEGIN .macro test_ori
#define fail  fail_ori
#define pass  pass_ori 
#include "../tests/ori.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "or"
#define RVTEST_CODE_BEGIN .macro test_or
#define fail  fail_or
#define pass  pass_or
#include "../tests/or.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "slli"
#define RVTEST_CODE_BEGIN .macro test_slli
#define fail  fail_slli
#define pass  pass_slli
#include "../tests/slli.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "sll"
#define RVTEST_CODE_BEGIN .macro test_sll
#define fail  fail_sll
#define pass  pass_sll 
#include "../tests/sll.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "slti"
#define RVTEST_CODE_BEGIN .macro test_slti
#define fail  fail_slti
#define pass  pass_slti
#include "../tests/slti.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "slt"
#define RVTEST_CODE_BEGIN .macro test_slt
#define fail  fail_slt
#define pass  pass_slt 
#include "../tests/slt.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "srai"
#define RVTEST_CODE_BEGIN .macro test_srai
#define fail  fail_srai
#define pass  pass_srai
#include "../tests/srai.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "sra"
#define RVTEST_CODE_BEGIN .macro test_sra
#define fail  fail_sra
#define pass  pass_sra 
#include "../tests/sra.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "srli"
#define RVTEST_CODE_BEGIN .macro test_srli
#define fail  fail_srli
#define pass  pass_srli
#include "../tests/srli.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "srl"
#define RVTEST_CODE_BEGIN .macro test_srl
#define fail  fail_srl
#define pass  pass_srl 
#include "../tests/srl.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "sub"
#define RVTEST_CODE_BEGIN .macro test_sub
#define fail  fail_sub
#define pass  pass_sub 
#include "../tests/sub.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "xori"
#define RVTEST_CODE_BEGIN .macro test_xori
#define fail  fail_xori
#define pass  pass_xori
#include "../tests/xori.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "xor"
#define RVTEST_CODE_BEGIN .macro test_xor
#define fail  fail_xor
#define pass  pass_xor 
#include "../tests/xor.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "auipc"
#define RVTEST_CODE_BEGIN .macro test_auipc
#define fail  fail_auipc
#define pass  pass_auipc
#include "../tests/auipc.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "beq"
#define RVTEST_CODE_BEGIN .macro test_beq
#define fail  fail_beq
#define pass  pass_beq
#include "../tests/beq.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "bge"
#define RVTEST_CODE_BEGIN .macro test_bge
#define fail  fail_bge
#define pass  pass_bge
#include "../tests/bge.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "bgeu"
#define RVTEST_CODE_BEGIN .macro test_bgeu
#define fail  fail_bgeu
#define pass  pass_bgeu 
#include "../tests/bgeu.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "blt"
#define RVTEST_CODE_BEGIN .macro test_blt
#define fail  fail_blt
#define pass  pass_blt 
#include "../tests/blt.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "bltu"
#define RVTEST_CODE_BEGIN .macro test_bltu
#define fail  fail_bltu
#define pass  pass_bltu
#include "../tests/bltu.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "bne"
#define RVTEST_CODE_BEGIN .macro test_bne
#define fail  fail_bne
#define pass  pass_bne 
#include "../tests/bne.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "mulhu"
#define RVTEST_CODE_BEGIN .macro test_mulhu
#define fail  fail_mulhu
#define pass  pass_mulhu
#include "../tests/mulhu.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "div"
#define RVTEST_CODE_BEGIN .macro test_div
#define fail  fail_div
#define pass  pass_div 
#include "../tests/div.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "divu"
#define RVTEST_CODE_BEGIN .macro test_divu
#define fail  fail_divu
#define pass  pass_divu 
#include "../tests/divu.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "mulh"
#define RVTEST_CODE_BEGIN .macro test_mulh
#define fail  fail_mulh
#define pass  pass_mulh
#include "../tests/mulh.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "mulhsu"
#define RVTEST_CODE_BEGIN .macro test_mulhsu
#define fail  fail_mulhsu
#define pass  pass_mulshu
#include "../tests/mulhsu.S"
#undef fail
#undef pass
#undef TEST_NAME 
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "mul"
#define RVTEST_CODE_BEGIN .macro test_mul
#define fail  fail_mul
#define pass  pass_mul 
#include "../tests/mul.S"
#undef fail
#undef pass
#undef TEST_NAME 
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "rem"
#define RVTEST_CODE_BEGIN .macro test_rem
#define fail  fail_rem
#define pass  pass_rem 
#include "../tests/rem.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define TEST_NAME "remu"
#define RVTEST_CODE_BEGIN .macro test_remu
#define fail  fail_remu
#define pass  pass_remu
#include "../tests/remu.S"
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define TEST_NAME "lb"
#define RVTEST_CODE_BEGIN .macro test_lb
#define tdat  lb_tdat
#define tdat1 lb_tdat1
#define tdat2 lb_tdat2
#define tdat3 lb_tdat3
#define tdat4 lb_tdat4
#define fail  fail_lb
#define pass  pass_lb 
#include "../tests/lb.S"
#undef fail
#undef pass
#undef tdat
#undef tdat1
#undef tdat2
#undef tdat3
#undef tdat4
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define tdat  lbu_tdat
#define tdat1 lbu_tdat1
#define tdat2 lbu_tdat2
#define tdat3 lbu_tdat3
#define tdat4 lbu_tdat4
#define TEST_NAME "lbu" 
#define RVTEST_CODE_BEGIN .macro test_lbu
#define fail  fail_lbu
#define pass  pass_lbu 
#include "../tests/lbu.S"
#undef tdat
#undef tdat1
#undef tdat2
#undef tdat3
#undef tdat4
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define tdat  lh_tdat
#define tdat1 lh_tdat1
#define tdat2 lh_tdat2
#define tdat3 lh_tdat3
#define tdat4 lh_tdat4
#define TEST_NAME "lh"
#define RVTEST_CODE_BEGIN .macro test_lh
#define fail  fail_lh
#define pass  pass_lh 
#include "../tests/lh.S"
#undef tdat
#undef tdat1
#undef tdat2
#undef tdat3
#undef tdat4
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN .macro test_lhu
#define tdat  lhu_tdat
#define tdat1 lhu_tdat1
#define tdat2 lhu_tdat2
#define tdat3 lhu_tdat3
#define tdat4 lhu_tdat4 
#define TEST_NAME "lhu" 
#define fail  fail_lhu
#define pass  pass_lhu 
#include "../tests/lhu.S"
#undef tdat
#undef tdat1
#undef tdat2
#undef tdat3
#undef tdat4
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN .macro test_lw
#define tdat  lw_tdat
#define tdat1 lw_tdat1
#define tdat2 lw_tdat2
#define tdat3 lw_tdat3
#define tdat4 lw_tdat4
#define fail  fail_lw
#define pass  pass_lw
#define TEST_NAME "lw" 
#include "../tests/lw.S"
#undef tdat
#undef tdat1
#undef tdat2
#undef tdat3
#undef tdat4
#undef fail
#undef pass
#undef TEST_NAME 
 
#undef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN .macro test_sb
#define tdat  sb_tdat
#define tdat1 sb_tdat1
#define tdat2 sb_tdat2
#define tdat3 sb_tdat3
#define tdat4 sb_tdat4
#define tdat5 sb_tdat5
#define tdat6 sb_tdat6
#define tdat7 sb_tdat7
#define tdat8 sb_tdat8
#define tdat9 sb_tdat9
#define tdat10 sb_tdat10 
#define fail  fail_sb
#define pass  pass_sb 
#define TEST_NAME "sb"
#include "../tests/sb.S"
#undef tdat
#undef tdat1
#undef tdat2
#undef tdat3
#undef tdat4
#undef tdat5
#undef tdat6
#undef tdat7
#undef tdat8
#undef tdat9
#undef tdat10 
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN .macro test_sh
#define tdat  sh_tdat
#define tdat1 sh_tdat1
#define tdat2 sh_tdat2
#define tdat3 sh_tdat3
#define tdat4 sh_tdat4
#define tdat5 sh_tdat5
#define tdat6 sh_tdat6
#define tdat7 sh_tdat7
#define tdat8 sh_tdat8
#define tdat9 sh_tdat9
#define tdat10 sh_tdat10
#define fail  fail_sh
#define pass  pass_sh
#define TEST_NAME "sh" 
#include "../tests/sh.S"
#undef tdat
#undef tdat1
#undef tdat2
#undef tdat3
#undef tdat4
#undef tdat5
#undef tdat6
#undef tdat7
#undef tdat8
#undef tdat9
#undef tdat10
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN .macro test_sw
#define tdat  sw_tdat
#define tdat1 sw_tdat1
#define tdat2 sw_tdat2
#define tdat3 sw_tdat3
#define tdat4 sw_tdat4
#define tdat5 sw_tdat5
#define tdat6 sw_tdat6
#define tdat7 sw_tdat7
#define tdat8 sw_tdat8
#define tdat9 sw_tdat9
#define tdat10 sw_tdat10
#define fail  fail_sw
#define pass  pass_sw
#define TEST_NAME "sw"
#include "../tests/sw.S"
#undef tdat
#undef tdat1
#undef tdat2
#undef tdat3
#undef tdat4
#undef tdat5
#undef tdat6
#undef tdat7
#undef tdat8
#undef tdat9
#undef tdat10
#undef fail
#undef pass
#undef TEST_NAME

#undef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN .macro test_jalr
#define fail  fail_jalr
#define pass  pass_jalr
#define TEST_NAME "jalr"
#include "../tests/jalr.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN .macro test_jal
#define fail  fail_jal
#define pass  pass_jal
#define TEST_NAME "jal" 
#include "../tests/jal.S"
#undef fail
#undef pass
#undef TEST_NAME
 
#undef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN .macro test_j
#define fail  fail_j
#define pass  pass_j
#define TEST_NAME "j"
#include "../tests/j.S"
#undef fail
#undef pass
#undef TEST_NAME 
 
#undef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN .macro test_lui
#define fail  fail_lui
#define pass  pass_lui 
#define TEST_NAME "lui"
#include "../tests/lui.S"
#undef fail
#undef pass
#undef TEST_NAME 
 

.global _start
_start:	
	/* zero-initialize all registers */
	addi x1, zero, 0
	addi x2, zero, 0
	addi x3, zero, 0
	addi x4, zero, 0
	addi x5, zero, 0
	addi x6, zero, 0
	addi x7, zero, 0
	addi x8, zero, 0
	addi x9, zero, 0
	addi x10, zero, 0
	addi x11, zero, 0
	addi x12, zero, 0
	addi x13, zero, 0
	addi x14, zero, 0
	addi x15, zero, 0
	addi x16, zero, 0
	addi x17, zero, 0
	addi x18, zero, 0
	addi x19, zero, 0
	addi x20, zero, 0
	addi x21, zero, 0
	addi x22, zero, 0
	addi x23, zero, 0
	addi x24, zero, 0
	addi x25, zero, 0
	addi x26, zero, 0
	addi x27, zero, 0
	addi x28, zero, 0
	addi x29, zero, 0
	addi x30, zero, 0
	addi x31, zero, 0
	

	test_mulhsu
	test_mulhu	
	test_mul
	test_mulh
	test_divu
	test_rem
	test_remu
	test_div

	test_slti
	test_xori
	test_ori
	test_andi
	test_slli
	test_srli
	test_srai
	
	test_add
	test_sub
	test_sll
	test_slt
	test_xor
	test_srl
	test_sra
	test_or
	test_and		

	test_bltu
	test_bge
	test_beq
	test_bne
	test_bgeu
	test_blt

	test_lb
	test_lh
	test_lw
	test_lbu
	test_lhu

	test_sb
	test_sh
	test_sw


	test_auipc	
	test_lui	
	test_j
	test_jal
	test_jalr
	
	ebreak        //End test here
		


