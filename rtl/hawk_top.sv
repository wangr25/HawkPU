`include "./defines/defines.sv"

module hawk_top (
	input logic clk,
	input logic rstn,
	input logic sys_security_level,	// 0-hawk512, 1-hawk1024
	input logic sys_mode,	// 0-sign, 1-vrfy

	// initial write data
	input logic sys_init,	// pulse, initialize system
	input logic sys_in_en,		// remain 1 when writing vectors
	input logic [`ADDR_WIDTH-1:0] sys_base_waddr,
	input logic sys_vec_wen,
	input logic [`VEC_BITS-1:0] sys_vec_wdata,

	// size of message
	input logic [`ADDR_WIDTH-1:0] m_lines,		// (512-bit) lines of m
	input logic [5:0] m_bytes,		// valid bytes in m's last (512-bit) line, range 0~63
    input logic [6:0] m_outlen,     // adapt m||hpub output length
    input logic [6:0] m_outbytes,     // adapt m||hpub output last-row bytes

	input logic sys_start,
	output logic sys_finish,
	output logic vrfy_pass,

	input logic sys_out_en,
    input logic [`ADDR_WIDTH-1:0] sys_base_raddr,
    input logic [1:0] sys_r_sel,
	input logic [`VEC_NUM_WIDTH-1:0] sys_r_vn,
	input logic sys_vec_ren,
    output logic [31:0] sys_r_data 

);

logic sys_vec_type;
logic sys_w_mapping_mode;
logic sys_r_mapping_mode;
assign sys_vec_type = 1'b1;
assign sys_w_mapping_mode = 1'b0;
assign sys_r_mapping_mode = 1'b0;

logic security_level;
assign security_level = sys_security_level;

// taskcode
logic [`TC_W-1:0] taskcode_dg;
logic [`TC_W-1:0] taskcode_code;
logic [`TC_W-1:0] taskcode_bfu;
logic [`TC_W-1:0] taskcode_bfu_1;
logic [`TC_W-1:0] taskcode_gf2;
logic [`TC_W-1:0] taskcode_fmt;
logic taskcode_vld;

// control -> buffer
logic buffer_r_mode;
logic buffer_w_mode;

// control-> bus
logic [2:0] buf_write_sel;
logic [2:0] buf_cmd_sel;

// buffer command
// mode-direct
logic [`ADDR_WIDTH-1:0] buf_av0_raddr_dir;
logic [`ADDR_WIDTH-1:0] buf_bv0_raddr_dir;
logic [`ADDR_WIDTH-1:0] buf_av1_raddr_dir;
logic [`ADDR_WIDTH-1:0] buf_bv1_raddr_dir;
logic [1:0] buf_av0_r_bs_dir;
logic [1:0] buf_bv0_r_bs_dir;
logic [1:0] buf_av1_r_bs_dir;
logic [1:0] buf_bv1_r_bs_dir;
logic [`ADDR_WIDTH-1:0] buf_av0_waddr_dir;
logic [`ADDR_WIDTH-1:0] buf_bv0_waddr_dir;
logic [`ADDR_WIDTH-1:0] buf_av1_waddr_dir;
logic [`ADDR_WIDTH-1:0] buf_bv1_waddr_dir;
logic [1:0] buf_av0_w_bs_dir;
logic [1:0] buf_bv0_w_bs_dir;
logic [1:0] buf_av1_w_bs_dir;
logic [1:0] buf_bv1_w_bs_dir;
// mode-mapping
logic buf_a_r_mapping_mode;
logic buf_b_r_mapping_mode;
logic [`ADDR_WIDTH-1:0]    buf_a_base_raddr;
logic [`ADDR_WIDTH-1:0]    buf_b_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] buf_r_avn0;
logic [`VEC_NUM_WIDTH-1:0] buf_r_bvn0;
logic [`VEC_NUM_WIDTH-1:0] buf_r_avn1;
logic [`VEC_NUM_WIDTH-1:0] buf_r_bvn1;
logic buf_avn0_ren;
logic buf_bvn0_ren;
logic buf_avn1_ren;
logic buf_bvn1_ren;
logic buf_a_w_mapping_mode;
logic buf_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] buf_a_base_waddr;
logic [`ADDR_WIDTH-1:0] buf_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] buf_w_avn0;
logic [`VEC_NUM_WIDTH-1:0] buf_w_bvn0;
logic [`VEC_NUM_WIDTH-1:0] buf_w_avn1;
logic [`VEC_NUM_WIDTH-1:0] buf_w_bvn1;
logic buf_avn0_wen;
logic buf_avn1_wen;
logic buf_bvn0_wen;
logic buf_bvn1_wen;
// buffer data
logic [`VEC_BITS-1:0]         buf_r_av0;
logic [`VEC_BITS-1:0]         buf_r_bv0;
logic [`VEC_BITS-1:0]         buf_r_av1;
logic [`VEC_BITS-1:0]         buf_r_bv1;
logic [`VEC_BITS-1:0]         buf_w_av0;
logic [`VEC_BITS-1:0]         buf_w_bv0;
logic [`VEC_BITS-1:0]         buf_w_av1;
logic [`VEC_BITS-1:0]         buf_w_bv1;

// data_gen -> control
logic                             dg_finish;
// data_gen read buffer
logic                             dg_a_r_mapping_mode;
logic                             dg_b_r_mapping_mode;
logic [`ADDR_WIDTH-1:0]           dg_a_base_raddr;
logic [`ADDR_WIDTH-1:0]           dg_b_base_raddr;
logic [`VEC_NUM_WIDTH-1:0]        dg_r_avn0;
logic [`VEC_NUM_WIDTH-1:0]        dg_r_bvn0;
logic [`VEC_NUM_WIDTH-1:0]        dg_r_avn1;
logic [`VEC_NUM_WIDTH-1:0]        dg_r_bvn1;
logic [`VEC_BITS-1:0]             dg_r_av0;
logic [`VEC_BITS-1:0]             dg_r_bv0;
logic [`VEC_BITS-1:0]             dg_r_av1;
logic [`VEC_BITS-1:0]             dg_r_bv1;
logic                             dg_avn0_ren;
logic                             dg_bvn0_ren;
logic                             dg_avn1_ren;
logic                             dg_bvn1_ren;
// data_gen write buffer
logic                             dg_a_w_mapping_mode;
logic                             dg_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0]           dg_a_base_waddr;
logic [`ADDR_WIDTH-1:0]           dg_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0]        dg_w_avn0;
logic [`VEC_NUM_WIDTH-1:0]        dg_w_bvn0;
logic [`VEC_NUM_WIDTH-1:0]        dg_w_avn1;
logic [`VEC_NUM_WIDTH-1:0]        dg_w_bvn1;
logic [`VEC_BITS-1:0]             dg_w_av0;
logic [`VEC_BITS-1:0]             dg_w_bv0;
logic [`VEC_BITS-1:0]             dg_w_av1;
logic [`VEC_BITS-1:0]             dg_w_bv1;
logic                             dg_avn0_wen;
logic                             dg_bvn0_wen;
logic                             dg_avn1_wen;
logic                             dg_bvn1_wen;

// gf2 -> control
logic gf2_finish;

// gf2 Read buffer interface
logic [`ADDR_WIDTH-1:0] gf2_av0_raddr_dir;
logic [`ADDR_WIDTH-1:0] gf2_bv0_raddr_dir;
logic [`ADDR_WIDTH-1:0] gf2_av1_raddr_dir;
logic [`ADDR_WIDTH-1:0] gf2_bv1_raddr_dir;
logic gf2_avn0_ren;
logic gf2_bvn0_ren;
logic gf2_avn1_ren;
logic gf2_bvn1_ren;
logic [1:0] gf2_av0_r_bs_dir;
logic [1:0] gf2_bv0_r_bs_dir;
logic [1:0] gf2_av1_r_bs_dir;
logic [1:0] gf2_bv1_r_bs_dir;
logic [`VEC_BITS-1:0] gf2_r_av0;
logic [`VEC_BITS-1:0] gf2_r_bv0;
logic [`VEC_BITS-1:0] gf2_r_av1;
logic [`VEC_BITS-1:0] gf2_r_bv1;

// gf2 Write buffer interface
logic [`ADDR_WIDTH-1:0] gf2_av0_waddr_dir;
logic [`ADDR_WIDTH-1:0] gf2_bv0_waddr_dir;
logic [`ADDR_WIDTH-1:0] gf2_av1_waddr_dir;
logic [`ADDR_WIDTH-1:0] gf2_bv1_waddr_dir;
logic gf2_avn0_wen;
logic gf2_bvn0_wen;
logic gf2_avn1_wen;
logic gf2_bvn1_wen;
logic [1:0] gf2_av0_w_bs_dir;
logic [1:0] gf2_bv0_w_bs_dir;
logic [1:0] gf2_av1_w_bs_dir;
logic [1:0] gf2_bv1_w_bs_dir;
logic [`VEC_BITS-1:0] gf2_w_av0;
logic [`VEC_BITS-1:0] gf2_w_bv0;
logic [`VEC_BITS-1:0] gf2_w_av1;
logic [`VEC_BITS-1:0] gf2_w_bv1;


// bfu read buffer
logic bfu_a_r_mapping_mode;
logic bfu_b_r_mapping_mode;
logic [`ADDR_WIDTH-1:0] bfu_a_base_raddr;
logic [`ADDR_WIDTH-1:0] bfu_b_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] bfu_r_avn0;
logic [`VEC_NUM_WIDTH-1:0] bfu_r_bvn0;
logic [`VEC_NUM_WIDTH-1:0] bfu_r_avn1;
logic [`VEC_NUM_WIDTH-1:0] bfu_r_bvn1;
logic [`VEC_BITS-1:0] bfu_r_av0;
logic [`VEC_BITS-1:0] bfu_r_bv0;
logic [`VEC_BITS-1:0] bfu_r_av1;
logic [`VEC_BITS-1:0] bfu_r_bv1;
logic bfu_avn0_ren;
logic bfu_bvn0_ren;
logic bfu_avn1_ren;
logic bfu_bvn1_ren;
logic poly_adjoint;

// bfu write buffer
logic bfu_a_w_mapping_mode;
logic bfu_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] bfu_a_base_waddr;
logic [`ADDR_WIDTH-1:0] bfu_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] bfu_w_avn0;
logic [`VEC_NUM_WIDTH-1:0] bfu_w_bvn0;
logic [`VEC_NUM_WIDTH-1:0] bfu_w_avn1;
logic [`VEC_NUM_WIDTH-1:0] bfu_w_bvn1;
logic [`VEC_BITS-1:0] bfu_w_av0;
logic [`VEC_BITS-1:0] bfu_w_bv0;
logic [`VEC_BITS-1:0] bfu_w_av1;
logic [`VEC_BITS-1:0] bfu_w_bv1;
logic [`VEC_BITS-1:0]         bfu_av0_o;  // same as bfu_w_*v*
logic [`VEC_BITS-1:0]         bfu_bv0_o;
logic [`VEC_BITS-1:0]         bfu_av1_o;
logic [`VEC_BITS-1:0]         bfu_bv1_o;
logic bfu_avn0_wen;
logic bfu_bvn0_wen;
logic bfu_avn1_wen;
logic bfu_bvn1_wen;

// bfu -> control
logic bfu_finish;
logic vrfy_finish;

///////////////////////////////////////////////////
// code
///////////////////////////////////////////////////
// control -> code
// control <- code
logic                             code_flag;
logic                             code_finish;
// code -> bfu
logic [31:0] q00_cstup;
// code read buffer
logic                             code_a_r_mapping_mode;
logic                             code_b_r_mapping_mode;
logic [`ADDR_WIDTH-1:0]           code_a_base_raddr;
logic [`ADDR_WIDTH-1:0]           code_b_base_raddr;
logic [`VEC_NUM_WIDTH-1:0]        code_r_avn0;
logic [`VEC_NUM_WIDTH-1:0]        code_r_bvn0;
logic [`VEC_NUM_WIDTH-1:0]        code_r_avn1;
logic [`VEC_NUM_WIDTH-1:0]        code_r_bvn1;
logic [`VEC_BITS-1:0]             code_r_av0;
logic [`VEC_BITS-1:0]             code_r_bv0;
logic [`VEC_BITS-1:0]             code_r_av1;
logic [`VEC_BITS-1:0]             code_r_bv1;
logic                             code_avn0_ren;
logic                             code_bvn0_ren;
logic                             code_avn1_ren;
logic                             code_bvn1_ren;
// code write buffer
logic                             code_a_w_mapping_mode;
logic                             code_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0]           code_a_base_waddr;
logic [`ADDR_WIDTH-1:0]           code_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0]        code_w_avn0;
logic [`VEC_NUM_WIDTH-1:0]        code_w_bvn0;
logic [`VEC_NUM_WIDTH-1:0]        code_w_avn1;
logic [`VEC_NUM_WIDTH-1:0]        code_w_bvn1;
logic [`VEC_BITS-1:0]             code_w_av0;
logic [`VEC_BITS-1:0]             code_w_bv0;
logic [`VEC_BITS-1:0]             code_w_av1;
logic [`VEC_BITS-1:0]             code_w_bv1;
logic                             code_avn0_wen;
logic                             code_bvn0_wen;
logic                             code_avn1_wen;
logic                             code_bvn1_wen;



///////////////////////////////////////////////////
// format
///////////////////////////////////////////////////
logic        fmt_a_r_mapping_mode;
logic        fmt_b_r_mapping_mode;
logic [`ADDR_WIDTH-1:0] fmt_a_base_raddr;
logic [`ADDR_WIDTH-1:0] fmt_b_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] fmt_r_avn0;
logic [`VEC_NUM_WIDTH-1:0] fmt_r_bvn0;
logic [`VEC_NUM_WIDTH-1:0] fmt_r_avn1;
logic [`VEC_NUM_WIDTH-1:0] fmt_r_bvn1;
logic [`VEC_BITS-1:0] fmt_r_av0;
logic [`VEC_BITS-1:0] fmt_r_bv0;
logic [`VEC_BITS-1:0] fmt_r_av1;
logic [`VEC_BITS-1:0] fmt_r_bv1;
logic        fmt_avn0_ren;
logic        fmt_bvn0_ren;
logic        fmt_avn1_ren;
logic        fmt_bvn1_ren;

logic        fmt_a_w_mapping_mode;
logic        fmt_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] fmt_a_base_waddr;
logic [`ADDR_WIDTH-1:0] fmt_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] fmt_w_avn0;
logic [`VEC_NUM_WIDTH-1:0] fmt_w_bvn0;
logic [`VEC_NUM_WIDTH-1:0] fmt_w_avn1;
logic [`VEC_NUM_WIDTH-1:0] fmt_w_bvn1;
logic [`VEC_BITS-1:0] fmt_w_av0;
logic [`VEC_BITS-1:0] fmt_w_bv0;
logic [`VEC_BITS-1:0] fmt_w_av1;
logic [`VEC_BITS-1:0] fmt_w_bv1;
logic        fmt_avn0_wen;
logic        fmt_bvn0_wen;
logic        fmt_avn1_wen;
logic        fmt_bvn1_wen;

logic        fmt_finish;


  datagen_top u_datagen_top (
  //datagen_top u_datagen_top (
    .clk                 (clk                ),
    .rstn                (rstn               ),
    .security_level      (security_level     ),

    .taskcode(taskcode_dg),
    .taskcode_vld,

    .m_lines             (m_lines            ),
    .m_bytes             (m_bytes            ),
    .m_outlen                 (m_outlen),
    .m_outbytes               (m_outbytes),

    .dg_a_r_mapping_mode (dg_a_r_mapping_mode),
    .dg_b_r_mapping_mode (dg_b_r_mapping_mode),
    .dg_a_base_raddr     (dg_a_base_raddr    ),
    .dg_b_base_raddr     (dg_b_base_raddr    ),
    .dg_r_avn0           (dg_r_avn0          ),
    .dg_r_bvn0           (dg_r_bvn0          ),
    .dg_r_avn1           (dg_r_avn1          ),
    .dg_r_bvn1           (dg_r_bvn1          ),
    .dg_r_av0            (dg_r_av0           ),
    .dg_r_bv0            (dg_r_bv0           ),
    .dg_r_av1            (dg_r_av1           ),
    .dg_r_bv1            (dg_r_bv1           ),
    .dg_avn0_ren         (dg_avn0_ren        ),
    .dg_bvn0_ren         (dg_bvn0_ren        ),
    .dg_avn1_ren         (dg_avn1_ren        ),
    .dg_bvn1_ren         (dg_bvn1_ren        ),

    .dg_a_w_mapping_mode (dg_a_w_mapping_mode),
    .dg_b_w_mapping_mode (dg_b_w_mapping_mode),
    .dg_a_base_waddr     (dg_a_base_waddr    ),
    .dg_b_base_waddr     (dg_b_base_waddr    ),
    .dg_w_avn0           (dg_w_avn0          ),
    .dg_w_bvn0           (dg_w_bvn0          ),
    .dg_w_avn1           (dg_w_avn1          ),
    .dg_w_bvn1           (dg_w_bvn1          ),
    .dg_w_av0            (dg_w_av0           ),
    .dg_w_bv0            (dg_w_bv0           ),
    .dg_w_av1            (dg_w_av1           ),
    .dg_w_bv1            (dg_w_bv1           ),
    .dg_avn0_wen         (dg_avn0_wen        ),
    .dg_bvn0_wen         (dg_bvn0_wen        ),
    .dg_avn1_wen         (dg_avn1_wen        ),
    .dg_bvn1_wen         (dg_bvn1_wen        ),

    .dg_finish           (dg_finish          )
  );
    assign dg_r_av0 = buf_r_av0;
    assign dg_r_bv0 = buf_r_bv0;
    assign dg_r_av1 = buf_r_av1;
    assign dg_r_bv1 = buf_r_bv1;

//----------------------------------------------------
// gf2
//----------------------------------------------------

assign gf2_r_av0 = buf_r_av0;
assign gf2_r_bv0 = buf_r_bv0;
assign gf2_r_av1 = buf_r_av1;
assign gf2_r_bv1 = buf_r_bv1;
gf2_top u_gf2_top (
    .clk                    (clk),
    .rstn                   (rstn),
    .security_level         (security_level),

    .taskcode(taskcode_gf2),
    .taskcode_vld,

    .gf2_av0_raddr_dir      (gf2_av0_raddr_dir),
    .gf2_bv0_raddr_dir      (gf2_bv0_raddr_dir),
    .gf2_av1_raddr_dir      (gf2_av1_raddr_dir),
    .gf2_bv1_raddr_dir      (gf2_bv1_raddr_dir),
    .gf2_avn0_ren           (gf2_avn0_ren),
    .gf2_bvn0_ren           (gf2_bvn0_ren),
    .gf2_avn1_ren           (gf2_avn1_ren),
    .gf2_bvn1_ren           (gf2_bvn1_ren),
    .gf2_av0_r_bs_dir       (gf2_av0_r_bs_dir),
    .gf2_bv0_r_bs_dir       (gf2_bv0_r_bs_dir),
    .gf2_av1_r_bs_dir       (gf2_av1_r_bs_dir),
    .gf2_bv1_r_bs_dir       (gf2_bv1_r_bs_dir),
    .gf2_r_av0              (gf2_r_av0),
    .gf2_r_bv0              (gf2_r_bv0),
    .gf2_r_av1              (gf2_r_av1),
    .gf2_r_bv1              (gf2_r_bv1),
    .gf2_av0_waddr_dir      (gf2_av0_waddr_dir),
    .gf2_bv0_waddr_dir      (gf2_bv0_waddr_dir),
    .gf2_av1_waddr_dir      (gf2_av1_waddr_dir),
    .gf2_bv1_waddr_dir      (gf2_bv1_waddr_dir),
    .gf2_avn0_wen           (gf2_avn0_wen),
    .gf2_bvn0_wen           (gf2_bvn0_wen),
    .gf2_avn1_wen           (gf2_avn1_wen),
    .gf2_bvn1_wen           (gf2_bvn1_wen),
    .gf2_av0_w_bs_dir       (gf2_av0_w_bs_dir),
    .gf2_bv0_w_bs_dir       (gf2_bv0_w_bs_dir),
    .gf2_av1_w_bs_dir       (gf2_av1_w_bs_dir),
    .gf2_bv1_w_bs_dir       (gf2_bv1_w_bs_dir),
    .gf2_w_av0              (gf2_w_av0),
    .gf2_w_bv0              (gf2_w_bv0),
    .gf2_w_av1              (gf2_w_av1),
    .gf2_w_bv1              (gf2_w_bv1),

    .gf2_finish             (gf2_finish)
);

code_top u_code_top (
    .clk                      (clk                     ),
    .rstn                     (rstn                    ),
    .security_level           (security_level          ),
    .sys_mode,

    .taskcode(taskcode_code),
    .taskcode_vld,

    .m_lines                  (m_lines            ),
    .m_bytes                  (m_bytes            ),
    .m_outlen                 (m_outlen),
    .m_outbytes               (m_outbytes),

    // from top control
    // to top control
    .code_flag                (code_flag               ),
    .code_finish              (code_finish             ),
    // to BFU
    .q00_cstup,
    // read buffer
    .code_a_r_mapping_mode    (code_a_r_mapping_mode   ),
    .code_b_r_mapping_mode    (code_b_r_mapping_mode   ),
    .code_a_base_raddr        (code_a_base_raddr       ),
    .code_b_base_raddr        (code_b_base_raddr       ),
    .code_r_avn0              (code_r_avn0             ),
    .code_r_bvn0              (code_r_bvn0             ),
    .code_r_avn1              (code_r_avn1             ),
    .code_r_bvn1              (code_r_bvn1             ),
    .code_r_av0               (code_r_av0              ),
    .code_r_bv0               (code_r_bv0              ),
    .code_r_av1               (code_r_av1              ),
    .code_r_bv1               (code_r_bv1              ),
    .code_avn0_ren            (code_avn0_ren           ),
    .code_bvn0_ren            (code_bvn0_ren           ),
    .code_avn1_ren            (code_avn1_ren           ),
    .code_bvn1_ren            (code_bvn1_ren           ),
    // write buffer
    .code_a_w_mapping_mode_o    (code_a_w_mapping_mode   ),
    .code_b_w_mapping_mode_o    (code_b_w_mapping_mode   ),
    .code_a_base_waddr_o        (code_a_base_waddr       ),
    .code_b_base_waddr_o        (code_b_base_waddr       ),
    .code_w_avn0_o              (code_w_avn0             ),
    .code_w_bvn0_o              (code_w_bvn0             ),
    .code_w_avn1_o              (code_w_avn1             ),
    .code_w_bvn1_o              (code_w_bvn1             ),
    .code_w_av0_o               (code_w_av0              ),
    .code_w_bv0_o               (code_w_bv0              ),
    .code_w_av1_o               (code_w_av1              ),
    .code_w_bv1_o               (code_w_bv1              ),
    .code_avn0_wen_o            (code_avn0_wen           ),
    .code_bvn0_wen_o            (code_bvn0_wen           ),
    .code_avn1_wen_o            (code_avn1_wen           ),
    .code_bvn1_wen_o            (code_bvn1_wen           )
);

assign code_r_av0 = buf_r_av0;
assign code_r_bv0 = buf_r_bv0;
assign code_r_av1 = buf_r_av1;
assign code_r_bv1 = buf_r_bv1;


bfu_top u_bfu_top (
    .clk,
    .rstn,
    .security_level,
    .sys_mode,
    .sys_init,

    .taskcode(taskcode_bfu),
    .taskcode_1(taskcode_bfu_1),
    .taskcode_vld,

    .bfu_constup(q00_cstup),

    .bfu_a_r_mapping_mode_o(bfu_a_r_mapping_mode),
    .bfu_b_r_mapping_mode_o(bfu_b_r_mapping_mode),
    .bfu_a_base_raddr_o(bfu_a_base_raddr),
    .bfu_b_base_raddr_o(bfu_b_base_raddr),
    .bfu_r_avn0_o(bfu_r_avn0),
    .bfu_r_bvn0_o(bfu_r_bvn0),
    .bfu_r_avn1_o(bfu_r_avn1),
    .bfu_r_bvn1_o(bfu_r_bvn1),
    .bfu_r_av0(buf_r_av0       ),
    .bfu_r_bv0(buf_r_bv0       ),
    .bfu_r_av1(buf_r_av1       ),
    .bfu_r_bv1(buf_r_bv1       ),
    .bfu_avn0_ren_o(bfu_avn0_ren),
    .bfu_bvn0_ren_o(bfu_bvn0_ren),
    .bfu_avn1_ren_o(bfu_avn1_ren),
    .bfu_bvn1_ren_o(bfu_bvn1_ren),
    .poly_adjoint,

    .bfu_a_w_mapping_mode_o(bfu_a_w_mapping_mode),
    .bfu_b_w_mapping_mode_o(bfu_b_w_mapping_mode),
    .bfu_a_base_waddr_o(bfu_a_base_waddr),
    .bfu_b_base_waddr_o(bfu_b_base_waddr),
    .bfu_w_avn0_o(bfu_w_avn0),
    .bfu_w_bvn0_o(bfu_w_bvn0),
    .bfu_w_avn1_o(bfu_w_avn1),
    .bfu_w_bvn1_o(bfu_w_bvn1),
    .bfu_w_av0_o(bfu_w_av0),
    .bfu_w_bv0_o(bfu_w_bv0),
    .bfu_w_av1_o(bfu_w_av1),
    .bfu_w_bv1_o(bfu_w_bv1),
    .bfu_avn0_wen_o(bfu_avn0_wen),
    .bfu_bvn0_wen_o(bfu_bvn0_wen),
    .bfu_avn1_wen_o(bfu_avn1_wen),
    .bfu_bvn1_wen_o(bfu_bvn1_wen),

    .bfu_finish_o(bfu_finish),
    .vrfy_finish,
    .vrfy_pass
);

assign bfu_av0_o = bfu_w_av0;
assign bfu_bv0_o = bfu_w_bv0;
assign bfu_av1_o = bfu_w_av1;
assign bfu_bv1_o = bfu_w_bv1;

format_top u_format_top (

    .clk                (clk),
    .rstn               (rstn),
    .security_level     (security_level),
    
    .taskcode           (taskcode_fmt),
    .taskcode_vld       (taskcode_vld),

    .m_lines                  (m_lines            ),
    .m_bytes                  (m_bytes            ),
    
    .fmt_a_r_mapping_mode (fmt_a_r_mapping_mode),
    .fmt_b_r_mapping_mode (fmt_b_r_mapping_mode),
    .fmt_a_base_raddr   (fmt_a_base_raddr),
    .fmt_b_base_raddr   (fmt_b_base_raddr),
    .fmt_r_avn0         (fmt_r_avn0),
    .fmt_r_bvn0         (fmt_r_bvn0),
    .fmt_r_avn1         (fmt_r_avn1),
    .fmt_r_bvn1         (fmt_r_bvn1),
    .fmt_r_av0          (fmt_r_av0),
    .fmt_r_bv0          (fmt_r_bv0),
    .fmt_r_av1          (fmt_r_av1),
    .fmt_r_bv1          (fmt_r_bv1),
    .fmt_avn0_ren       (fmt_avn0_ren),
    .fmt_bvn0_ren       (fmt_bvn0_ren),
    .fmt_avn1_ren       (fmt_avn1_ren),
    .fmt_bvn1_ren       (fmt_bvn1_ren),
    
    .fmt_a_w_mapping_mode (fmt_a_w_mapping_mode),
    .fmt_b_w_mapping_mode (fmt_b_w_mapping_mode),
    .fmt_a_base_waddr   (fmt_a_base_waddr),
    .fmt_b_base_waddr   (fmt_b_base_waddr),
    .fmt_w_avn0         (fmt_w_avn0),
    .fmt_w_bvn0         (fmt_w_bvn0),
    .fmt_w_avn1         (fmt_w_avn1),
    .fmt_w_bvn1         (fmt_w_bvn1),
    .fmt_w_av0          (fmt_w_av0),
    .fmt_w_bv0          (fmt_w_bv0),
    .fmt_w_av1          (fmt_w_av1),
    .fmt_w_bv1          (fmt_w_bv1),
    .fmt_avn0_wen       (fmt_avn0_wen),
    .fmt_bvn0_wen       (fmt_bvn0_wen),
    .fmt_avn1_wen       (fmt_avn1_wen),
    .fmt_bvn1_wen       (fmt_bvn1_wen),
    
    .fmt_finish         (fmt_finish)
    
);

assign fmt_r_av0 = buf_r_av0;
assign fmt_r_bv0 = buf_r_bv0;
assign fmt_r_av1 = buf_r_av1;
assign fmt_r_bv1 = buf_r_bv1;

control_top u_control_top (
    .clk                (clk               ),
    .rstn               (rstn              ),
    .security_level     (security_level    ),
    .sys_mode           (sys_mode          ),
    .sys_init           (sys_init          ),
    .sys_start          (sys_start         ),
    .sys_finish,

    .taskcode_dg_o(taskcode_dg),
    .taskcode_code_o(taskcode_code),
    .taskcode_bfu_o(taskcode_bfu),
    .taskcode_bfu_1_o(taskcode_bfu_1),
    .taskcode_gf2_o(taskcode_gf2),
    .taskcode_fmt_o(taskcode_fmt),
    .taskcode_vld_o(taskcode_vld),

	// BUFFER read - mapping
    .buffer_r_mode,
    .buffer_w_mode,
	// system bus
    .buf_write_sel      ,
    .buf_cmd_sel        ,
    // from code
    .code_flag,
    .code_finish,
    // datagen
    .dg_finish,
    // gf2
    .gf2_finish,
	// BFU
    .bfu_finish,
    // fmt
    .fmt_finish,

    .vrfy_finish
);

logic sys_vec_mapping_mode;
logic [`ADDR_WIDTH-1:0] sys_vec_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] sys_w_vn_cnt;

always_ff @(posedge clk) begin
	if (sys_init) begin
		sys_vec_mapping_mode <= sys_w_mapping_mode;
		sys_vec_base_waddr   <= sys_base_waddr;
	end
	else if ( sys_in_en && sys_vec_wen && (sys_vec_type==1'b1) ) begin
		if (security_level==1'b1) begin
			if (sys_w_vn_cnt=='d129) begin
				sys_vec_base_waddr <= sys_vec_base_waddr + 'd1;
			end
		end
		else begin
			if (sys_w_vn_cnt=='d65) begin
				sys_vec_base_waddr <= sys_vec_base_waddr + 'd1;
			end
		end
	end
end
always_ff @(posedge clk or negedge rstn) begin
	if (!rstn || sys_init) begin
		sys_w_vn_cnt <= 'd0;
	end
	else if (sys_in_en && sys_vec_wen) begin
		case (sys_vec_type)
			1'b0: begin			// polynomial
				if (sys_w_vn_cnt == (security_level ? 'd255 : 'd127)) begin
					sys_w_vn_cnt <= 'd0;
				end else begin
					sys_w_vn_cnt <= sys_w_vn_cnt + 'd1;
				end
			end
			1'b1: begin			// seed
				if (security_level == 1'b1) begin
					case (sys_w_vn_cnt)
						'd0:   sys_w_vn_cnt <= 'd1;
						'd1:   sys_w_vn_cnt <= 'd128;
						'd128: sys_w_vn_cnt <= 'd129;
						'd129: sys_w_vn_cnt <= 'd0;
					endcase	
				end
				else begin // security_level==1'b0
					case (sys_w_vn_cnt)
						'd0:   sys_w_vn_cnt <= 'd1;
						'd1:   sys_w_vn_cnt <= 'd64;
						'd64:  sys_w_vn_cnt <= 'd65;
						'd65:  sys_w_vn_cnt <= 'd0;
					endcase	
				end
			end
		endcase
	end
end


// buf write data select
always_comb begin
    // default value
    buf_w_av0 = bfu_av0_o;
    buf_w_bv0 = bfu_bv0_o;
    buf_w_av1 = bfu_av1_o;
    buf_w_bv1 = bfu_bv1_o;
	if (sys_in_en) begin
		buf_w_av0            = sys_vec_wdata;
	end
	else begin
		case (buf_write_sel)
            'd0: begin // code
				buf_w_av0 = code_w_av0;
				buf_w_bv0 = code_w_bv0;
				buf_w_av1 = code_w_av1;
				buf_w_bv1 = code_w_bv1;
            end
            'd1: begin // data_gen
				buf_w_av0 = dg_w_av0;
				buf_w_bv0 = dg_w_bv0;
				buf_w_av1 = dg_w_av1;
				buf_w_bv1 = dg_w_bv1;
            end
            'd2: begin  // gf2
				buf_w_av0 = gf2_w_av0;
				buf_w_bv0 = gf2_w_bv0;
				buf_w_av1 = gf2_w_av1;
				buf_w_bv1 = gf2_w_bv1;
            end
			'd3: begin	// BFU
				buf_w_av0 = bfu_av0_o;
				buf_w_bv0 = bfu_bv0_o;
				buf_w_av1 = bfu_av1_o;
				buf_w_bv1 = bfu_bv1_o;
			end
			'd5: begin	// fmt
				buf_w_av0 = fmt_w_av0;
				buf_w_bv0 = fmt_w_bv0;
				buf_w_av1 = fmt_w_av1;
				buf_w_bv1 = fmt_w_bv1;
			end
		endcase
	end
end

// buf command select
always_comb begin
    // default value
    buf_a_r_mapping_mode  = 'd0;
    buf_b_r_mapping_mode  = 'd0;
    buf_a_base_raddr      = 'd0;
    buf_b_base_raddr      = 'd0;
    buf_r_avn0            = 'd0;
    buf_r_bvn0            = 'd0;
    buf_r_avn1            = 'd0;
    buf_r_bvn1            = 'd0;
    buf_avn0_ren          = 'd0;
    buf_bvn0_ren          = 'd0;
    buf_avn1_ren          = 'd0;
    buf_bvn1_ren          = 'd0;
    buf_a_w_mapping_mode  = 'd0;
    buf_b_w_mapping_mode  = 'd0;
    buf_a_base_waddr      = 'd0;
    buf_b_base_waddr      = 'd0;
    buf_w_avn0            = 'd0;
    buf_w_bvn0            = 'd0;
    buf_w_avn1            = 'd0;
    buf_w_bvn1            = 'd0;
    buf_avn0_wen          = 'd0;
    buf_bvn0_wen          = 'd0;
    buf_avn1_wen          = 'd0;
    buf_bvn1_wen          = 'd0;

    buf_av0_raddr_dir = gf2_av0_raddr_dir;
    buf_bv0_raddr_dir = gf2_bv0_raddr_dir;
    buf_av1_raddr_dir = gf2_av1_raddr_dir;
    buf_bv1_raddr_dir = gf2_bv1_raddr_dir;
    buf_av0_r_bs_dir  = gf2_av0_r_bs_dir ;
    buf_bv0_r_bs_dir  = gf2_bv0_r_bs_dir ;
    buf_av1_r_bs_dir  = gf2_av1_r_bs_dir ;
    buf_bv1_r_bs_dir  = gf2_bv1_r_bs_dir ;
    buf_av0_waddr_dir = gf2_av0_waddr_dir;
    buf_bv0_waddr_dir = gf2_bv0_waddr_dir;
    buf_av1_waddr_dir = gf2_av1_waddr_dir;
    buf_bv1_waddr_dir = gf2_bv1_waddr_dir;
    buf_av0_w_bs_dir  = gf2_av0_w_bs_dir ;
    buf_bv0_w_bs_dir  = gf2_bv0_w_bs_dir ;
    buf_av1_w_bs_dir  = gf2_av1_w_bs_dir ;
    buf_bv1_w_bs_dir  = gf2_bv1_w_bs_dir ;
    //---------------------------------------------
	if (sys_in_en) begin
		buf_avn0_wen         = sys_vec_wen;
		buf_a_w_mapping_mode = sys_vec_mapping_mode;
		buf_a_base_waddr     = sys_vec_base_waddr;
		buf_w_avn0           = sys_w_vn_cnt;
	end
	else begin
		// from control_top
		case (buf_cmd_sel)
            'd0: begin  // code
                buf_avn0_wen         = code_avn0_wen;	
                buf_a_w_mapping_mode = code_a_w_mapping_mode;
                buf_a_base_waddr     = code_a_base_waddr;
                buf_w_avn0           = code_w_avn0;
            end
            'd1: begin  // data_gen
                buf_avn0_wen         = dg_avn0_wen;	
                buf_a_w_mapping_mode = dg_a_w_mapping_mode;
                buf_a_base_waddr     = dg_a_base_waddr;
                buf_w_avn0           = dg_w_avn0;
            end
            'd2: begin  // gf2
                buf_avn0_wen         = gf2_avn0_wen;	
            end
			'd3: begin	// bfu
                buf_avn0_wen         = bfu_avn0_wen;	
                buf_a_w_mapping_mode = bfu_a_w_mapping_mode;
                buf_a_base_waddr     = bfu_a_base_waddr;
                buf_w_avn0           = bfu_w_avn0;
			end
			'd5: begin	// fmt
                buf_avn0_wen         = fmt_avn0_wen;	
                buf_a_w_mapping_mode = fmt_a_w_mapping_mode;
                buf_a_base_waddr     = fmt_a_base_waddr;
                buf_w_avn0           = fmt_w_avn0;
			end
		endcase
	end
    //---------------------------------------------
	if (sys_out_en) begin
		buf_avn0_ren         = sys_vec_ren;
        buf_a_r_mapping_mode = sys_r_mapping_mode;
        buf_a_base_raddr     = sys_base_raddr;
		buf_r_avn0           = sys_r_vn;
	end
	else begin
		// from control_top
		case (buf_cmd_sel)
            'd0: begin  // code
                buf_avn0_ren         = code_avn0_ren;
                buf_a_r_mapping_mode = code_a_r_mapping_mode  ;
                buf_a_base_raddr     = code_a_base_raddr      ;
                buf_r_avn0           = code_r_avn0;
            end
            'd1: begin  // data_gen
                buf_avn0_ren         = dg_avn0_ren;
                buf_a_r_mapping_mode = dg_a_r_mapping_mode  ;
                buf_a_base_raddr     = dg_a_base_raddr      ;
                buf_r_avn0           = dg_r_avn0;
            end
            'd2: begin  // gf2
                buf_avn0_ren         = gf2_avn0_ren;
            end
			'd3: begin	// bfu
                buf_avn0_ren         = bfu_avn0_ren;
                buf_a_r_mapping_mode = bfu_a_r_mapping_mode  ;
                buf_a_base_raddr     = bfu_a_base_raddr      ;
                buf_r_avn0           = bfu_r_avn0;
			end
			'd5: begin	// fmt
                buf_avn0_ren         = fmt_avn0_ren;
                buf_a_r_mapping_mode = fmt_a_r_mapping_mode  ;
                buf_a_base_raddr     = fmt_a_base_raddr      ;
                buf_r_avn0           = fmt_r_avn0;
			end
		endcase
	end
    //---------------------------------------------
		case (buf_cmd_sel)
            'd0: begin  // code
                buf_b_r_mapping_mode  = code_b_r_mapping_mode  ;
                buf_b_base_raddr      = code_b_base_raddr      ;
                buf_r_bvn0            = code_r_bvn0            ;
                buf_r_avn1            = code_r_avn1            ;
                buf_r_bvn1            = code_r_bvn1            ;
                buf_bvn0_ren          = code_bvn0_ren          ;
                buf_avn1_ren          = code_avn1_ren          ;
                buf_bvn1_ren          = code_bvn1_ren          ;
                buf_b_w_mapping_mode  = code_b_w_mapping_mode  ;
                buf_b_base_waddr      = code_b_base_waddr      ;
                buf_w_bvn0            = code_w_bvn0            ;
                buf_w_avn1            = code_w_avn1            ;
                buf_w_bvn1            = code_w_bvn1            ;
                buf_bvn0_wen          = code_bvn0_wen          ;
                buf_avn1_wen          = code_avn1_wen          ;
                buf_bvn1_wen          = code_bvn1_wen          ;
            end
            'd1: begin  // data_gen
                buf_b_r_mapping_mode  = dg_b_r_mapping_mode  ;
                buf_b_base_raddr      = dg_b_base_raddr      ;
                buf_r_bvn0            = dg_r_bvn0            ;
                buf_r_avn1            = dg_r_avn1            ;
                buf_r_bvn1            = dg_r_bvn1            ;
                buf_bvn0_ren          = dg_bvn0_ren          ;
                buf_avn1_ren          = dg_avn1_ren          ;
                buf_bvn1_ren          = dg_bvn1_ren          ;
                buf_b_w_mapping_mode  = dg_b_w_mapping_mode  ;
                buf_b_base_waddr      = dg_b_base_waddr      ;
                buf_w_bvn0            = dg_w_bvn0            ;
                buf_w_avn1            = dg_w_avn1            ;
                buf_w_bvn1            = dg_w_bvn1            ;
                buf_bvn0_wen          = dg_bvn0_wen          ;
                buf_avn1_wen          = dg_avn1_wen          ;
                buf_bvn1_wen          = dg_bvn1_wen          ;
            end
            'd2: begin // gf2
                buf_bvn0_ren          = gf2_bvn0_ren          ;
                buf_avn1_ren          = gf2_avn1_ren          ;
                buf_bvn1_ren          = gf2_bvn1_ren          ;
                buf_bvn0_wen          = gf2_bvn0_wen          ;
                buf_avn1_wen          = gf2_avn1_wen          ;
                buf_bvn1_wen          = gf2_bvn1_wen          ;

                buf_av0_raddr_dir = gf2_av0_raddr_dir;
                buf_bv0_raddr_dir = gf2_bv0_raddr_dir;
                buf_av1_raddr_dir = gf2_av1_raddr_dir;
                buf_bv1_raddr_dir = gf2_bv1_raddr_dir;
                buf_av0_r_bs_dir  = gf2_av0_r_bs_dir ;
                buf_bv0_r_bs_dir  = gf2_bv0_r_bs_dir ;
                buf_av1_r_bs_dir  = gf2_av1_r_bs_dir ;
                buf_bv1_r_bs_dir  = gf2_bv1_r_bs_dir ;
                buf_av0_waddr_dir = gf2_av0_waddr_dir;
                buf_bv0_waddr_dir = gf2_bv0_waddr_dir;
                buf_av1_waddr_dir = gf2_av1_waddr_dir;
                buf_bv1_waddr_dir = gf2_bv1_waddr_dir;
                buf_av0_w_bs_dir  = gf2_av0_w_bs_dir ;
                buf_bv0_w_bs_dir  = gf2_bv0_w_bs_dir ;
                buf_av1_w_bs_dir  = gf2_av1_w_bs_dir ;
                buf_bv1_w_bs_dir  = gf2_bv1_w_bs_dir ;
            end
			'd3: begin	// bfu
                buf_b_r_mapping_mode  = bfu_b_r_mapping_mode  ;
                buf_b_base_raddr      = bfu_b_base_raddr      ;
                buf_r_bvn0            = bfu_r_bvn0            ;
                buf_r_avn1            = bfu_r_avn1            ;
                buf_r_bvn1            = bfu_r_bvn1            ;
                buf_bvn0_ren          = bfu_bvn0_ren          ;
                buf_avn1_ren          = bfu_avn1_ren          ;
                buf_bvn1_ren          = bfu_bvn1_ren          ;
                buf_b_w_mapping_mode  = bfu_b_w_mapping_mode  ;
                buf_b_base_waddr      = bfu_b_base_waddr      ;
                buf_w_bvn0            = bfu_w_bvn0            ;
                buf_w_avn1            = bfu_w_avn1            ;
                buf_w_bvn1            = bfu_w_bvn1            ;
                buf_bvn0_wen          = bfu_bvn0_wen          ;
                buf_avn1_wen          = bfu_avn1_wen          ;
                buf_bvn1_wen          = bfu_bvn1_wen          ;
			end
			'd5: begin	// fmt
                buf_b_r_mapping_mode  = fmt_b_r_mapping_mode  ;
                buf_b_base_raddr      = fmt_b_base_raddr      ;
                buf_r_bvn0            = fmt_r_bvn0            ;
                buf_r_avn1            = fmt_r_avn1            ;
                buf_r_bvn1            = fmt_r_bvn1            ;
                buf_bvn0_ren          = fmt_bvn0_ren          ;
                buf_avn1_ren          = fmt_avn1_ren          ;
                buf_bvn1_ren          = fmt_bvn1_ren          ;
                buf_b_w_mapping_mode  = fmt_b_w_mapping_mode  ;
                buf_b_base_waddr      = fmt_b_base_waddr      ;
                buf_w_bvn0            = fmt_w_bvn0            ;
                buf_w_avn1            = fmt_w_avn1            ;
                buf_w_bvn1            = fmt_w_bvn1            ;
                buf_bvn0_wen          = fmt_bvn0_wen          ;
                buf_avn1_wen          = fmt_avn1_wen          ;
                buf_bvn1_wen          = fmt_bvn1_wen          ;
			end
		endcase
end

buffer_top u_buffer_top (
    .clk               (clk             ),
    .rstn              (rstn            ),
    .security_level    (security_level  ),
    .buffer_r_mode,
    .buffer_w_mode,
    .poly_adjoint,

    .av0_raddr_dir (buf_av0_raddr_dir),
    .bv0_raddr_dir (buf_bv0_raddr_dir),
    .av1_raddr_dir (buf_av1_raddr_dir),
    .bv1_raddr_dir (buf_bv1_raddr_dir),
    .av0_r_bs_dir  (buf_av0_r_bs_dir),
    .bv0_r_bs_dir  (buf_bv0_r_bs_dir),
    .av1_r_bs_dir  (buf_av1_r_bs_dir),
    .bv1_r_bs_dir  (buf_bv1_r_bs_dir),

    .av0_waddr_dir (buf_av0_waddr_dir),
    .bv0_waddr_dir (buf_bv0_waddr_dir),
    .av1_waddr_dir (buf_av1_waddr_dir),
    .bv1_waddr_dir (buf_bv1_waddr_dir),
    .av0_w_bs_dir   (buf_av0_w_bs_dir),
    .bv0_w_bs_dir   (buf_bv0_w_bs_dir),
    .av1_w_bs_dir   (buf_av1_w_bs_dir),
    .bv1_w_bs_dir   (buf_bv1_w_bs_dir),

    .a_r_mapping_mode  (buf_a_r_mapping_mode),
    .b_r_mapping_mode  (buf_b_r_mapping_mode),
    .a_base_raddr      (buf_a_base_raddr    ),
    .b_base_raddr      (buf_b_base_raddr    ),
    .r_avn0            (buf_r_avn0),
    .r_bvn0            (buf_r_bvn0),
    .r_avn1            (buf_r_avn1),
    .r_bvn1            (buf_r_bvn1),
    .avn0_ren          (buf_avn0_ren),
    .bvn0_ren          (buf_bvn0_ren),
    .avn1_ren          (buf_avn1_ren),
    .bvn1_ren          (buf_bvn1_ren),
    .r_av0             (buf_r_av0       ),
    .r_bv0             (buf_r_bv0       ),
    .r_av1             (buf_r_av1       ),
    .r_bv1             (buf_r_bv1       ),

    .a_w_mapping_mode  (buf_a_w_mapping_mode    ),
    .b_w_mapping_mode  (buf_b_w_mapping_mode    ),
    .a_base_waddr      (buf_a_base_waddr),
    .b_base_waddr      (buf_b_base_waddr),
    .w_avn0            (buf_w_avn0      ),
    .w_bvn0            (buf_w_bvn0      ),
    .w_avn1            (buf_w_avn1      ),
    .w_bvn1            (buf_w_bvn1      ),
    .avn0_wen          (buf_avn0_wen    ),
    .bvn0_wen          (buf_bvn0_wen    ),
    .avn1_wen          (buf_avn1_wen    ),
    .bvn1_wen          (buf_bvn1_wen    ),
    .w_av0             (buf_w_av0       ),
    .w_bv0             (buf_w_bv0       ),
    .w_av1             (buf_w_av1       ),
    .w_bv1             (buf_w_bv1       )
);

always_comb begin
    case (sys_r_sel)
        2'b00: sys_r_data   = buf_r_av0[1*32-1 -: 32];
        2'b01: sys_r_data   = buf_r_av0[2*32-1 -: 32];
        2'b10: sys_r_data   = buf_r_av0[3*32-1 -: 32];
        default: sys_r_data = buf_r_av0[4*32-1 -: 32];
    endcase
end

endmodule
