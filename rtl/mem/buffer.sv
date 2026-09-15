`include "../defines/defines.sv"

module buffer_top (

	input wire clk,
	input wire rstn,

	input wire security_level,

    input wire poly_adjoint,// for self-adjoint polynomial use, in polyQnorm

    input wire buffer_r_mode, // 0-direct, 1-poly
    input wire buffer_w_mode, // 0-direct, 1-poly

    input wire [`ADDR_WIDTH-1:0] av0_raddr_dir,
    input wire [`ADDR_WIDTH-1:0] bv0_raddr_dir,
    input wire [`ADDR_WIDTH-1:0] av1_raddr_dir,
    input wire [`ADDR_WIDTH-1:0] bv1_raddr_dir,
    input wire [1:0] av0_r_bs_dir,
    input wire [1:0] bv0_r_bs_dir,
    input wire [1:0] av1_r_bs_dir,
    input wire [1:0] bv1_r_bs_dir,
    input wire [`ADDR_WIDTH-1:0] av0_waddr_dir,
    input wire [`ADDR_WIDTH-1:0] bv0_waddr_dir,
    input wire [`ADDR_WIDTH-1:0] av1_waddr_dir,
    input wire [`ADDR_WIDTH-1:0] bv1_waddr_dir,
    input wire [1:0] av0_w_bs_dir,
    input wire [1:0] bv0_w_bs_dir,
    input wire [1:0] av1_w_bs_dir,
    input wire [1:0] bv1_w_bs_dir,

	input wire a_r_mapping_mode,
	input wire b_r_mapping_mode,
	input wire [`ADDR_WIDTH-1:0] a_base_raddr,
	input wire [`ADDR_WIDTH-1:0] b_base_raddr,
	input wire [`VEC_NUM_WIDTH-1:0] r_avn0,
	input wire [`VEC_NUM_WIDTH-1:0] r_bvn0,
	input wire [`VEC_NUM_WIDTH-1:0] r_avn1,
	input wire [`VEC_NUM_WIDTH-1:0] r_bvn1,
	input wire avn0_ren,
	input wire bvn0_ren,
	input wire avn1_ren,
	input wire bvn1_ren,
    output logic [`VEC_BITS-1:0]   r_av0,
    output logic [`VEC_BITS-1:0]   r_bv0,
    output logic [`VEC_BITS-1:0]   r_av1,
    output logic [`VEC_BITS-1:0]   r_bv1,

	input wire a_w_mapping_mode,
	input wire b_w_mapping_mode,
	input wire [`ADDR_WIDTH-1:0] a_base_waddr,
	input wire [`ADDR_WIDTH-1:0] b_base_waddr,
	input wire [`VEC_NUM_WIDTH-1:0] w_avn0,
	input wire [`VEC_NUM_WIDTH-1:0] w_bvn0,
	input wire [`VEC_NUM_WIDTH-1:0] w_avn1,
	input wire [`VEC_NUM_WIDTH-1:0] w_bvn1,
	input wire avn0_wen,
	input wire bvn0_wen,
	input wire avn1_wen,
	input wire bvn1_wen,
    input  wire [`VEC_BITS-1:0]   w_av0,
    input  wire [`VEC_BITS-1:0]   w_bv0,
    input  wire [`VEC_BITS-1:0]   w_av1,
    input  wire [`VEC_BITS-1:0]   w_bv1

);

// from mapping
// read mapping
logic [1:0] map_av0_r_bs;
logic [1:0] map_bv0_r_bs;
logic [1:0] map_av1_r_bs;
logic [1:0] map_bv1_r_bs;
logic [`ADDR_WIDTH-1:0] map_av0_r_paddr;
logic [`ADDR_WIDTH-1:0] map_bv0_r_paddr;
logic [`ADDR_WIDTH-1:0] map_av1_r_paddr;
logic [`ADDR_WIDTH-1:0] map_bv1_r_paddr;

// write mapping
logic [1:0] map_av0_w_bs;
logic [1:0] map_bv0_w_bs;
logic [1:0] map_av1_w_bs;
logic [1:0] map_bv1_w_bs;
logic [`ADDR_WIDTH-1:0] map_av0_w_paddr;
logic [`ADDR_WIDTH-1:0] map_bv0_w_paddr;
logic [`ADDR_WIDTH-1:0] map_av1_w_paddr;
logic [`ADDR_WIDTH-1:0] map_bv1_w_paddr;


ntt_read_mapping u_read_map (
	.clk(clk),
    .security_level    (security_level),
    .a_mapping_mode    (a_r_mapping_mode),
    .b_mapping_mode    (b_r_mapping_mode),
    .a_base_raddr      (a_base_raddr),
    .b_base_raddr      (b_base_raddr),
    .avn0              (r_avn0),
    .bvn0              (r_bvn0),
    .avn1              (r_avn1),
    .bvn1              (r_bvn1),
    .av0_r_paddr       (map_av0_r_paddr),
    .bv0_r_paddr       (map_bv0_r_paddr),
    .av1_r_paddr       (map_av1_r_paddr),
    .bv1_r_paddr       (map_bv1_r_paddr),
    .av0_r_bs          (map_av0_r_bs),
    .bv0_r_bs          (map_bv0_r_bs),
    .av1_r_bs          (map_av1_r_bs),
    .bv1_r_bs          (map_bv1_r_bs)
);

ntt_write_mapping u_write_map (
    .security_level    (security_level),
    .a_mapping_mode    (a_w_mapping_mode),
    .b_mapping_mode    (b_w_mapping_mode),
    .a_base_waddr      (a_base_waddr),
    .b_base_waddr      (b_base_waddr),
    .avn0              (w_avn0),
    .bvn0              (w_bvn0),
    .avn1              (w_avn1),
    .bvn1              (w_bvn1),
    .av0_w_paddr       (map_av0_w_paddr),
    .bv0_w_paddr       (map_bv0_w_paddr),
    .av1_w_paddr       (map_av1_w_paddr),
    .bv1_w_paddr       (map_bv1_w_paddr),
    .av0_w_bs          (map_av0_w_bs),
    .bv0_w_bs          (map_bv0_w_bs),
    .av1_w_bs          (map_av1_w_bs),
    .bv1_w_bs          (map_bv1_w_bs)
);

// buffer mode sel
logic [1:0] av0_r_bs;
logic [1:0] bv0_r_bs;
logic [1:0] av1_r_bs;
logic [1:0] bv1_r_bs;
logic [`ADDR_WIDTH-1:0] av0_r_paddr;
logic [`ADDR_WIDTH-1:0] bv0_r_paddr;
logic [`ADDR_WIDTH-1:0] av1_r_paddr;
logic [`ADDR_WIDTH-1:0] bv1_r_paddr;
assign av0_r_bs = buffer_r_mode ? map_av0_r_bs : av0_r_bs_dir;
assign bv0_r_bs = buffer_r_mode ? map_bv0_r_bs : bv0_r_bs_dir;
assign av1_r_bs = buffer_r_mode ? map_av1_r_bs : av1_r_bs_dir;
assign bv1_r_bs = buffer_r_mode ? map_bv1_r_bs : bv1_r_bs_dir;
assign av0_r_paddr = buffer_r_mode ? map_av0_r_paddr : av0_raddr_dir;
assign bv0_r_paddr = buffer_r_mode ? map_bv0_r_paddr : bv0_raddr_dir;
assign av1_r_paddr = buffer_r_mode ? map_av1_r_paddr : av1_raddr_dir;
assign bv1_r_paddr = buffer_r_mode ? map_bv1_r_paddr : bv1_raddr_dir;
logic [1:0] av0_r_bs_q;
logic [1:0] bv0_r_bs_q;
logic [1:0] av1_r_bs_q;
logic [1:0] bv1_r_bs_q;
// Delay the bank selection to match the one-cycle RAM read latency.
dffre_pipe #(
    .WIDTH(2*4),
    .DELAY(1)
) u_dffre_pipe_r_bs (
    .clk,
    .rstn,
    .en(bvn1_ren || bvn0_ren || avn1_ren || avn0_ren),
    .d({bv1_r_bs, av1_r_bs, bv0_r_bs, av0_r_bs}),
    .q({bv1_r_bs_q, av1_r_bs_q, bv0_r_bs_q, av0_r_bs_q})
);

logic [1:0] av0_w_bs;
logic [1:0] bv0_w_bs;
logic [1:0] av1_w_bs;
logic [1:0] bv1_w_bs;
logic [`ADDR_WIDTH-1:0] av0_w_paddr;
logic [`ADDR_WIDTH-1:0] bv0_w_paddr;
logic [`ADDR_WIDTH-1:0] av1_w_paddr;
logic [`ADDR_WIDTH-1:0] bv1_w_paddr;

assign av0_w_bs = buffer_w_mode ? map_av0_w_bs : av0_w_bs_dir;
assign bv0_w_bs = buffer_w_mode ? map_bv0_w_bs : bv0_w_bs_dir;
assign av1_w_bs = buffer_w_mode ? map_av1_w_bs : av1_w_bs_dir;
assign bv1_w_bs = buffer_w_mode ? map_bv1_w_bs : bv1_w_bs_dir;
assign av0_w_paddr = buffer_w_mode ? map_av0_w_paddr : av0_waddr_dir;
assign bv0_w_paddr = buffer_w_mode ? map_bv0_w_paddr : bv0_waddr_dir;
assign av1_w_paddr = buffer_w_mode ? map_av1_w_paddr : av1_waddr_dir;
assign bv1_w_paddr = buffer_w_mode ? map_bv1_w_paddr : bv1_waddr_dir;


//---------------------------------------------------------
// fabric
//---------------------------------------------------------
logic [`ADDR_WIDTH-1:0] r_pa0, r_pa1, r_pa2, r_pa3;
logic bank0_ren, bank1_ren, bank2_ren, bank3_ren;
logic [`VEC_BITS-1:0] r_av0_m, r_bv0_m, r_av1_m, r_bv1_m; // internal rdata
logic [`VEC_BITS-1:0] r_v0, r_v1, r_v2, r_v3; // bank rdata
logic [3:0] r_mux_sel_0_oh;     // mux to bank0
logic [3:0] r_mux_sel_1_oh;     // mux to bank1
logic [3:0] r_mux_sel_2_oh;     // mux to bank2
logic [3:0] r_mux_sel_3_oh;     // mux to bank3
logic [3:0] r_mux_sel_0_oh_ae;
logic [3:0] r_mux_sel_1_oh_ae;
logic [3:0] r_mux_sel_2_oh_ae;
logic [3:0] r_mux_sel_3_oh_ae;
logic [3:0] rens;
assign r_mux_sel_0_oh = {bv1_r_bs==2'b00, av1_r_bs==2'b00, bv0_r_bs==2'b00, av0_r_bs==2'b00};
assign r_mux_sel_1_oh = {bv1_r_bs==2'b01, av1_r_bs==2'b01, bv0_r_bs==2'b01, av0_r_bs==2'b01};
assign r_mux_sel_2_oh = {bv1_r_bs==2'b10, av1_r_bs==2'b10, bv0_r_bs==2'b10, av0_r_bs==2'b10};
assign r_mux_sel_3_oh = {bv1_r_bs==2'b11, av1_r_bs==2'b11, bv0_r_bs==2'b11, av0_r_bs==2'b11};
assign rens = {bvn1_ren, avn1_ren, bvn0_ren, avn0_ren};
assign r_mux_sel_0_oh_ae = r_mux_sel_0_oh & rens;
assign r_mux_sel_1_oh_ae = r_mux_sel_1_oh & rens;
assign r_mux_sel_2_oh_ae = r_mux_sel_2_oh & rens;
assign r_mux_sel_3_oh_ae = r_mux_sel_3_oh & rens;

// r_en mux
mux41_onehot #(1) U_mux41oh_bk0ren (
	.select(r_mux_sel_0_oh),
	.data1(avn0_ren),
	.data2(bvn0_ren),
	.data3(avn1_ren),
	.data4(bvn1_ren),
	.data_out(bank0_ren)
);
mux41_onehot #(1) U_mux41oh_bk1ren (
	.select(r_mux_sel_1_oh),
	.data1(avn0_ren),
	.data2(bvn0_ren),
	.data3(avn1_ren),
	.data4(bvn1_ren),
	.data_out(bank1_ren)
);
mux41_onehot #(1) U_mux41oh_bk2ren (
	.select(r_mux_sel_2_oh),
	.data1(avn0_ren),
	.data2(bvn0_ren),
	.data3(avn1_ren),
	.data4(bvn1_ren),
	.data_out(bank2_ren)
);
mux41_onehot #(1) U_mux41oh_bk3ren (
	.select(r_mux_sel_3_oh),
	.data1(avn0_ren),
	.data2(bvn0_ren),
	.data3(avn1_ren),
	.data4(bvn1_ren),
	.data_out(bank3_ren)
);
// r_addr mux
mux41_onehot #(`ADDR_WIDTH) U_mux41oh_bk0raddr (
	.select(r_mux_sel_0_oh_ae),
	.data1(av0_r_paddr),
	.data2(bv0_r_paddr),
	.data3(av1_r_paddr),
	.data4(bv1_r_paddr),
	.data_out(r_pa0)
);
mux41_onehot #(`ADDR_WIDTH) U_mux41oh_bk1raddr (
	.select(r_mux_sel_1_oh_ae),
	.data1(av0_r_paddr),
	.data2(bv0_r_paddr),
	.data3(av1_r_paddr),
	.data4(bv1_r_paddr),
	.data_out(r_pa1)
);
mux41_onehot #(`ADDR_WIDTH) U_mux41oh_bk2raddr (
	.select(r_mux_sel_2_oh_ae),
	.data1(av0_r_paddr),
	.data2(bv0_r_paddr),
	.data3(av1_r_paddr),
	.data4(bv1_r_paddr),
	.data_out(r_pa2)
);
mux41_onehot #(`ADDR_WIDTH) U_mux41oh_bk3raddr (
	.select(r_mux_sel_3_oh_ae),
	.data1(av0_r_paddr),
	.data2(bv0_r_paddr),
	.data3(av1_r_paddr),
	.data4(bv1_r_paddr),
	.data_out(r_pa3)
);
// r_data mux
logic [`VEC_BITS-1:0] r_v2_r, r_v3_r;
assign r_v2_r = poly_adjoint ? {r_v2[1*32-1-:32],r_v2[2*32-1-:32],r_v2[3*32-1-:32],r_v2[4*32-1-:32]} : r_v2;
assign r_v3_r = poly_adjoint ? {r_v3[1*32-1-:32],r_v3[2*32-1-:32],r_v3[3*32-1-:32],r_v3[4*32-1-:32]} : r_v3;
// rdata use r_bs directly
mux41 #(`VEC_BITS) U_mux41_av0rdata (
	.select(av0_r_bs_q),
	.data00(r_v0),
	.data01(r_v1),
	.data10(r_v2_r),
	.data11(r_v3_r),
	.data_out(r_av0_m)
);
mux41 #(`VEC_BITS) U_mux41_bv0rdata (
	.select(bv0_r_bs_q),
	.data00(r_v0),
	.data01(r_v1),
	.data10(r_v2_r),
	.data11(r_v3_r),
	.data_out(r_bv0_m)
);
mux41 #(`VEC_BITS) U_mux41_av1rdata (
	.select(av1_r_bs_q),
	.data00(r_v0),
	.data01(r_v1),
	.data10(r_v2_r),
	.data11(r_v3_r),
	.data_out(r_av1_m)
);
mux41 #(`VEC_BITS) U_mux41_bv1rdata (
	.select(bv1_r_bs_q),
	.data00(r_v0),
	.data01(r_v1),
	.data10(r_v2_r),
	.data11(r_v3_r),
	.data_out(r_bv1_m)
);
assign r_av0 = r_av0_m;
assign r_bv0 = r_bv0_m;
assign r_av1 = r_av1_m;
assign r_bv1 = r_bv1_m;

logic [`ADDR_WIDTH-1:0] w_pa0, w_pa1, w_pa2, w_pa3;
logic bank0_wen, bank1_wen, bank2_wen, bank3_wen;
logic [`VEC_BITS-1:0] w_v0, w_v1, w_v2, w_v3;   // write mux output, directly go to bank 0~3

logic [3:0] w_mux_sel_0_oh;     // mux to bank0
logic [3:0] w_mux_sel_1_oh;     // mux to bank1
logic [3:0] w_mux_sel_2_oh;     // mux to bank2
logic [3:0] w_mux_sel_3_oh;     // mux to bank3
logic [3:0] w_mux_sel_0_oh_ae;  // mux_sel & wen
logic [3:0] w_mux_sel_1_oh_ae;
logic [3:0] w_mux_sel_2_oh_ae;
logic [3:0] w_mux_sel_3_oh_ae;
logic [3:0] wens;
assign w_mux_sel_0_oh = {bv1_w_bs==2'b00, av1_w_bs==2'b00, bv0_w_bs==2'b00, av0_w_bs==2'b00};
assign w_mux_sel_1_oh = {bv1_w_bs==2'b01, av1_w_bs==2'b01, bv0_w_bs==2'b01, av0_w_bs==2'b01};
assign w_mux_sel_2_oh = {bv1_w_bs==2'b10, av1_w_bs==2'b10, bv0_w_bs==2'b10, av0_w_bs==2'b10};
assign w_mux_sel_3_oh = {bv1_w_bs==2'b11, av1_w_bs==2'b11, bv0_w_bs==2'b11, av0_w_bs==2'b11};
assign wens = {bvn1_wen, avn1_wen, bvn0_wen, avn0_wen};
assign w_mux_sel_0_oh_ae = w_mux_sel_0_oh & wens;
assign w_mux_sel_1_oh_ae = w_mux_sel_1_oh & wens;
assign w_mux_sel_2_oh_ae = w_mux_sel_2_oh & wens;
assign w_mux_sel_3_oh_ae = w_mux_sel_3_oh & wens;

// w_en mux
mux41_onehot #(1) U_mux41oh_bk0wen (
	.select(w_mux_sel_0_oh),
	.data1(avn0_wen),
	.data2(bvn0_wen),
	.data3(avn1_wen),
	.data4(bvn1_wen),
	.data_out(bank0_wen)
);
mux41_onehot #(1) U_mux41oh_bk1wen (
	.select(w_mux_sel_1_oh),
	.data1(avn0_wen),
	.data2(bvn0_wen),
	.data3(avn1_wen),
	.data4(bvn1_wen),
	.data_out(bank1_wen)
);
mux41_onehot #(1) U_mux41oh_bk2wen (
	.select(w_mux_sel_2_oh),
	.data1(avn0_wen),
	.data2(bvn0_wen),
	.data3(avn1_wen),
	.data4(bvn1_wen),
	.data_out(bank2_wen)
);
mux41_onehot #(1) U_mux41oh_bk3wen (
	.select(w_mux_sel_3_oh),
	.data1(avn0_wen),
	.data2(bvn0_wen),
	.data3(avn1_wen),
	.data4(bvn1_wen),
	.data_out(bank3_wen)
);
// w_addr mux
mux41_onehot #(`ADDR_WIDTH) U_mux41oh_bk0waddr (
	.select(w_mux_sel_0_oh_ae),
	.data1(av0_w_paddr),
	.data2(bv0_w_paddr),
	.data3(av1_w_paddr),
	.data4(bv1_w_paddr),
	.data_out(w_pa0)
);
mux41_onehot #(`ADDR_WIDTH) U_mux41oh_bk1waddr (
	.select(w_mux_sel_1_oh_ae),
	.data1(av0_w_paddr),
	.data2(bv0_w_paddr),
	.data3(av1_w_paddr),
	.data4(bv1_w_paddr),
	.data_out(w_pa1)
);
mux41_onehot #(`ADDR_WIDTH) U_mux41oh_bk2waddr (
	.select(w_mux_sel_2_oh_ae),
	.data1(av0_w_paddr),
	.data2(bv0_w_paddr),
	.data3(av1_w_paddr),
	.data4(bv1_w_paddr),
	.data_out(w_pa2)
);
mux41_onehot #(`ADDR_WIDTH) U_mux41oh_bk3waddr (
	.select(w_mux_sel_3_oh_ae),
	.data1(av0_w_paddr),
	.data2(bv0_w_paddr),
	.data3(av1_w_paddr),
	.data4(bv1_w_paddr),
	.data_out(w_pa3)
);
// w_data mux
mux41_onehot #(`VEC_BITS) U_mux41oh_bk0wdata (
	.select(w_mux_sel_0_oh_ae),
	.data1(w_av0),
	.data2(w_bv0),
	.data3(w_av1),
	.data4(w_bv1),
	.data_out(w_v0)
);
mux41_onehot #(`VEC_BITS) U_mux41oh_bk1wdata (
	.select(w_mux_sel_1_oh_ae),
	.data1(w_av0),
	.data2(w_bv0),
	.data3(w_av1),
	.data4(w_bv1),
	.data_out(w_v1)
);
mux41_onehot #(`VEC_BITS) U_mux41oh_bk2wdata (
	.select(w_mux_sel_2_oh_ae),
	.data1(w_av0),
	.data2(w_bv0),
	.data3(w_av1),
	.data4(w_bv1),
	.data_out(w_v2)
);
mux41_onehot #(`VEC_BITS) U_mux41oh_bk3wdata (
	.select(w_mux_sel_3_oh_ae),
	.data1(w_av0),
	.data2(w_bv0),
	.data3(w_av1),
	.data4(w_bv1),
	.data_out(w_v3)
);

bank_wrapper u_bank_wrapper (
    .clk               (clk),
    // read ports
    .r_pa0             (r_pa0),
    .r_pa1             (r_pa1),
    .r_pa2             (r_pa2),
    .r_pa3             (r_pa3),
    .bank0_ren         (bank0_ren),
    .bank1_ren         (bank1_ren),
    .bank2_ren         (bank2_ren),
    .bank3_ren         (bank3_ren),
    .r_v0              ,
    .r_v1              ,
    .r_v2              ,
    .r_v3              ,
    // write ports
    .w_pa0             (w_pa0),
    .w_pa1             (w_pa1),
    .w_pa2             (w_pa2),
    .w_pa3             (w_pa3),
    .bank0_wen         (bank0_wen),
    .bank1_wen         (bank1_wen),
    .bank2_wen         (bank2_wen),
    .bank3_wen         (bank3_wen),
    .w_v0              ,
    .w_v1              ,
    .w_v2              ,
    .w_v3              
);

endmodule

module bank_wrapper (
    input  wire                   clk,
    // Read
    input  wire [`ADDR_WIDTH-1:0] r_pa0,
    input  wire [`ADDR_WIDTH-1:0] r_pa1,
    input  wire [`ADDR_WIDTH-1:0] r_pa2,
    input  wire [`ADDR_WIDTH-1:0] r_pa3,
    input  wire                   bank0_ren,
    input  wire                   bank1_ren,
    input  wire                   bank2_ren,
    input  wire                   bank3_ren,
    output wire [`VEC_BITS-1:0]   r_v0,
    output wire [`VEC_BITS-1:0]   r_v1,
    output wire [`VEC_BITS-1:0]   r_v2,
    output wire [`VEC_BITS-1:0]   r_v3,

    // Write
    input  wire [`ADDR_WIDTH-1:0] w_pa0,
    input  wire [`ADDR_WIDTH-1:0] w_pa1,
    input  wire [`ADDR_WIDTH-1:0] w_pa2,
    input  wire [`ADDR_WIDTH-1:0] w_pa3,
    input  wire                   bank0_wen,
    input  wire                   bank1_wen,
    input  wire                   bank2_wen,
    input  wire                   bank3_wen,
    input  wire [`VEC_BITS-1:0]   w_v0,
    input  wire [`VEC_BITS-1:0]   w_v1,
    input  wire [`VEC_BITS-1:0]   w_v2,
    input  wire [`VEC_BITS-1:0]   w_v3
);

    logic [`VEC_BITS-1:0] bank_din0, bank_din1, bank_din2, bank_din3;
    logic [`ADDR_WIDTH-1:0] bank_addr0, bank_addr1, bank_addr2, bank_addr3;

    logic [`VEC_BITS-1:0] bank_dout0, bank_dout1, bank_dout2, bank_dout3;

    assign r_v0 = bank_dout0;
    assign r_v1 = bank_dout1;
    assign r_v2 = bank_dout2;
    assign r_v3 = bank_dout3;

	assign bank_addr0 = w_pa0;
	assign bank_addr1 = w_pa1;
	assign bank_addr2 = w_pa2;
	assign bank_addr3 = w_pa3;
    assign bank_din0 = w_v0;
    assign bank_din1 = w_v1;
    assign bank_din2 = w_v2;
    assign bank_din3 = w_v3;

    // Instantiate 4 simple dual-port RAMs
`ifdef FPGA_SYN
blk_mem_gen_0 bank0_syn (
    .clka   (clk),              // input  wire          clka
    .ena    (bank0_wen),        // input  wire          ena
    .wea    (bank0_wen),        // input  wire  [0:0]   wea
    .addra  (bank_addr0),       // input  wire  [7:0]   addra
    .dina   (bank_din0),        // input  wire  [127:0] dina
    .clkb   (clk),              // input  wire          clkb
    .enb    (bank0_ren),        // input  wire          enb
    .addrb  (r_pa0),            // input  wire  [7:0]   addrb
    .doutb  (bank_dout0)        // output wire  [127:0] doutb
);
blk_mem_gen_0 bank1_syn (
    .clka   (clk),              // input  wire          clka
    .ena    (bank1_wen),        // input  wire          ena
    .wea    (bank1_wen),        // input  wire  [0:0]   wea
    .addra  (bank_addr1),       // input  wire  [7:0]   addra
    .dina   (bank_din1),        // input  wire  [127:0] dina
    .clkb   (clk),              // input  wire          clkb
    .enb    (bank1_ren),        // input  wire          enb
    .addrb  (r_pa1),            // input  wire  [7:0]   addrb
    .doutb  (bank_dout1)        // output wire  [127:0] doutb
);
blk_mem_gen_0 bank2_syn (
    .clka   (clk),              // input  wire          clka
    .ena    (bank2_wen),        // input  wire          ena
    .wea    (bank2_wen),        // input  wire  [0:0]   wea
    .addra  (bank_addr2),       // input  wire  [7:0]   addra
    .dina   (bank_din2),        // input  wire  [127:0] dina
    .clkb   (clk),              // input  wire          clkb
    .enb    (bank2_ren),        // input  wire          enb
    .addrb  (r_pa2),            // input  wire  [7:0]   addrb
    .doutb  (bank_dout2)        // output wire  [127:0] doutb
);
blk_mem_gen_0 bank3_syn (
    .clka   (clk),              // input  wire          clka
    .ena    (bank3_wen),        // input  wire          ena
    .wea    (bank3_wen),        // input  wire  [0:0]   wea
    .addra  (bank_addr3),       // input  wire  [7:0]   addra
    .dina   (bank_din3),        // input  wire  [127:0] dina
    .clkb   (clk),              // input  wire          clkb
    .enb    (bank3_ren),        // input  wire          enb
    .addrb  (r_pa3),            // input  wire  [7:0]   addrb
    .doutb  (bank_dout3)        // output wire  [127:0] doutb
);

`else
    sim_dpram #(
        .MEM_SIZE(`BRAM_DEPTH),
        .DATA_WIDTH(`VEC_BITS),
        .ADDR_WIDTH(`ADDR_WIDTH)
    ) bank0 (
        .clka   (clk),
        .ena    (bank0_wen),
        .wea    (bank0_wen),
        .addra  (bank_addr0),
        .dina   (bank_din0),
        .enb    (bank0_ren),
        .addrb  (r_pa0),
        .doutb  (bank_dout0)
    );

    sim_dpram #(
        .MEM_SIZE(`BRAM_DEPTH),
        .DATA_WIDTH(`VEC_BITS),
        .ADDR_WIDTH(`ADDR_WIDTH)
    ) bank1 (
        .clka   (clk),
        .ena    (bank1_wen),
        .wea    (bank1_wen),
        .addra  (bank_addr1),
        .dina   (bank_din1),
        .enb    (bank1_ren),
        .addrb  (r_pa1),
        .doutb  (bank_dout1)
    );

    sim_dpram #(
        .MEM_SIZE(`BRAM_DEPTH),
        .DATA_WIDTH(`VEC_BITS),
        .ADDR_WIDTH(`ADDR_WIDTH)
    ) bank2 (
        .clka   (clk),
        .ena    (bank2_wen),
        .wea    (bank2_wen),
        .addra  (bank_addr2),
        .dina   (bank_din2),
        .enb    (bank2_ren),
        .addrb  (r_pa2),
        .doutb  (bank_dout2)
    );

    sim_dpram #(
        .MEM_SIZE(`BRAM_DEPTH),
        .DATA_WIDTH(`VEC_BITS),
        .ADDR_WIDTH(`ADDR_WIDTH)
    ) bank3 (
        .clka   (clk),
        .ena    (bank3_wen),
        .wea    (bank3_wen),
        .addra  (bank_addr3),
        .dina   (bank_din3),
        .enb    (bank3_ren),
        .addrb  (r_pa3),
        .doutb  (bank_dout3)
    );
`endif

endmodule
