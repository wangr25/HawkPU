`include "../defines/defines.sv"

// address mapping for NTT/FFT and inverse.
// input vector number,
// output paddr and bank_sel

module ntt_read_mapping(

    input wire clk,
    input wire rstn,

	input wire security_level,
	// 2 mapping methods
	// for NTT(a)*NTT(b), a and b use different mapping methods
	input wire a_mapping_mode,
	input wire b_mapping_mode,

	input wire [`ADDR_WIDTH-1:0] a_base_raddr,
	input wire [`ADDR_WIDTH-1:0] b_base_raddr,

	input wire [`VEC_NUM_WIDTH-1:0] avn0,
	input wire [`VEC_NUM_WIDTH-1:0] bvn0,
	input wire [`VEC_NUM_WIDTH-1:0] avn1,
	input wire [`VEC_NUM_WIDTH-1:0] bvn1,

	output logic [1:0] av0_r_bs,
	output logic [1:0] bv0_r_bs,
	output logic [1:0] av1_r_bs,
	output logic [1:0] bv1_r_bs,

	output logic [`ADDR_WIDTH-1:0] av0_r_paddr,
	output logic [`ADDR_WIDTH-1:0] bv0_r_paddr,
	output logic [`ADDR_WIDTH-1:0] av1_r_paddr,
	output logic [`ADDR_WIDTH-1:0] bv1_r_paddr
	
);

localparam POLY_VEC_NUM_WIDTH = `VEC_NUM_WIDTH;

// in HAWK512, a polynomial has 128 vectors, range from v0 to v127, so use
// [6:0] only. While in HAWK 1024, vec_num range from v0 to v255, use [7:0].

logic avn0_msb;
logic bvn0_msb;
logic avn1_msb;
logic bvn1_msb;

logic [`VEC_NUM_WIDTH-2:0] avn0_lo;
logic [`VEC_NUM_WIDTH-2:0] bvn0_lo;
logic [`VEC_NUM_WIDTH-2:0] avn1_lo;
logic [`VEC_NUM_WIDTH-2:0] bvn1_lo;

logic avn0_xor;
logic avn1_xor;
logic bvn0_xor;
logic bvn1_xor;

assign avn0_msb = security_level ? avn0[`VEC_NUM_WIDTH-1] : avn0[`VEC_NUM_WIDTH-2];
assign avn1_msb = security_level ? avn1[`VEC_NUM_WIDTH-1] : avn1[`VEC_NUM_WIDTH-2];
assign bvn0_msb = security_level ? bvn0[`VEC_NUM_WIDTH-1] : bvn0[`VEC_NUM_WIDTH-2];
assign bvn1_msb = security_level ? bvn1[`VEC_NUM_WIDTH-1] : bvn1[`VEC_NUM_WIDTH-2];

assign avn0_lo = security_level ? avn0[`VEC_NUM_WIDTH-2:0] : {1'b0,avn0[`VEC_NUM_WIDTH-3:0]};
assign bvn0_lo = security_level ? bvn0[`VEC_NUM_WIDTH-2:0] : {1'b0,bvn0[`VEC_NUM_WIDTH-3:0]};
assign avn1_lo = security_level ? avn1[`VEC_NUM_WIDTH-2:0] : {1'b0,avn1[`VEC_NUM_WIDTH-3:0]};
assign bvn1_lo = security_level ? bvn1[`VEC_NUM_WIDTH-2:0] : {1'b0,bvn1[`VEC_NUM_WIDTH-3:0]};

assign avn0_xor = ^avn0_lo;
assign bvn0_xor = ^bvn0_lo;
assign avn1_xor = ^avn1_lo;
assign bvn1_xor = ^bvn1_lo;


assign av0_r_bs = a_mapping_mode ? {avn0_msb, ~avn0_xor} : {avn0_msb, avn0_xor};
assign bv0_r_bs = b_mapping_mode ? {bvn0_msb, ~bvn0_xor} : {bvn0_msb, bvn0_xor};
assign av1_r_bs = a_mapping_mode ? {avn1_msb, ~avn1_xor} : {avn1_msb, avn1_xor};
assign bv1_r_bs = b_mapping_mode ? {bvn1_msb, ~bvn1_xor} : {bvn1_msb, bvn1_xor};

// vn0 and vn1 must resolve to the same physical address for each port.
assign av0_r_paddr = a_base_raddr + avn0_lo[`VEC_NUM_WIDTH-2:1];
assign bv0_r_paddr = b_base_raddr + bvn0_lo[`VEC_NUM_WIDTH-2:1];
assign av1_r_paddr = a_base_raddr + avn1_lo[`VEC_NUM_WIDTH-2:1];
assign bv1_r_paddr = b_base_raddr + bvn1_lo[`VEC_NUM_WIDTH-2:1];

endmodule

module ntt_write_mapping(

	input wire security_level,

	// 2 mapping methods
	// for NTT(a)*NTT(b), a and b use different mapping methods
	input wire a_mapping_mode,
	input wire b_mapping_mode,

	input wire [`ADDR_WIDTH-1:0] a_base_waddr,
	input wire [`ADDR_WIDTH-1:0] b_base_waddr,

	input wire [`VEC_NUM_WIDTH-1:0] avn0,
	input wire [`VEC_NUM_WIDTH-1:0] bvn0,
	input wire [`VEC_NUM_WIDTH-1:0] avn1,
	input wire [`VEC_NUM_WIDTH-1:0] bvn1,

	output logic [1:0] av0_w_bs,
	output logic [1:0] bv0_w_bs,
	output logic [1:0] av1_w_bs,
	output logic [1:0] bv1_w_bs,

	// physical address
	output logic [`ADDR_WIDTH-1:0] av0_w_paddr,
	output logic [`ADDR_WIDTH-1:0] bv0_w_paddr,
	output logic [`ADDR_WIDTH-1:0] av1_w_paddr,
	output logic [`ADDR_WIDTH-1:0] bv1_w_paddr

);

logic avn0_msb;
logic bvn0_msb;
logic avn1_msb;
logic bvn1_msb;

logic [`VEC_NUM_WIDTH-2:0] avn0_lo;
logic [`VEC_NUM_WIDTH-2:0] bvn0_lo;
logic [`VEC_NUM_WIDTH-2:0] avn1_lo;
logic [`VEC_NUM_WIDTH-2:0] bvn1_lo;

logic avn0_xor;
logic avn1_xor;
logic bvn0_xor;
logic bvn1_xor;

assign avn0_msb = security_level ? avn0[`VEC_NUM_WIDTH-1] : avn0[`VEC_NUM_WIDTH-2];
assign avn1_msb = security_level ? avn1[`VEC_NUM_WIDTH-1] : avn1[`VEC_NUM_WIDTH-2];
assign bvn0_msb = security_level ? bvn0[`VEC_NUM_WIDTH-1] : bvn0[`VEC_NUM_WIDTH-2];
assign bvn1_msb = security_level ? bvn1[`VEC_NUM_WIDTH-1] : bvn1[`VEC_NUM_WIDTH-2];

assign avn0_lo = security_level ? avn0[`VEC_NUM_WIDTH-2:0] : {1'b0,avn0[`VEC_NUM_WIDTH-3:0]};
assign bvn0_lo = security_level ? bvn0[`VEC_NUM_WIDTH-2:0] : {1'b0,bvn0[`VEC_NUM_WIDTH-3:0]};
assign avn1_lo = security_level ? avn1[`VEC_NUM_WIDTH-2:0] : {1'b0,avn1[`VEC_NUM_WIDTH-3:0]};
assign bvn1_lo = security_level ? bvn1[`VEC_NUM_WIDTH-2:0] : {1'b0,bvn1[`VEC_NUM_WIDTH-3:0]};

assign avn0_xor = ^avn0_lo;
assign bvn0_xor = ^bvn0_lo;
assign avn1_xor = ^avn1_lo;
assign bvn1_xor = ^bvn1_lo;

assign av0_w_bs = a_mapping_mode ? {avn0_msb, ~avn0_xor} : {avn0_msb, avn0_xor};
assign bv0_w_bs = b_mapping_mode ? {bvn0_msb, ~bvn0_xor} : {bvn0_msb, bvn0_xor};
assign av1_w_bs = a_mapping_mode ? {avn1_msb, ~avn1_xor} : {avn1_msb, avn1_xor};
assign bv1_w_bs = b_mapping_mode ? {bvn1_msb, ~bvn1_xor} : {bvn1_msb, bvn1_xor};

// vn0 and vn1 must resolve to the same physical address for each port.
assign av0_w_paddr = a_base_waddr + avn0_lo[`VEC_NUM_WIDTH-2:1];
assign bv0_w_paddr = b_base_waddr + bvn0_lo[`VEC_NUM_WIDTH-2:1];
assign av1_w_paddr = a_base_waddr + avn1_lo[`VEC_NUM_WIDTH-2:1];
assign bv1_w_paddr = b_base_waddr + bvn1_lo[`VEC_NUM_WIDTH-2:1];

endmodule
