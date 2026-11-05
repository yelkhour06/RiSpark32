#---------- MAKEFILE ... ----------#
SHELL = bash
PYTHON = python3
IVERILOG = iverilog$(ICARUS_SUFFIX)
VVP = vvp$(ICARUS_SUFFIX)


#~~~~~~~~~~~ TESTs Obj/Opt Start .. ~~~~~~~~~~~#
TESTISNT_OBJS = $(addsuffix .o,$(basename $(wildcard tests/*.S)))
TEST_OBJS = firmware/test.S
TESTALL_OBJS = firmware/testall.S
TESTFW_OBJS = firmware/testfw.S
#MAIN_OBJS = coremark/startup.s firmware/coremark_short.c
MAIN_OBJS = coremark/startup.s firmware/snake.c
#IRQ version, enable DELAY_IRQ in code
#MAIN_OBJS = firmware/start_csr.S firmware/irq.S firmware/coremark_short.c
#MAIN_OBJS = firmware/start_csr.S firmware/irq.S firmware/snake.c
#........... TESTs Obj/Opt .. End   ...........#


#~~~~~~~~~~~ DHRYSTONE Obj/Opt Start .. ~~~~~~~~~~~#
TESTDHRYSTONE_OBJS = dhrystone/start.s dhrystone/irq.S dhrystone/dhry_1.c dhrystone/dhry_2.c dhrystone/stdlib.c
TESTDHRYSTONE_F_OBJS = $(notdir $(TESTDHRYSTONE_OBJS))
DHSTONE_CFLAGS = -MD -O3 -mabi=ilp32 -march=rv32im -DTIME -DRISCV \
		-DUSE_MYSTDLIB -ffreestanding -nostdlib \
		-Wno-implicit-int -Wno-implicit-function-declaration \
		-Wl,-Bstatic,-T,sections.lds,-Map,dhry.map,--strip-debug

DHSTONE_ELF_CFLAGS = -MD -O3 -mabi=ilp32 -march=rv32im -DTIME -DRISCV \
		-DUSE_MYSTDLIB -ffreestanding -nostdlib \
		-Wl,-Bstatic,-T,sections.lds,-Map,dhry.map,--strip-debug
#........... DHRYSTONE Obj/Opt .. End   ...........#


#~~~~~~~~~~~ COREMARK Obj/Opt Start .. ~~~~~~~~~~~#
TESTCOREMARK_OBJS = coremark/startup.s coremark/core_list_join.c coremark/core_main.c \
coremark/core_matrix.c coremark/core_state.c coremark/core_util.c \
coremark/barebones/core_portme.c coremark/barebones/ee_printf.c
ITERATIONS     = 0        # Iterations of CoreMark
CLOCKS_PER_SEC = 90000000   # Core clock speed 100Mhz
#CLOCKS_PER_SEC = 1000   # Core clock speed 100khz ==> Speed test
FLAGS_STR      = ""
GCC_DIR    = /opt/riscv
GCC_PREFIX = riscv64-unknown-elf
GCC_VER    = 14.2.0
XCFLAGS = -DITERATIONS=$(ITERATIONS) \
	-DCLOCKS_PER_SEC=$(CLOCKS_PER_SEC) \
	-I./coremark -I./coremark/barebones \
	-DFLAGS_STR=\"$(FLAGS_STR)\"
COREMARK_OPT = -fno-stack-protector \
	-fno-zero-initialized-in-bss \
	-mstrict-align \
	-fno-builtin	
#........... COREMARK Obj/Opt .. End   ...........#

CELLS = ../oss-cad-suite/share/yosys/ice40/cells_sim.v
TOOLCHAIN_PREFIX = riscv64-unknown-elf-

FULL_CMD = $(TOOLCHAIN_PREFIX)gcc -Os -mabi=ilp32 -march=rv32imzicsr -mdiv -ffreestanding -nostdlib -Ifirmware\
	       -Wl,--build-id=none,-Bstatic,-T,firmware/sections.lds,-Map,firmware/test.map,--strip-debug -lgcc

COREMARK_CMD = $(TOOLCHAIN_PREFIX)gcc -O3 $(XCFLAGS) $(COREMARK_OPT)\
               -Wno-error=missing-prototypes -Wno-error=discarded-qualifiers \
	       -mabi=ilp32 -march=rv32im -ffreestanding -nostdlib \
	       -Wl,--build-id=none,-Bstatic,-T,firmware/sections.lds,-Map,firmware/test.map,--strip-debug -lgcc\

DHSTONE_CMD = $(TOOLCHAIN_PREFIX)gcc $(DHSTONE_CFLAGS)

all: help

help:
	@printf "=========================================================== \n"
	@printf " make help                      : print this message\n"
	@printf " make all                       : print this message\n"
	@printf " make TESTALL=1 test            : run instructions in tests\n"
	@printf " make TESTFW=1 test             : run testfw.S test\n"
	@printf " make TESTCOREMARK=1 test       : run coremark test\n"
	@printf " make TESTDHRYSTONE=1 test      : run dhrystone test\n"
	@printf " make MAIN=1 test               : run main c test\n"
	@printf " make MAIN=1 test_fpga          : run main c test for fpga top\n"
	@printf " make ..=1 test_vcd             : run tests with vcd\n"
	@printf "=========================================================== \n"

test: testbench.vvp firmware/test.hex
	$(VVP) -N $<
	@rm firmware/test.elf

test_fpga: testbench_fpga.vvp fpga/fw/test_word.hex
	$(VVP) -N $< +vcd +trace +noerror

test_vcd: testbench_vcd.vvp firmware/test.hex
	$(VVP) -N $< +vcd +trace +noerror

testbench.vvp: testbench.v apb_periph.v rispark32.v
	$(IVERILOG) -g2012 -o $@ $^
	chmod -x $@

testbench_fpga.vvp: fpga/src_sim/top.v fpga/src_sim/simpleuart.v rispark32.v
	$(IVERILOG) -D WAVEFORM=1 -g2012 -o $@ $^
	chmod -x $@


testbench_vcd.vvp: testbench.v apb_periph.v rispark32.v
	$(IVERILOG) -D WAVEFORM=1 -g2012 -o $@ $^
	chmod -x $@


firmware/test.hex: firmware/test.elf
	$(TOOLCHAIN_PREFIX)objcopy -O verilog $< $@

fpga/fw/test_word.hex: firmware/test.elf
	@printf ".......................................................................\n"
	@printf "CHECK ==>  \n"
	@printf " Disable TRACE_RV32 in rispark32 and CSR_EXT if not supported by periph\n"
	@printf ".......................................................................\n"
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< fpga/fw/test_word.bin
	$(PYTHON) fpga/fw/makehex.py fpga/fw/test_word.bin 16384 > $@

ifdef MAIN
firmware/test.elf: $(MAIN_OBJS) firmware/sections.lds
	@printf "===========================================\n"
	@printf "Testing using envar  : ${MAIN_OBJS}\n"
	@printf "===========================================\n"
	$(FULL_CMD) -o $@ $(MAIN_OBJS)
	chmod -x $@
endif


ifdef TEST
firmware/test.elf: $(TEST_OBJS) firmware/sections.lds
	@printf "===========================================\n"
	@printf "Testing using envar  : ${TEST_OBJS}\n"
	@printf "===========================================\n"
	$(FULL_CMD) -o $@ $(TEST_OBJS)
	chmod -x $@
endif

ifdef TESTCOREMARK	
firmware/test.elf: $(TESTCOREMARK_OBJS) firmware/sections.lds
	@printf "===========================================\n"
	@printf "Testing using envar  : ${TESTCOREMARK_OBJS}\n"
	@printf "===========================================\n"
	$(COREMARK_CMD) -o $@ $(TESTCOREMARK_OBJS)
	chmod -x $@
endif

ifdef TESTDHRYSTONE
firmware/test.elf: $(TESTDHRYSTONE_OBJS) dhrystone/sections.lds
	@printf "===========================================\n"
	@printf "Testing using envar  : ${TESTDHRYSTONE_OBJS}\n"
	@printf "===========================================\n"
	cd dhrystone; $(DHSTONE_CMD) $(TESTDHRYSTONE_F_OBJS) -o ../$@
	chmod -x $@
endif


ifdef TESTFW		
firmware/test.elf: $(TESTFW_OBJS) firmware/sections.lds
	@printf "===========================================\n"
	@printf "Testing using envar  : ${TESTFW_OBJS}\n"
	@printf "==========================================\n"
	$(FULL_CMD) -o $@ $(TESTFW_OBJS) 
	chmod -x $@
endif
 
ifdef TESTALL	
firmware/test.elf: $(TESTALL_OBJS) firmware/sections.lds
	@printf "===========================================\n"
	@printf "Testing using envar  : ${TESTALL}\n"
	@printf "===========================================\n"
	$(FULL_CMD) -o $@ $(TESTALL_OBJS)
	chmod -x $@
endif



clean:
	rm -vrf $(TESTISNT_OBJS)\
		firmware/test.elf firmware/test.bin firmware/test.hex firmware/test.map \
		testbench.vvp testbench_vcd.vvp testbench.vcd testbench_fpga.vcd testbench_vcd.vcd \
		testbench_fpga.vvp testbench.trace dbg.trace fpga/fw/test_word.hex fpga/fw/test_word.bin
	find -type f -name *.o -exec rm -rf {} \;
