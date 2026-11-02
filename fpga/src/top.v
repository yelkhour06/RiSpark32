`timescale 1 ns / 1 ps

module Reset_Sync (
 input clk,
 input ext_reset,
 output reset_sync
);

 reg [3:0] reset_cnt = 0;
 
 always @(posedge clk or negedge ext_reset) begin
     if (~ext_reset)
         reset_cnt <= 4'b0;
     else
         reset_cnt <= reset_cnt + !reset_sync;
 end
 
 assign reset_sync = &reset_cnt;

endmodule


module system (
	input      clk,
	input      resetn,
	output     ser_tx
);

// 4096 32bit words = 16kB
parameter MEM_SIZE = 4096*4;

wire mem_valid;
wire mem_instr;
reg mem_ready;
wire [31:0] mem_addr;
wire [31:0] mem_wdata;
wire [3:0] mem_wstrb;
reg [31:0] mem_rdata;

wire pll_clk, pll_lock, pll_clk_out, resetn_out;
wire resetn_sync, reset_sync;

/*
Gowin_rPLL u_Gowin_rPLL
(.clkin     (clk     )
,.clkout    (pll_clk)  
,.lock      (pll_lock  )
);

Gowin_CLKDIV u_clkdiv
(.resetn(resetn)
,.hclkin(pll_clk)
,.clkout(pll_clk_out)
);
*/

//assign pll_clk_out = clk;
//assign resetn_out = resetn & pll_lock;

Reset_Sync u_Reset_Sync (
    .clk (clk),
    .ext_reset(resetn     ),
    .reset_sync(reset_sync)
);

assign resetn_sync = !reset_sync;

rispark32 #(
.reset_vector(0),
.irq_vector('h1_0000),
.csr_base_address(32'h0100_0400)
) rispark32_core (
    .clk         (clk         ),
    .resetn      (resetn_sync     ),
    .psel        (mem_valid   ),
    .pready      (mem_ready   ),
    .paddr       (mem_addr    ),
    .pwdata      (mem_wdata   ),
    .pwstrb      (mem_wstrb   ),
    .prdata      (mem_rdata   ),
    .irq         (1'b0)
);

wire uart_wait;

simpleuart #(
.DEFAULT_DIV(234)
) simpleuart_inst (
   .clk(clk),
   .resetn(resetn_sync),
   .ser_tx(ser_tx),
   .reg_dat_we(mem_valid && !mem_ready && |mem_wstrb && mem_addr == 32'h1000_0000),
   .reg_dat_di(mem_wdata),
   .reg_dat_wait(uart_wait)
);

reg [31:0] memory [0:MEM_SIZE-1];
initial $readmemh("firmware.hex", memory);

always @(posedge clk) begin
    mem_ready <= (mem_valid && !mem_ready && !mem_wstrb) || 
                 (mem_valid && !mem_ready && |mem_wstrb && mem_addr == 32'h1000_0000 && !uart_wait);

    mem_rdata <= memory[mem_addr >> 2];

    (* parallel_case *)
    case (1)
        mem_valid && !mem_ready && |mem_wstrb && (mem_addr >> 2) < MEM_SIZE: begin
            if (mem_wstrb[0]) memory[mem_addr >> 2][ 7: 0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) memory[mem_addr >> 2][15: 8] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
            mem_ready <= 1;
        end
    endcase
end

endmodule
