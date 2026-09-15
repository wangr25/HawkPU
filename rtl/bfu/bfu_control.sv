`include "../defines/defines.sv"

module bfu_control
(
    input wire clk,
	input wire rstn,
	input wire security_level,
	input wire sys_mode,	// 0-sign, 1-vrfy
	input wire sys_init,

    // taskcode
    input wire [`TC_W-1:0] taskcode,
    input wire [`TC_W-1:0] taskcode_1,
    input wire taskcode_vld,

	// from BFU
	input 	logic bfu_rdy,
    input   logic bfu_av0_vld_o,
    input   logic bfu_av1_vld_o,
    input   logic bfu_bv0_vld_o,
    input   logic bfu_bv1_vld_o,

	// from decoder
	input   logic [31:0] bfu_constup,

	// BFU control signals
	output 	logic polyqround,
	output 	logic [3:0] bfu_mode,
    output  logic bfu_av0_vld_i,
    output  logic bfu_av1_vld_i,
    output  logic bfu_bv0_vld_i,
    output  logic bfu_bv1_vld_i,
    output  logic bfu_load_str,
    output  logic bfu_a_str, // 0-av0/av1 is vector, 1-av0/av1 is string
    output 	logic [4:0]   a_pre_shift_len,
    output 	logic [4:0]   b_pre_shift_len,
	output 	logic in_permut_sel,
	output  logic bfu_sel_const,
	output  logic [31:0] bfu_const,
	output  logic symbreak_en,
	output  logic symbreak_calc,
	output 	logic out_permut_sel,
    output 	logic [4:0]   a_post_shift_len,
    output 	logic [4:0]   b_post_shift_len,
	output  logic post_shift_even,
	output  logic q00_0_set0,

	// to tw ROM
	output logic [10:0] tw_rom_ptr,
	output logic [1:0]  tw_rom_strb,
	output logic [1:0]  tw_rom_pat_grp,
	output logic [1:0]  tw_rom_pat_sel,
	output logic        tw_rom_ren,

	// finish
	output logic bfu_finish,

	// from msum
	input logic msum1_vld,
	input logic msum2_vld,
	input logic msum1_eq_msum2,

	// from symbreak
    input logic symbreak_result,

	// buffer interface

    // read buffer
    output logic bfu_a_r_mapping_mode,
    output logic bfu_b_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] bfu_a_base_raddr,
    output logic [`ADDR_WIDTH-1:0] bfu_b_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_r_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_r_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_r_avn1,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_r_bvn1,
    output logic bfu_avn0_ren,
    output logic bfu_bvn0_ren,
    output logic bfu_avn1_ren,
    output logic bfu_bvn1_ren,
	output logic poly_adjoint,

    // write buffer
    output logic bfu_a_w_mapping_mode,
    output logic bfu_b_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] bfu_a_base_waddr,
    output logic [`ADDR_WIDTH-1:0] bfu_b_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_w_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_w_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_w_avn1,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_w_bvn1,
    output logic bfu_avn0_wen,
    output logic bfu_bvn0_wen,
    output logic bfu_avn1_wen,
    output logic bfu_bvn1_wen

);

logic task_bfu;
logic bfu_start;
assign task_bfu  = (taskcode[2:0] == 3'b011) && (taskcode[26:23]!=`BFU_INV_MODE) && (taskcode[26:23]!=`BFU_DIV_MODE) ;
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) bfu_start <= 1'b0;
	else if (bfu_start==1'b1) bfu_start <= 1'b0;
	else if (taskcode_vld && task_bfu) bfu_start <= 1'b1;
end

assign bfu_mode       = taskcode_1[26:23];  // output
wire [3:0] bfu_mode_1 = taskcode[26:23];
assign bfu_a_str      = taskcode[28];

logic [4:0]   task_a_pre_shift_len;
logic [4:0]   task_b_pre_shift_len;
assign task_a_pre_shift_len = taskcode[33:29];
assign task_b_pre_shift_len = taskcode[38:34];

assign bfu_sel_const = taskcode[39];

logic [2:0] bfu_const_sel;
assign bfu_const_sel = taskcode[42:40];

logic [31:0] consts0;
assign consts0 = security_level ? 'd16 : 'd256;

always_comb begin
	bfu_const = 'd0;
	case (bfu_const_sel)
		'd0: bfu_const = 'd0;
		'd1: bfu_const = `P0_R2;
		'd2: bfu_const = bfu_constup;
		'd3: bfu_const = consts0;
		'd4: bfu_const = `P1_R3;
		'd5: bfu_const = `P2_R3;
	endcase
end

assign symbreak_en = taskcode[43] && task_bfu;
assign symbreak_calc = taskcode[44] && task_bfu;

assign a_post_shift_len = taskcode[49:45];
assign b_post_shift_len = a_post_shift_len;
assign polyqround = taskcode[50];

logic       [1:0]              arith1_bfu_str_banknum;
logic       [`ADDR_WIDTH-1:0]  arith1_str_base_raddr;
assign arith1_str_base_raddr  = taskcode[11: 3];
assign arith1_bfu_str_banknum = taskcode[52:51];

// buffer interface from taskcode
	logic       [`ADDR_WIDTH-1:0]    arith1_read_str_addr;

assign bfu_a_r_mapping_mode = taskcode[21];
assign bfu_b_r_mapping_mode = taskcode[22];
assign bfu_a_base_raddr     = bfu_a_str ? arith1_read_str_addr : taskcode[11: 3];
assign bfu_b_base_raddr     = taskcode[20:12];
assign bfu_a_base_waddr     = taskcode[61:53];
assign bfu_b_base_waddr     = taskcode[61:53];  // same as bfu_a_base_waddr
assign bfu_a_w_mapping_mode = taskcode[62];
assign bfu_b_w_mapping_mode = taskcode[62];     // same as bfu_a_w_mapping_mode

wire poly_adjoint_cond = taskcode[27] && task_bfu;
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) poly_adjoint <= 1'b0;
	else if (bfu_finish) poly_adjoint <= 1'b0;
	else if (poly_adjoint_cond && taskcode_vld) poly_adjoint <= 1'b1;
end

// BFU mode
wire bfu_ntt_mode       = (bfu_mode_1==`BFU_NTT_MODE       );
wire bfu_intt_mode      = (bfu_mode_1==`BFU_INTT_MODE      );
wire bfu_fft_mode       = (bfu_mode_1==`BFU_FFT_MODE       );
wire bfu_ifft_mode      = (bfu_mode_1==`BFU_IFFT_MODE      );
wire bfu_madd_mode      = (bfu_mode_1==`BFU_MADD_MODE      );
wire bfu_msub_mode      = (bfu_mode_1==`BFU_MSUB_MODE      );
wire bfu_add_mode       = (bfu_mode_1==`BFU_ADD_MODE       );
wire bfu_sub_mode       = (bfu_mode_1==`BFU_SUB_MODE       );
wire bfu_mmul_mode      = (bfu_mode_1==`BFU_MMUL_MODE      );
wire bfu_mul_mode       = (bfu_mode_1==`BFU_MUL_MODE       );
wire bfu_gf2cf_mode     = (bfu_mode_1==`BFU_GF2CF_MODE     );
wire bfu_mmac_mode      = (bfu_mode_1==`BFU_MMAC_MODE      );
wire bfu_inv_mode       = (bfu_mode_1==`BFU_INV_MODE       );
wire bfu_div_mode       = (bfu_mode_1==`BFU_DIV_MODE       );

    // counter_fft signals
    logic        fft_cnt_start;
    logic        fft_cnt_en;
    logic [6:0]  fft_cnt_idx1;
    logic [6:0]  fft_cnt_idx2;
    logic [3:0]  fft_cnt_stage;
    logic        fft_cnt_almost_finish;
    logic        fft_cnt_finish;
    logic        fft_cnt_busy;

    // counter_ifft signals
    logic        ifft_cnt_start;
    logic        ifft_cnt_en;
    logic [6:0]  ifft_cnt_idx1;
    logic [6:0]  ifft_cnt_idx2;
    logic [3:0]  ifft_cnt_stage;
    wire         ifft_cnt_almost_finish;
    logic        ifft_cnt_finish;
    logic        ifft_cnt_busy;

    // counter_seq signals
    parameter    CNT_WIDTH = 7;
    logic        seq_cnt_start;
    logic        seq_cnt_en;
    logic [CNT_WIDTH-1:0] seq_cnt_max;
    logic [CNT_WIDTH-1:0] seq_cnt_val;
    logic        seq_cnt_almost_finish;
    logic        seq_cnt_finish;

	// ntt_control signals
	logic ntt_mode;
	logic ntt_ctrl_start;
	logic ntt_ctrl_en;
    logic        ntt_seq_cnt_start;
    logic        ntt_seq_cnt_en;
    logic [CNT_WIDTH-1:0] ntt_seq_cnt_max;
    logic        ntt_fft_cnt_start;
    logic        ntt_fft_cnt_en;
	logic [3:0] ntt_stage;
	logic [`VEC_NUM_WIDTH-1:0] ntt_avn0;
	logic [`VEC_NUM_WIDTH-1:0] ntt_bvn0;
	logic [`VEC_NUM_WIDTH-1:0] ntt_avn1;
	logic [`VEC_NUM_WIDTH-1:0] ntt_bvn1;
	logic ntt_avn0_ren;
	logic ntt_bvn0_ren;
	logic ntt_avn1_ren;
	logic ntt_bvn1_ren;
	logic ntt_avn0_vld;
    logic ntt_bvn0_vld;
    logic ntt_avn1_vld;
    logic ntt_bvn1_vld;
	logic ntt_finish;
	logic ntt_busy;
	logic ntt_in_permut_sel;
	logic ntt_out_permut_sel;

	// intt_control signals
	logic intt_mode;
	logic intt_ctrl_start;
	logic intt_ctrl_en;
    logic        intt_seq_cnt_start;
    logic        intt_seq_cnt_en;
    logic [CNT_WIDTH-1:0] intt_seq_cnt_max;
    logic        intt_ifft_cnt_start;
    logic        intt_ifft_cnt_en;
	logic [3:0] intt_stage;
	logic [`VEC_NUM_WIDTH-1:0] intt_avn0;
	logic [`VEC_NUM_WIDTH-1:0] intt_bvn0;
	logic [`VEC_NUM_WIDTH-1:0] intt_avn1;
	logic [`VEC_NUM_WIDTH-1:0] intt_bvn1;
	logic intt_avn0_ren;
	logic intt_bvn0_ren;
	logic intt_avn1_ren;
	logic intt_bvn1_ren;
	logic intt_avn0_vld;
    logic intt_bvn0_vld;
    logic intt_avn1_vld;
    logic intt_bvn1_vld;
	logic intt_finish;
	logic intt_busy;
	logic intt_in_permut_sel;
	logic intt_out_permut_sel;

	// tw ROM control
	logic [1:0]  tw_rom_mode;
	logic        tw_rom_start;
	logic        tw_rom_en;

	// arith control
	logic                  arith_ctrl_start;
	logic                  arith_ctrl_en;
	logic                  arith_seq_cnt_start;
	logic                  arith_seq_cnt_en;
	logic        [6:0]     arith_seq_cnt_max;
	logic [`VEC_NUM_WIDTH-1:0] arith_avn0;
	logic [`VEC_NUM_WIDTH-1:0] arith_bvn0;
	logic [`VEC_NUM_WIDTH-1:0] arith_avn1;
	logic [`VEC_NUM_WIDTH-1:0] arith_bvn1;
	logic                  arith_avn0_ren;
	logic                  arith_bvn0_ren;
	logic                  arith_avn1_ren;
	logic                  arith_bvn1_ren;
	logic                  arith_avn0_vld;
	logic                  arith_bvn0_vld;
	logic                  arith_avn1_vld;
	logic                  arith_bvn1_vld;
	logic                  arith_finish;
	logic                  arith_busy;

	// arith1 control
	logic                          arith1_start;
	logic                          arith1_ctrl_en;
	logic                          arith1_seq_cnt_start;
	logic                          arith1_seq_cnt_en;
	logic       [6:0]              arith1_seq_cnt_max;
	logic       [`VEC_NUM_WIDTH-1:0] arith1_bvn0;
	logic       [`VEC_NUM_WIDTH-1:0] arith1_bvn1;
	logic       [`VEC_NUM_WIDTH-1:0] arith1_avn0;
	logic       [`VEC_NUM_WIDTH-1:0] arith1_avn1;
	logic                            arith1_avn0_ren;
	logic                            arith1_bvn0_ren;
	logic                            arith1_avn1_ren;
	logic                            arith1_bvn1_ren;
	logic                            arith1_avn0_vld;
	logic                            arith1_bvn0_vld;
	logic                            arith1_avn1_vld;
	logic                            arith1_bvn1_vld;
	logic                            arith1_finish;
	logic                            arith1_busy;

	// mmac control

	// from control_top
	logic mmac_ctrl_start;
	logic mmac_ctrl_en;
	logic mmac_seq_cnt_start;
	logic mmac_seq_cnt_en;
	logic [6:0] mmac_seq_cnt_max;
	logic [`VEC_NUM_WIDTH-1:0] mmac_avn0;
	logic [`VEC_NUM_WIDTH-1:0] mmac_bvn0;
	logic [`VEC_NUM_WIDTH-1:0] mmac_avn1;
	logic [`VEC_NUM_WIDTH-1:0] mmac_bvn1;
	logic mmac_avn0_ren;
	logic mmac_bvn0_ren;
	logic mmac_avn1_ren;
	logic mmac_bvn1_ren;
	logic mmac_avn0_vld;
	logic mmac_bvn0_vld;
	logic mmac_avn1_vld;
	logic mmac_bvn1_vld;
	logic mmac_finish;
	logic mmac_busy;


	// vec num FIFO
	// fifo 0~3 correspond to avn0, bvn0, avn1, bvn1
	localparam FIFO_DEPTH = `BFU_PIPE_STAGES+`BUFF_RD_LATENCY+2;		// REVIEW
	localparam FIFO_WIDTH = `VEC_NUM_WIDTH;
    logic        [3:0]fifo_en        ;
    logic        [3:0]fifo_wr_en     ;
    logic        [3:0]fifo_rd_en     ;
    logic [FIFO_WIDTH-1:0] fifo_din   [3:0];
    logic [FIFO_WIDTH-1:0] fifo_dout  [3:0];
    logic        [3:0]fifo_full      ;
    logic        [3:0]fifo_empty     ;
    logic        [3:0]fifo_almost_full  ;
    logic        [3:0]fifo_almost_empty ;
    logic [$clog2(FIFO_DEPTH):0] fifo_data_count [3:0];

//-----------------------------------------------------
// counters
//-----------------------------------------------------

    counter_fft u_counter_fft (
        .clk            (clk),
        .rstn           (rstn),
        .security_level (security_level),
        .start          (fft_cnt_start),
        .en             (fft_cnt_en),
        .idx1           (fft_cnt_idx1),
        .idx2           (fft_cnt_idx2),
        .stage          (fft_cnt_stage),
        .almost_finish  (fft_cnt_almost_finish),
        .finish         (fft_cnt_finish),
        .busy_o         (fft_cnt_busy)
    );

    counter_ifft u_counter_ifft (
        .clk            (clk),
        .rstn           (rstn),
        .security_level (security_level),
        .start          (ifft_cnt_start),
        .en             (ifft_cnt_en),
        .idx1           (ifft_cnt_idx1),
        .idx2           (ifft_cnt_idx2),
        .stage          (ifft_cnt_stage),
        .almost_finish  (ifft_cnt_almost_finish),
        .finish         (ifft_cnt_finish),
        .busy_o         (ifft_cnt_busy)
    );

    counter_seq #(
        .CNT_WIDTH(CNT_WIDTH)
    ) u_counter_seq (
        .clk        (clk),
        .rstn       (rstn),
        .start      (seq_cnt_start),
        .en         (seq_cnt_en),
        .cnt_max    (seq_cnt_max),
        .cnt        (seq_cnt_val),
        .almost_finish     (seq_cnt_almost_finish),
        .finish     (seq_cnt_finish)
    );

//-----------------------------------------------------
// sub control units
//-----------------------------------------------------

	ntt_control u_ntt_control (
		.clk(clk),
		.rstn(rstn),
		.security_level(security_level),
		.ntt_mode(ntt_mode),
		.ntt_start(ntt_ctrl_start),
		.ntt_en(ntt_ctrl_en),
		.seq_cnt_start(ntt_seq_cnt_start),
		.seq_cnt_en(ntt_seq_cnt_en),
		.seq_cnt_max(ntt_seq_cnt_max),
		.seq_cnt_val(seq_cnt_val),
		.seq_cnt_almost_finish(seq_cnt_almost_finish),
		.seq_cnt_finish(seq_cnt_finish),
		.fft_cnt_start(ntt_fft_cnt_start),
		.fft_cnt_en(ntt_fft_cnt_en),
		.fft_cnt_idx1(fft_cnt_idx1),
		.fft_cnt_idx2(fft_cnt_idx2),
		.fft_cnt_stage(fft_cnt_stage),
		.fft_cnt_almost_finish(fft_cnt_almost_finish),
		.fft_cnt_finish(fft_cnt_finish),
		.fft_cnt_busy(fft_cnt_busy),
		.ntt_stage(ntt_stage),
		.ntt_avn0(ntt_avn0),
		.ntt_bvn0(ntt_bvn0),
		.ntt_avn1(ntt_avn1),
		.ntt_bvn1(ntt_bvn1),
		.ntt_avn0_ren(ntt_avn0_ren),
		.ntt_bvn0_ren(ntt_bvn0_ren),
		.ntt_avn1_ren(ntt_avn1_ren),
		.ntt_bvn1_ren(ntt_bvn1_ren),
		.ntt_avn0_vld(ntt_avn0_vld),
		.ntt_bvn0_vld(ntt_bvn0_vld),
		.ntt_avn1_vld(ntt_avn1_vld),
		.ntt_bvn1_vld(ntt_bvn1_vld),
		.ntt_finish(ntt_finish),
		.ntt_busy(ntt_busy),
		.ntt_in_permut_sel,
		.ntt_out_permut_sel
	);
	intt_control u_intt_control (
		.clk(clk),
		.rstn(rstn),
		.security_level(security_level),
		.intt_mode(intt_mode),
		.intt_start(intt_ctrl_start),
		.intt_en(intt_ctrl_en),
		.seq_cnt_start(intt_seq_cnt_start),
		.seq_cnt_en(intt_seq_cnt_en),
		.seq_cnt_max(intt_seq_cnt_max),
		.seq_cnt_val(seq_cnt_val),
		.seq_cnt_almost_finish(seq_cnt_almost_finish),
		.seq_cnt_finish(seq_cnt_finish),
		.ifft_cnt_start(intt_ifft_cnt_start),
		.ifft_cnt_en(intt_ifft_cnt_en),
		.ifft_cnt_idx1(ifft_cnt_idx1),
		.ifft_cnt_idx2(ifft_cnt_idx2),
		.ifft_cnt_stage(ifft_cnt_stage),
		.ifft_cnt_almost_finish(ifft_cnt_almost_finish),
		.ifft_cnt_finish(ifft_cnt_finish),
		.ifft_cnt_busy(ifft_cnt_busy),
		.intt_stage(intt_stage),
		.intt_avn0(intt_avn0),
		.intt_bvn0(intt_bvn0),
		.intt_avn1(intt_avn1),
		.intt_bvn1(intt_bvn1),
		.intt_avn0_ren(intt_avn0_ren),
		.intt_bvn0_ren(intt_bvn0_ren),
		.intt_avn1_ren(intt_avn1_ren),
		.intt_bvn1_ren(intt_bvn1_ren),
		.intt_avn0_vld(intt_avn0_vld),
		.intt_bvn0_vld(intt_bvn0_vld),
		.intt_avn1_vld(intt_avn1_vld),
		.intt_bvn1_vld(intt_bvn1_vld),
		.intt_finish(intt_finish),
		.intt_busy(intt_busy),
		.intt_in_permut_sel,
		.intt_out_permut_sel
	);

// arith control
arith_control u_arith_control (
    .clk                 (clk),
    .rstn                (rstn),
    .security_level      (security_level),
    
    // from control_top
    .arith_start         (arith_ctrl_start),
    .arith_en            (arith_ctrl_en),

    // to and from counter_seq
    .seq_cnt_start         (arith_seq_cnt_start),
    .seq_cnt_en            (arith_seq_cnt_en),
    .seq_cnt_max           (arith_seq_cnt_max),
    .seq_cnt_val           (seq_cnt_val),
    .seq_cnt_almost_finish (seq_cnt_almost_finish),
    .seq_cnt_finish        (seq_cnt_finish),

    // arith_control output to FIFO
    .arith_avn0          (arith_avn0),
    .arith_bvn0          (arith_bvn0),
    .arith_avn1          (arith_avn1),
    .arith_bvn1          (arith_bvn1),

    // to buffer
    .arith_avn0_ren      (arith_avn0_ren),
    .arith_bvn0_ren      (arith_bvn0_ren),
    .arith_avn1_ren      (arith_avn1_ren),
    .arith_bvn1_ren      (arith_bvn1_ren),

    // to bfu
    .arith_avn0_vld      (arith_avn0_vld),
    .arith_bvn0_vld      (arith_bvn0_vld),
    .arith_avn1_vld      (arith_avn1_vld),
    .arith_bvn1_vld      (arith_bvn1_vld),

    // to control_top
    .arith_finish        (arith_finish),
    .arith_busy          (arith_busy)
);

arith1_control u_arith1_control (
    .clk                (clk),
    .rstn               (rstn),
    .security_level     (security_level),
    // from control_top
    .arith1_start       (arith1_start),
    .arith1_en          (arith1_ctrl_en),
    .bfu_str_banknum    (arith1_bfu_str_banknum),
    .str_base_raddr     (arith1_str_base_raddr),
    // to and from counter_seq
    .seq_cnt_start      (arith1_seq_cnt_start),
    .seq_cnt_en         (arith1_seq_cnt_en),
    .seq_cnt_max        (arith1_seq_cnt_max),
    .seq_cnt_val        (seq_cnt_val),
    .seq_cnt_almost_finish (seq_cnt_almost_finish),
    .seq_cnt_finish        (seq_cnt_finish),
    // to buffer and FIFO
    .arith1_bvn0        (arith1_bvn0),
    .arith1_bvn1        (arith1_bvn1),
    // to buffer
    .arith1_avn0        (arith1_avn0),
    .arith1_avn1        (arith1_avn1),
    .arith1_read_str_addr (arith1_read_str_addr),
    .arith1_avn0_ren    (arith1_avn0_ren),
    .arith1_bvn0_ren    (arith1_bvn0_ren),
    .arith1_avn1_ren    (arith1_avn1_ren),
    .arith1_bvn1_ren    (arith1_bvn1_ren),
    // to bfu
    .arith1_avn0_vld    (arith1_avn0_vld),
    .arith1_bvn0_vld    (arith1_bvn0_vld),
    .arith1_avn1_vld    (arith1_avn1_vld),
    .arith1_bvn1_vld    (arith1_bvn1_vld),
	.bfu_load_str,
	// to control
    .arith1_finish      (arith1_finish),
    .arith1_busy        (arith1_busy)
);

	////////////////////////////////////////////////////////////
	// twiddle factors ROM control
	////////////////////////////////////////////////////////////
	tw_rom_ctrl u_tw_rom_ctrl (
		.clk            (clk),
		.rstn           (rstn),
		.sys_mode       (sys_mode),
		.security_level (security_level),
		.tw_rom_mode    (tw_rom_mode),
		.polyqround     (polyqround),
		.tw_rom_start   (tw_rom_start),
		.tw_rom_en      (tw_rom_en),
		.tw_rom_ptr     (tw_rom_ptr),
		.tw_rom_strb    (tw_rom_strb),
		.tw_rom_pat_grp (tw_rom_pat_grp),
		.tw_rom_pat_sel (tw_rom_pat_sel)
	);

mmac_control u_mmac_control (
    .clk,
    .rstn,
    .security_level,
    .mmac_ctrl_start,
    .mmac_ctrl_en,
    .seq_cnt_start      (mmac_seq_cnt_start),
    .seq_cnt_en         (mmac_seq_cnt_en),
    .seq_cnt_max        (mmac_seq_cnt_max),
    .seq_cnt_val           (seq_cnt_val),
    .seq_cnt_almost_finish (seq_cnt_almost_finish),
    .seq_cnt_finish        (seq_cnt_finish),
    .mmac_avn0,
    .mmac_bvn0,
    .mmac_avn1,
    .mmac_bvn1,
    .mmac_avn0_ren,
    .mmac_bvn0_ren,
    .mmac_avn1_ren,
    .mmac_bvn1_ren,
    .mmac_avn0_vld,
    .mmac_bvn0_vld,
    .mmac_avn1_vld,
    .mmac_bvn1_vld,
    .mmac_finish,
    .mmac_busy
);


//----------------------------------------------------------
// vec num FIFOs
//----------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_vec_num_fifo
            fifo #(
                .DATA_WIDTH(FIFO_WIDTH),
                .DEPTH(FIFO_DEPTH),
				.ALMOST_FULL_THRESH(FIFO_DEPTH-2),
				.ALMOST_EMPTY_THRESH(2)
            ) u_fifo (
                .clk(clk),
                .rstn(rstn),
                .en(fifo_en[i]),
                .wr_en(fifo_wr_en[i]),
                .rd_en(fifo_rd_en[i]),
                .din(fifo_din[i]),

                .dout(fifo_dout[i]),
                .full(fifo_full[i]),
                .empty(fifo_empty[i]),
                .almost_full(fifo_almost_full[i]),
                .almost_empty(fifo_almost_empty[i]),
                .data_count(fifo_data_count[i])
            );
        end
    endgenerate

//----------------------------------------------------------
// counters and ntt/intt/arith control
//----------------------------------------------------------


always_comb begin
	// default value
	seq_cnt_start = 1'b0;
	seq_cnt_en = 1'b0;
	seq_cnt_max = 'd0;
	fft_cnt_start = 1'b0;
	fft_cnt_en = 1'b0;
	ntt_mode = 1'b0;
	ifft_cnt_start = 1'b0;
	ifft_cnt_en = 1'b0;
	intt_mode = 1'b0;

	if (bfu_a_str) begin
		seq_cnt_start = arith1_seq_cnt_start;
		seq_cnt_en = arith1_seq_cnt_en;
		seq_cnt_max = arith1_seq_cnt_max;
		fft_cnt_start = 1'b0;
		fft_cnt_en = 1'b0;
		ntt_mode = 1'b0;
		ifft_cnt_start = 1'b0;
		ifft_cnt_en = 1'b0;
		intt_mode = 1'b0;
	end
	else begin
		 case (1'b1)
			bfu_fft_mode: begin			// FFT
				seq_cnt_start = ntt_seq_cnt_start;
				seq_cnt_en = ntt_seq_cnt_en;
				seq_cnt_max = ntt_seq_cnt_max;
				fft_cnt_start = ntt_fft_cnt_start;
				fft_cnt_en = ntt_fft_cnt_en;
				ntt_mode = 1'b0;
				ifft_cnt_start = 1'b0;
				ifft_cnt_en = 1'b0;
				intt_mode = 1'b0;
			end
			bfu_ntt_mode: begin		// NTT p1
				seq_cnt_start = ntt_seq_cnt_start;
				seq_cnt_en = ntt_seq_cnt_en;
				seq_cnt_max = ntt_seq_cnt_max;
				fft_cnt_start = ntt_fft_cnt_start;
				fft_cnt_en = ntt_fft_cnt_en;
				ntt_mode = 1'b1;
				ifft_cnt_start = 1'b0;
				ifft_cnt_en = 1'b0;
				intt_mode = 1'b0;
			end
			bfu_ifft_mode: begin
				seq_cnt_start = intt_seq_cnt_start;
				seq_cnt_en = intt_seq_cnt_en;
				seq_cnt_max = intt_seq_cnt_max;
				fft_cnt_start = 1'b0;
				fft_cnt_en = 1'b0;
				ntt_mode = 1'b0;
				ifft_cnt_start = intt_ifft_cnt_start;
				ifft_cnt_en = intt_ifft_cnt_en;
				intt_mode = 1'b0;
			end
			bfu_intt_mode: begin
				seq_cnt_start = intt_seq_cnt_start;
				seq_cnt_en = intt_seq_cnt_en;
				seq_cnt_max = intt_seq_cnt_max;
				fft_cnt_start = 1'b0;
				fft_cnt_en = 1'b0;
				ntt_mode = 1'b0;
				ifft_cnt_start = intt_ifft_cnt_start;
				ifft_cnt_en = intt_ifft_cnt_en;
				intt_mode = 1'b1;
			end
			bfu_mmac_mode: begin
				seq_cnt_start = mmac_seq_cnt_start;
				seq_cnt_en = mmac_seq_cnt_en;
				seq_cnt_max = mmac_seq_cnt_max;
				fft_cnt_start = 1'b0;
				fft_cnt_en = 1'b0;
				ntt_mode = 1'b0;
				ifft_cnt_start = 1'b0;
				ifft_cnt_en = 1'b0;
				intt_mode = 1'b0;
			end
			default: begin
				seq_cnt_start = arith_seq_cnt_start;
				seq_cnt_en = arith_seq_cnt_en;
				seq_cnt_max = arith_seq_cnt_max;
				fft_cnt_start = 1'b0;
				fft_cnt_en = 1'b0;
				ntt_mode = 1'b0;
				ifft_cnt_start = 1'b0;
				ifft_cnt_en = 1'b0;
				intt_mode = 1'b0;
			end
		endcase
	end
end

always_comb begin
	ntt_ctrl_en    = 1'b0;	// ntt and fft control unit
	intt_ctrl_en   = 1'b0;  // intt and ifft control unit
	arith_ctrl_en  = 1'b0;
	arith1_ctrl_en = 1'b0;
	mmac_ctrl_en   = 1'b0;
	
	if (bfu_a_str) begin
		ntt_ctrl_en    = 1'b0;
		intt_ctrl_en   = 1'b0;
		arith_ctrl_en  = 1'b0;
		arith1_ctrl_en    = 1'b1;
		mmac_ctrl_en   = 1'b0;
	end
	else begin
		 case (1'b1)
			bfu_fft_mode,
			bfu_ntt_mode: begin
				ntt_ctrl_en    = 1'b1;
				intt_ctrl_en   = 1'b0;
				arith_ctrl_en  = 1'b0;
				arith1_ctrl_en = 1'b0;
				mmac_ctrl_en   = 1'b0;
			end
			bfu_ifft_mode,
			bfu_intt_mode: begin
				ntt_ctrl_en    = 1'b0;
				intt_ctrl_en   = 1'b1;
				arith_ctrl_en  = 1'b0;
				arith1_ctrl_en = 1'b0;
				mmac_ctrl_en   = 1'b0;
			end
			bfu_mmac_mode: begin
				ntt_ctrl_en    = 1'b0;
				intt_ctrl_en   = 1'b0;
				arith_ctrl_en  = 1'b0;
				arith1_ctrl_en = 1'b0;
				mmac_ctrl_en   = 1'b1;
			end
			default: begin  // REVIEW
				ntt_ctrl_en    = 1'b0;
				intt_ctrl_en   = 1'b0;
				arith_ctrl_en  = 1'b1;
				arith1_ctrl_en = 1'b0;
				mmac_ctrl_en   = 1'b0;
			end
		endcase
	end
end

// vld_i
always_comb begin
	// default value
	bfu_av0_vld_i = 1'b0;
	bfu_av1_vld_i = 1'b0;
	bfu_bv0_vld_i = 1'b0;
	bfu_bv1_vld_i = 1'b0;

	if (bfu_a_str) begin  // av0,av1 is string
		bfu_av0_vld_i = arith1_avn0_vld;
		bfu_bv0_vld_i = arith1_bvn0_vld;
		bfu_av1_vld_i = arith1_avn1_vld;
		bfu_bv1_vld_i = arith1_bvn1_vld;
	end
	else begin
		case (1'b1)
			bfu_fft_mode: begin
				bfu_av0_vld_i = ntt_avn0_vld;
				bfu_bv0_vld_i = ntt_bvn0_vld;
				bfu_av1_vld_i = ntt_avn1_vld;
				bfu_bv1_vld_i = ntt_bvn1_vld;
			end
			bfu_ntt_mode: begin
				bfu_av0_vld_i = ntt_avn0_vld;
				bfu_bv0_vld_i = ntt_bvn0_vld;
				bfu_av1_vld_i = ntt_avn1_vld;
				bfu_bv1_vld_i = ntt_bvn1_vld;
			end
			bfu_ifft_mode: begin
				bfu_av0_vld_i = intt_avn0_vld;
				bfu_bv0_vld_i = intt_bvn0_vld;
				bfu_av1_vld_i = intt_avn1_vld;
				bfu_bv1_vld_i = intt_bvn1_vld;
			end
			bfu_intt_mode: begin
				bfu_av0_vld_i = intt_avn0_vld;
				bfu_bv0_vld_i = intt_bvn0_vld;
				bfu_av1_vld_i = intt_avn1_vld;
				bfu_bv1_vld_i = intt_bvn1_vld;
			end
			bfu_mmac_mode: begin
				bfu_av0_vld_i = mmac_avn0_vld;
				bfu_bv0_vld_i = mmac_bvn0_vld;
				bfu_av1_vld_i = mmac_avn1_vld;
				bfu_bv1_vld_i = mmac_bvn1_vld;
			end
			default: begin
				bfu_av0_vld_i = arith_avn0_vld;
				bfu_bv0_vld_i = arith_bvn0_vld;
				bfu_av1_vld_i = arith_avn1_vld;
				bfu_bv1_vld_i = arith_bvn1_vld;
			end
		endcase
	end
end

// permut_sel
always_comb begin
	// default value
	in_permut_sel = 1'b0;
	out_permut_sel = 1'b1;

	case (1'b1)
		bfu_fft_mode: begin
			in_permut_sel  = ntt_in_permut_sel;
			out_permut_sel = ntt_out_permut_sel;
		end
		bfu_ntt_mode: begin
			in_permut_sel = ntt_in_permut_sel;
			out_permut_sel = ntt_out_permut_sel;
		end
		bfu_ifft_mode: begin
			in_permut_sel = intt_in_permut_sel;
			out_permut_sel = intt_out_permut_sel;
		end
		bfu_intt_mode: begin
			in_permut_sel = intt_in_permut_sel;
			out_permut_sel = intt_out_permut_sel;
		end
		default: begin
			in_permut_sel = 1'b0;
			out_permut_sel = 1'b1;
		end
	endcase
end
assign post_shift_even = bfu_ifft_mode;

//----------------------------------------------------------
// vec_num FIFO
//----------------------------------------------------------

// 0728: if fifo not enable, w_vn would be X, fabric would also give X to bram
// always enable FIFO
assign fifo_en = 4'b1111;

// when mmac, FIFO is not used, since no need write buffer
always_comb begin
	fifo_wr_en = 'b0;
	fifo_din[0] = ntt_avn0;
	fifo_din[1] = ntt_bvn0;
	fifo_din[2] = ntt_avn1;
	fifo_din[3] = ntt_bvn1;
	fifo_rd_en = 'b0;
	if (bfu_a_str) begin
			fifo_wr_en = {4{arith1_bvn0_ren}};
			if (bfu_add_mode || (symbreak_calc && (symbreak_result==1'b0))) begin
				fifo_din[0] = arith1_bvn0;
				fifo_din[1] = arith1_avn0;
				fifo_din[2] = arith1_bvn1;
				fifo_din[3] = arith1_avn1;
				fifo_rd_en = {4{bfu_av0_vld_o}};
			end
			else begin
				fifo_din[0] = arith1_avn0;
				fifo_din[1] = arith1_bvn0;
				fifo_din[2] = arith1_avn1;
				fifo_din[3] = arith1_bvn1;
				fifo_rd_en = {4{bfu_bv0_vld_o}};
			end
	end
	else begin
		case (1'b1)
			bfu_fft_mode: begin			// FFT
				fifo_wr_en = {4{ntt_busy}};
				fifo_din[0] = ntt_avn0;
				fifo_din[1] = ntt_bvn0;
				fifo_din[2] = ntt_avn1;
				fifo_din[3] = ntt_bvn1;
				fifo_rd_en = {4{bfu_av0_vld_o}};		// when fft, all vectors are valid, use av0_vld is OK
			end
			bfu_ntt_mode: begin		// NTT
				fifo_wr_en = {4{ntt_busy}};
				fifo_din[0] = ntt_avn0;
				fifo_din[1] = ntt_bvn0;
				fifo_din[2] = ntt_avn1;
				fifo_din[3] = ntt_bvn1;
				fifo_rd_en = {4{bfu_av0_vld_o}};		// when ntt, all vectors are valid, use av0_vld is OK
			end
			bfu_ifft_mode: begin
				fifo_wr_en = {4{intt_busy}};
				fifo_din[0] = intt_avn0;
				fifo_din[1] = intt_bvn0;
				fifo_din[2] = intt_avn1;
				fifo_din[3] = intt_bvn1;
				fifo_rd_en = {4{bfu_av0_vld_o}};
			end
			bfu_intt_mode: begin
				fifo_wr_en = {4{intt_busy}};
				fifo_din[0] = intt_avn0;
				fifo_din[1] = intt_bvn0;
				fifo_din[2] = intt_avn1;
				fifo_din[3] = intt_bvn1;
				fifo_rd_en = {4{bfu_av0_vld_o}};
			end
			// (m)add
			bfu_add_mode,
			bfu_madd_mode,
			bfu_gf2cf_mode: begin
				fifo_wr_en = {4{arith_avn0_ren}};
				fifo_din[0] = arith_avn0;
				fifo_din[1] = arith_bvn0;
				fifo_din[2] = arith_avn1;
				fifo_din[3] = arith_bvn1;
				fifo_rd_en = {4{bfu_av0_vld_o}};
			end
			// (m)sub/mul
			bfu_sub_mode,
			bfu_msub_mode,
			bfu_mul_mode,
			bfu_mmul_mode: begin
				fifo_wr_en = {4{arith_bvn0_ren}};
				fifo_din[0] = arith_avn0;
				fifo_din[1] = arith_bvn0;
				fifo_din[2] = arith_avn1;
				fifo_din[3] = arith_bvn1;
				fifo_rd_en = {4{bfu_bv0_vld_o}};
			end
			// div, inv
			bfu_div_mode,
			bfu_inv_mode: begin
				fifo_wr_en = '0;
				fifo_din[0] = arith_avn0;
				fifo_din[1] = arith_bvn0;
				fifo_din[2] = arith_avn1;
				fifo_din[3] = arith_bvn1;
				fifo_rd_en = '0;
			end
		endcase
	end
end

//----------------------------------------------------------
// to tw_rom control
//----------------------------------------------------------
always_comb begin
	// default value
	tw_rom_mode = 2'b00;
	tw_rom_start = ntt_ctrl_start;
	tw_rom_en = ntt_ctrl_en;
	// Keep the BFU inputs defined before an operation starts.
	tw_rom_ren = 1'b1;
	case (1'b1)
		bfu_fft_mode: begin
			tw_rom_mode = 2'b00;	// fft
			tw_rom_start = ntt_ctrl_start;
			tw_rom_en = ntt_ctrl_en;
			tw_rom_ren = ntt_avn0_ren;
		end
		bfu_ntt_mode: begin
			tw_rom_mode = 2'b01;	// ntt
			tw_rom_start = ntt_ctrl_start;
			tw_rom_en = ntt_ctrl_en;
			tw_rom_ren = ntt_avn0_ren;
		end
		bfu_ifft_mode: begin
			tw_rom_mode = 2'b10;
			tw_rom_start = intt_ctrl_start;
			tw_rom_en = intt_ctrl_en;
			tw_rom_ren = intt_avn0_ren;
		end
		bfu_intt_mode: begin
			tw_rom_mode = 2'b11;
			tw_rom_start = intt_ctrl_start;
			tw_rom_en = intt_ctrl_en;
			tw_rom_ren = intt_avn0_ren;
		end
	endcase
end

// buffer interface

always_comb begin
	// default value
	bfu_r_avn0 = arith_avn0;
	bfu_r_bvn0 = arith_bvn0;
	bfu_r_avn1 = arith_avn1;
	bfu_r_bvn1 = arith_bvn1;
	bfu_avn0_ren = 1'b0;
	bfu_bvn0_ren = 1'b0;
	bfu_avn1_ren = 1'b0;
	bfu_bvn1_ren = 1'b0;
	if (bfu_a_str) begin
		bfu_r_avn0 = arith1_avn0;
		bfu_r_bvn0 = arith1_bvn0;
		bfu_r_avn1 = arith1_avn1;
		bfu_r_bvn1 = arith1_bvn1;
		bfu_avn0_ren = arith1_avn0_ren;
		bfu_bvn0_ren = arith1_bvn0_ren;
		bfu_avn1_ren = arith1_avn1_ren;
		bfu_bvn1_ren = arith1_bvn1_ren;
	end
	else begin
		case (1'b1)
			bfu_fft_mode,
			bfu_ntt_mode: begin
				bfu_r_avn0 = ntt_avn0;
				bfu_r_bvn0 = ntt_bvn0;
				bfu_r_avn1 = ntt_avn1;
				bfu_r_bvn1 = ntt_bvn1;
				bfu_avn0_ren = ntt_avn0_ren;
				bfu_bvn0_ren = ntt_bvn0_ren;
				bfu_avn1_ren = ntt_avn1_ren;
				bfu_bvn1_ren = ntt_bvn1_ren;
			end
			bfu_ifft_mode,
			bfu_intt_mode: begin
				bfu_r_avn0 = intt_avn0;
				bfu_r_bvn0 = intt_bvn0;
				bfu_r_avn1 = intt_avn1;
				bfu_r_bvn1 = intt_bvn1;
				bfu_avn0_ren = intt_avn0_ren;
				bfu_bvn0_ren = intt_bvn0_ren;
				bfu_avn1_ren = intt_avn1_ren;
				bfu_bvn1_ren = intt_bvn1_ren;
			end
			bfu_mmac_mode: begin
				bfu_r_avn0 = mmac_avn0;
				bfu_r_bvn0 = mmac_bvn0;
				bfu_r_avn1 = mmac_avn1;
				bfu_r_bvn1 = mmac_bvn1;
				bfu_avn0_ren = mmac_avn0_ren;
				bfu_bvn0_ren = mmac_bvn0_ren;
				bfu_avn1_ren = mmac_avn1_ren;
				bfu_bvn1_ren = mmac_bvn1_ren;
			end
			default: begin
				bfu_r_avn0 = arith_avn0;
				bfu_r_bvn0 = arith_bvn0;
				bfu_r_avn1 = arith_avn1;
				bfu_r_bvn1 = arith_bvn1;
				bfu_avn0_ren = arith_avn0_ren;
				bfu_bvn0_ren = arith_bvn0_ren;
				bfu_avn1_ren = arith_avn1_ren;
				bfu_bvn1_ren = arith_bvn1_ren;
			end
		endcase
	end
end


// tie w_vn to 4 FIFOs
always_comb begin
	bfu_w_avn0 = fifo_dout[0];
	bfu_w_bvn0 = fifo_dout[1];
	bfu_w_avn1 = fifo_dout[2];
	bfu_w_bvn1 = fifo_dout[3];
end
always_comb begin
	if (bfu_mmac_mode||bfu_div_mode||bfu_inv_mode) begin
		bfu_avn0_wen = 1'b0;
		bfu_bvn0_wen = 1'b0;
		bfu_avn1_wen = 1'b0;
		bfu_bvn1_wen = 1'b0;
	end
	else begin
		bfu_avn0_wen = bfu_av0_vld_o;
		bfu_bvn0_wen = bfu_bv0_vld_o;
		bfu_avn1_wen = bfu_av1_vld_o;
		bfu_bvn1_wen = bfu_bv1_vld_o;
	end
end

// bfu_finish
always_comb begin

	bfu_finish = arith_finish;

	if (bfu_a_str) begin
		bfu_finish = arith1_finish;
	end
	else begin
		case (1'b1)
			bfu_fft_mode,
			bfu_ntt_mode: begin
				bfu_finish = ntt_finish;
			end
			bfu_ifft_mode,
			bfu_intt_mode: begin
				bfu_finish = intt_finish;
			end
			bfu_mmac_mode: begin
				bfu_finish = mmac_finish;
			end
			default: begin
				bfu_finish = arith_finish;
			end
		endcase
	end
end

//-------------------------------------------------------
// start
//-------------------------------------------------------
always_comb begin
	// default value
	ntt_ctrl_start   = 1'b0;
	intt_ctrl_start  = 1'b0;
	arith_ctrl_start = 1'b0;
	arith1_start     = 1'b0;
	mmac_ctrl_start  = 1'b0;
	if (bfu_a_str) begin
		ntt_ctrl_start   = 1'b0;
		intt_ctrl_start  = 1'b0;
		arith_ctrl_start = 1'b0;
		arith1_start     = bfu_start;
		mmac_ctrl_start  = 1'b0;
	end
	else begin
		case (1'b1)
			bfu_fft_mode,
			bfu_ntt_mode: begin
				ntt_ctrl_start   = bfu_start;
				intt_ctrl_start  = 1'b0;
				arith_ctrl_start = 1'b0;
				arith1_start     = 1'b0;
				mmac_ctrl_start  = 1'b0;
			end
			bfu_ifft_mode,
			bfu_intt_mode: begin
				ntt_ctrl_start   = 1'b0;
				intt_ctrl_start  = bfu_start;
				arith_ctrl_start = 1'b0;
				arith1_start     = 1'b0;
				mmac_ctrl_start  = 1'b0;
			end
			bfu_mmac_mode: begin
				ntt_ctrl_start   = 1'b0;
				intt_ctrl_start  = 1'b0;
				arith_ctrl_start = 1'b0;
				arith1_start     = 1'b0;
				mmac_ctrl_start  = bfu_start;
			end
			default: begin
				ntt_ctrl_start   = 1'b0;
				intt_ctrl_start  = 1'b0;
				arith_ctrl_start = bfu_start;
				arith1_start     = 1'b0;
				mmac_ctrl_start  = 1'b0;
			end
		endcase
	end
end

// pre-shift
// in FFT, only the first stage use pre_shift_len

assign a_pre_shift_len = task_a_pre_shift_len;
assign b_pre_shift_len = task_b_pre_shift_len;

wire q00_0_set0_cond = task_bfu && bfu_fft_mode && (ntt_stage=='d1) && (bfu_r_avn0=='d0) && (taskcode[63]==1'b1);
dffre_pipe #(
	.WIDTH(1),
	.DELAY(`BUFF_RD_LATENCY)
) u_dffre_pipe_q00_0_set0 (
	.clk,
	.rstn,
	.en(1'b1),
	.d(q00_0_set0_cond),
	.q(q00_0_set0)
);

endmodule
