`timescale 1 ns / 1 ps


//`define WAVEFORM
`define PERIOD 5
`define LONG_READY 10*`PERIOD

module testbench;
	reg clk = 1;
	reg resetn = 0;

	always #`PERIOD clk = ~clk;

	initial begin
		repeat (5) @(posedge clk);
		resetn <= 1;
	end

	wire mem_valid;
	wire mem_instr;
	reg  mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0]  mem_wstrb;
	wire  [31:0] mem_rdata;
	wire [7:0] mem_dbg;
	wire irq;
	reg  [31:0] irq_time;
	
	assign mem_rdata = (o_prdata_mem & {32{o_pready_mem}})  | 
	                   (o_prdata_tb & {32{o_pready_tb}})|
			   (o_prdata_regs & {32{o_pready_regs}});
	
	rispark32 #(.reset_vector(0),
	            .irq_vector('hFF00),
		    .csr_base_address('h0100_0000)
		    ) rispark32_core (
		    .clk      (clk   ),
		    .resetn   (resetn),

		    .psel  (mem_valid),
		    .paddr (mem_addr ),
		    .pwdata(mem_wdata),
		    .pwstrb(mem_wstrb),
		    .pready(o_pready_mem | o_pready_tb | o_pready_regs),
		    .prdata(mem_rdata),

		    .irq(irq | o_systick_irq)
	);
	
`ifdef WAVEFORM
	initial begin
		$dumpfile("testbench.vcd");
		$dumpvars(0, testbench);
	end	
`endif


wire i_psel_mem = mem_valid & (mem_addr[31:24] == 0);
wire i_penable_mem = i_psel_mem & o_pready_mem;
wire i_pwrite_mem = |mem_wstrb;
wire [31:0] o_prdata_mem;
wire o_pready_mem;

// Device Under Test
apb_mem #(
    .DW(32),
    .AW(24),
    .LR(0)
) i_apb_mem (
    .pclk(clk),
    .presetn(resetn),
    .i_paddr(mem_addr[23:0]),
    .i_pwrite(i_pwrite_mem),
    .i_psel(i_psel_mem),
    .i_penable(i_penable_mem),
    .i_pwdata(mem_wdata),
    .i_pstrb(mem_wstrb),
    .o_prdata(o_prdata_mem),
    .o_pslverr(),
    .o_pready(o_pready_mem),
    .o_hw_ctl(),
    .i_hw_sts()
);

wire i_psel_tb = mem_valid & (mem_addr[28] == 1); //0x1000_0000
wire i_penable_tb = i_psel_tb & o_pready_tb;
wire i_pwrite_tb = |mem_wstrb;
wire [31:0] o_prdata_tb;
wire [31:0] o_irq_vec;
wire o_pready_tb;

assign irq = |o_irq_vec;
// Device Under Test
apb_tb #(
    .DW(32),
    .AW(11),                    //0x400 - 1k
    .LR(0)
) i_apb_tb_1 (
    .pclk(clk),
    .presetn(resetn),
    .i_paddr({1'b0, mem_addr[9:0]}),
    .i_pwrite(i_pwrite_tb),
    .i_psel(i_psel_tb),
    .i_penable(i_penable_tb),
    .i_pwdata(mem_wdata),
    .i_pstrb(mem_wstrb),
    .o_prdata(o_prdata_tb),
    .o_pslverr(),
    .o_pready(o_pready_tb),
    .o_irq_vec(o_irq_vec)
);

wire i_psel_regs = mem_valid & (mem_addr[31:24] == 1) & (mem_addr[23:16] == 0); //0x0100_XXXX
wire i_penable_regs = i_psel_regs & o_pready_regs;
wire i_pwrite_regs = |mem_wstrb;
wire [31:0] o_prdata_regs;
wire o_pready_regs;
wire o_systick_irq;
// Device Under Test
apb_regs #(
    .DW(32),
    .AW(16),                    //
    .LR(0)
) i_apb_regs_1 (
    .pclk(clk),
    .presetn(resetn),
    .i_paddr(mem_addr[15:0]),
    .i_pwrite(i_pwrite_regs),
    .i_psel(i_psel_regs),
    .i_penable(i_penable_regs),
    .i_pwdata(mem_wdata),
    .i_pstrb(mem_wstrb),
    .o_prdata(o_prdata_regs),
    .o_pslverr(),
    .o_pready(o_pready_regs),
    .o_systick_irq(o_systick_irq)
);


endmodule
