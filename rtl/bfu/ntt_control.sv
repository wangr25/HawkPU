`include "../defines/defines.sv"

// ntt and fft control logic
// counters are reused
module ntt_control (
	input wire clk,
	input wire rstn,
	input wire security_level,
	// from control_top
	input wire ntt_mode,	// 1-ntt 0-fft
	input wire ntt_start,
	input wire ntt_en,
	// to and from counter_seq
	output logic seq_cnt_start,
	output logic seq_cnt_en,	
	output logic [6:0] seq_cnt_max,
	input wire [6:0] seq_cnt_val,
	input wire seq_cnt_almost_finish,
	input wire seq_cnt_finish,
	// to and from counter_fft
	output logic fft_cnt_start,
	output logic fft_cnt_en,
	input wire [6:0] fft_cnt_idx1,
	input wire [6:0] fft_cnt_idx2,
	input wire [3:0] fft_cnt_stage,
	input wire fft_cnt_almost_finish,
	input wire fft_cnt_finish,
	input wire fft_cnt_busy,
	// output
	output logic [3:0] ntt_stage,
	output logic [`VEC_NUM_WIDTH-1:0] ntt_avn0,
	output logic [`VEC_NUM_WIDTH-1:0] ntt_bvn0,
	output logic [`VEC_NUM_WIDTH-1:0] ntt_avn1,
	output logic [`VEC_NUM_WIDTH-1:0] ntt_bvn1,
	output logic ntt_avn0_ren,
	output logic ntt_bvn0_ren,
	output logic ntt_avn1_ren,
	output logic ntt_bvn1_ren,
	output logic ntt_avn0_vld,
	output logic ntt_bvn0_vld,
	output logic ntt_avn1_vld,
	output logic ntt_bvn1_vld,
	output logic ntt_finish,
	output logic ntt_busy,
	output logic ntt_in_permut_sel,
	output logic ntt_out_permut_sel
);

logic start;
logic cnt_sel;	// 0-counter_seq, 1-counter_fft

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn || (ntt_en && ntt_start && ntt_mode)) begin
		cnt_sel <= 1'b0; 
	end
	else if (ntt_mode) begin	// ntt
		if (ntt_en && seq_cnt_almost_finish && (cnt_sel==1'b0)) begin
			cnt_sel <= 1'b1;
		end
	end
	else if (!ntt_mode) begin	// fft
		if (ntt_en && start && (cnt_sel==1'b0)) begin
			cnt_sel <= 1'b1;
		end
	end
end

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		start <= 1'b0; 
	end else if (ntt_en && ntt_start) begin
		start <= 1'b1;
	end else if (ntt_en && (start == 1'b1)) begin
		start <= 1'b0;
	end
end

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		ntt_busy <= 1'b0;
	end else if (ntt_en && start) begin
		ntt_busy <= 1'b1;
	end else if (ntt_en && fft_cnt_almost_finish) begin
		ntt_busy <= 1'b0;
	end
end

dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY)
) u_dffre_pipe_ntt_vn_vld_i (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(ntt_avn0_ren),
	.q(ntt_avn0_vld) 
);
assign ntt_bvn0_vld = ntt_avn0_vld;
assign ntt_avn1_vld = ntt_avn0_vld;
assign ntt_bvn1_vld = ntt_avn0_vld;

assign seq_cnt_start = ntt_mode ? start : 1'b0;
assign seq_cnt_en = ntt_mode ? ntt_en : 1'b0;
assign seq_cnt_max = security_level ? 'd63 : 'd31;

assign fft_cnt_start = ntt_en && (ntt_mode ? seq_cnt_almost_finish : start );
assign fft_cnt_en = ntt_en;

assign ntt_avn0_ren = ntt_en && ntt_busy;
assign ntt_avn1_ren = ntt_en && ntt_busy;
assign ntt_bvn0_ren = ntt_en && ntt_busy;
assign ntt_bvn1_ren = ntt_en && ntt_busy;

assign ntt_avn0 = cnt_sel ? (fft_cnt_idx1) : ({seq_cnt_val,1'b0});
assign ntt_bvn0 = cnt_sel ? (fft_cnt_idx2) : (security_level ? (8'b1000_0000|ntt_avn0) : (8'b0100_0000|ntt_avn0));
assign ntt_avn1 = cnt_sel ? (security_level ? (ntt_avn0|8'b1000_0000) : (ntt_avn0|8'b0100_0000)) : (ntt_avn0|1'b1);
assign ntt_bvn1 = cnt_sel ? (security_level ? (ntt_bvn0|8'b1000_0000) : (ntt_bvn0|8'b0100_0000)) : (ntt_bvn0|1'b1);

always_comb begin
	if (!ntt_mode) begin
		ntt_stage = fft_cnt_stage;	// let fft stage count from 1
	end
	else if (!cnt_sel) begin
		ntt_stage = 'd0;
	end else begin
		ntt_stage = fft_cnt_stage;
	end
end

dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY+`BFU_PIPE_STAGES)
) u_dffre_pipe_ntt_finish (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(fft_cnt_finish),
	.q(ntt_finish) 
);

// permutation network
logic out_permut_flop;
logic out_permut_flop_ntt;
logic out_permut_flop_fft;
logic out_permut_flop_thres;
assign out_permut_flop_thres = security_level ? (ntt_stage==7) : (ntt_stage==6);
assign ntt_in_permut_sel = 1'b0;
dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY+`BFU_PIPE_STAGES-1)	// -1 because it needs one cycle to set permut_sel
) u_dffre_pipe_ntt_out_permut_sel (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(out_permut_flop_thres),
	.q(out_permut_flop_ntt) 
);
dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY + `BFU_PIPE_STAGES-2 -1)
) u_dffre_pipe_fft_out_permut_sel (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(out_permut_flop_thres),
	.q(out_permut_flop_fft) 
);
assign out_permut_flop = ntt_mode ? out_permut_flop_ntt : out_permut_flop_fft;
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn || ntt_start) begin
		ntt_out_permut_sel <= 1'b1;
	end
	else if ((ntt_out_permut_sel==1'b1) && out_permut_flop) begin
		ntt_out_permut_sel <= 1'b0;
	end
end

endmodule

