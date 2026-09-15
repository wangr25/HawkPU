module tw_rom (
	input logic clk,
	input logic rstn,
	input logic ren,
	input logic [10:0] ptr,
	input logic [1:0] strb,		// strobe, 01-low 16 bits, 10-high 16 bits, 11-all
	input logic [1:0] pat_grp,		// select twiddle factors' pattern group
	input logic [1:0] pat_sel,

	// d*a_o to BFU_A, d*b_o to BFU_B
    output logic [31:0] d0a_o,
    output logic [31:0] d0b_o,
    output logic [31:0] d1a_o,
    output logic [31:0] d1b_o,
    output logic [31:0] d2a_o,
    output logic [31:0] d2b_o,
    output logic [31:0] d3a_o,
    output logic [31:0] d3b_o
);


// rom wrapper
logic                       rom_ren;
logic [9:0]                 rom_paddr;  
logic [31:0]                d0a, d0b; 	// bank0
logic [31:0]                d1a, d1b; 	// bank1
logic [31:0]                d2a, d2b; 	// bank2
logic [31:0]                d3a, d3b; 	// bank3

assign rom_ren = ren;
assign rom_paddr = {ptr[10:2],1'b0};

rom_wrapper #(
    .MEM_SIZE   (1024),
    .DATA_WIDTH (32),
    .ADDR_WIDTH (10)
) u_rom_wrapper (
    .clka       (clk),
    .rom_ren    (rom_ren),
    .rom_paddr  (rom_paddr),
    .d0a        (d0a),
    .d0b        (d0b),
    .d1a        (d1a),
    .d1b        (d1b),
    .d2a        (d2a),
    .d2b        (d2b),
    .d3a        (d3a),
    .d3b        (d3b)
);

// strobe
logic [31:0] d0a_strb, d0b_strb;
logic [31:0] d1a_strb, d1b_strb;
logic [31:0] d2a_strb, d2b_strb;
logic [31:0] d3a_strb, d3b_strb;

always @(*) begin
	case (strb)
		2'b01: begin
			d0a_strb = {16'b0, d0a[15:0]};
			d0b_strb = {16'b0, d0b[15:0]};
			d1a_strb = {16'b0, d1a[15:0]};
			d1b_strb = {16'b0, d1b[15:0]};
			d2a_strb = {16'b0, d2a[15:0]};
			d2b_strb = {16'b0, d2b[15:0]};
			d3a_strb = {16'b0, d3a[15:0]};
			d3b_strb = {16'b0, d3b[15:0]};
		end
		2'b10: begin
			d0a_strb = {16'b0, d0a[31:16]};
			d0b_strb = {16'b0, d0b[31:16]};
			d1a_strb = {16'b0, d1a[31:16]};
			d1b_strb = {16'b0, d1b[31:16]};
			d2a_strb = {16'b0, d2a[31:16]};
			d2b_strb = {16'b0, d2b[31:16]};
			d3a_strb = {16'b0, d3a[31:16]};
			d3b_strb = {16'b0, d3b[31:16]};
		end
		default: begin
			d0a_strb = d0a;
			d0b_strb = d0b;
			d1a_strb = d1a;
			d1b_strb = d1b;
			d2a_strb = d2a;
			d2b_strb = d2b;
			d3a_strb = d3a;
			d3b_strb = d3b;
		end
	endcase
end

// pattern

always@(*) begin
	case (pat_grp)
		2'b00: begin
			case (pat_sel[1:0])
				2'b00: begin
					d0a_o = d0a_strb;
					d1a_o = d0a_strb;
					d2a_o = d0a_strb;
					d3a_o = d0a_strb;
					d0b_o = d0b_strb;
					d1b_o = d0b_strb;
					d2b_o = d0b_strb;
					d3b_o = d0b_strb;
				end
				2'b01: begin
					d0a_o = d1a_strb;
					d1a_o = d1a_strb;
					d2a_o = d1a_strb;
					d3a_o = d1a_strb;
					d0b_o = d1b_strb;
					d1b_o = d1b_strb;
					d2b_o = d1b_strb;
					d3b_o = d1b_strb;
				end
				2'b10: begin
					d0a_o = d2a_strb;
					d1a_o = d2a_strb;
					d2a_o = d2a_strb;
					d3a_o = d2a_strb;
					d0b_o = d2b_strb;
					d1b_o = d2b_strb;
					d2b_o = d2b_strb;
					d3b_o = d2b_strb;
				end
				//2'b11: begin
				default: begin
					d0a_o = d3a_strb;
					d1a_o = d3a_strb;
					d2a_o = d3a_strb;
					d3a_o = d3a_strb;
					d0b_o = d3b_strb;
					d1b_o = d3b_strb;
					d2b_o = d3b_strb;
					d3b_o = d3b_strb;
				end
			endcase
		end
		2'b01: begin
			case (pat_sel[1])
				1'b0: begin
					d0a_o = d0a_strb;
					d1a_o = d1a_strb;
					d2a_o = d0a_strb;
					d3a_o = d1a_strb;
					d0b_o = d0b_strb;
					d1b_o = d1b_strb;
					d2b_o = d0b_strb;
					d3b_o = d1b_strb;
				end
				//1'b1: begin
				default: begin
					d0a_o = d2a_strb;
					d1a_o = d3a_strb;
					d2a_o = d2a_strb;
					d3a_o = d3a_strb;
					d0b_o = d2b_strb;
					d1b_o = d3b_strb;
					d2b_o = d2b_strb;
					d3b_o = d3b_strb;
				end
			endcase
		end
		default: begin
			d0a_o = d0a_strb;
			d1a_o = d1a_strb;
			d2a_o = d2a_strb;
			d3a_o = d3a_strb;
			d0b_o = d0b_strb;
			d1b_o = d1b_strb;
			d2b_o = d2b_strb;
			d3b_o = d3b_strb;
		end
	endcase
end
endmodule


// rom_wrapper.sv
// Synthesizable SystemVerilog module that instantiates four 2‑port ROMs (sim_dprom)
// Each ROM has 1,024 words of 32 bits, 10‑bit address, initialized from hex

module rom_wrapper #(
    parameter integer MEM_SIZE    = 1024,
    parameter integer DATA_WIDTH  = 32,
    parameter integer ADDR_WIDTH  = 10
)(
    input  logic                       clka,
	input  logic 					   rom_ren,
    input  logic [ADDR_WIDTH-1:0]      rom_paddr,
    output logic [DATA_WIDTH-1:0]      d0a, d0b,
    output logic [DATA_WIDTH-1:0]      d1a, d1b,
    output logic [DATA_WIDTH-1:0]      d2a, d2b,
    output logic [DATA_WIDTH-1:0]      d3a, d3b
);

    // Internal “+1” address for port B
    logic [ADDR_WIDTH-1:0] addr_plus1;
    assign addr_plus1 = rom_paddr + 1;

`ifdef USE_ARR_FOR_TW

    twmem0_arr #(
        .MEM_SIZE   (MEM_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) rom0 (
        .clk    (clka),
        // Port A
        .ena    (rom_ren),
        .addra  (rom_paddr),
        .douta  (d0a),
        // Port B
        .enb    (rom_ren),
        .addrb  (addr_plus1),
        .doutb  (d0b)
    );
    twmem1_arr #(
        .MEM_SIZE   (MEM_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) rom1 (
        .clk    (clka),
        // Port A
        .ena    (rom_ren),
        .addra  (rom_paddr),
        .douta  (d1a),
        // Port B
        .enb    (rom_ren),
        .addrb  (addr_plus1),
        .doutb  (d1b)
    );
    twmem2_arr #(
        .MEM_SIZE   (MEM_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) rom2 (
        .clk    (clka),
        // Port A
        .ena    (rom_ren),
        .addra  (rom_paddr),
        .douta  (d2a),
        // Port B
        .enb    (rom_ren),
        .addrb  (addr_plus1),
        .doutb  (d2b)
    );
    twmem3_arr #(
        .MEM_SIZE   (MEM_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) rom3 (
        .clk    (clka),
        // Port A
        .ena    (rom_ren),
        .addra  (rom_paddr),
        .douta  (d3a),
        // Port B
        .enb    (rom_ren),
        .addrb  (addr_plus1),
        .doutb  (d3b)
    );

`else

`ifdef FPGA_SYN
blk_mem_gen_1 rom0_syn (
  .clka		(clka),    		// input wire clka
  .ena		(rom_ren),      // input wire ena
  .addra	(rom_paddr),  	// input wire [9 : 0] addra
  .douta	(d0a),  		// output wire [31 : 0] douta
  .clkb		(clka),    		// input wire clkb
  .enb		(rom_ren),      // input wire enb
  .addrb	(addr_plus1),  	// input wire [9 : 0] addrb
  .doutb	(d0b)  			// output wire [31 : 0] doutb
);
blk_mem_gen_1 rom1_syn (
  .clka		(clka),    		// input wire clka
  .ena		(rom_ren),      // input wire ena
  .addra	(rom_paddr),  	// input wire [9 : 0] addra
  .douta	(d1a),  		// output wire [31 : 0] douta
  .clkb		(clka),    		// input wire clkb
  .enb		(rom_ren),      // input wire enb
  .addrb	(addr_plus1),  	// input wire [9 : 0] addrb
  .doutb	(d1b)  			// output wire [31 : 0] doutb
);
blk_mem_gen_1 rom2_syn (
  .clka		(clka),    		// input wire clka
  .ena		(rom_ren),      // input wire ena
  .addra	(rom_paddr),  	// input wire [9 : 0] addra
  .douta	(d2a),  		// output wire [31 : 0] douta
  .clkb		(clka),    		// input wire clkb
  .enb		(rom_ren),      // input wire enb
  .addrb	(addr_plus1),  	// input wire [9 : 0] addrb
  .doutb	(d2b)  			// output wire [31 : 0] doutb
);
blk_mem_gen_1 rom3_syn (
  .clka		(clka),    		// input wire clka
  .ena		(rom_ren),      // input wire ena
  .addra	(rom_paddr),  	// input wire [9 : 0] addra
  .douta	(d3a),  		// output wire [31 : 0] douta
  .clkb		(clka),    		// input wire clkb
  .enb		(rom_ren),      // input wire enb
  .addrb	(addr_plus1),  	// input wire [9 : 0] addrb
  .doutb	(d3b)  			// output wire [31 : 0] doutb
);
`else
    //----------------------------------------------------------------
    // Instantiate ROM 0
    //----------------------------------------------------------------
    sim_dprom #(
        .MEM_SIZE   (MEM_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        //.INIT_FILE  ("rom0.hex")
        .INIT_FILE  ("rom0.mem")
    ) rom0 (
        .clka   (clka),
        // Port A
        .ena    (rom_ren),
        .addra  (rom_paddr),
        .douta  (d0a),
        // Port B
        .enb    (rom_ren),
        .addrb  (addr_plus1),
        .doutb  (d0b)
    );

    //----------------------------------------------------------------
    // Instantiate ROM 1
    //----------------------------------------------------------------
    sim_dprom #(
        .MEM_SIZE   (MEM_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        //.INIT_FILE  ("rom1.hex")
        .INIT_FILE  ("rom1.mem")
    ) rom1 (
        .clka   (clka),
        .ena    (rom_ren),
        .addra  (rom_paddr),
        .douta  (d1a),
        .enb    (rom_ren),
        .addrb  (addr_plus1),
        .doutb  (d1b)
    );

    //----------------------------------------------------------------
    // Instantiate ROM 2
    //----------------------------------------------------------------
    sim_dprom #(
        .MEM_SIZE   (MEM_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        //.INIT_FILE  ("rom2.hex")
        .INIT_FILE  ("rom2.mem")
    ) rom2 (
        .clka   (clka),
        .ena    (rom_ren),
        .addra  (rom_paddr),
        .douta  (d2a),
        .enb    (rom_ren),
        .addrb  (addr_plus1),
        .doutb  (d2b)
    );

    //----------------------------------------------------------------
    // Instantiate ROM 3
    //----------------------------------------------------------------
    sim_dprom #(
        .MEM_SIZE   (MEM_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        //.INIT_FILE  ("rom3.hex")
        .INIT_FILE  ("rom3.mem")
    ) rom3 (
        .clka   (clka),
        .ena    (rom_ren),
        .addra  (rom_paddr),
        .douta  (d3a),
        .enb    (rom_ren),
        .addrb  (addr_plus1),
        .doutb  (d3b)
    );
`endif

`endif

endmodule
