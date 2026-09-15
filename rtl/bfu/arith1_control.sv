`include "../defines/defines.sv"

// arith control logic for h-w (using BFU)
// where h is a string, w is vector
// generates vec_num, seq_counter is reused
module arith1_control (
	input wire clk,
	input wire rstn,
	input wire security_level,
	// from control_top
	input wire arith1_start,
	input wire arith1_en,
	input wire [1:0] bfu_str_banknum,
	input wire [`ADDR_WIDTH-1:0] str_base_raddr,
	// to and from counter_seq
	output logic seq_cnt_start,
	output logic seq_cnt_en,	
	output logic [6:0] seq_cnt_max,
	input wire [6:0] seq_cnt_val,
	input wire seq_cnt_almost_finish,
	input wire seq_cnt_finish,
	// arith1_control output
	// to FIFO
	output logic [`VEC_NUM_WIDTH-1:0] arith1_bvn0,
	output logic [`VEC_NUM_WIDTH-1:0] arith1_bvn1,
	// to buffer
	output logic [`VEC_NUM_WIDTH-1:0] arith1_avn0,
	output logic [`VEC_NUM_WIDTH-1:0] arith1_avn1,
	output logic [`ADDR_WIDTH-1:0] arith1_read_str_addr,
	output logic arith1_avn0_ren,
	output logic arith1_bvn0_ren,
	output logic arith1_avn1_ren,
	output logic arith1_bvn1_ren,
	// to bfu
	output logic arith1_avn0_vld,
	output logic arith1_bvn0_vld,
	output logic arith1_avn1_vld,
	output logic arith1_bvn1_vld,
	// to control_top
	output logic bfu_load_str,
	output logic arith1_finish,
	output logic arith1_busy
);

  typedef enum logic [6:0] {
	st_idle								= 'd0,
	st_read_str,
	//st_load_str,
	st_read_poly,
	st_finish
  } state_e;
  state_e arith1_state, arith1_next_state;

// FSM
always @(posedge clk or negedge rstn) begin
	if (!rstn) arith1_state <= st_idle;
	else arith1_state <= arith1_next_state;
end

//-------------------------------
// gen next_state
//-------------------------------
always_comb begin
	arith1_next_state = arith1_state;
	case (arith1_state)
		st_idle: if (arith1_start) arith1_next_state = st_read_str;
		st_read_str: if (bfu_load_str) arith1_next_state = st_read_poly;
		st_read_poly: begin
			if (seq_cnt_almost_finish) arith1_next_state = st_finish;
			else if (seq_cnt_val[3:0]==4'b1111) arith1_next_state = st_read_str;
		end
		st_finish: arith1_next_state = st_idle;
	endcase
end

//-------------------------------
// gen output
//-------------------------------

assign seq_cnt_start = arith1_start;
assign seq_cnt_en    = arith1_state == st_read_poly;
assign seq_cnt_max   = security_level ? 'd127 : 'd63;

always_comb begin
	arith1_avn0 = 'd0;
	case (bfu_str_banknum)
		2'd0: arith1_avn0 = 'd0;
		2'd1: arith1_avn0 = 'd1;
		2'd2: arith1_avn0 = security_level ? 'd128 : 'd64;
		2'd3: arith1_avn0 = security_level ? 'd129 : 'd65;
	endcase
end

assign arith1_avn1 = 'd0;
assign arith1_bvn0 = {seq_cnt_val,1'b0};
assign arith1_bvn1 = {seq_cnt_val,1'b1};

dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY+`BFU_PIPE_STAGES)
) u_dffre_pipe_arith1_finish (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(arith1_state==st_finish),
	.q(arith1_finish) 
);

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		arith1_busy <= 1'b0;
	end else if (arith1_en && arith1_start) begin
		arith1_busy <= 1'b1;
	end else if (arith1_busy && seq_cnt_almost_finish) begin
		arith1_busy <= 1'b0;
	end
end

// use port avn0 to read string
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) arith1_avn0_ren <= 1'b0;
	else if (arith1_avn0_ren==1'b1) arith1_avn0_ren <= 1'b0;
	else if (arith1_next_state==st_read_str) arith1_avn0_ren <= 1'b1;
end
assign arith1_avn1_ren = 1'b0;
assign arith1_bvn0_ren = arith1_state==st_read_poly;
assign arith1_bvn1_ren = arith1_bvn0_ren;

dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY)
) u_dffre_pipe_arith1_vn_vld_i (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(arith1_bvn0_ren),
	.q(arith1_bvn0_vld) 
);
assign arith1_bvn1_vld = arith1_bvn0_vld;

dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY)
) u_dffre_pipe_arith1_str_load (
	.clk(clk),
	.rstn(rstn),
	.en(1'b1),
	.d(arith1_avn0_ren),
	.q(bfu_load_str) 
);
// when read string, should not enable bfu core
assign arith1_avn0_vld = 1'b0;
assign arith1_avn1_vld = 1'b0;

always_ff @(posedge clk) begin
	if (arith1_start) arith1_read_str_addr <= str_base_raddr;
	else if ((arith1_state==st_read_str) && (arith1_next_state==st_read_poly)) arith1_read_str_addr <= arith1_read_str_addr + 'd1;
end

endmodule
