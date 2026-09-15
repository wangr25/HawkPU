`include "../defines/defines.sv"

// control logic for mmac (using BFU and msum)
// generates vec_num, seq_counter is reused
module mmac_control (
	input wire clk,
	input wire rstn,
	input wire security_level,
	// from control_top
	input wire mmac_ctrl_start,
	input wire mmac_ctrl_en,
	// to and from counter_seq
	output logic seq_cnt_start,
	output logic seq_cnt_en,	
	output logic [6:0] seq_cnt_max,
	input wire [6:0] seq_cnt_val,
	input wire seq_cnt_almost_finish,
	input wire seq_cnt_finish,
	// mmac_control output
	// to FIFO
	output logic [`VEC_NUM_WIDTH-1:0] mmac_avn0,
	output logic [`VEC_NUM_WIDTH-1:0] mmac_bvn0,
	output logic [`VEC_NUM_WIDTH-1:0] mmac_avn1,
	output logic [`VEC_NUM_WIDTH-1:0] mmac_bvn1,
	// to buffer
	output logic mmac_avn0_ren,
	output logic mmac_bvn0_ren,
	output logic mmac_avn1_ren,
	output logic mmac_bvn1_ren,
	// to bfu
	output logic mmac_avn0_vld,
	output logic mmac_bvn0_vld,
	output logic mmac_avn1_vld,
	output logic mmac_bvn1_vld,
	// to control_top
	output logic mmac_finish,
	output logic mmac_busy
);

logic start;
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		start <= 1'b0; 
	end else if (mmac_ctrl_en && mmac_ctrl_start) begin
		start <= 1'b1;
	end else if (mmac_ctrl_en && (start == 1'b1)) begin
		start <= 1'b0;
	end
end

assign seq_cnt_start = start;
assign seq_cnt_en    = mmac_ctrl_en;
assign seq_cnt_max   = security_level ? 'd63 : 'd31;

// hawk512
// avn: (0,1),(2,3),...,(62,63)
// bvn: (127,126),(125,124),...,(65,64)
// hawk1024
// avn: (0,1),(2,3),...,(126,127)
// bvn: (255,254),(253,252),...,(129,128)
assign mmac_avn0 = {seq_cnt_val, 1'b0};
assign mmac_avn1 = {seq_cnt_val, 1'b1};
assign mmac_bvn0 = mmac_bvn1 | 1'b1;
assign mmac_bvn1 = (security_level ? 'd254:'d126) - {seq_cnt_val,1'b0};

localparam mmac_pipe_stages = `BUFF_RD_LATENCY+`BFU_PIPE_STAGES+1;
dffre_pipe #(
	.WIDTH(1),
	.DELAY(mmac_pipe_stages)
) u_dffre_pipe_mmac_finish (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(seq_cnt_finish),
	.q(mmac_finish) 
);

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		mmac_busy <= 1'b0;
	end else if (mmac_ctrl_en && start) begin
		mmac_busy <= 1'b1;
	end else if (mmac_busy && seq_cnt_almost_finish) begin
		mmac_busy <= 1'b0;
	end
end

dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY)
) u_dffre_pipe_mmac_vn_vld_i (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(mmac_avn0_ren),
	.q(mmac_avn0_vld) 
);
assign mmac_bvn0_vld = mmac_avn0_vld;
assign mmac_avn1_vld = mmac_avn0_vld;
assign mmac_bvn1_vld = mmac_avn0_vld;

assign mmac_avn0_ren = mmac_ctrl_en && mmac_busy;
assign mmac_avn1_ren = mmac_ctrl_en && mmac_busy;
assign mmac_bvn0_ren = mmac_ctrl_en && mmac_busy;
assign mmac_bvn1_ren = mmac_ctrl_en && mmac_busy;

endmodule

