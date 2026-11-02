/*
 *  Rispark32 -- RISC-V (RV32IM) von Neumann, Pipelined, APB Processor Core
 *
 *  Copyright (C) 2025  Yassine El khourassani <yassine.elkhourassani@gmail.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */
 

`timescale 1 ns / 1 ps

`define SIM_RV32
//`define TRACE_RV32
`define MULTIPLIER_DIVIDER
`define MULTIPLIER_FAST
//`define CSR_EXT

`ifndef RISPARK_REGS
`define RISPARK_REGS rispark32_reg
`endif

/***************************************************************
 * rispark32
 ***************************************************************/

module rispark32 (
        input clk, resetn,
        
        output            psel,
        input             pready,

        output     [31:0] paddr,
        output     [31:0] pwdata,
        output     [ 3:0] pwstrb,
        input      [31:0] prdata,

        input       irq
);

	    parameter [31:0] reset_vector = 32'h 0010_0000;
        parameter [31:0] irq_vector   = 32'h 0010_0000;
	    parameter [31:0] csr_base_address = 32'h 0100_0400;
	
        localparam integer regfile_size = 32;
        localparam p_alu_add  = 4'b0_000;
        localparam p_alu_sub  = 4'b1_000;
        localparam p_alu_sll  = 4'b0_001;
        localparam p_alu_slt  = 4'b0_010;
        localparam p_alu_sltu = 4'b0_011;
        localparam p_alu_xor  = 4'b0_100;
        localparam p_alu_srl  = 4'b0_101;
        localparam p_alu_sra  = 4'b1_101;
        localparam p_alu__or  = 4'b0_110;
        localparam p_alu_and  = 4'b0_111;
        localparam p_alussub  = 4'b1_111;
	
	    localparam cpu_state_fetch        = 3'd0;
        localparam cpu_state_decod        = 3'd1;
        localparam cpu_state_exec         = 3'd2;
        localparam cpu_state_exec_wait    = 3'd3;
        localparam cpu_state_decod2       = 3'd4;
        localparam cpu_state_exec2        = 3'd5;
        localparam cpu_state_exec2_wait   = 3'd6;
        
        reg [63:0] count_cycle, count_instr;

        reg [63:0] new_ascii_instr;
        reg [63:0] new_rs1, new_rs2, new_rd, reg_name[0:regfile_size-1], abi_name[0:regfile_size-1];
        
        wire alu_valid;
        wire [31:0] alu_a,alu_b;
        wire [3:0] aluop;
        wire[31:0] aluout;
        wire alu_ready;
        wire over, zero, operandzero;

        wire regram_wen;
        wire [31:0] regram_wrdata;
        wire[31:0] regram_rdata1_nozero;
        wire[31:0] regram_rdata2_nozero;
        wire[31:0] regram_rdata1;
        wire[31:0] regram_rdata2;
        wire [5:0]  regram_waddr;
        wire [5:0]  regram_raddr1;
        wire [5:0]  regram_raddr2;
        
        ALUsync #(
                        .p_alu_add(p_alu_add),
                        .p_alu_sub(p_alu_sub),
                        .p_alu_sll(p_alu_sll),
                        .p_alu_slt(p_alu_slt),
                        .p_alu_sltu(p_alu_sltu),
                        .p_alu_xor(p_alu_xor),
                        .p_alu_srl(p_alu_srl),
                        .p_alu_sra(p_alu_sra),
                        .p_alu__or(p_alu__or),
                        .p_alu_and(p_alu_and),
                        .p_alussub(p_alussub)
                ) ALUsync_i
                (
                        .clk       (clk        ),
                        .resetn    (resetn     ),
                        .valid     (alu_valid  ),
                        .a         (alu_a      ),
                        .b         (alu_b      ),
                        .ALUop     (aluop      ),
                        .ALUOut    (aluout     ),
                        .ready     (alu_ready  ),
                        .over      (over  )
                );
                        
        assign zero = aluout == 0;
        assign operandzero = (|alu_a == 0) && (|alu_b == 0);
        
        wire [31:0] muldiv_a,muldiv_b;
        wire [63:0] product_mul;
        wire start_mul;
        wire mul_ready;
        wire [31:0] rd_div, rd_rem;
        wire start_div, signeda, signedb;
        wire div_ready;                        

        wire instr_lui, instr_auipc, instr_jal, instr_jalr;
        wire instr_beq, instr_bne, instr_blt, instr_bge, instr_bltu, instr_bgeu;
        wire instr_lb, instr_lh, instr_lw, instr_lbu, instr_lhu, instr_sb, instr_sh, instr_sw;
        
        wire instr_addi, instr_slti, instr_sltiu, instr_xori, instr_ori, instr_andi, instr_slli, instr_srli, instr_srai;
        wire instr_add, instr_sub, instr_sll, instr_slt, instr_sltu, instr_xor, instr_srl, instr_sra, instr_or, instr_and;

        wire instr_ecall_ebreak;
        wire r_type, b_type, l_type, s_type, i_type, csr_type, instr_mret;
        wire [3:0] inst_r_opcode;
        wire [3:0] inst_i_opcode;
        wire [2:0] func3;
        wire [6:0] func7;
        wire [6:0] major_opcode;

        wire instr_mul, instr_mulh, instr_mulhsu, instr_mulhu;        
        wire instr_div, instr_divu;
        wire instr_rem, instr_remu;
	
        wire instr_csrrw, instr_csrrs, instr_csrrc;
	wire instr_csrrwi, instr_csrrsi, instr_csrrci;
        
        reg mem_valid_fetch, mem_valid_fetch_next;
        reg do_fetch, do_fetch_next;
        reg irq_latched, irq_latched_next, rising_irq, dec_irq;
        
        wire mem_valid_execute, mem_valid_execute2;        
        assign psel = mem_valid_execute | mem_valid_execute2 | mem_valid_fetch;
        wire [31:0] mem_addr_exe;
        wire [31:0] mem_addr_dec;                        
        
`ifdef TRACE_RV32
        integer trace_file;
        initial begin
                trace_file = $fopen("dbg.trace", "w");                
        end

        initial begin
            reg_name[0] = "x0";    abi_name[0] = "zero";
            reg_name[1] = "x1";    abi_name[1] = "ra";
            reg_name[2] = "x2";    abi_name[2] = "sp";
            reg_name[3] = "x3";    abi_name[3] = "gp";
            reg_name[4] = "x4";    abi_name[4] = "tp";
            reg_name[5] = "x5";    abi_name[5] = "t0";
            reg_name[6] = "x6";    abi_name[6] = "t1";
            reg_name[7] = "x7";    abi_name[7] = "t2";
            reg_name[8] = "x8";    abi_name[8] = "s0";
            reg_name[9] = "x9";    abi_name[9] = "s1";
            reg_name[10] = "x10";  abi_name[10] = "a0";
            reg_name[11] = "x11";  abi_name[11] = "a1";
            reg_name[12] = "x12";  abi_name[12] = "a2";
            reg_name[13] = "x13";  abi_name[13] = "a3";
            reg_name[14] = "x14";  abi_name[14] = "a4";
            reg_name[15] = "x15";  abi_name[15] = "a5";
            reg_name[16] = "x16";  abi_name[16] = "a6";
            reg_name[17] = "x17";  abi_name[17] = "a7";
            reg_name[18] = "x18";  abi_name[18] = "s2";
            reg_name[19] = "x19";  abi_name[19] = "s3";
            reg_name[20] = "x20";  abi_name[20] = "s4";
            reg_name[21] = "x21";  abi_name[21] = "s5";
            reg_name[22] = "x22";  abi_name[22] = "s6";
            reg_name[23] = "x23";  abi_name[23] = "s7";
            reg_name[24] = "x24";  abi_name[24] = "s8";
            reg_name[25] = "x25";  abi_name[25] = "s9";
            reg_name[26] = "x26";  abi_name[26] = "s10";
            reg_name[27] = "x27";  abi_name[27] = "s11";
            reg_name[28] = "x28";  abi_name[28] = "t3";
            reg_name[29] = "x29";  abi_name[29] = "t4";
            reg_name[30] = "x30";  abi_name[30] = "t5";
            reg_name[31] = "x31";  abi_name[31] = "t6";
	end

        always @* begin
                new_ascii_instr = "";
                new_rs1 = "";
                new_rs2 = "";
                new_rd = "";
                
                if (instr_lui)      new_ascii_instr = "lui";
                if (instr_auipc)    new_ascii_instr = "auipc";
                if (instr_jal)      new_ascii_instr = "jal";
                if (instr_jalr)     new_ascii_instr = "jalr";

                if (instr_beq)      new_ascii_instr = "beq";
                if (instr_bne)      new_ascii_instr = "bne";
                if (instr_blt)      new_ascii_instr = "blt";
                if (instr_bge)      new_ascii_instr = "bge";
                if (instr_bltu)     new_ascii_instr = "bltu";
                if (instr_bgeu)     new_ascii_instr = "bgeu";

                if (instr_lb)       new_ascii_instr = "lb";
                if (instr_lh)       new_ascii_instr = "lh";
                if (instr_lw)       new_ascii_instr = "lw";
                if (instr_lbu)      new_ascii_instr = "lbu";
                if (instr_lhu)      new_ascii_instr = "lhu";
                if (instr_sb)       new_ascii_instr = "sb";
                if (instr_sh)       new_ascii_instr = "sh";
                if (instr_sw)       new_ascii_instr = "sw";

                if (instr_addi)     new_ascii_instr = "addi";
                if (instr_slti)     new_ascii_instr = "slti";
                if (instr_sltiu)    new_ascii_instr = "sltiu";
                if (instr_xori)     new_ascii_instr = "xori";
                if (instr_ori)      new_ascii_instr = "ori";
                if (instr_andi)     new_ascii_instr = "andi";
                if (instr_slli)     new_ascii_instr = "slli";
                if (instr_srli)     new_ascii_instr = "srli";
                if (instr_srai)     new_ascii_instr = "srai";

                if (instr_add)      new_ascii_instr = "add";
                if (instr_sub)      new_ascii_instr = "sub";
                if (instr_sll)      new_ascii_instr = "sll";
                if (instr_slt)      new_ascii_instr = "slt";
                if (instr_sltu)     new_ascii_instr = "sltu";
                if (instr_xor)      new_ascii_instr = "xor";
                if (instr_srl)      new_ascii_instr = "srl";
                if (instr_sra)      new_ascii_instr = "sra";
                if (instr_or)       new_ascii_instr = "or";
                if (instr_and)      new_ascii_instr = "and";
                if (instr_mul)      new_ascii_instr = "mul";                        
                if (instr_mulh)     new_ascii_instr = "mulh";
                if (instr_mulhsu)   new_ascii_instr = "mulhsu";
                if (instr_mulhu)    new_ascii_instr = "mulhu";
                if (instr_div)      new_ascii_instr = "div";
                if (instr_divu)     new_ascii_instr = "divu";
                if (instr_rem)      new_ascii_instr = "rem";
                if (instr_remu)     new_ascii_instr = "remu";
		if (instr_csrrw)    new_ascii_instr = "csrrw";
		if (instr_csrrc)    new_ascii_instr = "csrrs";
		if (instr_csrrs)    new_ascii_instr = "csrrc";
		if (instr_csrrwi)   new_ascii_instr = "csrrwi";
		if (instr_csrrci)   new_ascii_instr = "csrrsi";
		if (instr_csrrsi)   new_ascii_instr = "csrrci";
		if (instr_mret)     new_ascii_instr = "mret";
                if (instr_ecall_ebreak) new_ascii_instr = "ecall_ebreak";
                
		new_rs1 <= abi_name[rs1_reg];
		new_rs2 <= abi_name[rs2_reg];
		new_rd <= abi_name[rd_reg];                
        end
`endif
        
        reg [2:0] cpu_state, cpu_state_next;
        reg [31:0] counter_reg, counter_reg_next;
        reg [31:0] counter_instr_reg, counter_instr_reg_next;
        wire [31:0] mem_data_reg;
        reg [31:0] mem_data_reg1, mem_data_reg1_next;
        reg [31:0] mem_data_reg2, mem_data_reg2_next;        
        wire [3:0] byte_memsrc;
        wire [4:0] byte_memdest;
        reg [31:0] pc_reg, pc_reg_next, mepc_reg, mepc_next;
        wire [31:0] branch_pc_reg;
        wire [11:0] imm_s_type_reg, imm_i_type_reg, imm_b_type_reg;
        wire [20:0] imm_j_type_reg;
        wire [31:0] imm_u_type_reg;
        wire [4:0] rs1_reg, rs2_reg, rd_reg;
        wire [4:0] rd_reg_latched;
        wire [31:0] mem_dest, mem_src;
        wire branch_cond;
        wire [31:0] cpuregs_rs1, cpuregs_rs2;
        reg [31:0] cpuregs_rd;
        wire instr_rdcycle, instr_rdcycleh;
        wire instr_rdinstr, instr_rdinstrh;
        
    instruction_decoder u_instruction_decoder (
        .mem_data_reg(mem_data_reg),

        .func3(func3),
        .func7(func7),
        .major_opcode(major_opcode),

        .i_type(i_type),
        .r_type(r_type),
        .b_type(b_type),
        .l_type(l_type),
        .s_type(s_type),

        .instr_ecall_ebreak(instr_ecall_ebreak),
        .instr_rdcycle(instr_rdcycle), 
        .instr_rdcycleh(instr_rdcycleh),
        .instr_rdinstr(instr_rdinstr),
        .instr_rdinstrh(instr_rdinstrh),
        .inst_r_opcode(inst_r_opcode),
        .inst_i_opcode(inst_i_opcode),

        .instr_lui(instr_lui),
        .instr_auipc(instr_auipc),
        .instr_jal(instr_jal),
        .instr_jalr(instr_jalr),

        .instr_beq(instr_beq),
        .instr_bne(instr_bne),
        .instr_blt(instr_blt),
        .instr_bge(instr_bge),
        .instr_bltu(instr_bltu),
        .instr_bgeu(instr_bgeu),

        .instr_lb(instr_lb),
        .instr_lh(instr_lh),
        .instr_lw(instr_lw),
        .instr_lbu(instr_lbu),
        .instr_lhu(instr_lhu),

        .instr_sb(instr_sb),
        .instr_sh(instr_sh),
        .instr_sw(instr_sw),

        .instr_addi(instr_addi),
        .instr_slti(instr_slti),
        .instr_sltiu(instr_sltiu),
        .instr_xori(instr_xori),
        .instr_ori(instr_ori),
        .instr_andi(instr_andi),

        .instr_slli(instr_slli),
        .instr_srli(instr_srli),
        .instr_srai(instr_srai),
        .instr_add(instr_add),
        .instr_sub(instr_sub),
        .instr_sll(instr_sll),
        .instr_slt(instr_slt),
        .instr_sltu(instr_sltu),
        .instr_xor(instr_xor),
        .instr_srl(instr_srl),
        .instr_sra(instr_sra),
        .instr_or(instr_or),
        .instr_and(instr_and),
`ifdef MULTIPLIER_DIVIDER
        .instr_mul(instr_mul),
        .instr_mulh(instr_mulh),
        .instr_mulhsu(instr_mulhsu),
        .instr_mulhu(instr_mulhu),
        .instr_div(instr_div),
        .instr_divu(instr_divu),
        .instr_rem(instr_rem),
        .instr_remu(instr_remu),
`endif
        .csr_type(csr_type),
	.instr_mret(instr_mret),
        .instr_csrrw(instr_csrrw),
	.instr_csrrs(instr_csrrs),
	.instr_csrrc(instr_csrrc),
	.instr_csrrwi(instr_csrrwi),
	.instr_csrrsi(instr_csrrsi),
	.instr_csrrci(instr_csrrci),

        .rs1_reg(rs1_reg),
        .rs2_reg(rs2_reg),
        .rd_reg(rd_reg),

        .imm_s_type_reg(imm_s_type_reg),
        .imm_i_type_reg(imm_i_type_reg),
        .imm_b_type_reg(imm_b_type_reg),
        .imm_j_type_reg(imm_j_type_reg),
        .imm_u_type_reg(imm_u_type_reg)
    );
        
        
        assign byte_memsrc[0] = mem_src[1:0] == 0;
        assign byte_memsrc[1] = mem_src[1:0] == 1;
        assign byte_memsrc[2] = mem_src[1:0] == 2;
        assign byte_memsrc[3] = mem_src[1:0] == 3;

        assign byte_memdest = (mem_dest[1:0] << 3);

        assign branch_cond = ( (instr_beq && zero) || 
                               (instr_bne && (!zero && !operandzero)) ||
                               (instr_blt && over && !zero) ||
                               (instr_bge && !over) ||
                               (instr_bge && zero) ||
                               (instr_bltu && over && !zero) ||
                               (instr_bgeu && !over) || 
                               (instr_bgeu && zero) );
        
        assign cpuregs_rs1 = regram_rdata1;
        assign cpuregs_rs2 = regram_rdata2;                

        assign regram_rdata1 = rs1_reg == 0 ? 0:regram_rdata1_nozero;
        assign regram_rdata2 = rs2_reg == 0 ? 0:regram_rdata2_nozero;

`ifdef TRACE_RV32                
        wire [31:0] dbg_x0;  
        wire [31:0] dbg_x1;  
        wire [31:0] dbg_x2;  
        wire [31:0] dbg_x3; 
        wire [31:0] dbg_x4;  
	wire [31:0] dbg_x5;  
        wire [31:0] dbg_x6;  
        wire [31:0] dbg_x7;  
        wire [31:0] dbg_x8;  
        wire [31:0] dbg_x9;  
        wire [31:0] dbg_x10; 
        wire [31:0] dbg_x11; 
        wire [31:0] dbg_x12; 
        wire [31:0] dbg_x13; 
        wire [31:0] dbg_x14; 
        wire [31:0] dbg_x15; 
        wire [31:0] dbg_x16; 
        wire [31:0] dbg_x17; 
        wire [31:0] dbg_x18; 
        wire [31:0] dbg_x19; 
        wire [31:0] dbg_x20; 
        wire [31:0] dbg_x21; 
        wire [31:0] dbg_x22; 
        wire [31:0] dbg_x23; 
        wire [31:0] dbg_x24; 
        wire [31:0] dbg_x25;
        wire [31:0] dbg_x26; 
        wire [31:0] dbg_x27; 
        wire [31:0] dbg_x28; 
        wire [31:0] dbg_x29; 
        wire [31:0] dbg_x30; 
        wire [31:0] dbg_x31; 
`endif        
                
                
`RISPARK_REGS ram_cpuregs (
        .clk(clk),
        .wen(resetn && regram_wen),
        .waddr({1'b0,rd_reg_latched}),        
        .raddr1({1'b0,rs1_reg}),
        .raddr2({1'b0,rs2_reg}),        
        .wdata(rd_reg_latched == 0 ? 0:regram_wrdata),
        .rdata1(regram_rdata1_nozero),
        .rdata2(regram_rdata2_nozero)
`ifdef TRACE_RV32                
        ,
        .trace_file(trace_file),
        .dbg_x0(dbg_x0),
        .dbg_x1(dbg_x1),  
        .dbg_x2(dbg_x2),
        .dbg_x3(dbg_x3),
        .dbg_x4(dbg_x4),
        .dbg_x5(dbg_x5),
        .dbg_x6(dbg_x6),
        .dbg_x7(dbg_x7),
        .dbg_x8(dbg_x8),
        .dbg_x9(dbg_x9),
        .dbg_x10(dbg_x10),
        .dbg_x11(dbg_x11),
        .dbg_x12(dbg_x12),
        .dbg_x13(dbg_x13),
        .dbg_x14(dbg_x14),
        .dbg_x15(dbg_x15),
        .dbg_x16(dbg_x16),
        .dbg_x17(dbg_x17),
        .dbg_x18(dbg_x18),
        .dbg_x19(dbg_x19),
        .dbg_x20(dbg_x20),
        .dbg_x21(dbg_x21),
        .dbg_x22(dbg_x22),
        .dbg_x23(dbg_x23),
        .dbg_x24(dbg_x24),
        .dbg_x25(dbg_x25),
        .dbg_x26(dbg_x26),
        .dbg_x27(dbg_x27),
        .dbg_x28(dbg_x28),
        .dbg_x29(dbg_x29),
        .dbg_x30(dbg_x30),
        .dbg_x31(dbg_x31)
`endif                
);

`ifdef MULTIPLIER_DIVIDER
        riscv_mul riscv_mul_i (
                        .clk       (clk        ),
                        .resetn    (resetn     ),
                        .a         (muldiv_a      ),
                        .b         (muldiv_b      ),
                        .product   (product_mul), 
                        .start     (start_mul  ), 
                        .signeda   (instr_mulhsu | instr_mulh | instr_mul),
                        .signedb   (instr_mulh | instr_mul),
                        .ready     (mul_ready  )
                );
                
        riscv_div_rem riscv_div_rem_i (
                        .clk       (clk        ),
                        .resetn    (resetn     ),
                        .start     (start_div  ),
                        .signeddiv (instr_div),
                        .signedrem (instr_rem),
                        .rs1       (muldiv_a   ),
                        .rs2       (muldiv_b   ),
                        .rd_div    (rd_div     ), 
                        .rd_rem    (rd_rem     ),
                        .done      (div_ready   )
                );
`else                
`endif

cpu_decode #(.cpu_state_decod(cpu_state_decod),
             .cpu_state_decod2(cpu_state_decod2),
             .p_alu_add(p_alu_add),
             .p_alu_sub(p_alu_sub),
             .p_alussub(p_alussub),
	     .csr_base_address(csr_base_address)
             ) cpu_decode_inst(
    .clk(clk),
    .resetn(resetn),
    .pc_reg(pc_reg),
    .cpu_state(cpu_state),
    .imm_s_type_reg(imm_s_type_reg),
    .imm_i_type_reg(imm_i_type_reg),
    .imm_u_type_reg(imm_u_type_reg),
    .imm_j_type_reg(imm_j_type_reg),
    .imm_b_type_reg(imm_b_type_reg),
    .cpuregs_rs1(cpuregs_rs1),
    .cpuregs_rs2(cpuregs_rs2),
    .func3(func3),
    .instr_ecall_ebreak(instr_ecall_ebreak),
    .s_type(s_type),
    .l_type(l_type),
    .i_type(i_type),
    .r_type(r_type),
    .b_type(b_type),
    .instr_lui(instr_lui),
    .instr_auipc(instr_auipc),
    .instr_jal(instr_jal),
    .instr_jalr(instr_jalr),
`ifdef MULTIPLIER_DIVIDER    
    .instr_mul(instr_mul),
    .instr_mulhu(instr_mulhu),
    .instr_mulh(instr_mulh),
    .instr_mulhsu(instr_mulhsu),
    .instr_div(instr_div),
    .instr_rem(instr_rem),
    .instr_divu(instr_divu),
    .instr_remu(instr_remu),
`endif    
    .csr_type(csr_type),
    .instr_mret(instr_mret),
    .new_rs1(new_rs1),
    .new_rs2(new_rs2),
    .new_rd(new_rd),
    .inst_i_opcode(inst_i_opcode),
    .inst_r_opcode(inst_r_opcode),
    .regram_wen(regram_wen),
    .rd_reg_latched(rd_reg_latched),
    .rs1_reg(rs1_reg),
    .rs2_reg(rs2_reg),
    .regram_wrdata(regram_wrdata),    
`ifdef TRACE_RV32
    .trace_file(trace_file),
    .new_ascii_instr(new_ascii_instr),    
`endif
    .counter_reg(counter_reg),
    .mem_dest(mem_dest),
    .mem_src(mem_src),
    .alu_ready(alu_ready),
    .mul_ready(mul_ready),
    .div_ready(div_ready),
    .alu_a(alu_a),
    .alu_b(alu_b),
    .alu_valid(alu_valid),
    .muldiv_a(muldiv_a),
    .muldiv_b(muldiv_b),
    .aluop(aluop),
    .branch_pc_reg(branch_pc_reg),
    .start_mul(start_mul),
    .start_div(start_div)
);


cpu_exec #(.regfile_size (regfile_size), 
           .cpu_state_fetch(cpu_state_fetch),
	       .cpu_state_exec(cpu_state_exec),
           .cpu_state_exec2(cpu_state_exec2),
           .reset_vector(reset_vector),
	       .irq_vector(irq_vector)) cpu_exec_inst (
    .clk(clk),
    .resetn(resetn),
    .pc_reg(pc_reg),
    .counter_reg(counter_reg),
    .counter_instr_reg(counter_instr_reg),
    .mem_dest(mem_dest),
    .mem_src(mem_src),
    .imm_u_type_reg(imm_u_type_reg),
    .aluout(aluout),
    .branch_pc_reg(branch_pc_reg),
    .mem_rdata(prdata),
    .product_mul(product_mul),
    .rd_div(rd_div),
    .rd_rem(rd_rem),
    .rs1_reg(rs1_reg),
    .rd_reg(rd_reg),
    .cpuregs_rs1(regram_rdata1),
    .cpuregs_rs2(regram_rdata2),
    .byte_memdest(byte_memdest),
    .byte_memsrc(byte_memsrc),
    .s_type(s_type),
    .l_type(l_type),
    .i_type(i_type),
    .r_type(r_type),
    .b_type(b_type),
    .instr_sw(instr_sw),
    .instr_sb(instr_sb),
    .instr_sh(instr_sh),
    .instr_lw(instr_lw),
    .instr_lb(instr_lb),
    .instr_lbu(instr_lbu),
    .instr_lh(instr_lh),
    .instr_lhu(instr_lhu),
    .instr_lui(instr_lui),
    .instr_auipc(instr_auipc),
    .instr_jal(instr_jal),
    .instr_jalr(instr_jalr),
`ifdef MULTIPLIER_DIVIDER    
    .instr_mul(instr_mul),
    .instr_mulhu(instr_mulhu),
    .instr_mulh(instr_mulh),
    .instr_mulhsu(instr_mulhsu),
    .instr_div(instr_div),
    .instr_rem(instr_rem),
    .instr_divu(instr_divu),
    .instr_remu(instr_remu),
`endif  
    .csr_type(csr_type), 
    .instr_mret(instr_mret),
    .instr_csrrw(instr_csrrw),
    .instr_csrrs(instr_csrrs),
    .instr_csrrc(instr_csrrc),
    .instr_csrrwi(instr_csrrwi),
    .instr_csrrsi(instr_csrrsi),
    .instr_csrrci(instr_csrrci),     
    .instr_beq(instr_beq),
    .instr_bne(instr_bne),
    .instr_blt(instr_blt),
    .instr_bge(instr_bge),
    .instr_bltu(instr_bltu),
    .instr_bgeu(instr_bgeu),
    .instr_rdcycle(instr_rdcycle),
    .instr_rdinstr(instr_rdinstr),
    .alu_ready(alu_ready),
    .mul_ready(mul_ready),
    .div_ready(div_ready),
    .mem_ready(pready),
    .mem_valid(mem_valid),
    .mem_valid_fetch(mem_valid_fetch),
    .cpu_state(cpu_state),
    .rising_irq(rising_irq),
    .mepc_reg(mepc_reg),
`ifdef TRACE_RV32    
    .trace_file(trace_file),    
`endif            
    .regram_wen(regram_wen),
    .regram_wrdata(regram_wrdata),
    .rd_reg_latched(rd_reg_latched),
    .mem_valid_execute(mem_valid_execute),
    .mem_valid_execute2(mem_valid_execute2),
    .branch_cond(branch_cond),
    .mem_addr(mem_addr_exe),
    .mem_wdata(pwdata),
    .mem_wstrb(pwstrb)
);

wire end_ls_type;
wire end_execute;
reg end_execute_next, end_execute_reg;
assign end_ls_type = ((l_type || s_type) && mem_valid_execute && pready) || 
                     (csr_type && mem_valid_execute2 && pready);
assign end_execute = div_ready || mul_ready || alu_ready || end_ls_type ||
                instr_rdcycle || instr_rdinstr;

wire branch_inst;
assign branch_inst = instr_jal || instr_jalr || b_type || instr_mret;

//+ 4 only during execute without mem_valid_execute
wire incr_4;
assign incr_4 = ((cpu_state == cpu_state_exec) || (cpu_state == cpu_state_exec2)) && ~mem_valid_execute && ~mem_valid_execute2;
//keep fetch address the address of exec + 4, don't take the next decided when exec is over
//rising_irq redirect to irq_vector only in the fetch that follows last execution
assign paddr = (rising_irq && (cpu_state == cpu_state_fetch)) ? irq_vector : ((incr_4 & ~end_execute_reg) ? mem_addr_exe + 4: mem_addr_exe);

assign mem_data_reg = ((cpu_state == cpu_state_exec) || (cpu_state == cpu_state_decod)) ? mem_data_reg1 : mem_data_reg2;

// Sequential block: state and registers update
always @(posedge clk) begin
    if (!resetn) begin
        irq_latched     <= 1'b0;
        rising_irq      <= 1'b0;
	dec_irq         <= 1'b0;
    end else begin
        irq_latched     <= irq;
        if (irq && ~irq_latched) begin
	    dec_irq <= 1'b1;
        end
	//Ensure that irq seen exclusively at decode where pc is figured out
        if (dec_irq && ((cpu_state == cpu_state_decod) || (cpu_state == cpu_state_decod2))) begin
            rising_irq <= 1'b1;
	    dec_irq <= 1'b0;
        end
	//Ensure that rising_irq ends only at execute end
	if (rising_irq && (cpu_state == cpu_state_fetch) && pready) begin
	    rising_irq <= 1'b0;	    
	end
    end
end        


always @(posedge clk) begin
    if (!resetn) begin
        cpu_state       <= cpu_state_fetch;
        mem_valid_fetch <= 1'b0;
        pc_reg          <= reset_vector;
	    mepc_reg        <= 32'd0;
        mem_data_reg1   <= 32'd0;
        mem_data_reg2    <= 32'd0;
        do_fetch        <= 0;          
        end_execute_reg <= 1'b0;
`ifdef SIM_RV32
        counter_reg     <= 32'd0;
        counter_instr_reg <= 32'd0;
`endif
    end else begin
        cpu_state       <= cpu_state_next;
        mem_valid_fetch <= mem_valid_fetch_next;
        pc_reg          <= pc_reg_next;
	mepc_reg        <= mepc_next;
        mem_data_reg1   <= mem_data_reg1_next;
        mem_data_reg2   <= mem_data_reg2_next;        
        do_fetch        <= do_fetch_next;
        end_execute_reg <= end_execute_next;
`ifdef SIM_RV32        
        counter_reg     <= counter_reg_next;
        counter_instr_reg <= counter_instr_reg_next;
`endif
    end
end

always @(*) begin
    // Default assignments to hold current values
    cpu_state_next       = cpu_state;
    mem_valid_fetch_next = mem_valid_fetch;
    counter_reg_next     = counter_reg + 1;
    counter_instr_reg_next = counter_instr_reg;
    pc_reg_next          = pc_reg;
    mepc_next            = mepc_reg;
    mem_data_reg1_next   = mem_data_reg1;
    mem_data_reg2_next   = mem_data_reg2;
    do_fetch_next        = do_fetch;
    end_execute_next     = end_execute_reg;

    //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
    // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
    // State transitions
    // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
    //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
    case (cpu_state)
    /////////////////
    /////////////////FETCH
    /////////////////    
        cpu_state_fetch: begin
            if (!pready) begin
                cpu_state_next = cpu_state_fetch;
            end else 
            if (pready) begin
                cpu_state_next = cpu_state_decod;
            end else begin
                cpu_state_next = cpu_state_fetch;
            end
        end

    /////////////////
    /////////////////DECODE
    /////////////////
        cpu_state_decod: begin
            cpu_state_next = cpu_state_exec;
        end
        
        cpu_state_decod2: begin
            cpu_state_next = cpu_state_exec2;
        end        

    /////////////////
    /////////////////EXECUTION
    /////////////////
        cpu_state_exec: begin
            if (end_execute | end_execute_reg) begin
	            //capture end_execute ==> end_execute_next ==> end_execute_reg
		    //to wait the end of fetch, when fetch is too long
                    end_execute_next = 1; 
                    if (branch_cond || instr_jal || instr_jalr || rising_irq || instr_mret) begin
                        cpu_state_next = cpu_state_fetch;
                        end_execute_next = 0;
                    end
                    //if both request and grant are already done in execute
                    //otherwise, request hangs so wait ..
                    else if (~mem_valid_fetch) begin
                        cpu_state_next = cpu_state_decod2;
                        //end_execute_reg to keep the end of execute, when ready is too long
                        end_execute_next = 0;
                    end
            end            
        end
        
        cpu_state_exec2: begin
            if (end_execute | end_execute_reg) begin
                    end_execute_next = 1;
                    if (branch_cond || instr_jal || instr_jalr || rising_irq || instr_mret) begin
                        cpu_state_next = cpu_state_fetch;
                        end_execute_next = 0;
                    end
                    //if both request and grant are already done in execute
                    //otherwise, request hangs so wait ..
                    else if (~mem_valid_fetch) begin
                        cpu_state_next = cpu_state_decod;
                        end_execute_next = 0;
                    end
            end
        end        
    /////////////////
    /////////////////DEFAULT
    /////////////////
        default: begin
            cpu_state_next = cpu_state_fetch;
        end
    endcase

    //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
    // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
    // Outputs and registers update
    // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
    //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
    /////////////////
    /////////////////FETCH
    /////////////////
    if (cpu_state == cpu_state_fetch) begin
        if (!pready) begin
            mem_valid_fetch_next = 1'b1;            
        end 
        else if (mem_valid_fetch) begin
            mem_valid_fetch_next = 1'b0;
        end
    end

    if ((cpu_state == cpu_state_fetch) && mem_valid_fetch && pready) begin
        mem_data_reg1_next = prdata;
    end

    /////////////////
    /////////////////DECODE
    /////////////////    
    if (cpu_state == cpu_state_decod) begin            
        pc_reg_next = pc_reg + 4;
	//in execute, parallel fetch or prior to load/store
        if (~instr_jal && ~instr_jalr && ~instr_mret) begin
            mem_valid_fetch_next = 1'b1;
        end
        else begin
            mem_valid_fetch_next = 1'b0;
        end
    end

    if (cpu_state == cpu_state_decod2) begin            
        pc_reg_next = pc_reg + 4;
        if (~instr_jal && ~instr_jalr && ~instr_mret) begin
            mem_valid_fetch_next = 1'b1;
        end
        else begin
            mem_valid_fetch_next = 1'b0;
        end         
    end
        
    /////////////////
    /////////////////EXECUTE
    /////////////////
    if (cpu_state == cpu_state_exec) begin
        if (mem_valid_fetch && pready) begin
            mem_valid_fetch_next = 1'b0;
            mem_data_reg2_next = prdata;
        end
        //staying in execute may regenerate a new fetch valid while it is time of execute valid
        else if(~do_fetch && ~branch_inst) begin
            mem_valid_fetch_next = 1'b1;
            //To ensure fetch in exe is done once
            do_fetch_next        = 1'b1;
        end
        //anticipate going back to fetch
        else if ((end_execute | end_execute_reg) && (branch_cond || instr_jal || instr_jalr || instr_mret)) begin
            mem_valid_fetch_next = 1'b1;
            do_fetch_next        = 1'b0;
        end

	if (rising_irq && end_execute) begin
	    pc_reg_next = irq_vector;
	    mepc_next = pc_reg;
`ifdef TRACE_RV32
            $fwrite(trace_file, "..............irq at %x saved next pc %x\n", pc_reg_next, pc_reg);
`endif	    
	    if (b_type && alu_ready && branch_cond) begin
                mepc_next = branch_pc_reg;
`ifdef TRACE_RV32
            $fwrite(trace_file, "..............irq at %x saved next pc %x\n", pc_reg_next, branch_pc_reg);
`endif	    
            end else if ((instr_jal || instr_jalr) && alu_ready) begin
                mepc_next = aluout;
`ifdef TRACE_RV32
            $fwrite(trace_file, "..............irq at %x saved next pc %x\n", pc_reg_next, aluout);
`endif	    		
            end
	end else begin
	    if (b_type && alu_ready && branch_cond) begin
                pc_reg_next = branch_pc_reg;
            end else if ((instr_jal || instr_jalr) && alu_ready) begin
                pc_reg_next = aluout;
            end else if (instr_mret && alu_ready) begin
                pc_reg_next = mepc_reg;
            end
	end
	
    end        

    if (cpu_state == cpu_state_exec2) begin
        if (mem_valid_fetch && pready) begin
            mem_valid_fetch_next = 1'b0;
            mem_data_reg1_next = prdata;
        end
        else if(~do_fetch && ~branch_inst) begin
            mem_valid_fetch_next = 1'b1;
            do_fetch_next        = 1'b1;
        end
        //anticipate going back to fetch
        else if ((end_execute | end_execute_reg) && (branch_cond || instr_jal || instr_jalr || instr_mret)) begin
            mem_valid_fetch_next = 1'b1;
            do_fetch_next        = 1'b0;
        end

        
	if (rising_irq && end_execute) begin
	    pc_reg_next = irq_vector;
	    mepc_next = pc_reg;
`ifdef TRACE_RV32
            $fwrite(trace_file, "..............irq at %x saved next pc %x\n", pc_reg_next, pc_reg);
`endif	    
	    if (b_type && alu_ready && branch_cond) begin
                mepc_next = branch_pc_reg;
`ifdef TRACE_RV32
            $fwrite(trace_file, "..............irq at %x saved next pc %x\n", pc_reg_next, branch_pc_reg);
`endif	    
            end else if ((instr_jal || instr_jalr) && alu_ready) begin
                mepc_next = aluout;
`ifdef TRACE_RV32
            $fwrite(trace_file, "..............irq at %x saved next pc %x\n", pc_reg_next, aluout);
`endif	    		
            end
	end else begin
	    if (b_type && alu_ready && branch_cond) begin
                pc_reg_next = branch_pc_reg;
            end else if ((instr_jal || instr_jalr) && alu_ready) begin
                pc_reg_next = aluout;
            end else if (instr_mret && alu_ready) begin
                pc_reg_next = mepc_reg;
            end	    
	end

    end
    
    
    ////////////////////////////////////////////////////////////////////
    // counter_instr_reg update
    ////////////////////////////////////////////////////////////////////    
`ifdef SIM_RV32
    if ((cpu_state == cpu_state_decod) || (cpu_state == cpu_state_decod2)) begin
        counter_instr_reg_next = counter_instr_reg + 1;
    end
`endif
`ifdef TRACE_RV32    
    if (counter_reg == 32'hFFFF_FFFF) begin
        $display("End of simulation at: %d", counter_reg);
        $fclose(trace_file);
        $stop;
    end    
`endif
end

endmodule


module instruction_decoder (
    input  wire [31:0] mem_data_reg,

    output wire [2:0]  func3,
    output wire [6:0]  func7,
	    output wire [6:0]  major_opcode,

    output wire        i_type,
    output wire        r_type,
    output wire        b_type,
    output wire        l_type,
    output wire        s_type,

    output wire [3:0]  inst_r_opcode,
    output wire [3:0]  inst_i_opcode,

    output wire        instr_lui,
    output wire        instr_auipc,
    output wire        instr_jal,
    output wire        instr_jalr,

    output wire        instr_ecall_ebreak,
    output wire        instr_rdcycle,                            
    output wire        instr_rdcycleh,                           
    output wire        instr_rdinstr,
    output wire        instr_rdinstrh,
    output wire        instr_beq,
    output wire        instr_bne,
    output wire        instr_blt,
    output wire        instr_bge,
    output wire        instr_bltu,
    output wire        instr_bgeu,

    output wire        instr_lb,
    output wire        instr_lh,
    output wire        instr_lw,
    output wire        instr_lbu,
    output wire        instr_lhu,

    output wire        instr_sb,
    output wire        instr_sh,
    output wire        instr_sw,

    output wire        instr_addi,
    output wire        instr_slti,
    output wire        instr_sltiu,
    output wire        instr_xori,
    output wire        instr_ori,
    output wire        instr_andi,

    output wire        instr_slli,
    output wire        instr_srli,
    output wire        instr_srai,
    output wire        instr_add,
    output wire        instr_sub,
    output wire        instr_sll,
    output wire        instr_slt,
    output wire        instr_sltu,
    output wire        instr_xor,
    output wire        instr_srl,
    output wire        instr_sra,
    output wire        instr_or,
    output wire        instr_and,

`ifdef MULTIPLIER_DIVIDER
    output wire        instr_mul,
    output wire        instr_mulh,
    output wire        instr_mulhsu,
    output wire        instr_mulhu,
    output wire        instr_div,
    output wire        instr_divu,
    output wire        instr_rem,
    output wire        instr_remu,
`endif
    output wire        csr_type,
    output wire        instr_mret,
    output wire        instr_csrrw,
    output wire        instr_csrrs,
    output wire        instr_csrrc,
    output wire        instr_csrrwi,
    output wire        instr_csrrsi,
    output wire        instr_csrrci,
    

    output wire [4:0]  rs1_reg,
    output wire [4:0]  rs2_reg,
    output wire [4:0]  rd_reg,

    output wire [11:0] imm_s_type_reg,
    output wire [11:0] imm_i_type_reg,
    output wire [11:0] imm_b_type_reg,
    output wire [20:0] imm_j_type_reg,
    output wire [31:0] imm_u_type_reg
);

    localparam system_opcode  = 7'b1110011;

    assign func3        = mem_data_reg[14:12];
    assign func7        = mem_data_reg[31:25];
    assign major_opcode = mem_data_reg[6:0];

    assign i_type = (major_opcode == 7'b0010011);
    assign r_type = (major_opcode == 7'b0110011) && (func7 != 7'b0000001); // avoid confusion with mul & co
    assign b_type = (major_opcode == 7'b1100011);
    assign l_type = (major_opcode == 7'b0000011);
    assign s_type = (major_opcode == 7'b0100011);

    assign inst_r_opcode = {mem_data_reg[30], mem_data_reg[14:12]};
    assign inst_i_opcode[2:0] = func3;
    assign inst_i_opcode[3] = (func3 == 3'b101) ? mem_data_reg[30] : 1'b0;

    assign instr_lui   = (major_opcode == 7'b0110111);
    assign instr_auipc = (major_opcode == 7'b0010111);
    assign instr_jal   = (major_opcode == 7'b1101111);
    assign instr_jalr  = (major_opcode == 7'b1100111) && (func3 == 3'b000);

    assign instr_beq   = (major_opcode == 7'b1100011) && (func3 == 3'b000);
    assign instr_bne   = (major_opcode == 7'b1100011) && (func3 == 3'b001);
    assign instr_blt   = (major_opcode == 7'b1100011) && (func3 == 3'b100);
    assign instr_bge   = (major_opcode == 7'b1100011) && (func3 == 3'b101);
    assign instr_bltu  = (major_opcode == 7'b1100011) && (func3 == 3'b110);
    assign instr_bgeu  = (major_opcode == 7'b1100011) && (func3 == 3'b111);

    assign instr_lb    = (major_opcode == 7'b0000011) && (func3 == 3'b000);
    assign instr_lh    = (major_opcode == 7'b0000011) && (func3 == 3'b001);
    assign instr_lw    = (major_opcode == 7'b0000011) && (func3 == 3'b010);
    assign instr_lbu   = (major_opcode == 7'b0000011) && (func3 == 3'b100);
    assign instr_lhu   = (major_opcode == 7'b0000011) && (func3 == 3'b101);

    assign instr_sb    = (major_opcode == 7'b0100011) && (func3 == 3'b000);
    assign instr_sh    = (major_opcode == 7'b0100011) && (func3 == 3'b001);
    assign instr_sw    = (major_opcode == 7'b0100011) && (func3 == 3'b010);

    assign instr_addi  = (major_opcode == 7'b0010011) && (func3 == 3'b000);
    assign instr_slti  = (major_opcode == 7'b0010011) && (func3 == 3'b010);
    assign instr_sltiu = (major_opcode == 7'b0010011) && (func3 == 3'b011);
    assign instr_xori  = (major_opcode == 7'b0010011) && (func3 == 3'b100);
    assign instr_ori   = (major_opcode == 7'b0010011) && (func3 == 3'b110);
    assign instr_andi  = (major_opcode == 7'b0010011) && (func3 == 3'b111);

    assign instr_slli  = (major_opcode == 7'b0010011) && (func3 == 3'b001) && (func7 == 7'b0000000);
    assign instr_srli  = (major_opcode == 7'b0010011) && (func3 == 3'b101) && (func7 == 7'b0000000);
    assign instr_srai  = (major_opcode == 7'b0010011) && (func3 == 3'b101) && (func7 == 7'b0100000);

    assign instr_add   = (major_opcode == 7'b0110011) && (func3 == 3'b000) && (func7 == 7'b0000000);
    assign instr_sub   = (major_opcode == 7'b0110011) && (func3 == 3'b000) && (func7 == 7'b0100000);
    assign instr_sll   = (major_opcode == 7'b0110011) && (func3 == 3'b001) && (func7 == 7'b0000000);
    assign instr_slt   = (major_opcode == 7'b0110011) && (func3 == 3'b010) && (func7 == 7'b0000000);
    assign instr_sltu  = (major_opcode == 7'b0110011) && (func3 == 3'b011) && (func7 == 7'b0000000);
    assign instr_xor   = (major_opcode == 7'b0110011) && (func3 == 3'b100) && (func7 == 7'b0000000);
    assign instr_srl   = (major_opcode == 7'b0110011) && (func3 == 3'b101) && (func7 == 7'b0000000);
    assign instr_sra   = (major_opcode == 7'b0110011) && (func3 == 3'b101) && (func7 == 7'b0100000);
    assign instr_or    = (major_opcode == 7'b0110011) && (func3 == 3'b110) && (func7 == 7'b0000000);
    assign instr_and   = (major_opcode == 7'b0110011) && (func3 == 3'b111) && (func7 == 7'b0000000);

`ifdef MULTIPLIER_DIVIDER
    assign instr_mul    = (major_opcode == 7'b0110011) && (func7 == 7'b0000001) && (func3 == 3'b000);
    assign instr_mulh   = (major_opcode == 7'b0110011) && (func7 == 7'b0000001) && (func3 == 3'b001);
    assign instr_mulhsu = (major_opcode == 7'b0110011) && (func7 == 7'b0000001) && (func3 == 3'b010);
    assign instr_mulhu  = (major_opcode == 7'b0110011) && (func7 == 7'b0000001) && (func3 == 3'b011);
    assign instr_div    = (major_opcode == 7'b0110011) && (func7 == 7'b0000001) && (func3 == 3'b100);
    assign instr_divu   = (major_opcode == 7'b0110011) && (func7 == 7'b0000001) && (func3 == 3'b101);
    assign instr_rem    = (major_opcode == 7'b0110011) && (func7 == 7'b0000001) && (func3 == 3'b110);
    assign instr_remu   = (major_opcode == 7'b0110011) && (func7 == 7'b0000001) && (func3 == 3'b111);
`endif

    assign csr_type     = (major_opcode == system_opcode) && (func3 != 3'b000);
    assign instr_mret   = (major_opcode == system_opcode) && 
                          (func3 == 3'b000) && 
			  (func7 == 7'b0011000) &&
			  (rs1_reg == 5'b00000) &&
			  (rs2_reg == 5'b00010) &&
			  (rd_reg  == 5'b00000);

`ifdef CSR_EXT    
    assign instr_csrrw  = (major_opcode == system_opcode) && (func3 == 3'b001);
    assign instr_csrrs  = (major_opcode == system_opcode) && (func3 == 3'b010);
    assign instr_csrrc  = (major_opcode == system_opcode) && (func3 == 3'b011);
    assign instr_csrrwi = (major_opcode == system_opcode) && (func3 == 3'b101);
    assign instr_csrrsi = (major_opcode == system_opcode) && (func3 == 3'b110);
    assign instr_csrrci = (major_opcode == system_opcode) && (func3 == 3'b111);
    
`endif
    
    assign rs1_reg = mem_data_reg[19:15];
    assign rs2_reg = mem_data_reg[24:20];
    assign rd_reg  = mem_data_reg[11:7];

    assign imm_s_type_reg = {mem_data_reg[31:25], mem_data_reg[11:7]};
    assign imm_i_type_reg = mem_data_reg[31:20];
    assign imm_b_type_reg = {mem_data_reg[31], mem_data_reg[7], mem_data_reg[30:25], mem_data_reg[11:8], 1'b0};
    assign imm_j_type_reg = {mem_data_reg[31], mem_data_reg[19:12], mem_data_reg[20], mem_data_reg[30:21], 1'b0};
    assign imm_u_type_reg = {mem_data_reg[31:12], 12'b0};

`ifdef SIM_RV32    
    assign instr_ecall_ebreak = major_opcode == 7'b1110011 && !mem_data_reg[31:21] && !mem_data_reg[19:7] && !func3;
    assign instr_rdcycle  = ((major_opcode && mem_data_reg[31:12] == 20'b11000000000000000010) ||
                                  (major_opcode && mem_data_reg[31:12] == 20'b11000000000100000010));
                                           
    assign instr_rdcycleh = ((major_opcode && mem_data_reg[31:12] == 20'b11001000000000000010) ||
                                  (major_opcode && mem_data_reg[31:12] == 20'b11001000000100000010));
                                           
    assign instr_rdinstr  =  (major_opcode && mem_data_reg[31:12] == 20'b11000000001000000010);
        
    assign instr_rdinstrh =  (major_opcode && mem_data_reg[31:12] == 20'b11001000001000000010);
`endif

endmodule


module cpu_decode #(parameter cpu_state_decod  = 3'd1,
                    parameter cpu_state_decod2  = 3'd4,
                    parameter p_alu_add  = 4'b0_000,
                    parameter p_alu_sub  = 4'b1_000,
                    parameter p_alussub  = 4'b1_111,
		    parameter csr_base_address = 32'h0
                    ) (
    input  clk,
    input  resetn,
    input  [31:0] pc_reg,
    input  [2:0] cpu_state,
    input  [11:0] imm_s_type_reg,
    input  [11:0] imm_i_type_reg,
    input  [31:0] imm_u_type_reg,
    input  [20:0] imm_j_type_reg,
    input  [11:0] imm_b_type_reg,
    input  [31:0] cpuregs_rs1,
    input  [31:0] cpuregs_rs2,
    input  [2:0] func3,
    input  s_type,
    input  l_type,
    input  i_type,
    input  r_type,
    input  instr_ecall_ebreak,
    input  instr_lui,
    input  instr_auipc,
    input  instr_jal,
    input  instr_jalr,
    input  b_type,
`ifdef MULTIPLIER_DIVIDER    
    input  instr_mul,
    input  instr_mulhu,
    input  instr_mulh,
    input  instr_mulhsu,
    input  instr_div,
    input  instr_rem,
    input  instr_divu,
    input  instr_remu,
`endif  
    input  csr_type,
    input  instr_mret,
    input  [63:0] new_rs1,
    input  [63:0] new_rs2,
    input  [63:0] new_rd,
    input  [3:0] inst_i_opcode,
    input  [3:0] inst_r_opcode,
    input  regram_wen,
    input  [4:0] rd_reg_latched,
    input  [4:0] rs1_reg,
    input  [4:0] rs2_reg,
    input  [31:0] regram_wrdata,
`ifdef TRACE_RV32    
    input  [31:0] trace_file,    
    input  [63:0] new_ascii_instr,    
`endif    
    input  [31:0] counter_reg,
    input  alu_ready,
    input  mul_ready,
    input  div_ready,
    output reg [31:0] mem_dest,
    output reg [31:0] mem_src,
    output reg [31:0] alu_a,
    output reg [31:0] alu_b,
    output reg [31:0] muldiv_a,
    output reg [31:0] muldiv_b,
    output reg alu_valid,
    output reg [3:0] aluop,
    output reg [31:0] branch_pc_reg,
    output reg start_mul,
    output reg start_div
);

//No time to write in reg and reread, intercept when first instr use rd_reg which is rs_reg of next
//write in x0 does not matter
wire [31:0] cpuregs_rs1_latched;
wire [31:0] cpuregs_rs2_latched;
assign cpuregs_rs1_latched = ((regram_wen == 1) && (rs1_reg == rd_reg_latched) && (rd_reg_latched != 0)) ? regram_wrdata:cpuregs_rs1;
assign cpuregs_rs2_latched = ((regram_wen == 1) && (rs2_reg == rd_reg_latched) && (rd_reg_latched != 0)) ? regram_wrdata:cpuregs_rs2;
        

always @(posedge clk) begin
    if (!resetn) begin
        // Reset logic
        mem_dest <= 0;
        mem_src  <= 0;
        
        alu_valid <= 0;
        aluop <= 0;
        alu_a <= 0;
        alu_b <= 0;
        
        start_mul <= 0;
        start_div <= 0;
        muldiv_a <= 0;
        muldiv_b <= 0;                        

    end else if ((cpu_state == cpu_state_decod) || (cpu_state == cpu_state_decod2)) begin            
        if (instr_ecall_ebreak)
        begin
`ifdef TRACE_RV32                
                $fwrite(trace_file, "%x: %s\n",pc_reg, new_ascii_instr);
                $display("########################## Code Runtime: ########################## ");
                $display("End of simulation at: ............................................. ");
                $display("                            %d", counter_reg);
                $display("################################################################### ");
                $display("%5d", counter_reg);
                $fclose(trace_file);

                $finish;
`endif
        end
        else         
        if (s_type) begin            
            mem_dest <= $signed(cpuregs_rs1_latched) + $signed(imm_s_type_reg);
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %d(%s)\n", pc_reg, new_ascii_instr, new_rs2, imm_s_type_reg, new_rs1);
`endif            
        end else if (l_type) begin
            mem_src <= $signed(cpuregs_rs1_latched) + $signed(imm_i_type_reg);
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %d(%s)\n", pc_reg, new_ascii_instr, new_rd, imm_i_type_reg, new_rs1);
`endif            

`ifdef CSR_EXT
        end else if (csr_type) begin
            mem_src <= imm_i_type_reg + csr_base_address;
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %d(%s)\n", pc_reg, new_ascii_instr, new_rd, mem_src, new_rs1);
`endif            
        end else if (instr_mret) begin
            //dummy operation for timing like others with alu_ready only        
            alu_valid <= 1;
            alu_a <= 0;
            alu_b <= 0;
            aluop <= p_alu_add;          
`ifdef TRACE_RV32        
            $fwrite(trace_file, "%x: %s\n", pc_reg, new_ascii_instr);
`endif
`endif //CSR_EXT
        end else if (i_type) begin            
            alu_valid <= 1;
            alu_a <= $signed(cpuregs_rs1_latched);
            alu_b <= $signed(imm_i_type_reg);
            aluop <= inst_i_opcode;
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %d(%s)\n", pc_reg, new_ascii_instr, new_rd, imm_i_type_reg, new_rs1);
`endif            
        end else if (r_type) begin            
            alu_valid <= 1;
            alu_a <= cpuregs_rs1_latched;
            alu_b <= cpuregs_rs2_latched;
            aluop <= inst_r_opcode;
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %s\n", pc_reg, new_ascii_instr, new_rd, new_rs1, new_rs2);
`endif            
        end else if (instr_lui) begin
            //dummy operation for timing like others with alu_ready only        
            alu_valid <= 1;
            alu_a <= 0;
            alu_b <= 0;
            aluop <= p_alu_add;          
`ifdef TRACE_RV32        
            $fwrite(trace_file, "%x: %s %s, %d\n", pc_reg, new_ascii_instr, new_rd, imm_u_type_reg[31:12]);
`endif
        end else if (instr_auipc) begin            
            alu_valid <= 1;
            alu_a <= pc_reg;
            alu_b <= imm_u_type_reg;
            aluop <= p_alu_add;
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %d\n", pc_reg, new_ascii_instr, new_rd, imm_u_type_reg[31:12]);
`endif            
        end else if (instr_jal) begin            
            alu_valid <= 1;
            alu_a <= $signed(pc_reg);
            alu_b <= $signed(imm_j_type_reg);
            aluop <= p_alu_add;
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %d\n", pc_reg, new_ascii_instr, new_rd, imm_j_type_reg);
`endif            
        end else if (instr_jalr) begin            
            alu_valid <= 1;
            alu_a <= $signed(cpuregs_rs1_latched);
            alu_b <= $signed(imm_i_type_reg);
            aluop <= p_alu_add;
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %d(%s)\n", pc_reg, new_ascii_instr, new_rd, imm_i_type_reg, new_rs1);
`endif            
        end else if (b_type) begin            
            branch_pc_reg <= $signed(pc_reg) + $signed(imm_b_type_reg);
            alu_valid <= 1;
            alu_a <= cpuregs_rs1_latched;
            alu_b <= cpuregs_rs2_latched;
            if ((func3 == 4) || (func3 == 5)) // blt, bge
                aluop <= p_alussub;
            else
                aluop <= p_alu_sub;
`ifdef TRACE_RV32                
            $fwrite(trace_file, "%x: %s %s, %s, %d\n", pc_reg, new_ascii_instr, new_rs1, new_rs2, imm_b_type_reg);
`endif            
        end
`ifdef MULTIPLIER_DIVIDER         
        else if (instr_mul || instr_mulhu) begin
            start_mul <= 1;
            muldiv_a <= cpuregs_rs1_latched;
            muldiv_b <= cpuregs_rs2_latched;            
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %s, %s\n", pc_reg, new_ascii_instr, new_rs1, new_rs2, new_rd);
`endif            
        end else if (instr_mulh) begin
            start_mul <= 1;
            muldiv_a <= $signed(cpuregs_rs1_latched);
            muldiv_b <= $signed(cpuregs_rs2_latched);            
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %s, %s\n", pc_reg, new_ascii_instr, new_rs1, new_rs2, new_rd);
`endif            
        end else if (instr_mulhsu) begin
            start_mul <= 1;
            muldiv_a <= $signed(cpuregs_rs1_latched);
            muldiv_b <= cpuregs_rs2_latched;            
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %s, %s\n", pc_reg, new_ascii_instr, new_rs1, new_rs2, new_rd);
`endif            
        end else if (instr_div) begin
            start_div <= 1;
            muldiv_a <= cpuregs_rs1_latched;
            muldiv_b <= cpuregs_rs2_latched;
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %s, %s\n", pc_reg, new_ascii_instr, new_rs1, new_rs2, new_rd);
`endif            
        end else if (instr_rem) begin
            start_div <= 1;
            muldiv_a <= $signed(cpuregs_rs1_latched);
            muldiv_b <= $signed(cpuregs_rs2_latched);            
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %s, %s\n", pc_reg, new_ascii_instr, new_rs1, new_rs2, new_rd);
`endif            
        end else if (instr_divu) begin
            start_div <= 1;
            muldiv_a <= cpuregs_rs1_latched;
            muldiv_b <= cpuregs_rs2_latched;            
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %s, %s\n", pc_reg, new_ascii_instr, new_rs1, new_rs2, new_rd);
`endif
        end else if (instr_remu) begin
            start_div <= 1;
            muldiv_a <= cpuregs_rs1_latched;
            muldiv_b <= cpuregs_rs2_latched;            
`ifdef TRACE_RV32            
            $fwrite(trace_file, "%x: %s %s, %s, %s\n", pc_reg, new_ascii_instr, new_rs1, new_rs2, new_rd);
`endif            
        end        
`endif        
    end
    else begin
        if(alu_ready) begin
            alu_valid <= 0;
        end 
`ifdef MULTIPLIER_DIVIDER        
        if(mul_ready) begin
            start_mul <= 0;
        end 
        if (div_ready) begin
            start_div <= 0;
        end
`endif        
    end
end

endmodule




module cpu_exec #(parameter regfile_size = 32, 
                  parameter cpu_state_fetch  = 3'd0,
		          parameter cpu_state_exec  = 3'd2,
                  parameter cpu_state_exec2  = 3'd5,
                  parameter reset_vector = 32'h 0000_0000,
		          parameter irq_vector = 32'h 0010_0000,
		          parameter csr_addr_mepc = 32'h341) (
    input wire clk,
    input wire resetn,
    input wire [31:0] pc_reg,
    input wire [31:0] counter_reg,
    input wire [31:0] counter_instr_reg,
    input wire [31:0] mem_dest,
    input wire [31:0] mem_src,
    input wire [31:0] imm_u_type_reg,
    input wire [31:0] aluout,
    input wire [31:0] branch_pc_reg,
    input wire [31:0] mem_rdata,
    input wire [63:0] product_mul,
    input wire [31:0] rd_div,
    input wire [31:0] rd_rem,
    input wire [4:0] rs1_reg,
    input wire [4:0] rd_reg,
    input wire [31:0] cpuregs_rs1,
    input wire [31:0] cpuregs_rs2,    
    input wire [4:0] byte_memdest,
    input wire [3:0] byte_memsrc,
    input wire s_type,
    input wire l_type,
    input wire i_type,
    input wire r_type,
    input wire b_type,
    input wire instr_sw,
    input wire instr_sb,
    input wire instr_sh,
    input wire instr_lw,
    input wire instr_lb,
    input wire instr_lbu,
    input wire instr_lh,
    input wire instr_lhu,
    input wire instr_lui,
    input wire instr_auipc,
    input wire instr_jal,
    input wire instr_jalr,
`ifdef MULTIPLIER_DIVIDER    
    input wire instr_mul,
    input wire instr_mulhu,
    input wire instr_mulh,
    input wire instr_mulhsu,
    input wire instr_div,
    input wire instr_rem,
    input wire instr_divu,
    input wire instr_remu,
`endif    
    input wire csr_type,
    input wire instr_mret,
    input wire instr_csrrw,
    input wire instr_csrrs,
    input wire instr_csrrc,
    input wire instr_csrrwi,
    input wire instr_csrrsi,
    input wire instr_csrrci,
    input wire instr_beq,
    input wire instr_bne,
    input wire instr_blt,
    input wire instr_bge,
    input wire instr_bltu,
    input wire instr_bgeu,
    input wire instr_rdcycle,
    input wire instr_rdinstr,
    input wire alu_ready,
    input wire mul_ready,
    input wire div_ready,
    input wire mem_ready,
    input wire [2:0] cpu_state,
    input wire branch_cond,
    input wire mem_valid,
    input wire mem_valid_fetch,
    input wire rising_irq,
    input wire [31:0] mepc_reg,
`ifdef TRACE_RV32    
    input  [31:0] trace_file,    
`endif            
    output reg regram_wen,
    output reg [31:0] regram_wrdata,
    output reg [4:0] rd_reg_latched,
    output reg mem_valid_execute,
    output reg mem_valid_execute2,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [3:0] mem_wstrb,    
    output reg alu_valid,
    output reg start_mul,
    output reg start_div
);

`ifdef CSR_EXT
wire [31:0] csr_reg;
assign csr_reg = (mem_src == csr_addr_mepc) ? mepc_reg : mem_rdata;
`endif

always @(posedge clk) begin
        if (!resetn) begin
                // Reset logic
                mem_valid_execute <= 0;
		        mem_valid_execute2 <= 0;
                mem_addr <= reset_vector;
                mem_wstrb <= 0;
                regram_wen <= 0;
                regram_wrdata <= 0;
        end 
            else if (rising_irq && (cpu_state == cpu_state_fetch)) begin
	        mem_addr <= irq_vector;
		regram_wen <= 0;
	    end    
            else if ((cpu_state == cpu_state_exec) || (cpu_state == cpu_state_exec2)) begin
                //latch rd_reg even in rd_reg_latched, to keep a coherent 
                //destination when decode (new mem_data_reg is set)
                rd_reg_latched <= rd_reg;
`ifdef SIM_RV32                
                if (instr_rdcycle) begin
                        regram_wen <= 1;
                        regram_wrdata <= counter_reg;
                        mem_addr <= pc_reg;
                end
                else if (instr_rdinstr) begin
                        regram_wen <= 1;
                        regram_wrdata <= counter_instr_reg;
                        mem_addr <= pc_reg;
                end
                else
		
`endif                
                if (s_type) begin
                        //if (!mem_valid) begin //Will help to wait pipelined fetch
                        //as soon as mem_fetch is over
                        if (mem_valid_fetch && mem_ready) begin
`ifdef TRACE_RV32
            $fwrite(trace_file, "..............smem_addr: %x\n", mem_dest & (~2'b11));
`endif
                                mem_valid_execute <= 1;
                                //Address aligned
                                mem_addr <= mem_dest & (~2'b11);        
                                if (instr_sw) begin
                                        mem_wstrb <= 4'b1111;
                                        mem_wdata <= cpuregs_rs2;
                                end
                                else if (instr_sb) begin
                                        mem_wstrb <= 4'b0001 << mem_dest[1:0];
                                        mem_wdata <= cpuregs_rs2 << byte_memdest;                                
                                end                                                
                                else if (instr_sh) begin
                                        mem_wstrb <= 4'b0011 << mem_dest[1:0];
                                        mem_wdata <= cpuregs_rs2 << byte_memdest;                                
                                end                                                
                        end
                        else if (mem_ready) begin
                                mem_valid_execute <= 0;
                                mem_wstrb <= 0;
                                mem_addr <= pc_reg;
                        end
                end
`ifdef CSR_EXT
                else if (csr_type) begin
                        //as soon as mem_fetch is over
                        if (mem_valid_fetch && mem_ready) begin
                                mem_valid_execute <= 1;
                                mem_wstrb <= 0;
                                mem_addr <= mem_src & (~2'b11);
`ifdef TRACE_RV32
            $fwrite(trace_file, "..............csr_addr: %x\n", mem_src & (~2'b11));
`endif                                
                        end
                        else if (mem_ready && ~mem_valid_execute2) begin
                                mem_valid_execute <= 0;
                                regram_wen <= 1;				                                
				mem_valid_execute2 <= 1;                            
                                mem_wstrb <= 4'b1111;                                
				if (instr_csrrw) begin				
                                        regram_wrdata <= csr_reg; //csr => rd
					mem_wdata <= cpuregs_rs1;   //rs1 ==> csr
                                end
				else if (instr_csrrs) begin
                                        regram_wrdata <= csr_reg;             //csr => rd
					mem_wdata <= cpuregs_rs1 | mem_rdata;   //rs1 (1 set, 0 keep) ==> csr
				end
				else if (instr_csrrc) begin
                                        regram_wrdata <= csr_reg;             //csr => rd
					mem_wdata <= cpuregs_rs1 & mem_rdata;   //rs1 (0 clear, 1 keep) ==> csr
				end
				else if (instr_csrrwi) begin
                                        regram_wrdata <= csr_reg;             //csr => rd
					mem_wdata <= rs1_reg;                   //rs1 value ==> csr
                                end
				else if (instr_csrrsi) begin
                                        regram_wrdata <= csr_reg;         //csr => rd
					mem_wdata <= rs1_reg | csr_reg;   //rs1 value (1 set, 0 keep) ==> csr
				end
				else if (instr_csrrci) begin
                                        regram_wrdata <= csr_reg;         //csr => rd
					mem_wdata <= rs1_reg & csr_reg;   //rs1 value (0 clear, 1 keep) ==> csr
				end
                        end
                        else if (mem_ready && mem_valid_execute2) begin
				mem_valid_execute2 <= 0;
				mem_wstrb <= 0;
				mem_addr <= pc_reg;
                        end   
                end
                else if (instr_mret) begin
                        if (alu_ready) begin
                                mem_addr <= mepc_reg;				
                        end
                end
`endif	//CSI_EXT	
                else if (l_type) begin
                        //as soon as mem_fetch is over
                        if (mem_valid_fetch && mem_ready) begin
                                mem_valid_execute <= 1;
                                mem_wstrb <= 0;
                                mem_addr <= mem_src & (~2'b11);
`ifdef TRACE_RV32
            $fwrite(trace_file, "..............lmem_addr: %x\n", mem_src & (~2'b11));
`endif
                                
                        end
                        else if (mem_ready) begin
                                mem_valid_execute <= 0;
                                if (instr_lw) begin
                                        regram_wen <= 1;
                                        regram_wrdata <= mem_rdata;
                                end
                                else if (instr_lb) begin
                                        regram_wen <= 1;                           
                                        regram_wrdata[7:0] <= byte_memsrc[3]? mem_rdata[31:24]:
                                                                   (byte_memsrc[2]? mem_rdata[23:16]:
                                                                   (byte_memsrc[1]? mem_rdata[15:8]:mem_rdata[7:0]));
                                        regram_wrdata[31:8] <= byte_memsrc[3]? {24{mem_rdata[31]}}:
                                                                   (byte_memsrc[2]? {24{mem_rdata[23]}}:
                                                                   (byte_memsrc[1]? {24{mem_rdata[15]}}:{24{mem_rdata[7]}}));
                                end
                                else if (instr_lbu) begin
                                        regram_wen <= 1;
                                        regram_wrdata[7:0] <= byte_memsrc[3]? mem_rdata[31:24]:
                                                                   (byte_memsrc[2]? mem_rdata[23:16]:
                                                                   (byte_memsrc[1]? mem_rdata[15:8]:mem_rdata[7:0]));
                                        regram_wrdata[31:8] <= 0;                                
                                end
                                else if (instr_lh) begin
                                        regram_wen <= 1;
                                        regram_wrdata[15:0] <= byte_memsrc[2]? mem_rdata[31:16]:mem_rdata[15:0];
                                        regram_wrdata[31:16] <= byte_memsrc[2]? {16{mem_rdata[31]}}:{16{mem_rdata[15]}};
                                end
                                else if (instr_lhu) begin
                                        regram_wen <= 1;
                                        regram_wrdata[15:0] <= byte_memsrc[2]? mem_rdata[31:16]:mem_rdata[15:0];
                                        regram_wrdata[31:16] <= 0;
                                end
                                                                
                                mem_addr <= pc_reg;
                        end
                end
                else if (i_type || r_type) begin
                        if (alu_ready) begin
                                regram_wen <= 1;
                                regram_wrdata <= aluout;
                                mem_addr <= pc_reg;
                        end        
                end
                else if (b_type) begin
                        if (alu_ready) begin
                                if (branch_cond) begin
                                        mem_addr <= branch_pc_reg;
                                end
                                else begin
                                        mem_addr <= pc_reg;
                                end        
                        end                                        
                end
                else if (instr_lui) begin
                        if (alu_ready) begin
                                regram_wen <= 1;
                                regram_wrdata[31:12] <= imm_u_type_reg[31:12];
                                regram_wrdata[11:0] <= 0;
                                mem_addr <= pc_reg;
                        end
                end
                else if (instr_auipc) begin
                        if (alu_ready) begin
                                regram_wen <= 1;
                                regram_wrdata <= aluout;
                                mem_addr <= pc_reg;
                        end
                end
                else if (instr_jal || instr_jalr) begin
                        if (alu_ready) begin
                                regram_wen <= 1;
                                regram_wrdata <= pc_reg;
                                mem_addr <= aluout;				
                        end
                end
`ifdef MULTIPLIER_DIVIDER                
                else if(instr_mul) begin
                        if(mul_ready) begin
                                regram_wen <= 1;
                                regram_wrdata <= product_mul[31:0];
                                mem_addr <= pc_reg;
                        end
                end
                else if(instr_mulhu || instr_mulh || instr_mulhsu) begin
                        if(mul_ready) begin
                                regram_wen <= 1;
                                regram_wrdata <= product_mul[63:32];
                                mem_addr <= pc_reg;
                        end
                end
                else if(instr_div || instr_divu) begin
                        if(div_ready) begin
                                regram_wen <= 1;
                                regram_wrdata <= rd_div;
                                mem_addr <= pc_reg;
                        end
                end
                else if(instr_rem || instr_remu) begin
                        if(div_ready) begin
                                regram_wen <= 1;
                                regram_wrdata <= rd_rem;
                                mem_addr <= pc_reg;
                        end
                end
`endif                
        end
        else begin
                regram_wen <= 0;
        end
end
endmodule




/***************************************************************
 * riscv_mul
 ***************************************************************/
`ifdef MULTIPLIER_DIVIDER
module riscv_mul (
    input wire clk,
    input wire resetn,    
    input wire [31:0] a,
    input wire [31:0] b,
    output wire [63:0] product,
    input wire start,
    input wire signeda,
    input wire signedb,
    output wire ready
);

    // Internal signals
    reg [31:0] a_reg, b_reg;
    reg [63:0] product_reg;
    reg [63:0] product_reg_neg;
    reg [5:0] counter; // 6-bit counter for 32 iterations
    reg busy;

    // State machine states
    localparam IDLE = 2'b00,
               MULTIPLY = 2'b01,
               DONE = 2'b10;

    reg [1:0] state, next_state;

    // State machine
    always @(posedge clk) begin
        if (!resetn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    assign product = ((a[31] & signeda) ^ (b[31] & signedb)) ? -product_reg:product_reg;
    assign ready = state == DONE;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = MULTIPLY;
                end else begin
                    next_state = IDLE;
                end
            end
            MULTIPLY: begin
                if (counter == 6'd32) begin
                    next_state = DONE;
                end else begin
                    next_state = MULTIPLY;
                end
            end
            DONE: begin
                    if (start == 0) begin
                    next_state = IDLE;
                end    
                else begin
                    next_state = state;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output and internal signal logic
    always @(posedge clk) begin
        if (!resetn) begin
            a_reg <= 32'b0;
            b_reg <= 32'b0;
            product_reg <= 64'b0;
            product_reg_neg <= 64'b0;
            counter <= 6'b0;
            //ready <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    a_reg <= (a[31] & signeda) ? -a:a;
                    b_reg <= (b[31] & signedb) ? -b:b;
                    product_reg <= 64'b0;
                    product_reg_neg <= 64'b0;
                    counter <= 6'b0;
              //      ready <= 1'b0;
                end
                MULTIPLY: begin
`ifdef MULTIPLIER_FAST
                    product_reg <= a_reg * b_reg;
                    counter <= 6'd32;
                    product_reg_neg <= -product_reg;
`else                            
                    if (b_reg[0]) begin
                        product_reg <= product_reg + (a_reg << counter);
                    end
                    b_reg <= b_reg >> 1;
                    counter <= counter + 1;
                    product_reg_neg <= -product_reg;
`endif
                end
                DONE: begin
                //    ready <= 1'b1;
                end
            endcase
        end
    end

endmodule


/***************************************************************
 * riscv_div_rem
 ***************************************************************/
module riscv_div_rem (
    input wire clk,
    input wire resetn,
    input wire start,
    input wire signeddiv,
    input wire signedrem,
    input wire [31:0] rs1, // Dividend
    input wire [31:0] rs2, // Divisor
    output reg [31:0] rd_div, // Quotient
    output reg [31:0] rd_rem, // Remainder
    output reg done // Done signal
);

reg [31:0] quotient;
reg [31:0] quotientmask;
reg [31:0] remainder;
reg [62:0] divisor;
reg [5:0] count;
reg busy;
wire endquotient;

assign endquotient = quotient >> 1;

always @(posedge clk) begin
    if (!resetn) begin
        rd_div <= 32'b0;
        rd_rem <= 32'b0;
        done <= 1'b0;
        quotient <= 32'b0;
        quotientmask <= 32'b0;
        remainder <= 32'b0;
        divisor <= 32'b0;
        busy <= 1'b0;
    end else if (!start) begin
        busy <= 1'b0;
        done <= 1'b0;
    end else if (start && !busy) begin
        if (rs2 != 0) begin
            quotient <= 32'b0;
            quotientmask <= 1 << 31;
            remainder <= (rs1[31] & (signeddiv || signedrem))? -rs1:rs1;
            divisor <= ((rs2[31] & (signeddiv || signedrem))? -rs2:rs2) << 31;
            busy <= 1'b1;
            done <= 1'b0;
        end else begin
            rd_div <= 32'hFFFFFFFF; // Indicate division by zero
            rd_rem <= rs1; // Remainder is the dividend when divisor is zero
            done <= 1'b1;
        end
    end else if (busy) begin
        if (quotientmask) begin               
            if (divisor <= remainder) begin
                remainder = remainder - divisor;
                quotient <= quotient | quotientmask;        
            end
            divisor <= divisor >> 1;
            quotientmask <= quotientmask >> 1;
        end else begin
            rd_div <= (((rs1[31] ^ rs2[31]) & signeddiv) || (rs1[31] && signedrem))? -quotient:quotient;
            rd_rem <= (((rs1[31] ^ rs2[31]) & signeddiv) || (rs1[31] && signedrem))? -remainder:remainder;
            done <= 1'b1;
            busy <= 1'b0;
        end
    end
end

endmodule
`endif

/***************************************************************
 * //YEL //Alusync
 ***************************************************************/
module ALUsync 
#(
        parameter p_alu_add  = 4'b0_000,
        parameter p_alu_sub  = 4'b1_000,
        parameter p_alu_sll  = 4'b0_001,
        parameter p_alu_slt  = 4'b0_010,
        parameter p_alu_sltu = 4'b0_011,
        parameter p_alu_xor  = 4'b0_100,
        parameter p_alu_srl  = 4'b0_101,
        parameter p_alu_sra  = 4'b1_101,
        parameter p_alu__or  = 4'b0_110,
        parameter p_alu_and  = 4'b0_111,
        parameter p_alussub  = 4'b1_111        
)
(
        input clk, resetn,
        input valid,
        input [31:0] a,b,
        input [3:0] ALUop,
        output reg[31:0] ALUOut,
        output reg ready,
        output reg over);// 0 indicate no overflow

        always @(posedge clk) begin
                if (!resetn) begin
                        ready <= 0;
                        ALUOut <= 0;
                        over <= 0; 
                end                        
                else if (valid) begin
                           case (ALUop)
                                p_alu_add  : ALUOut <=a+b;
                                p_alu_sub  : {over, ALUOut} <=a-b;
                                p_alu_and  : ALUOut <=a&b;
                                p_alu__or  : ALUOut <=a|b;
                                p_alu_xor  : ALUOut <=a^b;
                                p_alu_sll  : ALUOut <=a<<b[4:0];//left shift logical
                                p_alu_srl  : ALUOut <=a>>b[4:0];//right shift logical
                                p_alu_sra  : ALUOut <=$signed(a)>>>$signed(b[4:0]);//arithmetic right shift
                                p_alu_slt  : ALUOut <=$signed(a) < $signed(b)? 32'b1:32'b0;//set less than
                                p_alu_sltu : ALUOut <=a < b ? 32'b1:32'b0;//set less than unsigned
                                p_alussub  : {over, ALUOut} <= $signed(a) - $signed(b);
                        endcase
                        ready <= 1;
                end
                else begin
                        ready <= 0;
                end
        end

endmodule

module rispark32_reg (
        input clk, wen,
        input [5:0] waddr,
        input [5:0] raddr1,
        input [5:0] raddr2,
        input [31:0] wdata,
        output [31:0] rdata1,
        output [31:0] rdata2
`ifdef TRACE_RV32        
        ,
        input  [31:0] trace_file
`endif        
`ifdef TRACE_RV32
        ,
        output wire [31:0] dbg_x0,  
        output wire [31:0] dbg_x1,  
        output wire [31:0] dbg_x2,  
        output wire [31:0] dbg_x3, 
        output wire [31:0] dbg_x4,  
        output wire [31:0] dbg_x5,  
        output wire [31:0] dbg_x6,  
        output wire [31:0] dbg_x7,  
        output wire [31:0] dbg_x8,  
        output wire [31:0] dbg_x9,  
        output wire [31:0] dbg_x10, 
        output wire [31:0] dbg_x11, 
        output wire [31:0] dbg_x12, 
        output wire [31:0] dbg_x13, 
        output wire [31:0] dbg_x14, 
        output wire [31:0] dbg_x15, 
        output wire [31:0] dbg_x16, 
        output wire [31:0] dbg_x17, 
        output wire [31:0] dbg_x18, 
        output wire [31:0] dbg_x19, 
        output wire [31:0] dbg_x20, 
        output wire [31:0] dbg_x21, 
        output wire [31:0] dbg_x22, 
        output wire [31:0] dbg_x23, 
        output wire [31:0] dbg_x24, 
        output wire [31:0] dbg_x25,
        output wire [31:0] dbg_x26, 
        output wire [31:0] dbg_x27, 
        output wire [31:0] dbg_x28, 
        output wire [31:0] dbg_x29, 
        output wire [31:0] dbg_x30, 
        output wire [31:0] dbg_x31
`endif        
);
        
`ifdef TRACE_RV32        
        assign dbg_x0  = regs[0];
        assign dbg_x1  = regs[1];
        assign dbg_x2  = regs[2];
        assign dbg_x3  = regs[3];
        assign dbg_x4  = regs[4];
        assign dbg_x5  = regs[5];
        assign dbg_x6  = regs[6];
        assign dbg_x7  = regs[7];
        assign dbg_x8  = regs[8];
        assign dbg_x9  = regs[9];
        assign dbg_x10  = regs[10];
        assign dbg_x11  = regs[11];
        assign dbg_x12  = regs[12];
        assign dbg_x13  = regs[13];
        assign dbg_x14  = regs[14];
        assign dbg_x15  = regs[15];
        assign dbg_x16  = regs[16];
        assign dbg_x17  = regs[18];
        assign dbg_x18  = regs[18];
        assign dbg_x19  = regs[19];
        assign dbg_x20  = regs[20];
        assign dbg_x21  = regs[21];
        assign dbg_x22  = regs[22];
        assign dbg_x23  = regs[23];
        assign dbg_x24  = regs[24];
        assign dbg_x25  = regs[25];
        assign dbg_x26  = regs[26];
        assign dbg_x27  = regs[27];
        assign dbg_x28  = regs[28];
        assign dbg_x29  = regs[29];
        assign dbg_x30  = regs[30];
        assign dbg_x31  = regs[31];
`endif        


        reg [31:0] regs [0:31];
                
        always @(posedge clk)
                if (wen) regs[waddr[4:0]] <= wdata;

`ifdef TRACE_RV32
        reg wen_dly;
        
        always @(negedge clk) begin
                        wen_dly <= wen;
        end
        
        //to take only one one wen that may last two cycles
        //last one cycle for loads for instance but in decode
        always @(posedge wen_dly) begin
                $fwrite(trace_file, "..............reg: %x data: %x\n", waddr[4:0], wdata);                    
        end
`endif        
        assign rdata1 = regs[raddr1[4:0]];
        assign rdata2 = regs[raddr2[4:0]];
        
endmodule
