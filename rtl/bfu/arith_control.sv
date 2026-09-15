`include "../defines/defines.sv"

// arith control logic for (m)add/sub/mul (using BFU)
// generates vec_num, seq_counter is reused
module arith_control (
	input wire clk,
	input wire rstn,
	input wire security_level,
	// from control_top
	input wire arith_start,
	input wire arith_en,
	// to and from counter_seq
	output logic seq_cnt_start,
	output logic seq_cnt_en,	
	output logic [6:0] seq_cnt_max,
	input wire [6:0] seq_cnt_val,
	input wire seq_cnt_almost_finish,
	input wire seq_cnt_finish,
	// arith_control output
	// to FIFO
	output logic [`VEC_NUM_WIDTH-1:0] arith_avn0,
	output logic [`VEC_NUM_WIDTH-1:0] arith_bvn0,
	output logic [`VEC_NUM_WIDTH-1:0] arith_avn1,
	output logic [`VEC_NUM_WIDTH-1:0] arith_bvn1,
	// to buffer
	output logic arith_avn0_ren,
	output logic arith_bvn0_ren,
	output logic arith_avn1_ren,
	output logic arith_bvn1_ren,
	// to bfu
	output logic arith_avn0_vld,
	output logic arith_bvn0_vld,
	output logic arith_avn1_vld,
	output logic arith_bvn1_vld,
	// to control_top
	output logic arith_finish,
	output logic arith_busy
);

logic start;
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		start <= 1'b0; 
	end else if (arith_en && arith_start) begin
		start <= 1'b1;
	end else if (arith_en && (start == 1'b1)) begin
		start <= 1'b0;
	end
end

assign seq_cnt_start = start;
assign seq_cnt_en    = arith_en;
assign seq_cnt_max   = security_level ? 'd127 : 'd63;

assign arith_avn0 = seq_cnt_val;
assign arith_bvn0 = arith_avn0;
assign arith_avn1 = security_level ? (seq_cnt_val | 8'b1000_0000) : (seq_cnt_val | 7'b100_0000);
assign arith_bvn1 = arith_avn1;

dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY+`BFU_PIPE_STAGES)
) u_dffre_pipe_arith_finish (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(seq_cnt_finish),
	.q(arith_finish) 
);

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		arith_busy <= 1'b0;
	end else if (arith_en && start) begin
		arith_busy <= 1'b1;
	end else if (arith_busy && seq_cnt_almost_finish) begin
		arith_busy <= 1'b0;
	end
end

dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY)
) u_dffre_pipe_arith_vn_vld_i (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(arith_avn0_ren),
	.q(arith_avn0_vld) 
);
assign arith_bvn0_vld = arith_avn0_vld;
assign arith_avn1_vld = arith_avn0_vld;
assign arith_bvn1_vld = arith_avn0_vld;

assign arith_avn0_ren = arith_en && arith_busy;
assign arith_avn1_ren = arith_en && arith_busy;
assign arith_bvn0_ren = arith_en && arith_busy;
assign arith_bvn1_ren = arith_en && arith_busy;

endmodule
