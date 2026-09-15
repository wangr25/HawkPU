`include "../defines/defines.sv"

module enc_top (

    input wire clk,
    input wire rstn,
    input wire security_level,

    // <-> control
    input  logic [`ADDR_WIDTH-1:0] code_base_raddr,
    input  logic [`ADDR_WIDTH-1:0] code_base_waddr,
    input  logic [`ADDR_WIDTH-1:0] another_addr,
    input  logic [8:0] code_length,
    input wire enc_start,
    output logic enc_finish,

    // buffer
    // read buffer
    output logic enc_a_r_mapping_mode,
    output logic enc_b_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] enc_a_base_raddr,
    output logic [`ADDR_WIDTH-1:0] enc_b_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    enc_r_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    enc_r_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    enc_r_avn1,
    output logic [`VEC_NUM_WIDTH-1:0]    enc_r_bvn1,
    input  logic [`VEC_BITS-1:0]         enc_r_av0,
    input  logic [`VEC_BITS-1:0]         enc_r_bv0,
    input  logic [`VEC_BITS-1:0]         enc_r_av1,
    input  logic [`VEC_BITS-1:0]         enc_r_bv1,
    output logic enc_avn0_ren,
    output logic enc_bvn0_ren,
    output logic enc_avn1_ren,
    output logic enc_bvn1_ren,

    // write buffer
    output logic enc_a_w_mapping_mode,
    output logic enc_b_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] enc_a_base_waddr,
    output logic [`ADDR_WIDTH-1:0] enc_b_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    enc_w_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    enc_w_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    enc_w_avn1,
    output logic [`VEC_NUM_WIDTH-1:0]    enc_w_bvn1,
    output logic [`VEC_BITS-1:0]         enc_w_av0,
    output logic [`VEC_BITS-1:0]         enc_w_bv0,
    output logic [`VEC_BITS-1:0]         enc_w_av1,
    output logic [`VEC_BITS-1:0]         enc_w_bv1,
    output logic enc_avn0_wen,
    output logic enc_bvn0_wen,
    output logic enc_avn1_wen,
    output logic enc_bvn1_wen

);

wire [`ADDR_WIDTH-1:0] enc_ip_w_base_addr     = 200;
wire [`ADDR_WIDTH-1:0] enc_ip_salt_addr       = 0;
wire [`ADDR_WIDTH-1:0] enc_ip_r_base_addr     = (security_level == 0)? 1 : 2;

logic enc_vld_i;
logic enc_rdy;
logic enc_ren;
logic [`ADDR_WIDTH-1:0] enc_r_addr;
logic [`VEC_BITS*2-1:0] enc_r_data;
logic enc_wen;
logic [`ADDR_WIDTH-1:0] enc_w_addr;
logic [`VEC_BITS*2-1:0] enc_w_data;

assign enc_r_data = {enc_r_bv1, enc_r_bv0};

encode u_encode(
    .clk,
    .rstn,               // async, low active reset
    .security_level,     // 0-hawk512, 1-hawk1024

    .start(enc_start),              // pulse
    .finish(enc_finish),

    .rdy_o(enc_rdy),

    // read buffer
    .ren(enc_ren),
    .r_offset_addr(enc_r_addr),
    .vld_i(enc_vld_i),          // the read vector is valid
    .r_data(enc_r_data),           // vn="vector number"
    
    // write buffer
    .wen(enc_wen),
    .w_offset_addr(enc_w_addr),
    .w_data(enc_w_data)
);

// Buffer reads have one cycle of latency.
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) enc_vld_i <= 1'b0;
    else if (enc_vld_i && enc_rdy) enc_vld_i <= 1'b0;
    else if (enc_ren) enc_vld_i <= 1'b1;
end

logic enc_rd_salt;
logic enc_rd_poly;
logic enc_rd_sig;

always_comb begin
    if (enc_r_addr<enc_ip_r_base_addr) begin  // read salt
        enc_rd_salt = 1'b1;
        enc_rd_poly = 1'b0;
        enc_rd_sig  = 1'b0;
    end
    else if (enc_r_addr < enc_ip_w_base_addr) begin
        enc_rd_salt = 1'b0;
        enc_rd_poly = 1'b1;
        enc_rd_sig  = 1'b0;
    end
    else begin
        enc_rd_salt = 1'b0;
        enc_rd_poly = 1'b0;
        enc_rd_sig  = 1'b1;
    end
end

// ------------------------------------------
// encoder read: use bv0,bv1 to read poly, string and sig
// ------------------------------------------

assign enc_avn0_ren = 1'b0;
assign enc_avn1_ren = 1'b0;

logic [`ADDR_WIDTH-2:0] enc_r_addr_lo;
logic [`ADDR_WIDTH-2:0] enc_r_addr_m1;
assign enc_r_addr_lo = enc_r_addr - 'd200;
assign enc_r_addr_m1 = enc_r_addr_lo - 'd1;

wire [`ADDR_WIDTH-1:0] enc_rd_salt_addr = enc_r_addr - enc_ip_salt_addr;
wire [`ADDR_WIDTH-1:0] enc_rd_poly_addr = enc_r_addr - enc_ip_r_base_addr;
wire [`ADDR_WIDTH-1:0] enc_rd_sig_addr  = enc_r_addr - enc_ip_w_base_addr;

always_comb begin
    // default
    enc_bvn0_ren = 1'b0;
    enc_bvn1_ren = 1'b0;

    case ({enc_rd_poly,enc_rd_sig,enc_rd_salt})
        3'b001: begin  // read salt
            enc_b_r_mapping_mode = 1'b0;
            enc_b_base_raddr = another_addr;
            enc_r_bvn0 = {enc_rd_salt_addr[0],7'b0};  // enc_rd_salt_addr is 0/0~1 -> vn0=0/128
            enc_r_bvn1 = enc_r_bvn0 | 1'b1;
            enc_bvn0_ren = enc_ren;
            enc_bvn1_ren = enc_ren;
        end
        3'b010: begin  // read sig
            enc_b_r_mapping_mode = 1'b0;
            enc_b_base_raddr = code_base_waddr;
            enc_r_bvn0 = {enc_rd_sig_addr, 1'b0};
            enc_r_bvn1 = enc_r_bvn0 | 1'b1;
            enc_bvn0_ren = enc_ren;
            enc_bvn1_ren = enc_ren;
        end
        default: begin  // read poly
            enc_b_r_mapping_mode = `MAP_S1_SIGN;
            enc_b_base_raddr = code_base_raddr;
            enc_r_bvn0 = {enc_rd_poly_addr, 1'b0};
            enc_r_bvn1 = enc_r_bvn0 | 1'b1;
            enc_bvn0_ren = enc_ren;
            enc_bvn1_ren = enc_ren;
        end
    endcase
end

// ------------------------------------------
// encoder write: use bv0, bv1 to write sig
// ------------------------------------------

logic [`ADDR_WIDTH-2:0] enc_w_addr_lo;
logic [`ADDR_WIDTH-2:0] enc_w_addr_m1;
assign enc_w_addr_lo = enc_w_addr[`ADDR_WIDTH-2:0];
assign enc_w_addr_m1 = enc_w_addr_lo - 'd1;

wire [`ADDR_WIDTH-1:0] enc_wr_sig_addr  = enc_w_addr - enc_ip_w_base_addr;

assign enc_a_w_mapping_mode = 1'b0;
assign enc_b_w_mapping_mode = 1'b0;
assign enc_b_base_waddr = code_base_waddr;
assign enc_w_bvn0 = {enc_wr_sig_addr, 1'b0};
assign enc_w_bvn1 = enc_w_bvn0 | 1'b1;
assign enc_w_bv0 = enc_w_data[1*128-1 -: 128];
assign enc_w_bv1 = enc_w_data[2*128-1 -: 128];

// encoder wen reset value is 1, so mask it until encoder really needs write 
logic code_wen_mask;

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) code_wen_mask <= 1'b0;
    else if (enc_start) code_wen_mask <= 1'b0;
    else if (enc_rd_salt) code_wen_mask <= 1'b1;
end

assign enc_avn0_wen = 1'b0;
assign enc_bvn0_wen = enc_wen && code_wen_mask;
assign enc_avn1_wen = 1'b0;
assign enc_bvn1_wen = enc_wen && code_wen_mask;

endmodule
