`include "../defines/defines.sv"

module dec_top (

    input wire clk,
    input wire rstn,
    input wire security_level,

    // from taskcode
    input  logic [`ADDR_WIDTH-1:0] code_base_raddr,
    input  logic [`ADDR_WIDTH-1:0] code_base_waddr,
    input  logic [`ADDR_WIDTH-1:0] another_addr,
    input  logic dec_start,
    input  logic dec_funct,          // 0-input is sig, 1-input is pub
    input  logic q00_mode,           // 0-q00[0] = 0, 1- Normal Adjust q00
    input  logic q00_only,           // 0-decode q00 and q01, 1-only decode q00
    // to control
    output logic dec_finish,
    // to BFU
    output logic [31:0] q00_cstup,

    // buffer
    // read buffer
    output logic dec_a_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] dec_a_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    dec_r_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    dec_r_avn1,
    input  logic [`VEC_BITS-1:0]         dec_r_av0,
    input  logic [`VEC_BITS-1:0]         dec_r_av1,
    output logic dec_avn0_ren,
    output logic dec_avn1_ren,

    // write buffer
    output logic dec_a_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] dec_a_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    dec_w_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    dec_w_avn1,
    output logic [`VEC_BITS-1:0]         dec_w_av0,
    output logic [`VEC_BITS-1:0]         dec_w_av1,
    output logic dec_avn0_wen,
    output logic dec_avn1_wen,
    output logic dec_b_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] dec_b_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    dec_w_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    dec_w_bvn1,
    output logic [`VEC_BITS-1:0]         dec_w_bv0,
    output logic [`VEC_BITS-1:0]         dec_w_bv1,
    output logic dec_bvn0_wen,
    output logic dec_bvn1_wen

);

// decode core r/w data
logic dec_ren;
logic [`ADDR_WIDTH-1:0] r_addr_decode;
logic [`VEC_BITS*2-1:0] r_data_decode;
logic dec_wen;
logic [`ADDR_WIDTH-1:0] w_addr_decode;
logic [`VEC_BITS*2-1:0] w_data_decode;
// decode flag
logic decode_salt_en;
logic decode_sig_en;
logic decode_q00_en;
logic adjust_q00_en;
logic decode_q01_en;
// q00[0] normal adjusted value
logic [31:0] q00_0;
logic q00_adjust_valid;
wire dec_vld_i;

decode u_decode (

    .clk,
    .rstn,               // async, low active reset
    .security_level,     // 0-hawk512, 1-hawk1024

    .dec_funct,          // 0-input is sig, 1-input is pub
    .q00_mode,           // 0-q00[0] = 0, 1- Normal Adjust q00
    .q00_only,           // 0-decode q00 and q01, 1-only decode q00

    .start(dec_start),              // pulse
    .finish(dec_finish),

    .decode_salt_en,
    .decode_sig_en,
    .decode_q00_en,
    .adjust_q00_en,
    .decode_q01_en,
    .q00_0,
    .q00_adjust_valid,

    // read buffer
    .ren(dec_ren),
    .r_offset_addr(r_addr_decode),
    .vld_i(dec_vld_i),
    .r_data(r_data_decode),
    
    // write buffer
    .wen(dec_wen),
    .w_offset_addr(w_addr_decode),
    .w_data(w_data_decode)
);

assign r_data_decode = {dec_r_av1,dec_r_av0};

enc_pipeline_delay #(
    `BUFF_RD_LATENCY
) u_pipeline_delay_decode_vld_i(
    .clk,
    .rstn,
    .data_in(dec_ren),
    .data_out(dec_vld_i)
);

// q00[0]
logic q00_0_vld;
assign q00_0_vld = q00_adjust_valid;
always_ff @(posedge clk) begin
    if (q00_0_vld) q00_cstup <= security_level ? (q00_0<<10) : (q00_0<<12);
end

// bus interface

wire [`VEC_NUM_WIDTH-1:0] HN0 = security_level ? 'd128 : 'd64;
wire [`VEC_NUM_WIDTH-1:0] HN1 = security_level ? 'd129 : 'd65;
wire [`VEC_NUM_WIDTH-1:0] N = security_level ? 'd256 : 'd128;
wire [`ADDR_WIDTH-1:0] wa   = w_addr_decode-'d100;
wire [`ADDR_WIDTH-1:0] wa_1 = w_addr_decode-(security_level ? 'd102 : 'd101);
wire [`ADDR_WIDTH-1:0] wa_2 = w_addr_decode-(security_level ? 'd164 : 'd132);

// read port a
assign dec_a_r_mapping_mode = adjust_q00_en ? `MAP_Q00_VF0 : 1'b0;
assign dec_a_base_raddr = adjust_q00_en ? code_base_waddr : (code_base_raddr + (r_addr_decode>>1));
// note: when adjust q00[0], read offset=100 -> vn is also 0,1
assign dec_r_avn0 = r_addr_decode[0] ? HN0 : 0;
assign dec_r_avn1 = r_addr_decode[0] ? HN1 : 1;
assign dec_avn0_ren = dec_ren;
assign dec_avn1_ren = dec_ren;

// write port a
always_comb begin
    dec_a_w_mapping_mode = 1'b0;
    case (1'b1)
        decode_salt_en: dec_a_w_mapping_mode = 1'b0;
        decode_sig_en: dec_a_w_mapping_mode = 1'b0;
        decode_q00_en,
        adjust_q00_en: dec_a_w_mapping_mode = `MAP_Q00_VF0;
        decode_q01_en: dec_a_w_mapping_mode = `MAP_Q01_VF0;
    endcase
end
assign dec_a_base_waddr = (decode_salt_en||decode_q01_en) ? another_addr : code_base_waddr;
always_comb begin
    if (decode_salt_en) begin
        dec_w_avn0 = wa << 7; // wa=0->0, wa==1->128
    end
    else if (decode_sig_en) begin  // write s1
        dec_w_avn0 = wa_1 << 1;
    end
    else if (decode_q01_en) begin // write q01
        dec_w_avn0 = wa_2 << 1;
    end
    else begin // write q00
        dec_w_avn0 = wa << 1;
    end
end
assign dec_w_avn1 = dec_w_avn0 | 'b1;
assign dec_w_av0 = w_data_decode[`VEC_BITS-1:0];
assign dec_w_av1 = w_data_decode[2*`VEC_BITS-1:`VEC_BITS];
assign dec_avn0_wen = dec_wen;
assign dec_avn1_wen = dec_wen;

// write port b (write adj(q00))
assign dec_b_w_mapping_mode = `MAP_Q00_VF0;
assign dec_b_base_waddr = code_base_waddr;

logic [5:0] b_cnt;
logic b_cnt_finish;
assign b_cnt_finish = (b_cnt == (security_level ? 'd63 : 'd31)) && dec_wen;
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) b_cnt <= 'd0;
    else if (b_cnt_finish) b_cnt <= 'd0;
    else if (decode_q00_en && dec_wen) b_cnt <= b_cnt + 'd1;
end

logic [2*`VEC_BITS-1:0] dec_wdata_q;
always_ff @(posedge clk) begin
    if (dec_wen) dec_wdata_q <= w_data_decode;
end

logic adjoint_q00_last_en;

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) adjoint_q00_last_en <= 'd0;
    else if (adjoint_q00_last_en==1'b1) adjoint_q00_last_en <= 1'b0;
    else if (b_cnt_finish) adjoint_q00_last_en <= 1'b1;
end

assign dec_w_bvn0 = dec_w_bvn1 + 'd1;
assign dec_w_bvn1 = adjoint_q00_last_en ? HN0 : (N - {b_cnt,1'b0});

logic [2*`VEC_BITS-1:0] tmp;
logic [31:0] tmp1;
assign tmp1 = adjoint_q00_last_en ? 'd0 : w_data_decode[31:0];
assign tmp = {tmp1, dec_wdata_q[2*`VEC_BITS-1 -: (7*32)]};

assign dec_w_bv0 = {-tmp[1*32-1 -:32], -tmp[2*32-1 -:32], -tmp[3*32-1 -:32], -tmp[4*32-1 -:32]};
assign dec_w_bv1 = {-tmp[5*32-1 -:32], -tmp[6*32-1 -:32], -tmp[7*32-1 -:32], -tmp[8*32-1 -:32]};

assign dec_bvn0_wen = ( dec_wen && (b_cnt>'d0) ) || adjoint_q00_last_en;
assign dec_bvn1_wen = dec_bvn0_wen;


endmodule
