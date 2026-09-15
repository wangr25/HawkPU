`include "../defines/defines.sv"

// intt and ifft control logic
// counters are reused
module intt_control (
	input wire clk,
	input wire rstn,
	input wire security_level,
	// from control_top
	input wire intt_mode,	// 1-intt 0-ifft
	input wire intt_start,
	input wire intt_en,
	// to and from counter_seq
	output logic seq_cnt_start,
	output logic seq_cnt_en,	
	output logic [6:0] seq_cnt_max,
	input wire [6:0] seq_cnt_val,
	input wire seq_cnt_almost_finish,
	input wire seq_cnt_finish,
	// to and from counter_ifft
	output logic ifft_cnt_start,
	output logic ifft_cnt_en,
	input wire [6:0] ifft_cnt_idx1,
	input wire [6:0] ifft_cnt_idx2,
	input wire [3:0] ifft_cnt_stage,
	input wire ifft_cnt_almost_finish,
	input wire ifft_cnt_finish,
	input wire ifft_cnt_busy,
	// intt_control output
	output logic [3:0] intt_stage,
	output logic [`VEC_NUM_WIDTH-1:0] intt_avn0,
	output logic [`VEC_NUM_WIDTH-1:0] intt_bvn0,
	output logic [`VEC_NUM_WIDTH-1:0] intt_avn1,
	output logic [`VEC_NUM_WIDTH-1:0] intt_bvn1,
	output logic intt_avn0_ren,
	output logic intt_bvn0_ren,
	output logic intt_avn1_ren,
	output logic intt_bvn1_ren,
	output logic intt_avn0_vld,
	output logic intt_bvn0_vld,
	output logic intt_avn1_vld,
	output logic intt_bvn1_vld,
	output logic intt_finish,
	output logic intt_busy,
	output logic intt_in_permut_sel,
	output logic intt_out_permut_sel
);

logic start;
logic cnt_sel;	// 0-counter_seq, 1-counter_ifft

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		cnt_sel <= 1'b1; 
	end
	else if (intt_en && intt_start) begin
		cnt_sel <= 1'b1; 
	end
	else if (intt_mode) begin	// intt
		if (intt_en && ifft_cnt_almost_finish && (cnt_sel==1'b1)) begin
			cnt_sel <= 1'b0;
		end
	end
end

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		start <= 1'b0; 
	end else if (intt_en && intt_start) begin
		start <= 1'b1;
	end else if (intt_en && (start == 1'b1)) begin
		start <= 1'b0;
	end
end

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		intt_busy <= 1'b0;
	end else if (intt_en && start) begin
		intt_busy <= 1'b1;
	end else begin
		case (intt_mode)
		1'b1: begin //intt
			if (intt_en && seq_cnt_almost_finish) begin
				intt_busy <= 1'b0;
			end
		end
		1'b0: begin //ifft
			if (intt_en && ifft_cnt_almost_finish) begin
				intt_busy <= 1'b0;
			end
		end
		endcase
	end
end

// 250707
dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY)
) u_dffre_pipe_intt_vn_vld_i (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(intt_avn0_ren),
	.q(intt_avn0_vld) 
);
assign intt_bvn0_vld = intt_avn0_vld;
assign intt_avn1_vld = intt_avn0_vld;
assign intt_bvn1_vld = intt_avn0_vld;

assign seq_cnt_start = (intt_en && intt_mode) ? ifft_cnt_almost_finish : 1'b0;
assign seq_cnt_en = intt_mode ? intt_en : 1'b0;
assign seq_cnt_max = security_level ? 'd63 : 'd31;

assign ifft_cnt_start = intt_en && start;
assign ifft_cnt_en = intt_en;

assign intt_avn0_ren = intt_en && intt_busy;
assign intt_avn1_ren = intt_en && intt_busy;
assign intt_bvn0_ren = intt_en && intt_busy;
assign intt_bvn1_ren = intt_en && intt_busy;

assign intt_avn0 = cnt_sel ? (ifft_cnt_idx1) : ({seq_cnt_val,1'b0});
assign intt_bvn0 = cnt_sel ? (ifft_cnt_idx2) : (security_level ? (8'b1000_0000|intt_avn0) : (8'b0100_0000|intt_avn0));
assign intt_avn1 = cnt_sel ? (security_level ? (intt_avn0|8'b1000_0000) : (intt_avn0|8'b0100_0000)) : (intt_avn0|1'b1);
assign intt_bvn1 = cnt_sel ? (security_level ? (intt_bvn0|8'b1000_0000) : (intt_bvn0|8'b0100_0000)) : (intt_bvn0|1'b1);

always_comb begin
	if (!intt_mode) begin // ifft
		intt_stage = ifft_cnt_stage;	// ifft stage count from 8/9
	end
	else if (cnt_sel) begin // intt stage > 0, use ifft cnt stage
		intt_stage = ifft_cnt_stage;
	end else begin // intt stage = 0
		intt_stage = 'd0;
	end
end

logic intt_finish_m;
assign intt_finish_m = intt_mode ? seq_cnt_finish : ifft_cnt_finish;
dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY+`BFU_PIPE_STAGES)
) u_dffre_pipe_intt_finish (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(intt_finish_m),
	.q(intt_finish) 
);

// permutation network
logic permut_flop;
logic permut_flop_intt;
logic permut_flop_ifft;
logic permut_flop_thres;
assign permut_flop_thres = security_level ? (intt_stage==6) : (intt_stage==5);
dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY-1)
) u_dffre_pipe_intt_permut_sel (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(permut_flop_thres),
	.q(permut_flop_intt) 
);
dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY-1)
) u_dffre_pipe_ifft_permut_sel (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(permut_flop_thres),
	.q(permut_flop_ifft) 
);
assign permut_flop = intt_mode ? permut_flop_intt : permut_flop_ifft;

assign intt_out_permut_sel = 1'b1;
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn || intt_start) begin
		intt_in_permut_sel <= 1'b1;
	end
	else if ((intt_in_permut_sel==1'b1) && permut_flop) begin
		intt_in_permut_sel <= 1'b0;
	end
end

endmodule


