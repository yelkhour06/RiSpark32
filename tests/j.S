# See LICENSE for license details.

#*****************************************************************************
# j.S
#-----------------------------------------------------------------------------
#
# Test j instruction.
#

#include "riscv_allmacros.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # Test basic
  #-------------------------------------------------------------

  li  TESTNUM, 2;
  j test_2_j;
  j fail;
test_2_j:

  #-------------------------------------------------------------
  # Test delay slot instructions not executed nor bypassed
  #-------------------------------------------------------------

  TEST_CASE( 3, j, x1, 3, \
    li  x1, 1; \
    j 1f; \
    addi x1, x1, 1; \
    addi x1, x1, 1; \
    addi x1, x1, 1; \
    addi x1, x1, 1; \
1:  addi x1, x1, 1; \
    addi x1, x1, 1; \
  )

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
