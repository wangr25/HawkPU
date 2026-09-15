`include "../defines/defines.sv"

module control_top (

	input wire clk,
	input wire rstn,
	input wire security_level,
	input wire sys_mode,	// 0-sign, 1-vrfy
	input wire sys_init,
	input wire sys_start,
	output logic sys_finish,

	// taskcode
	output logic [`TC_W-1:0] taskcode_dg_o,
	output logic [`TC_W-1:0] taskcode_code_o,
	output logic [`TC_W-1:0] taskcode_bfu_o,
	output logic [`TC_W-1:0] taskcode_bfu_1_o,
	output logic [`TC_W-1:0] taskcode_gf2_o,
	output logic [`TC_W-1:0] taskcode_fmt_o,
	output logic taskcode_vld_o,

	// to buffer_top
	output logic buffer_r_mode,
	output logic buffer_w_mode,

	// to bus
	// 000-from code
	// 001-from data_gen
	// 010-from gf2
	// 011-from BFU
	// 101-from fmt
	output logic [2:0] buf_write_sel,
	output logic [2:0] buf_cmd_sel,		

	input wire code_flag,
	input wire code_finish,

	input  wire  dg_finish,
	input  wire  gf2_finish,
	input  wire  bfu_finish,
	input  wire  fmt_finish,
	input  wire  vrfy_finish

);

logic sys_en;
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) sys_en <= 1'b0;
	else if (sys_start) sys_en <= 1'b1;
	else if (sys_finish) sys_en <= 1'b0;
end

logic task_encdec;
logic task_dg;
logic task_gf2;
logic task_bfu;
logic task_fmt;

assign task_encdec = taskcode_code_o[2:0] == 3'b000;
assign task_dg     = taskcode_dg_o  [2:0] == 3'b001;
assign task_gf2    = taskcode_gf2_o [2:0] == 3'b010;
assign task_bfu    = taskcode_bfu_o [2:0] == 3'b011;
assign task_fmt    = taskcode_fmt_o [2:0] == 3'b101;
////////////////////////////////////////////////////////////

logic calc_finish;  // one of the modules finished
logic fetch_en;  // pulse
logic [`TC_W-1:0] fetch_taskcode;
logic fetch_taskcode_vld;  // pulse
logic fetch_cond;

assign calc_finish = 
		(code_finish && task_encdec)
		|	( dg_finish && task_dg )
		|	( gf2_finish && task_gf2 )
		|	( bfu_finish && task_bfu )
		|	( fmt_finish && task_fmt )
		|   vrfy_finish
;

assign fetch_cond = (calc_finish==1'b1) || (sys_start==1'b1) || (sys_finish==1'b1);

// gen pulse
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) fetch_en <= 1'b0;
	else if (fetch_en==1'b1) fetch_en <= 1'b0;
	else if (fetch_cond) fetch_en <= 1'b1;
end

task_fetcher u_task_fetcher
(
	.clk,
	.rstn,
	.fetch_en,
	.sys_mode,
	.sys_init,
	.security_level,
	.sys_finish,
	.taskcode(fetch_taskcode),
	.taskcode_vld(fetch_taskcode_vld)
);

localparam taskcode_pipe_cycles = 1;

dffe_pipe #(
	.WIDTH(`TC_W),
	.DELAY(taskcode_pipe_cycles)
) u_dffe_pipe_taskcode_datagen (
	.clk,
	.en(1'b1),
	.d(fetch_taskcode),
	.q(taskcode_dg_o)
);

dffe_pipe #(
	.WIDTH(`TC_W),
	.DELAY(taskcode_pipe_cycles)
) u_dffe_pipe_taskcode_code (
	.clk,
	.en(1'b1),
	.d(fetch_taskcode),
	.q(taskcode_code_o)
);

dffe_pipe #(
	.WIDTH(`TC_W),
	.DELAY(taskcode_pipe_cycles)
) u_dffe_pipe_taskcode_bfu (
	.clk,
	.en(1'b1),
	.d(fetch_taskcode),
	.q(taskcode_bfu_o)
);
dffe_pipe #(
	.WIDTH(`TC_W),
	.DELAY(taskcode_pipe_cycles)
) u_dffe_pipe_taskcode_bfu_1 (
	.clk,
	.en(1'b1),
	.d(fetch_taskcode),
	.q(taskcode_bfu_1_o)
);
dffe_pipe #(
	.WIDTH(`TC_W),
	.DELAY(taskcode_pipe_cycles)
) u_dffe_pipe_taskcode_gf2 (
	.clk,
	.en(1'b1),
	.d(fetch_taskcode),
	.q(taskcode_gf2_o)
);

dffe_pipe #(
	.WIDTH(`TC_W),
	.DELAY(taskcode_pipe_cycles)
) u_dffe_pipe_taskcode_fmt (
	.clk,
	.en(1'b1),
	.d(fetch_taskcode),
	.q(taskcode_fmt_o)
);

dffre_pipe #(
	.WIDTH(1),
	.DELAY(taskcode_pipe_cycles)
) u_dffre_pipe_taskcode_vld (
	.clk,
	.rstn,
	.en(1'b1),
	.d(fetch_taskcode_vld),
	.q(taskcode_vld_o)
);

// one of the output taskcode
logic [`TC_W-1:0] taskcode_1;
assign taskcode_1 = taskcode_gf2_o;

//----------------------------------------------------------
// system bus: buf_write_sel, buf_cmd_sel
//----------------------------------------------------------

always_comb begin
	case (taskcode_1[2:0])
		3'b000: begin
			buf_write_sel = 'b000;
			buf_cmd_sel   = 'b000;
		end
		3'b001: begin
			buf_write_sel = 'b001;
			buf_cmd_sel   = 'b001;
		end
		3'b010: begin
			buf_write_sel = 'b010;
			buf_cmd_sel   = 'b010;
		end
		3'b011: begin
			buf_write_sel = 'b011;
			buf_cmd_sel   = 'b011;
		end
		3'b101: begin
			buf_write_sel = 'b101;
			buf_cmd_sel   = 'b101;
		end
		default: begin
			buf_write_sel = 'b011;
			buf_cmd_sel   = 'b011;
		end
	endcase
end

//------------------------------------------
// buffer r/w mode
//------------------------------------------

always_comb begin
	buffer_r_mode = 1'b1;	// poly mapping
	buffer_w_mode = 1'b1;	// poly mapping
	unique case (1'b1)
		task_gf2: begin
			buffer_r_mode = 1'b0;
			buffer_w_mode = 1'b0;
		end
		default: begin
			buffer_r_mode = 1'b1;
			buffer_w_mode = 1'b1;
		end
	endcase
end

//------------------------------------------
wire task_sys_ctrl = taskcode_1[2:0]=='d4;
wire [2:0] sys_ctrl_subop = taskcode_1[5:3];

wire sys_finish_cond = task_sys_ctrl && (sys_ctrl_subop=='d0) ;  // task_finish
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) sys_finish <= 1'b0;
	else if (sys_finish_cond) sys_finish <= 1'b1;
	else sys_finish <= 1'b0;
end


endmodule
