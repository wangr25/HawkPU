`include "../defines/defines.sv"

module re_bfu (

    input wire clk,
    input wire rstn,

	// 0-sign, 1-verify
	input wire sys_mode_in,
	input wire [3:0] bfu_mode_in,
	input wire polyqround_in,
	input wire bfu_sel_const_in,
	input wire [31:0] bfu_const_in,
	input wire symbreak_result,

	input wire [31:0] a_i,
	input wire [31:0] b_i,
	input wire [31:0] c_i,
	input wire [31:0] d_i,
	input wire [31:0] w0_i,
	input wire [31:0] w1_i,

	input wire vld_i,
	output logic rdy_o,

	// to div
	output logic [63:0] Xre,
	output logic [63:0] Xim,
	output logic [31:0] divisor,
	// output data
	output logic [31:0] a_o,
	output logic [31:0] b_o,
	output logic [31:0] c_o,
	output logic [31:0] d_o,

	output wire vld_o,
	input wire rdy_i
);

logic [3:0] bfu_mode;
// lower the fanout
`ifdef FPGA_SYN
(* dont_touch = "true" *)logic [3:0] bfu_mode_1;
(* dont_touch = "true" *)logic [3:0] bfu_mode_2;
(* dont_touch = "true" *)logic [3:0] bfu_mode_3;
(* dont_touch = "true" *)logic [3:0] bfu_mode_4;
//(* dont_touch = "true" *)logic [3:0] bfu_mode_5;
//(* dont_touch = "true" *)logic [3:0] bfu_mode_6;
//(* dont_touch = "true" *)logic [3:0] bfu_mode_7;
//(* dont_touch = "true" *)logic [3:0] bfu_mode_8;
//(* dont_touch = "true" *)logic [3:0] bfu_mode_9;
`else
logic [3:0] bfu_mode_1;
logic [3:0] bfu_mode_2;
logic [3:0] bfu_mode_3;
logic [3:0] bfu_mode_4;
logic [3:0] bfu_mode_5;
logic [3:0] bfu_mode_6;
logic [3:0] bfu_mode_7;
logic [3:0] bfu_mode_8;
logic [3:0] bfu_mode_9;
`endif

logic sys_mode;
logic polyqround;
logic [30:0] P;
logic [31:0] P_i;
logic bfu_sel_const;
logic [31:0] bfu_const;
assign sys_mode = sys_mode_in;
always_ff @(posedge clk) begin
	bfu_mode   <= bfu_mode_in;
	bfu_mode_1 <= bfu_mode_in;
	bfu_mode_2 <= bfu_mode_in;
	bfu_mode_3 <= bfu_mode_in;
	bfu_mode_4 <= bfu_mode_in;
end
assign polyqround = polyqround_in;
assign bfu_sel_const = bfu_sel_const_in;
assign P = sys_mode ? (polyqround ? `P2 : `P1) : `P0;
assign P_i = sys_mode ? (polyqround ? `P2_I : `P1_I) : `P0_I;
assign bfu_const = bfu_const_in;

wire ntt_mode       = (bfu_mode  ==`BFU_NTT_MODE       );
wire intt_mode      = (bfu_mode  ==`BFU_INTT_MODE      );
wire fft_mode       = (bfu_mode  ==`BFU_FFT_MODE       );
wire ifft_mode      = (bfu_mode  ==`BFU_IFFT_MODE      );
wire maddsub_mode   = (bfu_mode  ==`BFU_MADD_MODE      ) || (bfu_mode  ==`BFU_MSUB_MODE   );
wire addsub_mode    = (bfu_mode  ==`BFU_ADD_MODE       ) || (bfu_mode  ==`BFU_SUB_MODE    );
wire mmul_mode      = (bfu_mode  ==`BFU_MMUL_MODE      );
wire mul_mode       = (bfu_mode  ==`BFU_MUL_MODE       );
wire gf2cf_mode     = (bfu_mode  ==`BFU_GF2CF_MODE     );
wire mmac_mode      = (bfu_mode  ==`BFU_MMAC_MODE      );
wire div_mode       = (bfu_mode  ==`BFU_DIV_MODE       );
wire  ntt_mode_1    = (bfu_mode_1==`BFU_NTT_MODE       );
wire intt_mode_1    = (bfu_mode_1==`BFU_INTT_MODE      );
wire mmul_mode_1    = (bfu_mode_1==`BFU_MMUL_MODE      );
wire mmac_mode_1    = (bfu_mode_1==`BFU_MMAC_MODE      );
wire  ntt_mode_2    = (bfu_mode_2==`BFU_NTT_MODE       );
wire intt_mode_2    = (bfu_mode_2==`BFU_INTT_MODE      );
wire mmul_mode_2    = (bfu_mode_2==`BFU_MMUL_MODE      );
wire mmac_mode_2    = (bfu_mode_2==`BFU_MMAC_MODE      );
wire  ntt_mode_3    = (bfu_mode_3==`BFU_NTT_MODE       );
wire intt_mode_3    = (bfu_mode_3==`BFU_INTT_MODE      );
wire mmul_mode_3    = (bfu_mode_3==`BFU_MMUL_MODE      );
wire mmac_mode_3    = (bfu_mode_3==`BFU_MMAC_MODE      );
wire  ntt_mode_4    = (bfu_mode_4==`BFU_NTT_MODE       );
wire intt_mode_4    = (bfu_mode_4==`BFU_INTT_MODE      );
wire mmul_mode_4    = (bfu_mode_4==`BFU_MMUL_MODE      );
wire mmac_mode_4    = (bfu_mode_4==`BFU_MMAC_MODE      );

// if montred is used, need full stages of BFU
logic use_mred;
assign use_mred = ntt_mode || intt_mode || mmul_mode || mmac_mode;

logic [`BFU_PIPE_STAGES-1:0] vld ;
logic [`BFU_PIPE_STAGES-1:0] rdy ;
logic [`BFU_PIPE_STAGES-1:0] dff_en ;
logic [31:0] a_q [0:1];
logic [31:0] b_q [0:1];
logic [31:0] c_q [0:1];
logic [31:0] d_q [0:1];
logic [31:0] e_q [0:1];
logic [31:0] f_q [0:1];
logic [31:0] a_d [0:1];
logic [31:0] b_d [0:1];
logic [31:0] c_d [0:1];
logic [31:0] d_d [0:1];
logic [31:0] e_d [0:1];
logic [31:0] f_d [0:1];
logic [31:0] w0_q;
logic [31:0] w1_q;
logic [63:0] b_d_2;
logic [63:0] b_q_2;
logic [63:0] d_d_2;
logic [63:0] d_q_2;
logic [63:0] a_d_5;
logic [63:0] b_d_5;
logic [63:0] c_d_5;
logic [63:0] d_d_5;
logic [63:0] a_q_5;
logic [63:0] b_q_5;
logic [63:0] c_q_5;
logic [63:0] d_q_5;
logic [31:0] a_d_6;
logic [31:0] b_d_6;
logic [31:0] c_d_6;
logic [31:0] d_d_6;
logic [31:0] a_q_6;
logic [31:0] b_q_6;
logic [31:0] c_q_6;
logic [31:0] d_q_6;

//////////////////////
// stage 0 (input)
//////////////////////
pipe_handshake u_pipe_handshake_stage0 (
    .clk(clk),
    .rstn(rstn),
    .vld_i(vld_i),
    .rdy_o(rdy_o),
    .vld_o(vld[0]),
    .rdy_i(rdy[0]),
    .finish(1'b1),
    .d_en(dff_en[0])
);
dffe #(32*6) u_dffe_stage0 (
	.clk(clk),
	.en(dff_en[0]),
	.d({a_i, b_i, c_i, d_i, w0_i, w1_i}),
	.q({a_q[0], b_q[0], c_q[0], d_q[0], w0_q, w1_q})
);

logic [2:0] block1_a_sel_oh;
logic [2:0] block1_b_sel_oh;
logic [2:0] input_e_sel_oh;
logic [3:0] input_f_sel_oh;

// 027
logic cond1;
logic cond2;
logic cond3;
assign cond1 = (mul_mode || mmul_mode || mmac_mode || div_mode);
assign cond2 = (ntt_mode || intt_mode || fft_mode || ifft_mode);
assign cond3 = (ntt_mode || intt_mode || fft_mode);
assign input_e_sel_oh = {
	cond1,
	!(cond1 || cond2),
	cond2
};
mux31_onehot #(32) u_mux31_oh_inpute (
	.select(input_e_sel_oh),
	.data1(w0_q),
	.data2(32'd1),
	.data3(a_q[0]),
	.data_out(e_d[1])
);
assign input_f_sel_oh = {
	ifft_mode,
	cond1,
	!(cond1 || cond2),
	cond3
};
mux41_onehot #(32) u_mux41_oh_inputf (
	.select(input_f_sel_oh),
	.data1(w1_q),
	.data2(32'd1),
	.data3(c_q[0]),
	.data4(-w1_q),
	.data_out(f_d[1])
);
assign block1_a_sel_oh = {
	addsub_mode || ifft_mode || div_mode,
	intt_mode,
	!(addsub_mode || ifft_mode || intt_mode || div_mode)
};
assign block1_b_sel_oh = {
	addsub_mode || ifft_mode,
	intt_mode,
	!(addsub_mode || ifft_mode || intt_mode)
};
bfu_block1 u_bfu_block1_ab (
	.sys_mode,
    .a_i(a_q[0]),
    .b_i(bfu_sel_const ? bfu_const : b_q[0]),
	.div_mode,
	.bfu_const,
    .a_sel_oh(block1_a_sel_oh),
    .b_sel_oh(block1_b_sel_oh),
    .a_o(a_d[1]),
    .b_o(b_d[1])
);
bfu_block1 u_bfu_block1_cd (
	.sys_mode,
    .a_i(c_q[0]),
    .b_i(bfu_sel_const ? bfu_const : d_q[0]),
	.div_mode(1'b0),
	.bfu_const,
    .a_sel_oh(block1_a_sel_oh),
    .b_sel_oh(block1_b_sel_oh),
    .a_o(c_d[1]),
    .b_o(d_d[1])
);

//////////////////////
// stage 1 ~ 4
//////////////////////
pipe_handshake u_pipe_handshake_stage1 (
    .clk(clk),
    .rstn(rstn),
    .vld_i(vld[0]),
    .rdy_o(rdy[0]),
    .vld_o(vld[1]),
    .rdy_i(rdy[1]),
    .finish(1'b1),
    .d_en(dff_en[1])
);
logic stage2_rdy_i;
assign stage2_rdy_i = use_mred ? rdy[2] : rdy[4];
pipe_handshake u_pipe_handshake_stage2 (
    .clk(clk),
    .rstn(rstn),
    .vld_i(vld[1]),
    .rdy_o(rdy[1]),
    .vld_o(vld[2]),
    .rdy_i(stage2_rdy_i),
    .finish(1'b1),
    .d_en(dff_en[2])
);
pipe_handshake u_pipe_handshake_stage3 (
    .clk(clk),
    .rstn(rstn),
    .vld_i(vld[2]),
    .rdy_o(rdy[2]),
    .vld_o(vld[3]),
    .rdy_i(rdy[3]),
    .finish(1'b1),
    .d_en(dff_en[3])
);
pipe_handshake u_pipe_handshake_stage4 (
    .clk(clk),
    .rstn(rstn),
    .vld_i(vld[3]),
    .rdy_o(rdy[3]),
    .vld_o(vld[4]),
    .rdy_i(rdy[4]),
    .finish(1'b1),
    .d_en(dff_en[4])
);
dffe #(32*6) u_dffe_stage1 (
	.clk(clk),
	.en(dff_en[1]),
	.d({a_d[1], b_d[1], c_d[1], d_d[1], e_d[1], f_d[1]}),
	.q({a_q[1], b_q[1], c_q[1], d_q[1], e_q[1], f_q[1]})
);
dffe #(64*2) u_dffe_stage2 (
	.clk(clk),
	.en(dff_en[2]),
	.d({b_d_2, d_d_2}),
	.q({b_q_2, d_q_2})
);

logic [1:0] block2_sel0_oh;
logic [2:0] block2_sel1_oh;
logic [1:0] mred_dff_en;

assign block2_sel0_oh = {
	intt_mode,
	!intt_mode
};
assign block2_sel1_oh = {
	use_mred,
	!(use_mred || fft_mode),
	fft_mode
};
bfu_block2 u_bfu_block2_ab (
    .clk(clk),
	.sys_mode,
    .a_i(a_q[1]),
    .block2_dff_en(dff_en[2]),
	.mred_dff_en(mred_dff_en),
    .sel0_oh(block2_sel0_oh),
    .sel1_oh(block2_sel1_oh),
    .a_o(a_d_5)
);
bfu_block2 u_bfu_block2_cd (
    .clk(clk),
	.sys_mode,
    .a_i(c_q[1]),
    .block2_dff_en(dff_en[2]),
	.mred_dff_en(mred_dff_en),
    .sel0_oh(block2_sel0_oh),
    .sel1_oh(block2_sel1_oh),
    .a_o(c_d_5)
);

logic signed [63:0] bfu_mul1_r;
logic signed [63:0] bfu_mul2_r;

mul_signed_32x32 u_b_mul_e (
	.clk(clk),
	.en(1'b1),
	.a32($signed(b_q[1])),
	.b32($signed(e_q[1])),
	.d64(bfu_mul1_r)
);
mul_signed_32x32 u_d_mul_f (
	.clk(clk),
	.en(1'b1),
	.a32($signed(d_q[1])),
	.b32($signed(f_q[1])),
	.d64(bfu_mul2_r)
);
assign b_d_2 = bfu_mul1_r;
assign d_d_2 = bfu_mul2_r;

logic [30:0] b_mr;
logic [2:0] bfu_b_mux31_sel_oh;

assign bfu_b_mux31_sel_oh = {
	(fft_mode || ifft_mode),
	!(fft_mode || ifft_mode || use_mred),
	use_mred
};
mred u_mred (
    .clk(clk),
    .rstn(rstn),
	.sys_mode,
	.use_mred,
	.polyqround,
    .P(P),
    .P_i(P_i),
    .dff_en({dff_en[4],dff_en[3]}),
    .data_in(b_q_2[61:0]),
    .data_out(b_mr)
);
assign Xre = b_q_2 - d_q_2;
mux31_onehot #(64) u_mux31_oh_bfu_stage2 (
	.select(bfu_b_mux31_sel_oh),
	.data1({33'b0,b_mr}),
	.data2(b_q_2),
	.data3(Xre),
	.data_out(b_d_5)
);

logic block3_n_sel_1;
logic block3_n_sel_2;  // to lower fan-out
logic block3_n_sel_3;  // to lower fan-out
logic block3_n_sel_4;  // to lower fan-out
assign block3_n_sel_1 = ntt_mode_1 || intt_mode_1 || mmul_mode_1 || mmac_mode_1;
assign block3_n_sel_2 = ntt_mode_2 || intt_mode_2 || mmul_mode_2 || mmac_mode_2;
assign block3_n_sel_3 = ntt_mode_3 || intt_mode_3 || mmul_mode_3 || mmac_mode_3;
assign block3_n_sel_4 = ntt_mode_4 || intt_mode_4 || mmul_mode_4 || mmac_mode_4;
// if performing montred, then it is stage 3 and 4;
// otherwise, it is stage 2
assign mred_dff_en = block3_n_sel_1 ? {dff_en[4],dff_en[3]} : {2{dff_en[2]}};
logic [2:0] block3_out_sel_oh;
assign block3_out_sel_oh = bfu_b_mux31_sel_oh;

// put m2, m4 mux before pipeline reg
logic [31:0] m2, m4;
always_ff @(posedge clk) begin
	if (dff_en[1]) begin
		m2 <= block3_n_sel_1 ? P_i : e_d[1];
		m4 <= block3_n_sel_3 ? {1'b0,P} : f_d[1];
	end
end
bfu_block3 u_bfu_block3 (
    .clk(clk),
	.rstn(rstn),
	.sys_mode,
	.use_mred,
    .dff_en(mred_dff_en),
    .n_sel(block3_n_sel_1),
    .n_sel_1(block3_n_sel_2),
    .n_sel_2(block3_n_sel_3),
    .n_sel_3(block3_n_sel_4),
    .n0(d_q_2),
    .m1(b_q[1]),
    .m2(m2),
    .m3(d_q[1]),
    .m4(m4),
    .P(P),
    .P_i(P_i),
    .out_sel_oh(block3_out_sel_oh),
	.Xim,
    .block3_o(d_d_5)
); 

//////////////////////
// stage 5
//////////////////////
logic stage5_vld_i;
assign stage5_vld_i = use_mred ? vld[4] : vld[2];
logic [2:0] block4_a_sel_oh;
logic [3:0] block4_b_sel_oh;
assign block4_a_sel_oh = {
	fft_mode,
	maddsub_mode || ntt_mode || gf2cf_mode || mmac_mode,
	!(fft_mode || maddsub_mode || ntt_mode || gf2cf_mode || mmac_mode) // bypass
};
assign block4_b_sel_oh = {
	fft_mode,
	maddsub_mode || ntt_mode || gf2cf_mode,
	ifft_mode,
	!(fft_mode || maddsub_mode || ntt_mode || ifft_mode || gf2cf_mode) // bypass
};
pipe_handshake u_pipe_handshake_stage5 (
    .clk(clk),
    .rstn(rstn),
    .vld_i(stage5_vld_i),
    .rdy_o(rdy[4]),
    .vld_o(vld[5]),
    .rdy_i(rdy[5]),
    .finish(1'b1),
    .d_en(dff_en[5])
);
dffe #(64*4) u_dffe_stage5 (
	.clk(clk),
	.en(dff_en[5]),
	.d({a_d_5, b_d_5, c_d_5, d_d_5}),
	.q({a_q_5, b_q_5, c_q_5, d_q_5})
);
bfu_block4 u_bfu_block4_ab (
	.sys_mode,
	.P(P),
	.gf2cf(gf2cf_mode),
    .a_i(a_q_5),
    .b_i(b_q_5),
    .a_sel_oh(block4_a_sel_oh),
    .b_sel_oh(block4_b_sel_oh),
    .a_o(a_d_6),
    .b_o(b_d_6)
);
logic [63:0] blk4_c;
assign blk4_c = mmac_mode ? b_q_5 : c_q_5;
bfu_block4 u_bfu_block4_cd (
	.sys_mode,
	.P(P),
	.gf2cf(gf2cf_mode),
    .a_i(blk4_c),
    .b_i(d_q_5),
    .a_sel_oh(block4_a_sel_oh),
    .b_sel_oh(block4_b_sel_oh),
    .a_o(c_d_6),
    .b_o(d_d_6)
);

//////////////////////
// stage 6 (output)
//////////////////////
pipe_handshake u_pipe_handshake_stage6 (
    .clk(clk),
    .rstn(rstn),
    .vld_i(vld[5]),
    .rdy_o(rdy[5]),
    .vld_o(vld_o),
    .rdy_i(rdy_i),
    .finish(1'b1),
    .d_en(dff_en[6])
);


dffe #(32*4) u_dffe_stage6 (
	.clk(clk),
	.en(dff_en[6]),
	.d({a_d_6, b_d_6, c_d_6, d_d_6}),
	.q({a_q_6, b_q_6, c_q_6, d_q_6})
);
assign a_o = a_q_6;
assign b_o = b_q_6;
assign c_o = c_q_6;
assign d_o = d_q_6;

// div
assign divisor = a_q[1];


endmodule

module bfu_block1 (
	input wire sys_mode,
	input wire [31:0] a_i,
	input wire [31:0] b_i,
	input wire div_mode,
	input wire [31:0] bfu_const,
	input wire [2:0] a_sel_oh,
	input wire [2:0] b_sel_oh,
	output logic [31:0] a_o,
	output logic [31:0] b_o
);

logic [31:0] a_bp;
logic [31:0] a_a_b;
logic [31:0] a_s_b;
logic [31:0] b_bp;

assign a_bp = a_i;
assign a_a_b = a_i + (div_mode ? bfu_const : b_i);
assign a_s_b = a_i - b_i;
assign b_bp = b_i;

logic [31:0] a_bp_q;
logic [31:0] a_a_b_q;
logic [31:0] a_s_b_q;
logic [31:0] b_bp_q;

assign {a_bp_q, a_a_b_q, a_s_b_q, b_bp_q} = {a_bp, a_a_b, a_s_b, b_bp};

logic [14:0] a_ma_b;
logic [14:0] a_ms_b;

addred16 u_addred16 (
	.sum(a_a_b_q[15:0]),
	.msum(a_ma_b)
);
subred16 u_subred16 (
	.diff(a_s_b_q[15:0]),
	.mdiff(a_ms_b)
);
mux31_onehot #(32) u_mux31_oh_block1_0 (
	.select(a_sel_oh),
	.data1(a_bp_q),
	.data2({17'b0,a_ma_b}),
	.data3(a_a_b_q),
	.data_out(a_o)
);
mux31_onehot #(32) u_mux31_oh_block1_1 (
	.select(b_sel_oh),
	.data1(b_bp_q),
	.data2({17'b0,a_ms_b}),
	.data3(a_s_b_q),
	.data_out(b_o)
);

endmodule

module bfu_block2 (
	input wire clk,
	input wire sys_mode,
	input wire [31:0] a_i,
	input wire block2_dff_en,
	input wire [1:0] mred_dff_en,
	input wire [1:0] sel0_oh,
	input wire [2:0] sel1_oh,
	output logic [63:0] a_o
);

logic [14:0] mhalf;
logic [31:0] am;
logic [31:0] am_q;

mhalf15 u_mhalf15 (
	.data_in(a_i[14:0]),
	.data_out(mhalf)
);
assign am = ({32{sel0_oh[0]}} & a_i)
		|	({32{sel0_oh[1]}} & {17'b0,mhalf});
dffe #(32) u_dffe_block2 (
	.clk(clk),
	.en(block2_dff_en),
	.d(am),
	.q(am_q)
);

logic [63:0] am_s31;
logic [31:0] am_q1;
logic [31:0] am_qlast;

// signed << 31
assign am_s31 = {am_q[31],am_q,31'b0};
// align with montred
always_ff @(posedge clk) begin
	if (mred_dff_en[0]) begin
		am_q1 <= am_q;
	end
end
always_ff @(posedge clk) begin
	if (mred_dff_en[1]) begin
		am_qlast <= am_q1;
	end
end

mux31_onehot #(64) u_mux31_oh_block2_1 (
	.select(sel1_oh),
	.data1(am_s31),
	.data2({32'b0,am_q}),
	.data3({32'b0,am_qlast}),
	.data_out(a_o)
);

endmodule

module bfu_block3 (
	input wire clk,
	input wire rstn,
	input wire sys_mode,
	input wire use_mred,
	input wire [1:0] dff_en,
	input wire n_sel,	// only if ntt/intt, n_sel=1
	input wire n_sel_1,	// only if ntt/intt, n_sel=1
	input wire n_sel_2,	// only if ntt/intt, n_sel=1
	input wire n_sel_3,	// only if ntt/intt, n_sel=1
	input wire [63:0] n0,
	input wire [31:0] m1,
	input wire [31:0] m2,
	input wire [31:0] m3,
	input wire [31:0] m4,
	input wire [30:0] P,
	input wire [31:0] P_i,
	input wire [2:0] out_sel_oh,
	output logic [63:0] Xim,
	output logic [63:0] block3_o
);

localparam [1:0] mred_delay_cycle = 2;

logic [32:0] mul1_a_u;
logic [31:0] mul1_b_u;
logic signed [32:0] mul1_a_s;
logic signed [31:0] mul1_b_s;
logic signed [63:0] mul1_r_s;
logic [63:0] mul1_r_u;

assign mul1_a_u = n_sel ? {1'b0,n0[31:0]} : {m3[31],m3[31:0]};
assign mul1_b_u = m2;
assign mul1_a_s = $signed(mul1_a_u);
assign mul1_b_s = $signed(mul1_b_u);
mul_signed_33x32 u_a_s_mul_b_s_1 (
	.clk(clk),
	.en(1'b1),
	.a33(mul1_a_s),
	.b32(mul1_b_s),
	.d64(mul1_r_s)
);
assign mul1_r_u = mul1_r_s;

logic [61:0] n0_q1, n0_q2;
logic [63:0] mul1_r_q, mul2_r_q;
logic [32:0] mul2_a_u;
logic [31:0] mul2_b_u;
logic signed [32:0] mul2_a_s;
logic signed [31:0] mul2_b_s;
logic signed [63:0] mul2_r_s;
logic [63:0] mul2_r_u;

dffe #(62+64) u_dffe_block3_0 (
	.clk(clk),
	.en(dff_en[0]),
	.d({n0[61:0], mul1_r_u}),
	.q({n0_q1, mul1_r_q})
);
dffe #(62+64) u_dffe_block3_1 (
	.clk(clk),
	.en(dff_en[1]),
	.d({n0_q1, mul2_r_u}),
	.q({n0_q2, mul2_r_q})
);

assign mul2_a_u = n_sel_2 ? {1'b0,mul1_r_q[31:0]} : {m1[31],m1[31:0]};
assign mul2_b_u = m4;
assign mul2_a_s = $signed(mul2_a_u);
assign mul2_b_s = $signed(mul2_b_u);
mul_signed_33x32 u_a_s_mul_b_s_2 (
	.clk(clk),
	.en(1'b1),
	.a33(mul2_a_s),
	.b32(mul2_b_s),
	.d64(mul2_r_s)
);
assign mul2_r_u = mul2_r_s;

logic [63:0] add_a,add_b,sum;
assign add_a = n_sel_3 ? n0_q2 : mul1_r_q;
assign add_b = mul2_r_q;
// 64-bits adder
assign sum = add_a + add_b;

logic [30:0] msum;
addred32 u_addred32 (
	.sys_mode,
	.P(P),
	.gf2cf(1'b0),
	.sum(sum[63:32]),
	.msum(msum)
);

assign Xim = sum;

logic [63:0] block3_data_out;
mux31_onehot #(64) u_mux31_oh_block3 (
	.select(out_sel_oh),
	.data1({33'b0,msum}),
	.data2({32'b0,n0[31:0]}),
	.data3(sum),
	.data_out(block3_data_out)
);

logic p0_bound;
logic flag;
assign p0_bound = (sys_mode==1'b0) && (mul1_r_u==`P0) && use_mred;
dffre_pipe #(
	.WIDTH(1),
	.DELAY(mred_delay_cycle)
) u_dffre_pipe_block3_mred_p0_bound (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(p0_bound),
	.q(flag) 
);
assign block3_o = flag ? `P0 : block3_data_out;

endmodule

module bfu_block4 (
	input wire sys_mode,
	input wire [30:0] P,
	input wire gf2cf,
	input wire [63:0] a_i,
	input wire [63:0] b_i,
	input wire [2:0] a_sel_oh,
	input wire [3:0] b_sel_oh,
	output logic [31:0] a_o,
	output logic [31:0] b_o
);

logic [31:0] a_bp_lo;
logic [63:0] a_a_b;
logic [63:0] a_s_b;
logic [31:0] b_bp_lo;
logic [31:0] b_bp_hi;

assign a_bp_lo = a_i[31:0];
assign a_a_b = a_i + b_i;
assign a_s_b = a_i - b_i;
assign b_bp_lo = b_i[31:0];
assign b_bp_hi = b_i[63:32];

logic [31:0] a_bp_lo_q;
logic [63:0] a_a_b_q;
logic [63:0] a_s_b_q;
logic [31:0] b_bp_lo_q;
logic [31:0] b_bp_hi_q;

assign {a_bp_lo_q, a_a_b_q, a_s_b_q, b_bp_lo_q, b_bp_hi_q}
    = {a_bp_lo, a_a_b, a_s_b, b_bp_lo, b_bp_hi};

logic [31:0] a_ma_b; 	// a mod add b
logic [30:0] a_ms_b; 	// a mod sub b

addred32 u_addred32 (
	.sys_mode,
	.P(P),
	.gf2cf(gf2cf),
	.sum(a_a_b_q[31:0]),
	.msum(a_ma_b)
);
subred32 u_subred32 (
	.sys_mode,
	.P(P),
	.diff(a_s_b_q[31:0]),
	.mdiff(a_ms_b)
);
mux31_onehot #(32) u_mux31_oh_block4_0 (
	.select(a_sel_oh),
	.data1(a_bp_lo_q),
	.data2(a_ma_b),
	.data3(a_a_b_q[63:32]),
	.data_out(a_o)
);
mux41_onehot #(32) u_mux41_oh_block4_1 (
	.select(b_sel_oh),
	.data1(b_bp_lo_q),
	.data2(b_bp_hi_q),
	.data3({1'b0,a_ms_b}),
	.data4(a_s_b_q[63:32]),
	.data_out(b_o)
);

endmodule

module addred16 (
	input wire [15:0] sum,
    output wire [14:0] msum
);

wire cond;
wire [15:0] M;

assign cond = sum > `P0; // gt
assign M = cond ? `P0 : 'd0;
assign msum = sum - M;

endmodule

module subred16 (
	input wire [15:0] diff,
    output wire [14:0] mdiff
);

wire cond;
wire [15:0] M;

assign cond = diff[15] || (diff=='0);		// <= 0
assign M = cond ? `P0 : 'd0;
assign mdiff = diff + M;

endmodule

module addred32 (
	// determined by sys_mode and polyqround
	input wire sys_mode,
	input wire [30:0] P,
	input wire gf2cf,	// in sign only
	input wire [31:0] sum,
    output wire [31:0] msum // gf2cf needs all 32 bits
);

wire cond;
wire [30:0] c;
wire [31:0] M;

assign c = (gf2cf ? (`P0>>1) : P);

assign cond = sys_mode ? (sum >= c) : (sum > c);
assign M = cond ? P : 32'd0;
assign msum = sum - M;

endmodule

module subred32 (
	// determined by sys_mode and polyqround
	input wire sys_mode,
	input wire [30:0] P,
	input wire [31:0] diff,
    output wire [30:0] mdiff
);

wire cond;
wire [31:0] M;

assign cond = diff[31] || (diff=='0);  // <= 0
assign M = cond ? P : 32'd0;
assign mdiff = diff + M;

endmodule

module mhalf15 (
    input wire [14:0] data_in,
    output wire [14:0] data_out
);

wire [14:0] M;

assign M = {15{data_in[0]}} & 15'd`HP0;
assign data_out = {1'b0, data_in[14:1]} + M;

endmodule

// montgomery reduction
// input: a*b
// output: a*b*R^{-1} mod p
module mred (

    input wire clk,
    input wire rstn,
	input wire sys_mode,
	input wire use_mred,
	input wire polyqround,

	// determined by sys_mode and polyqround
	input wire [30:0] P,
	input wire [31:0] P_i,
	input wire [1:0] dff_en,

    input wire [61:0] data_in,

    output reg [30:0] data_out

);

localparam [1:0] mred_delay_cycle = 2;

// pipeline stage 0

logic [63:0] mP0i_d;		// only least 32 bits are used
reg [31:0] mP0i_q;
reg [61:0] data_in_q0;

// 32-bit multiplier
mul_const_P_I u_mul_const_P_I (
	.sys_mode,
	.polyqround,
	.a(data_in[31:0]),
	.r(mP0i_d)
);

dffe #(
	.DATA_WIDTH(32)
) U_dff_mP0i (
	.clk(clk),
	.en(dff_en[0]),
	.d(mP0i_d[31:0]),
	.q(mP0i_q)
);

dffe #(
	.DATA_WIDTH(62)
) U_dff_datain (
	.clk(clk),
	.en(dff_en[0]),
	.d(data_in),
	.q(data_in_q0)
);

// pipeline stage 1

logic [62:0] mPP0i_d;
reg [62:0] mPP0i_q;
reg [61:0] data_in_q1;

mul_const_P u_mul_const_P (
	.sys_mode,
	.polyqround,
	.a(mP0i_q),
	.r(mPP0i_d)
);

dffe #(
	.DATA_WIDTH(63)
) U_dff_mPP0i (
	.clk(clk),
	.en(dff_en[1]),
	.d(mPP0i_d),
	.q(mPP0i_q)
);

dffe #(
	.DATA_WIDTH(62)
) U_dff_datain1 (
	.clk(clk),
	.en(dff_en[1]),
	.d(data_in_q0),
	.q(data_in_q1)
);


// pipeline stage 2

wire [63:0] rinner_v_d;		// only high 32 bits are used
wire [31:0] rinner_v_q;

// 63-bit adder
assign rinner_v_d = mPP0i_q + data_in_q1;
assign rinner_v_q = rinner_v_d[63:32];


// pipeline stage 3

wire [30:0] v_M;
wire [30:0] data_out_d;

assign v_M = (rinner_v_q < P) ? 31'b0 : P;
// 32-bit subtractor
assign data_out_d = rinner_v_q - v_M;

logic p0_bound;
logic flag;
assign p0_bound = (sys_mode==1'b0) && (data_in==`P0) && use_mred;
dffre_pipe #(
	.WIDTH(1),
	.DELAY(mred_delay_cycle)
) u_dffre_pipe_mred_p0_bound (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(p0_bound),
	.q(flag) 
);
assign data_out = flag ? `P0 : data_out_d;

endmodule

module mul_signed_32x32 (
	input logic clk,
	input logic en,
	input logic signed [31:0] a32,
	input logic signed [31:0] b32,
	output logic signed [63:0] d64
);

assign d64 = a32 * b32;

endmodule

module mul_signed_33x32 (
	input logic clk,
	input logic en,
	input logic signed [32:0] a33,
	input logic signed [31:0] b32,
	output logic signed [63:0] d64
);

assign d64 = a33 * b32;

endmodule
