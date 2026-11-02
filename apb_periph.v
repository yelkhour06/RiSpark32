

//-----------------------------------------------------------------------------------
//   Memory Map
//-----------------------------------------------------------------------------------
//   1) 0x0 : 0x800000 //1 MB

//-----------------------------------------------------------------------------------

// Command timing
// ==============
// 1. Command valid assertion with valid address.
// 2. Output ready in following period
// 3. End of cycle when both psel and pready are on
//
//                __    __    __    __    __    __    __
// pclk        __/  \__/  \__/  \__/  \__/  \__/  \__/  \
//                            ____________________
// i_paddr     ______xx______/C0         C1       \__xx
//                                  _____       _____ 
// i_penable   ____________________/     \_____/     \___
//                            _______________________ 
// i_psel   _________________/                       \___
//                                  _____       _____ 
// o_pready    ____________________/     \_____/     \___
//
// Modules
// =======
// apb_mem: memory for test.hex code + ram
//           Base address (see top) ---- 0x0000_0000
// apb_regs: general purpore registers 
//           Base address (see top) ---- 0x0100_0000
//           0x0 - RW - systick enable
//           0x4 - RW - systick period
//           0x8 - RO - systick count
//           0xC- RW - GP0
//           0x10- RW - GP1 
// apb_tb: general purpore registers for testbench
//           Base address (see top) ---- 0x1000_0000
//           0x0 - WO - general ASCII print
//           0x4 - WO - general Pass print
//           0x8 - WO - general Fail print   
//           0xC - RW - Interrupt enable
//           0x10- RW - Interrupt activation counter 



module apb_mem #(
   // Configurable Parameters
   parameter DW = 32,  // Data width
   parameter AW = 32,  // Address width; max. 32 as per APB spec
   parameter LR = 0    //Long Ready
)
(
   // Clock and Reset
   input  wire                  pclk,      // Clock
   input  wire                  presetn,   // Reset (active low)

   // APB Interface
   input  wire [AW-1:0]         i_paddr,   // Address
   input  wire                  i_pwrite,  // Write enable
   input  wire                  i_psel,    // Select
   input  wire                  i_penable, // Enable
   input  wire [DW-1:0]         i_pwdata,  // Write data
   input  wire [(DW/8)-1:0]     i_pstrb,   // Write strobe (strobe width = DW/8)
   output reg  [DW-1:0]         o_prdata,  // Read data
   output reg                   o_pslverr, // Slave error
   output reg                   o_pready,  // Ready

   // HW interface
   output wire                  o_hw_ctl,  // Control signal from APB registers to external HW
   input  wire                  i_hw_sts   // Status signal from external HW to APB registers
);

   // Local parameters
   localparam SW = DW/8;               // Strobe width
   localparam ADDR_LSB = $clog2(DW/8); // Address LSB index (byte addressing)
   localparam N_REG = (1 << (AW - ADDR_LSB)); // Number of registers

   // State encoding
   localparam IDLE     = 2'b00;
   localparam W_ACCESS = 2'b01;
   localparam R_ACCESS = 2'b10;
   localparam R_WAIT   = 2'b11;

   reg [1:0] state_ff;
   reg [31:0] wait_cnt;

   // Registers array (5 registers)
   reg [DW-1:0] apb_reg [0:4];

   // Read/write requests
   wire req_rd = i_psel && ~i_pwrite;
   wire req_wr = i_psel &&  i_pwrite;

   // Write and read errors
   wire wr_err;
   wire rd_err;

   integer i;

   //mem interface
   reg [1023:0] firmware_file;
   reg [7:0] memory [0:1024*64-1]; //64kB
   initial begin
   	   if (!$value$plusargs("firmware=%s", firmware_file))
   		   firmware_file = "firmware/test.hex";
   	   $readmemh(firmware_file, memory);
   end	

   // Synchronous logic: state machine and register read/write
   always @(posedge pclk or negedge presetn) begin
      if (!presetn) begin
         state_ff <= IDLE;
         o_prdata <= {DW{1'bx}};
         o_pready <= 1'b0;
         o_pslverr <= 1'b0;
	 wait_cnt <= 32'b0;
      end else begin
         // Register error signals
         o_pslverr <= wr_err | rd_err;

         case (state_ff)
            IDLE: begin
               o_pready <= 1'b0;
	       if (LR == 0) begin
                   if (req_wr) begin	          
                       o_pready <= 1'b1; // Write access no wait state
                       state_ff <= W_ACCESS;
                   end else if (req_rd) begin
                       o_pready <= 1'b1; // Read access no wait state
                       state_ff <= R_ACCESS;
		       o_prdata[ 7: 0] <= memory[i_paddr + 0];
		       o_prdata[15: 8] <= memory[i_paddr + 1];
		       o_prdata[23:16] <= memory[i_paddr + 2];
		       o_prdata[31:24] <= memory[i_paddr + 3];
		       /*
		       o_prdata[ 7: 0] <= memory[i_paddr >> 2][ 7: 0];
		       o_prdata[15: 8] <= memory[i_paddr >> 2][15: 8];
		       o_prdata[23:16] <= memory[i_paddr >> 2][23:16];
		       o_prdata[31:24] <= memory[i_paddr >> 2][31:24];
                       */
		   end    
               end else begin
	           state_ff <= R_WAIT;
	       end
            end
	    
	    R_WAIT: begin	        
		if (wait_cnt == LR) begin
		    wait_cnt <= 32'b0;
		    if (req_wr) begin	          
                       o_pready <= 1'b1; // Write access no wait state
                       state_ff <= W_ACCESS;  
                    end else if (req_rd) begin
                       o_pready <= 1'b1; // Read access no wait state
                       state_ff <= R_ACCESS;
		       o_prdata[ 7: 0] <= memory[i_paddr + 0];
		       o_prdata[15: 8] <= memory[i_paddr + 1];
		       o_prdata[23:16] <= memory[i_paddr + 2];
		       o_prdata[31:24] <= memory[i_paddr + 3];
		       /*
		       o_prdata[ 7: 0] <= memory[i_paddr >> 2][ 7: 0];
		       o_prdata[15: 8] <= memory[i_paddr >> 2][15: 8];
		       o_prdata[23:16] <= memory[i_paddr >> 2][23:16];
		       o_prdata[31:24] <= memory[i_paddr >> 2][31:24];
		       */
		   end
		end else begin
		    wait_cnt <= wait_cnt + 1;
		    o_prdata <= 32'ha5a5_a5a5;
		    state_ff <= R_WAIT;
		end    
	    end

            W_ACCESS: begin
               if (req_wr && i_penable) begin		
		  if (i_pstrb[0]) memory[i_paddr + 0] <= i_pwdata[ 7: 0];
		  if (i_pstrb[1]) memory[i_paddr + 1] <= i_pwdata[15: 8];
		  if (i_pstrb[2]) memory[i_paddr + 2] <= i_pwdata[23:16];
		  if (i_pstrb[3]) memory[i_paddr + 3] <= i_pwdata[31:24];
                  /*
		  if (i_pstrb[0]) memory[i_paddr >> 2][ 7: 0] <= i_pwdata[ 7: 0];
		  if (i_pstrb[1]) memory[i_paddr >> 2][15: 8] <= i_pwdata[15: 8];
		  if (i_pstrb[2]) memory[i_paddr >> 2][23:16] <= i_pwdata[23:16];
		  if (i_pstrb[3]) memory[i_paddr >> 2][31:24] <= i_pwdata[31:24];
                  */  
	       end
               o_pready <= 1'b0;
               state_ff <= IDLE;
            end

            R_ACCESS: begin	    
               o_pready <= 1'b0; // One wait state
               state_ff <= IDLE;
            end

            default: state_ff <= IDLE;
         endcase
      end
   end

   // Drive HW control output from apb_reg[0]
   assign o_hw_ctl = apb_reg[0];

endmodule

//-----------------------------------------------------------------------------------
//   apb_tb
//-----------------------------------------------------------------------------------
module apb_tb #(
   // Configurable Parameters
   parameter DW = 32,  // Data width
   parameter AW = 32,    // Address width; max. 32 as per APB spec
   parameter LR = 0    //Long Ready
)
(
   // Clock and Reset
   input  wire                  pclk,      // Clock
   input  wire                  presetn,   // Reset (active low)

   // APB Interface
   input  wire [AW-1:0]         i_paddr,   // Address
   input  wire                  i_pwrite,  // Write enable
   input  wire                  i_psel,    // Select
   input  wire                  i_penable, // Enable
   input  wire [DW-1:0]         i_pwdata,  // Write data
   input  wire [(DW/8)-1:0]     i_pstrb,   // Write strobe (strobe width = DW/8)
   output reg  [DW-1:0]         o_prdata,  // Read data
   output reg                   o_pslverr, // Slave error
   output reg                   o_pready,  // Ready

   // HW interface
   output reg [DW-1:0]         o_irq_vec  // output irq sources
);

   // Local parameters
   localparam SW = DW/8;               // Strobe width
   localparam ADDR_LSB = $clog2(DW/8); // Address LSB index (byte addressing)
   localparam N_REG = (1 << (AW - ADDR_LSB)); // Number of registers

   // State encoding
   localparam IDLE     = 2'b00;
   localparam W_ACCESS = 2'b01;
   localparam R_ACCESS = 2'b10;
   localparam R_WAIT   = 2'b11;

   reg [1:0] state_ff;
   reg [31:0] wait_cnt;

   // Registers array (5 registers)
   reg [DW-1:0] apb_reg [0:4];
   reg [DW-1:0] apb_reg_prev;
   wire [DW-1:0] apb_regdbg0;
   assign apb_regdbg0 = apb_reg[0];
   wire [DW-1:0] apb_regdbg1;
   assign apb_regdbg1 = apb_reg[1];

   // Read/write requests
   wire req_rd = i_psel && ~i_pwrite;
   wire req_wr = i_psel &&  i_pwrite;

   // Write and read errors
   wire wr_err;
   wire rd_err;

   integer i;

   // Synchronous logic: state machine and register read/write
   always @(posedge pclk or negedge presetn) begin
      if (!presetn) begin
         state_ff <= IDLE;
         o_prdata <= {DW{1'bx}};
         o_pready <= 1'b0;
         o_pslverr <= 1'b0;
	 wait_cnt <= 32'b0;
	 //for (int unsigned i = 0; i < 5; i++) begin
	 //    apb_reg[i] <= 32'b0;
	 //end
	 apb_reg[0] <= 32'b0;
	 apb_reg[1] <= 32'hF; //default irq delay
      end else begin
         // Register error signals
         o_pslverr <= wr_err | rd_err;

         case (state_ff)
            IDLE: begin
               o_pready <= 1'b0;
	       if (LR == 0) begin
                   if (req_wr) begin	          
                       o_pready <= 1'b1; // Write access no wait state
                       state_ff <= W_ACCESS;
                   end else if (req_rd) begin
                       o_pready <= 1'b1; // Read access no wait state
                       case (i_paddr[AW-1:ADDR_LSB])
                           3: o_prdata <= apb_reg[0];
			   4: o_prdata <= apb_reg[1];
                       endcase
                       state_ff <= R_ACCESS;
		   end
               end else begin
	           state_ff <= R_WAIT;
	       end
            end
	    
	    R_WAIT: begin	        
		if (wait_cnt == LR) begin
		    wait_cnt <= 32'b0;
		    if (req_wr) begin	          
                       o_pready <= 1'b1; // Write access no wait state
                       state_ff <= W_ACCESS;
                    end else if (req_rd) begin
                       o_pready <= 1'b1; // Read access no wait state
                       case (i_paddr[AW-1:ADDR_LSB])
                           3: o_prdata <= apb_reg[0];
			   4: o_prdata <= apb_reg[1];
                       endcase
                       state_ff <= R_ACCESS;
		   end
		end else begin
		    wait_cnt <= wait_cnt + 1;
		    o_prdata <= 32'ha5a5_a5a5;
		    state_ff <= R_WAIT;
		end    
	    end	    
	    
            W_ACCESS: begin
               if (req_wr && i_penable) begin				      
		    case (i_paddr[AW-1:ADDR_LSB])
		       0: $write("%c", i_pwdata);
		       1: $write(" -> pass\n");
		       2: $write(" -> fail\n");
		       3: apb_reg[0] <= i_pwdata;
		       4: apb_reg[1] <= i_pwdata;
		       default: ; // No write on other addresses
		    endcase	          
               end
               o_pready <= 1'b0;
               state_ff <= IDLE;
            end

            R_ACCESS: begin	    
               o_pready <= 1'b0; // One wait state
               state_ff <= IDLE;
            end

            default: state_ff <= IDLE;
         endcase
      end
   end

   reg [31:0] irq_cnt;
   always @(posedge pclk or negedge presetn) begin
      if (!presetn) begin
          irq_cnt <= 32'b0;
	  apb_reg_prev <= 32'b0;
	  o_irq_vec <= 32'b0;
      end else begin
          apb_reg_prev <= apb_reg[0];
	  
	  if (apb_reg_prev != 0 && apb_reg[0] == 0) begin
	      o_irq_vec = apb_reg[0];               //falling immediate irq 	  
	  end else begin    
              if (irq_cnt == apb_reg[1]) begin
	          irq_cnt <= 32'b0;
	          o_irq_vec = apb_reg[0];
	      end
	      else if (irq_cnt != 0) begin
	          irq_cnt <= irq_cnt + 1;
	      end
	      else begin
                  if (apb_reg_prev == 0 && apb_reg[0] != 0) begin
	              irq_cnt <= irq_cnt + 1;
                  end
	      end
	  end
	  
	  
      end
   end    

endmodule

//-----------------------------------------------------------------------------------
//   apb_regs
//-----------------------------------------------------------------------------------
module apb_regs #(
   // Configurable Parameters
   parameter DW = 32,  // Data width
   parameter AW = 32,    // Address width; max. 32 as per APB spec
   parameter LR = 0    //Long Ready
)
(
   // Clock and Reset
   input  wire                  pclk,      // Clock
   input  wire                  presetn,   // Reset (active low)

   // APB Interface
   input  wire [AW-1:0]         i_paddr,   // Address
   input  wire                  i_pwrite,  // Write enable
   input  wire                  i_psel,    // Select
   input  wire                  i_penable, // Enable
   input  wire [DW-1:0]         i_pwdata,  // Write data
   input  wire [(DW/8)-1:0]     i_pstrb,   // Write strobe (strobe width = DW/8)
   output reg  [DW-1:0]         o_prdata,  // Read data
   output reg                   o_pslverr, // Slave error
   output reg                   o_pready,  // Ready

   // HW interface
   output reg                  o_systick_irq
);

   // Local parameters
   localparam SW = DW/8;               // Strobe width
   localparam ADDR_LSB = $clog2(DW/8); // Address LSB index (byte addressing)
   localparam N_REG = (1 << (AW - ADDR_LSB)); // Number of registers

   // State encoding
   localparam IDLE     = 2'b00;
   localparam W_ACCESS = 2'b01;
   localparam R_ACCESS = 2'b10;

   reg [1:0] state_ff;
   reg [31:0] wait_cnt;

   // Registers array (5 registers)
   reg  [DW-1:0] apb_reg [0:4];
   wire [DW-1:0] apb_regdbg;
   reg systick_en; 
   reg [DW-1:0] systick_period;
   reg systick_period_wr;
   reg [DW-1:0] systick_cnt;
   
   assign apb_regdbg = apb_reg[0]; 

   // Read/write requests
   wire req_rd = i_psel && ~i_pwrite;
   wire req_wr = i_psel &&  i_pwrite;

   // Write and read errors
   wire wr_err;
   wire rd_err;

   integer i;

   // Synchronous logic: state machine and register read/write
   always @(posedge pclk or negedge presetn) begin
      if (!presetn) begin
         state_ff <= IDLE;
         o_prdata <= {DW{1'bx}};
         o_pready <= 1'b0;
         o_pslverr <= 1'b0;
	 wait_cnt <= 32'b0;
	 systick_period_wr <= 1'b0;
	 systick_en <= 1'b0;
	 systick_period <= 32'b0;
	 for (int i = 0; i < 5; i++) begin
	     apb_reg[i] <= 32'b0;
	 end
      end else begin
         // Register error signals
         o_pslverr <= wr_err | rd_err;
	 systick_period_wr <= 1'b0;

         case (state_ff)
            IDLE: begin
               o_pready <= 1'b0;
	       if (LR == 0) begin
                   if (req_wr) begin	          
                       o_pready <= 1'b1; // Write access no wait state
                       state_ff <= W_ACCESS;
                   end else if (req_rd) begin
                       o_pready <= 1'b1; // Read access no wait state
                       state_ff <= R_ACCESS;		       
                       case (i_paddr[AW-1:ADDR_LSB])
                           0: o_prdata <= {31'b0, systick_en};
			   1: o_prdata <= systick_period;
                           2: o_prdata <= systick_cnt;
                           3: o_prdata <= apb_reg[0];
                           4: o_prdata <= apb_reg[1];
                           default: o_prdata <= {DW{1'b0}}; // Invalid or WO reads return 0
                       endcase		       
		   end
               end else begin
	           state_ff <= IDLE;
	       end
            end
	    
            W_ACCESS: begin
               if (req_wr && i_penable) begin				      	          
	       	   case (i_paddr[AW-1:ADDR_LSB])
		       0: systick_en <= i_pwdata[0];  //[0]: systick enable
		       1: begin 
		           systick_period <= i_pwdata;  //[31:0] systick period
			   systick_period_wr <= 1'b1;
		       end
		       //2: systick_cnt <= i_pwdata;  RO //[31:0] systick count
		       3: apb_reg[0] <= i_pwdata;
		       4: apb_reg[1] <= i_pwdata;
		     default: ; // No write on other addresses
		   endcase		  
               end
               o_pready <= 1'b0;
               state_ff <= IDLE;
            end

            R_ACCESS: begin	    
               o_pready <= 1'b0; // One wait state
               state_ff <= IDLE;
            end

            default: state_ff <= IDLE;
         endcase
      end
   end



   always @(posedge pclk or negedge presetn) begin
       if (!presetn) begin
           systick_cnt <= 32'b0;
	   o_systick_irq <= 1'b0;
       end else begin
           o_systick_irq <= 1'b0;
	   if (systick_en && (systick_cnt == systick_period)) begin
	       systick_cnt <= 32'b0;
	       o_systick_irq <= 1'b1; 
	   end
	   else if (systick_en) begin
	       systick_cnt <= systick_cnt + 1;
	   end
       end
   end




endmodule
