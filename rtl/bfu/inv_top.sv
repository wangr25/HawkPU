`include "../defines/defines.sv"

module inv_top (
	input wire clk,
	input wire rstn,
	input wire security_level,

    // taskcode
    input wire [`TC_W-1:0] taskcode,
    input wire taskcode_vld,

	// 
	output logic inv_finish,

    // read buffer
    output logic inv_a_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] inv_a_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    inv_r_avn0,
	input  logic [`VEC_BITS-1:0] inv_r_av0,
    output logic inv_avn0_ren,

    // write buffer
    output logic inv_a_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] inv_a_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    inv_w_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    inv_w_avn1,
	output logic [`VEC_BITS-1:0] inv_w_av0,
	output logic [`VEC_BITS-1:0] inv_w_av1,
    output logic inv_avn0_wen,
    output logic inv_avn1_wen

);

wire task_bfu  = taskcode[2:0] == 3'b011;
wire task_inv  = task_bfu && (taskcode[26:23] == 'd13);
wire polyqround = taskcode[50];


logic inv_start;
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) inv_start <= 1'b0;
	else if (inv_start==1'b1) inv_start <= 1'b0;
	else if (taskcode_vld && task_inv) inv_start <= 1'b1;
end

localparam M=31;
localparam N=32;
localparam inv_stages = 2*M;
localparam inv_rd_latency = `BUFF_RD_LATENCY + 1;

logic in_sel;

logic [M-1:0] x_in;
logic [N-1:0] q_out;
logic inv_vld_i;
logic inv_vld_o;

// read counter
localparam cnt_BW = 10;
logic rd_cnt_start;
logic [cnt_BW-1:0] rd_num;
logic rd_cnt_run;
logic [cnt_BW-1:0] rd_cnt;
logic rd_cnt_en;
logic rd_cnt_last;
logic rd_cnt_done;
// rd en cnt
localparam cnt_i_BW = 6;  // 0-31
logic rd_cnt_i_start;
logic [cnt_i_BW-1:0] rd_cnt_i_num;
logic rd_cnt_i_run;
logic [cnt_i_BW-1:0] rd_cnt_i;
logic rd_cnt_i_en;
logic rd_cnt_i_last;
logic rd_cnt_i_done;
logic rd_cnt_i_done_d2;
// counter that waits for the round to finish
localparam cnt_j_BW = 6;  // 0-31
logic rd_cnt_j_start;
logic [cnt_j_BW-1:0] rd_cnt_j_num;
logic rd_cnt_j_run;
logic [cnt_j_BW-1:0] rd_cnt_j;
logic rd_cnt_j_en;
logic rd_cnt_j_last;
logic rd_cnt_j_done;

assign rd_cnt_start = inv_start;
assign rd_num = security_level ? 512 : 256;
assign rd_cnt_run = inv_avn0_ren;
  counter_ce #(
    .BW(cnt_BW)
  ) u_rd_cnt (
    .clk,
    .rst_n(rstn),
    .start (rd_cnt_start),
    .num   (rd_num),
    .run   (rd_cnt_run),
    .cnt   (rd_cnt),
    .cnt_en(rd_cnt_en),
    .last  (rd_cnt_last),
    .done  (rd_cnt_done)
  );

assign rd_cnt_i_start = inv_start || (rd_cnt_j_done && rd_cnt_en);
assign rd_cnt_i_num = 32;
assign rd_cnt_i_run = 1'b1;
  counter_ce #(
    .BW(cnt_i_BW)
  ) u_rd_cnt_i (
    .clk,
    .rst_n(rstn),
    .start (rd_cnt_i_start),
    .num   (rd_cnt_i_num),
    .run   (rd_cnt_i_run),
    .cnt   (rd_cnt_i),
    .cnt_en(rd_cnt_i_en),
    .last  (rd_cnt_i_last),
    .done  (rd_cnt_i_done)
  );

assign rd_cnt_j_start = rd_cnt_i_done_d2;
assign rd_cnt_j_num = 32;
assign rd_cnt_j_run = 1'b1;
  counter_ce #(
    .BW(cnt_j_BW)
  ) u_rd_cnt_j (
    .clk,
    .rst_n(rstn),
    .start (rd_cnt_j_start),
    .num   (rd_cnt_j_num),
    .run   (rd_cnt_j_run),
    .cnt   (rd_cnt_j),
    .cnt_en(rd_cnt_j_en),
    .last  (rd_cnt_j_last),
    .done  (rd_cnt_j_done)
  );

assign in_sel = rd_cnt_j_en;

dffre_pipe #(
	.WIDTH(1),
	.DELAY(inv_rd_latency)
) u_dffre_pipe_inv_cnt_i_done_delay (
	.clk,
	.rstn,
	.en(task_inv),
	.d(rd_cnt_i_done),
	.q(rd_cnt_i_done_d2)
);

// write counter
logic wr_cnt_start;
logic [cnt_BW-1:0] wr_num;
logic wr_cnt_run;
logic [cnt_BW-1:0] wr_cnt;  // counter value
logic wr_cnt_en;
logic wr_cnt_last;
logic wr_cnt_done;
assign wr_cnt_start = inv_start;
assign wr_num = security_level ? 512 : 256;
assign wr_cnt_run = inv_vld_o;
  counter_ce #(
    .BW(cnt_BW)
  ) u_wr_cnt (
    .clk,
    .rst_n(rstn),
    .start (wr_cnt_start),
    .num   (wr_num),
    .run   (wr_cnt_run),
    .cnt   (wr_cnt),
    .cnt_en(wr_cnt_en),
    .last  (wr_cnt_last),
    .done  (wr_cnt_done)
  );

// input mux
logic inv_ren_delay;
logic [1:0] in_sel_cnt;
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) in_sel_cnt <= 'd0;
	else if (inv_ren_delay) in_sel_cnt <= in_sel_cnt + 'd1;
end
always_ff @(posedge clk) begin
	if (task_inv) begin
		case (in_sel_cnt)
			'd0: x_in <= inv_r_av0[1*32-1-:32];
			'd1: x_in <= inv_r_av0[2*32-1-:32];
			'd2: x_in <= inv_r_av0[3*32-1-:32];
			'd3: x_in <= inv_r_av0[4*32-1-:32];
		endcase
	end
end

assign inv_a_r_mapping_mode = taskcode[21];
assign inv_a_base_raddr     = taskcode[11: 3];
assign inv_a_base_waddr     = taskcode[61:53];
assign inv_a_w_mapping_mode = taskcode[62];

assign inv_avn0_ren = rd_cnt_i_en;
assign inv_r_avn0 = rd_cnt>>2;

assign inv_avn0_wen = (wr_cnt[1:0]==2'b11) && inv_vld_o;
assign inv_avn1_wen = inv_avn0_wen;
assign inv_w_avn0 = wr_cnt>>2;
assign inv_w_avn1 = (security_level ? 'd255 : 'd127) - inv_w_avn0;

logic [N-1:0] wr_buff[4];
always_ff @(posedge clk) begin
	wr_buff[wr_cnt[1:0]] <= q_out;
end
assign inv_w_av0 = {q_out,wr_buff[2],wr_buff[1],wr_buff[0]};
assign inv_w_av1 = {inv_w_av0[1*32-1-:32], inv_w_av0[2*32-1-:32], inv_w_av0[3*32-1-:32], inv_w_av0[4*32-1-:32]};

dffre_pipe #(
	.WIDTH(1),
	.DELAY(inv_rd_latency-1)
) u_dffre_pipe_inv_ren_delay (
	.clk,
	.rstn,
	.en(1'b1),
	.d(inv_avn0_ren),
	.q(inv_ren_delay)
);
dffre_pipe #(
	.WIDTH(1),
	.DELAY(inv_rd_latency)
) u_dffre_pipe_inv_vld_i (
	.clk,
	.rstn,
	.en(1'b1),
	.d(inv_avn0_ren),
	.q(inv_vld_i)
);
dffe_pipe #(
	.WIDTH(1),
	.DELAY(inv_stages+1)
) u_dffre_pipe_inv_stages (
	.clk,
	.en(1'b1),
	.d(inv_vld_i),
	.q(inv_vld_o)
);

hawk_inv_2round_datapath #(
	.M(M),
	.N(N),
	.B1(`P1),
	.B2(`P2)
) u_inv_datapath (
	.clk,
	.en(task_inv),  // 
	.x_in(x_in),
	.B_mode(polyqround),
	.in_sel(in_sel),
	.q_out(q_out)
);

dffre_pipe #(
	.WIDTH(1),
	.DELAY(1)
) u_dffre_pipe_inv_finish (
	.clk,
	.rstn,
	.en(1'b1),
	.d(wr_cnt_done),
	.q(inv_finish)
);

//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////


endmodule
