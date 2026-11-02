// A version of the dhrystone test bench that isn't using the look-ahead interface

`timescale 1 ns / 1 ps

//`define LONG_READY
//`define WAVEFORM

module testbench;
	reg clk = 1;
	reg resetn = 0;
	wire trap;

	always #5 clk = ~clk;

	initial begin
		repeat (100) @(posedge clk);
		resetn <= 1;
	end

	wire mem_valid;
	wire mem_instr;
	reg  mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0]  mem_wstrb;
	reg  [31:0] mem_rdata;
	wire [7:0] mem_dbg;

/*
	picorv32 #(
		.BARREL_SHIFTER(1),
		.ENABLE_FAST_MUL(1),
		.ENABLE_DIV(1),
		.PROGADDR_RESET('h10000),
		.STACKADDR('h10000)
	) uut (
		.clk         (clk        ),
		.resetn      (resetn     ),
		.trap        (trap       ),
		.mem_valid   (mem_valid  ),
		.mem_instr   (mem_instr  ),
		.mem_ready   (mem_ready  ),
		.mem_addr    (mem_addr   ),
		.mem_wdata   (mem_wdata  ),
		.mem_wstrb   (mem_wstrb  ),
		.mem_rdata   (mem_rdata  )
	);
*/	
	rispark32 #(.reset_vector(0)) rispark32_core (
		.clk      (clk   ),
		.resetn   (resetn),
		.trap     (trap  ),

		.mem_valid(mem_valid),
		.mem_addr (mem_addr ),
		.mem_wdata(mem_wdata),
		.mem_wstrb(mem_wstrb),
		.mem_instr(mem_instr),
		.mem_ready(mem_ready),
		.mem_rdata(mem_rdata),

		.irq(1'b0),
		.eoi(),

		.trace_valid(),
		.trace_data ()
	);
	

	reg [7:0] memory [0:256*1024-1];
	initial $readmemh("./dhry.hex", memory);
	
	assign mem_dbg = memory[0];
	reg [3:0] count_dly;

	always @(posedge clk) begin
		mem_ready <= 1'b0;
		count_dly <= 0;

		mem_rdata[ 7: 0] <= 'bx;
		mem_rdata[15: 8] <= 'bx;
		mem_rdata[23:16] <= 'bx;
		mem_rdata[31:24] <= 'bx;

		if (mem_valid & !mem_ready) begin
`ifdef LONG_READY		
			count_dly <= count_dly + 1'b1;
			if (count_dly == 4'b1111) begin
`endif			
				if (|mem_wstrb) begin
					mem_ready <= 1'b1;
	
					case (mem_addr)
						32'h1000_0000: begin
							$write("%c", mem_wdata);
							$fflush();
						end
						default: begin
							if (mem_wstrb[0]) memory[mem_addr + 0] <= mem_wdata[ 7: 0];
							if (mem_wstrb[1]) memory[mem_addr + 1] <= mem_wdata[15: 8];
							if (mem_wstrb[2]) memory[mem_addr + 2] <= mem_wdata[23:16];
							if (mem_wstrb[3]) memory[mem_addr + 3] <= mem_wdata[31:24];
						end
					endcase
				end
				else begin
					mem_ready <= 1'b1;
	
					mem_rdata[ 7: 0] <= memory[mem_addr + 0];
					mem_rdata[15: 8] <= memory[mem_addr + 1];
					mem_rdata[23:16] <= memory[mem_addr + 2];
					mem_rdata[31:24] <= memory[mem_addr + 3];			
				end
`ifdef LONG_READY
			end
`endif			
		end
		else begin
			mem_ready <= 1'b0;
		end
		
	end	

`ifdef WAVEFORM
	initial begin
		$dumpfile("testbench_nola.vcd");
		$dumpvars(0, testbench);
	end
`endif

	always @(posedge clk) begin
		if (resetn && trap) begin
			repeat (10) @(posedge clk);
			$display("TRAP");
			$finish;
		end
	end
endmodule
