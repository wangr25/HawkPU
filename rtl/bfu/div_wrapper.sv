`include "../defines/defines.sv"

module div_wrapper(

    input   logic           clk,
    input   logic           rstn,
    input   logic           security_level,

    // taskcode
    input wire [`TC_W-1:0] taskcode,
    input wire taskcode_vld,

    // from BFU cores
    input logic [63:0] Xre[0:3],
    input logic [63:0] Xim[0:3],
    input logic [31:0] divisor[0:3],

    // 
    output logic div_finish,
    output logic bfu_div_av0_vld_i,
    output logic bfu_div_av1_vld_i,
    output logic bfu_div_bv0_vld_i,
    output logic bfu_div_bv1_vld_i,

    // read buffer, all 4 ports are used
    output logic div_a_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] div_a_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    div_r_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    div_r_avn1,
    output logic div_avn0_ren,
    output logic div_avn1_ren,

    output logic div_b_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] div_b_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    div_r_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    div_r_bvn1,
    output logic div_bvn0_ren,
    output logic div_bvn1_ren,

    // write buffer, port b is used
    output logic div_b_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] div_b_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    div_w_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    div_w_bvn1,
	output logic [`VEC_BITS-1:0] div_w_bv0,
	output logic [`VEC_BITS-1:0] div_w_bv1,
    output logic div_bvn0_wen,
    output logic div_bvn1_wen
    
);

wire [`VEC_NUM_WIDTH-1:0] HVN = security_level ? 'd128 : 'd64;

wire task_div = (taskcode[2:0]==2'b11) && (taskcode[26:23]==`BFU_DIV_MODE);

//-------------------------------------------
// div top signals
//-------------------------------------------
localparam int P         = 8;
localparam int M         = 64;
localparam int N         = 32;

logic start;
logic [9:0] rd_base_addr;
logic [9:0] wr_base_addr;
logic [9:0] depth; // depth = NUM / P

logic [P*M-1:0] x_in;
logic [P*N-1:0] y_in;

logic done;
logic rd_memen_x;
logic rd_memen_y;
logic wr_memen;
logic [9:0] rd_mem_addr_x;
logic [9:0] rd_mem_addr_y;  // same as rd_mem_addr_x
logic [9:0] wr_mem_addr;
logic [P*N-1:0] q_out;

wire [9:0] rd_offset = (rd_memen_y ? rd_mem_addr_y : rd_mem_addr_x) - rd_base_addr;
wire [9:0] wr_offset = wr_mem_addr   - wr_base_addr;

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) start <= 1'b0;
	else if (start==1'b1) start <= 1'b0;
	else if (taskcode_vld && task_div) start <= 1'b1;
end
assign rd_base_addr = 'd0;
assign wr_base_addr = 'd0;
assign depth = security_level ? 1024/P : 512/P;

// -------------------------------------------------------------
// inst. div_top
div_top #(
    .P         (P),
    .M         (M),
    .N         (N)
) u_div_top (
    .clk            (clk),
    .rst_n          (rstn),
    .start          (start),
    .done_o         (done),
    .rd_base_addr   (rd_base_addr),
    .wr_base_addr   (wr_base_addr),
    .depth          (depth),
    .rd_mem_en_x     (rd_memen_x),
    .rd_mem_en_y     (rd_memen_y),
    .wr_memen       (wr_memen),
    .rd_mem_addr_x  (rd_mem_addr_x),
    .rd_mem_addr_y  (rd_mem_addr_y),
    .wr_mem_addr    (wr_mem_addr),
    .x_in           (x_in),
    .y_in           (y_in),
    .q_out          (q_out)
);

logic dividend_vld_i;
dffre_pipe #(
	.WIDTH(1),
	.DELAY(4)
) u_dffre_dividend_vld_i (
	.clk,
	.rstn,
	.en(1'b1),
	.d(rd_memen_x),
	.q(dividend_vld_i)
);
// unsigned
logic [63:0] Xre_u[0:3];
logic [63:0] Xim_u[0:3];
// sign bit
logic Xre_s[0:3];
logic Xim_s[0:3];
// sign bit buffer
logic sign_bits_i_buff_sel;
logic sign_bits_o_buff_sel;
logic [3:0]Xre_s_q[2];
logic [3:0]Xim_s_q[2];

always_ff @(posedge clk) begin
    if (start) sign_bits_i_buff_sel <= 1'b0;
    else if (dividend_vld_i) sign_bits_i_buff_sel <= ~sign_bits_i_buff_sel;
end
always_ff @(posedge clk) begin
    if (start) sign_bits_o_buff_sel <= 1'b0;
    else if (div_bvn0_wen) sign_bits_o_buff_sel <= ~sign_bits_o_buff_sel;
end

integer i;
always_comb begin
    foreach (Xre[i]) begin
        Xre_s[i] = Xre[i][63];
        Xim_s[i] = Xim[i][63];
        Xre_u[i] = (Xre[i] ^ {64{Xre_s[i]}}) + Xre_s[i];
        Xim_u[i] = (Xim[i] ^ {64{Xim_s[i]}}) + Xim_s[i];
    end
end
always_ff @(posedge clk) begin
    if (dividend_vld_i) begin
        for (i=0;i<=3;i=i+1) begin
            Xre_s_q[sign_bits_i_buff_sel][i] <= Xre_s[i];
            Xim_s_q[sign_bits_i_buff_sel][i] <= Xim_s[i];
        end
    end
end

assign x_in = {Xim_u[3], Xim_u[2], Xim_u[1], Xim_u[0], Xre_u[3], Xre_u[2], Xre_u[1], Xre_u[0]};
assign y_in = {
    divisor[3], divisor[2], divisor[1], divisor[0],
    divisor[3], divisor[2], divisor[1], divisor[0]
};

logic [N-1:0] q_re_u[0:3];  // unsigned quotient
logic [N-1:0] q_im_u[0:3];  // unsigned quotient
logic [N-1:0] q_re_s[0:3];  // signed quotient
logic [N-1:0] q_im_s[0:3];  // signed quotient
assign q_re_u[0] = q_out[1*N-1-:N];
assign q_re_u[1] = q_out[2*N-1-:N];
assign q_re_u[2] = q_out[3*N-1-:N];
assign q_re_u[3] = q_out[4*N-1-:N];
assign q_im_u[0] = q_out[5*N-1-:N];
assign q_im_u[1] = q_out[6*N-1-:N];
assign q_im_u[2] = q_out[7*N-1-:N];
assign q_im_u[3] = q_out[8*N-1-:N];
always_comb begin
    foreach (q_re_s[i]) begin
        q_re_s[i] = (q_re_u[i] ^ {64{Xre_s_q[sign_bits_o_buff_sel][i]}}) + Xre_s_q[sign_bits_o_buff_sel][i];
    end
    foreach (q_im_s[i]) begin
        q_im_s[i] = (q_im_u[i] ^ {64{Xim_s_q[sign_bits_o_buff_sel][i]}}) + Xim_s_q[sign_bits_o_buff_sel][i];
    end
end


//-------------------------------------------
// to bfu
//-------------------------------------------
dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY)
) u_dffre_bfu_div_a_vld_i (
	.clk,
	.rstn,
	.en(1'b1),
	.d(div_avn0_ren),
	.q(bfu_div_av0_vld_i)
);
assign bfu_div_av1_vld_i = bfu_div_av0_vld_i;
dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY)
) u_dffre_bfu_div_b_vld_i (
	.clk,
	.rstn,
	.en(1'b1), 
	.d(div_bvn0_ren),
	.q(bfu_div_bv0_vld_i)
);
assign bfu_div_bv1_vld_i = bfu_div_bv0_vld_i;


//-------------------------------------------
// buffer interface
//-------------------------------------------
wire [8:0] src1_addr = taskcode[11: 3];
wire [8:0] src2_addr = taskcode[20:12];
wire a_mapping       = taskcode[21];
wire b_mapping       = taskcode[22];

logic [`ADDR_WIDTH-1:0] q00_dec_addr;
assign q00_dec_addr = security_level ? `ADDR_FFT_Z00_VF1 : `ADDR_FFT_Z00;

// r
// rd port case0: a->q01, b->w1
// rd port case1: a->q00
wire rd_dividend = rd_memen_x;   // reading q01 and w1

// r port a
assign div_a_base_raddr     = rd_dividend ? src1_addr : q00_dec_addr;
assign div_a_r_mapping_mode = rd_dividend ? a_mapping : `MAP_Q00_VF0;
assign div_r_avn0           = rd_offset;
assign div_r_avn1           = div_r_avn0 + HVN;
assign div_avn0_ren         = (rd_memen_x || rd_memen_y) && task_div;
assign div_avn1_ren         = div_avn0_ren;
// r port b
assign div_b_base_raddr     = src2_addr;
assign div_b_r_mapping_mode = b_mapping;
assign div_r_bvn0           = rd_offset;
assign div_r_bvn1           = div_r_bvn0 + HVN;
assign div_bvn0_ren         = rd_memen_x && task_div;
assign div_bvn1_ren         = div_bvn0_ren;

// w
assign div_b_base_waddr     = taskcode[61:53];
assign div_b_w_mapping_mode = taskcode[62];
// w port b
assign div_w_bvn0   = wr_offset;
assign div_w_bvn1   = div_w_bvn0 | HVN;
assign div_bvn0_wen = wr_memen && task_div;
assign div_bvn1_wen = div_bvn0_wen;
assign div_w_bv0    = {q_re_s[3], q_re_s[2], q_re_s[1], q_re_s[0]};
assign div_w_bv1    = {q_im_s[3], q_im_s[2], q_im_s[1], q_im_s[0]};

// finish
assign div_finish = done;

endmodule
