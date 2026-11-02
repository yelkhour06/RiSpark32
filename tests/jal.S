# See LICENSE for license details.

#*****************************************************************************
# jal.S
#-----------------------------------------------------------------------------
#
# Test jal instruction.
#

#include "riscv_allmacros.h"
#include "test_macros.h"

.option norvc

RVTEST_RV32U
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # Test 2: Basic test
  #-------------------------------------------------------------

test_2_jal:
  li  TESTNUM, 2
  li  ra, 0

linkaddr_2_jal:
  jal target_2_jal
  nop
  nop

  j fail

target_2_jal:
  la  x2, linkaddr_2_jal
  addi x2, x2, 4
  bne x2, ra, fail

  #-------------------------------------------------------------
  # Test delay slot instructions not executed nor bypassed
  #-------------------------------------------------------------

  TEST_CASE( 3, jal, x2, 3, \
    li  x2, 1; \
    jal 1f; \
    addi x2, x2, 1; \
    addi x2, x2, 1; \
    addi x2, x2, 1; \
    addi x2, x2, 1; \
1:  addi x2, x2, 1; \
    addi x2, x2, 1; \
  )

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
