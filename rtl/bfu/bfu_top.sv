`include "../defines/defines.sv"

module bfu_top (

    input wire clk,
    input wire rstn,
    input wire security_level,
    input wire sys_mode,
	input wire sys_init,

    // taskcode
    input wire [`TC_W-1:0] taskcode,
    input wire [`TC_W-1:0] taskcode_1,
    input wire taskcode_vld,

    // from decoder
    input wire [31:0] bfu_constup,

    // read buffer
    output logic bfu_a_r_mapping_mode_o,
    output logic bfu_b_r_mapping_mode_o,
    output logic [`ADDR_WIDTH-1:0] bfu_a_base_raddr_o,
    output logic [`ADDR_WIDTH-1:0] bfu_b_base_raddr_o,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_r_avn0_o,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_r_bvn0_o,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_r_avn1_o,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_r_bvn1_o,
    input  logic [`VEC_BITS-1:0]         bfu_r_av0,  // data
    input  logic [`VEC_BITS-1:0]         bfu_r_bv0,
    input  logic [`VEC_BITS-1:0]         bfu_r_av1,
    input  logic [`VEC_BITS-1:0]         bfu_r_bv1,
    output logic bfu_avn0_ren_o,
    output logic bfu_bvn0_ren_o,
    output logic bfu_avn1_ren_o,
    output logic bfu_bvn1_ren_o,
	output logic poly_adjoint,

    // write buffer
    output logic bfu_a_w_mapping_mode_o,
    output logic bfu_b_w_mapping_mode_o,
    output logic [`ADDR_WIDTH-1:0] bfu_a_base_waddr_o,
    output logic [`ADDR_WIDTH-1:0] bfu_b_base_waddr_o,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_w_avn0_o,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_w_bvn0_o,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_w_avn1_o,
    output logic [`VEC_NUM_WIDTH-1:0]    bfu_w_bvn1_o,
    output logic [`VEC_BITS-1:0]         bfu_w_av0_o,  // data
    output logic [`VEC_BITS-1:0]         bfu_w_bv0_o,
    output logic [`VEC_BITS-1:0]         bfu_w_av1_o,
    output logic [`VEC_BITS-1:0]         bfu_w_bv1_o,
    output logic bfu_avn0_wen_o,
    output logic bfu_bvn0_wen_o,
    output logic bfu_avn1_wen_o,
    output logic bfu_bvn1_wen_o,

    // to top control
    output logic bfu_finish_o,
    output logic vrfy_finish,
    output logic vrfy_pass
);

    // read buffer
    logic bfu_a_r_mapping_mode;
    logic bfu_b_r_mapping_mode;
    logic [`ADDR_WIDTH-1:0] bfu_a_base_raddr;
    logic [`ADDR_WIDTH-1:0] bfu_b_base_raddr;
    logic [`VEC_NUM_WIDTH-1:0]    bfu_r_avn0;
    logic [`VEC_NUM_WIDTH-1:0]    bfu_r_bvn0;
    logic [`VEC_NUM_WIDTH-1:0]    bfu_r_avn1;
    logic [`VEC_NUM_WIDTH-1:0]    bfu_r_bvn1;
    logic bfu_avn0_ren;
    logic bfu_bvn0_ren;
    logic bfu_avn1_ren;
    logic bfu_bvn1_ren;

    // write buffer
     logic bfu_a_w_mapping_mode;
     logic bfu_b_w_mapping_mode;
     logic [`ADDR_WIDTH-1:0] bfu_a_base_waddr;
     logic [`ADDR_WIDTH-1:0] bfu_b_base_waddr;
     logic [`VEC_NUM_WIDTH-1:0]    bfu_w_avn0;
     logic [`VEC_NUM_WIDTH-1:0]    bfu_w_bvn0;
     logic [`VEC_NUM_WIDTH-1:0]    bfu_w_avn1;
     logic [`VEC_NUM_WIDTH-1:0]    bfu_w_bvn1;
     logic [`VEC_BITS-1:0]         bfu_w_av0;  // data
     logic [`VEC_BITS-1:0]         bfu_w_bv0;
     logic [`VEC_BITS-1:0]         bfu_w_av1;
     logic [`VEC_BITS-1:0]         bfu_w_bv1;
     logic bfu_avn0_wen;
     logic bfu_bvn0_wen;
     logic bfu_avn1_wen;
     logic bfu_bvn1_wen;

    // to top control
     logic bfu_finish;

// vrfy
logic task_post_process;
logic vrfy_post_process_vld;


// bfu -> ctrl
logic bfu_rdy_o;
logic bfu_av0_vld_o;
logic bfu_av1_vld_o;
logic bfu_bv0_vld_o;
logic bfu_bv1_vld_o;
logic msum1_vld;
logic msum2_vld;
logic msum1_eq_msum2;

// ctrl -> bfu
logic polyqround;
logic [3:0] bfu_mode;
logic bfu_ctrl_av0_vld_i;
logic bfu_ctrl_av1_vld_i;
logic bfu_ctrl_bv0_vld_i;
logic bfu_ctrl_bv1_vld_i;
logic bfu_div_av0_vld_i;
logic bfu_div_av1_vld_i;
logic bfu_div_bv0_vld_i;
logic bfu_div_bv1_vld_i;
logic bfu_av0_vld_i;
logic bfu_av1_vld_i;
logic bfu_bv0_vld_i;
logic bfu_bv1_vld_i;
logic bfu_load_str;
logic bfu_a_str;
logic [4:0] a_pre_shift_len;
logic [4:0] b_pre_shift_len;
logic in_permut_sel;
logic bfu_sel_const;
logic [31:0] bfu_const;
logic symbreak_en;
logic symbreak_calc;
logic symbreak_result;
logic out_permut_sel;
logic [4:0] a_post_shift_len;
logic [4:0] b_post_shift_len;
logic post_shift_even;
logic q00_0_set0;

// ctrl -> tw_rom
logic [10:0] tw_rom_ptr;
logic [1:0]  tw_rom_strb;
logic [1:0]  tw_rom_pat_grp;
logic [1:0]  tw_rom_pat_sel;
logic        tw_rom_ren;

// tw_rom -> bfu
logic [31:0] tw_rom_d0a;
logic [31:0] tw_rom_d0b;
logic [31:0] tw_rom_d1a;
logic [31:0] tw_rom_d1b;
logic [31:0] tw_rom_d2a;
logic [31:0] tw_rom_d2b;
logic [31:0] tw_rom_d3a;
logic [31:0] tw_rom_d3b;

// bfu -> div
logic [63:0] Xre[0:3];
logic [63:0] Xim[0:3];
logic [31:0] divisor[0:3];


bfu_control u_bfu_control (
    .clk,
    .rstn,
    .security_level,
    .sys_mode,
    .sys_init,

    .taskcode(taskcode),
    .taskcode_1(taskcode_1),
    .taskcode_vld,

    .bfu_rdy(bfu_rdy_o),
    .bfu_av0_vld_o,
    .bfu_av1_vld_o,
    .bfu_bv0_vld_o,
    .bfu_bv1_vld_o,

    .bfu_constup,

    .polyqround,
    .bfu_mode,
    .bfu_av0_vld_i(bfu_ctrl_av0_vld_i),
    .bfu_av1_vld_i(bfu_ctrl_av1_vld_i),
    .bfu_bv0_vld_i(bfu_ctrl_bv0_vld_i),
    .bfu_bv1_vld_i(bfu_ctrl_bv1_vld_i),
    .bfu_load_str,
    .bfu_a_str,
    .a_pre_shift_len,
    .b_pre_shift_len,
    .in_permut_sel,
    .bfu_sel_const,
    .bfu_const,
    .symbreak_en,
    .symbreak_calc,
    .out_permut_sel,
    .a_post_shift_len,
    .b_post_shift_len,
    .post_shift_even,
    .q00_0_set0,

    .tw_rom_ptr,
    .tw_rom_strb,
    .tw_rom_pat_grp,
    .tw_rom_pat_sel,
    .tw_rom_ren,

    .bfu_finish,

    .msum1_vld,
    .msum2_vld,
    .msum1_eq_msum2,
    .symbreak_result,

    .bfu_a_r_mapping_mode,
    .bfu_b_r_mapping_mode,
    .bfu_a_base_raddr,
    .bfu_b_base_raddr,
    .bfu_r_avn0,
    .bfu_r_bvn0,
    .bfu_r_avn1,
    .bfu_r_bvn1,
    .bfu_avn0_ren,
    .bfu_bvn0_ren,
    .bfu_avn1_ren,
    .bfu_bvn1_ren,
    .poly_adjoint,
    .bfu_a_w_mapping_mode,
    .bfu_b_w_mapping_mode,
    .bfu_a_base_waddr,
    .bfu_b_base_waddr,
    .bfu_w_avn0,
    .bfu_w_bvn0,
    .bfu_w_avn1,
    .bfu_w_bvn1,
    .bfu_avn0_wen,
    .bfu_bvn0_wen,
    .bfu_avn1_wen,
    .bfu_bvn1_wen
);



bfu_datapath u_bfu_datapath (
    .clk,
    .rstn,
    .security_level,
    .sys_mode,
    .polyqround,
    .sys_init,

    .vrfy_post_process(task_post_process),
    .vrfy_post_process_vld,
    .vrfy_finish,

    .rdy_o(bfu_rdy_o),
    .bfu_av0_i(bfu_r_av0),
    .bfu_bv0_i(bfu_r_bv0),
    .bfu_av1_i(bfu_r_av1),
    .bfu_bv1_i(bfu_r_bv1),

    .bfu_av0_vld_i,
    .bfu_av1_vld_i,
    .bfu_bv0_vld_i,
    .bfu_bv1_vld_i,
    .bfu_a_str,
    .bfu_load_str,
    .a_pre_shift_len,
    .b_pre_shift_len,
    .in_permut_sel,
    .bfu_mode,
    .bfu_const,
    .bfu_sel_const,
    .symbreak_en,
    .symbreak_calc,
    .symbreak_result,

    .tw_rom_d0a,
    .tw_rom_d0b,
    .tw_rom_d1a,
    .tw_rom_d1b,
    .tw_rom_d2a,
    .tw_rom_d2b,
    .tw_rom_d3a,
    .tw_rom_d3b,

    .q00_0_set0,
    .out_permut_sel,
    .msum1_vld,
    .msum2_vld,
    .msum1_eq_msum2,
    .a_post_shift_len,
    .b_post_shift_len,
    .post_shift_even,

    .Xre,
    .Xim,
    .divisor,

    .bfu_av0_o(bfu_w_av0),
    .bfu_av1_o(bfu_w_av1),
    .bfu_bv0_o(bfu_w_bv0),
    .bfu_bv1_o(bfu_w_bv1),
    .bfu_av0_vld_o,
    .bfu_av1_vld_o,
    .bfu_bv0_vld_o,
    .bfu_bv1_vld_o
);


// tw ROM
tw_rom u_tw_rom (
    .clk     (clk),
    .rstn    (rstn),
    .ren     (tw_rom_ren),
    .ptr     (tw_rom_ptr),
    .strb    (tw_rom_strb),
    .pat_grp (tw_rom_pat_grp),
    .pat_sel (tw_rom_pat_sel),

    .d0a_o   (tw_rom_d0a),
    .d0b_o   (tw_rom_d0b),
    .d1a_o   (tw_rom_d1a),
    .d1b_o   (tw_rom_d1b),
    .d2a_o   (tw_rom_d2a),
    .d2b_o   (tw_rom_d2b),
    .d3a_o   (tw_rom_d3a),
    .d3b_o   (tw_rom_d3b)
);

// -------------------------------------------------
// inv

logic inv_finish;
logic inv_a_r_mapping_mode;
logic [`ADDR_WIDTH-1:0] inv_a_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] inv_r_avn0;
logic inv_avn0_ren;
logic inv_a_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] inv_a_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] inv_w_avn0;
logic [`VEC_NUM_WIDTH-1:0] inv_w_avn1;
logic [`VEC_BITS-1:0] inv_w_av0;
logic [`VEC_BITS-1:0] inv_w_av1;
logic inv_avn0_wen;
logic inv_avn1_wen;


inv_top u_inv_top (
    .clk                (clk),
    .rstn               (rstn),
    .security_level     (security_level),

    .taskcode           (taskcode),
    .taskcode_vld       (taskcode_vld),

    .inv_finish         (inv_finish),

    // read buffer
    .inv_a_r_mapping_mode (inv_a_r_mapping_mode),
    .inv_a_base_raddr     (inv_a_base_raddr),
    .inv_r_avn0           (inv_r_avn0),
    .inv_r_av0            (bfu_r_av0),
    .inv_avn0_ren         (inv_avn0_ren),

    // write buffer
    .inv_a_w_mapping_mode (inv_a_w_mapping_mode),
    .inv_a_base_waddr     (inv_a_base_waddr),
    .inv_w_avn0           (inv_w_avn0),
    .inv_w_avn1           (inv_w_avn1),
    .inv_w_av0,
    .inv_w_av1,
    .inv_avn0_wen         (inv_avn0_wen),
    .inv_avn1_wen         (inv_avn1_wen)
);

// ----------------------------------------------------------
// div

logic div_finish;

logic div_a_r_mapping_mode;
logic [`ADDR_WIDTH-1:0] div_a_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] div_r_avn0;
logic [`VEC_NUM_WIDTH-1:0] div_r_avn1;
logic div_avn0_ren;
logic div_avn1_ren;

logic div_b_r_mapping_mode;
logic [`ADDR_WIDTH-1:0] div_b_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] div_r_bvn0;
logic [`VEC_NUM_WIDTH-1:0] div_r_bvn1;
logic div_bvn0_ren;
logic div_bvn1_ren;

logic div_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] div_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] div_w_bvn0;
logic [`VEC_NUM_WIDTH-1:0] div_w_bvn1;
logic [`VEC_BITS-1:0] div_w_bv0;
logic [`VEC_BITS-1:0] div_w_bv1;
logic div_bvn0_wen;
logic div_bvn1_wen;

div_wrapper u_div_wrapper (
    .clk                    (clk),
    .rstn                   (rstn),
    .security_level         (security_level),

    // taskcode
    .taskcode               (taskcode),
    .taskcode_vld           (taskcode_vld),

    // input from BFU cores
    .Xre                    (Xre),
    .Xim                    (Xim),
    .divisor                (divisor),

    // output
    .div_finish             (div_finish),
    .bfu_div_av0_vld_i,
    .bfu_div_av1_vld_i,
    .bfu_div_bv0_vld_i,
    .bfu_div_bv1_vld_i,

    // read buffer A
    .div_a_r_mapping_mode   (div_a_r_mapping_mode),
    .div_a_base_raddr       (div_a_base_raddr),
    .div_r_avn0             (div_r_avn0),
    .div_r_avn1             (div_r_avn1),
    .div_avn0_ren           (div_avn0_ren),
    .div_avn1_ren           (div_avn1_ren),

    // read buffer B
    .div_b_r_mapping_mode   (div_b_r_mapping_mode),
    .div_b_base_raddr       (div_b_base_raddr),
    .div_r_bvn0             (div_r_bvn0),
    .div_r_bvn1             (div_r_bvn1),
    .div_bvn0_ren           (div_bvn0_ren),
    .div_bvn1_ren           (div_bvn1_ren),

    // write buffer
    .div_b_w_mapping_mode   (div_b_w_mapping_mode),
    .div_b_base_waddr       (div_b_base_waddr),
    .div_w_bvn0             (div_w_bvn0),
    .div_w_bvn1             (div_w_bvn1),
    .div_w_bv0              (div_w_bv0),
    .div_w_bv1              (div_w_bv1),
    .div_bvn0_wen           (div_bvn0_wen),
    .div_bvn1_wen           (div_bvn1_wen)
);

wire task_bfu  = taskcode[2:0] == 3'b011;
wire task_div  = task_bfu && (taskcode[26:23] == `BFU_DIV_MODE);
wire task_inv  = task_bfu && (taskcode[26:23] == `BFU_INV_MODE);
assign task_post_process = (taskcode[2:0] == 3'b100) && (taskcode[5:3]=='d2);
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) vrfy_post_process_vld <= 1'b0;
    else if (vrfy_post_process_vld==1'b1) vrfy_post_process_vld <= 1'b0;
    else if (task_post_process && taskcode_vld) vrfy_post_process_vld <= 1'b1;
end


// port a 0
always_comb begin
    unique case (1'b1)
        task_div: begin  // rd port a0,a1,b0,b1,  wr port b0,b1
            // a r
            bfu_a_r_mapping_mode_o = div_a_r_mapping_mode;
            bfu_a_base_raddr_o     = div_a_base_raddr;
            // a r 0
            bfu_r_avn0_o           = div_r_avn0;
            bfu_avn0_ren_o         = div_avn0_ren;
            // a r 1
            bfu_r_avn1_o           = div_r_avn1;
            bfu_avn1_ren_o         = div_avn1_ren;
            // a w
            bfu_a_w_mapping_mode_o = bfu_a_w_mapping_mode;
            bfu_a_base_waddr_o     = bfu_a_base_waddr;
            // a w 0
            bfu_avn0_wen_o         = bfu_avn0_wen;
            bfu_w_avn0_o           = bfu_w_avn0;
            bfu_w_av0_o            = bfu_w_av0;
            // a w 1
            bfu_avn1_wen_o         = bfu_avn1_wen;
            bfu_w_avn1_o           = bfu_w_avn1;
            bfu_w_av1_o            = bfu_w_av1;
            // b r
            bfu_b_r_mapping_mode_o = div_b_r_mapping_mode;
            bfu_b_base_raddr_o     = div_b_base_raddr;
            // b r 0
            bfu_r_bvn0_o           = div_r_bvn0;
            bfu_bvn0_ren_o         = div_bvn0_ren;
            // b r 1
            bfu_r_bvn1_o           = div_r_bvn1;
            bfu_bvn1_ren_o         = div_bvn1_ren;
            // b w
            bfu_b_w_mapping_mode_o = div_b_w_mapping_mode;
            bfu_b_base_waddr_o     = div_b_base_waddr;
            // b w 0
            bfu_bvn0_wen_o         = div_bvn0_wen;
            bfu_w_bvn0_o           = div_w_bvn0;
            bfu_w_bv0_o            = div_w_bv0;
            // b w 1
            bfu_bvn1_wen_o         = div_bvn1_wen;
            bfu_w_bvn1_o           = div_w_bvn1;
            bfu_w_bv1_o            = div_w_bv1;
            // finish
            bfu_finish_o           = div_finish;
        end
        task_inv: begin  // rd port a0, wr port a0,a1
            // a r
            bfu_a_r_mapping_mode_o = inv_a_r_mapping_mode;
            bfu_a_base_raddr_o     = inv_a_base_raddr;
            // a r 0
            bfu_r_avn0_o           = inv_r_avn0;
            bfu_avn0_ren_o         = inv_avn0_ren;
            // a r 1
            bfu_r_avn1_o           = bfu_r_avn1;
            bfu_avn1_ren_o         = bfu_avn1_ren;
            // a w
            bfu_a_w_mapping_mode_o = inv_a_w_mapping_mode;
            bfu_a_base_waddr_o     = inv_a_base_waddr;
            // a w 0
            bfu_avn0_wen_o         = inv_avn0_wen;
            bfu_w_avn0_o           = inv_w_avn0;
            bfu_w_av0_o            = inv_w_av0;
            // a w 1
            bfu_avn1_wen_o         = inv_avn1_wen;
            bfu_w_avn1_o           = inv_w_avn1;
            bfu_w_av1_o            = inv_w_av1;
            // b r
            bfu_b_r_mapping_mode_o = bfu_b_r_mapping_mode;
            bfu_b_base_raddr_o     = bfu_b_base_raddr;
            // b r 0
            bfu_r_bvn0_o           = bfu_r_bvn0;
            bfu_bvn0_ren_o         = bfu_bvn0_ren;
            // b r 1
            bfu_r_bvn1_o           = bfu_r_bvn1;
            bfu_bvn1_ren_o         = bfu_bvn1_ren;
            // b w
            bfu_b_w_mapping_mode_o = bfu_b_w_mapping_mode;
            bfu_b_base_waddr_o     = bfu_b_base_waddr;
            // b w 0
            bfu_bvn0_wen_o         = bfu_bvn0_wen;
            bfu_w_bvn0_o           = bfu_w_bvn0;
            bfu_w_bv0_o            = bfu_w_bv0;
            // b w 1
            bfu_bvn1_wen_o         = bfu_bvn1_wen;
            bfu_w_bvn1_o           = bfu_w_bvn1;
            bfu_w_bv1_o            = bfu_w_bv1;
            // finish
            bfu_finish_o           = inv_finish;
        end
        default: begin
            // a r
            bfu_a_r_mapping_mode_o = bfu_a_r_mapping_mode;
            bfu_a_base_raddr_o     = bfu_a_base_raddr;
            // a r 0
            bfu_r_avn0_o           = bfu_r_avn0;
            bfu_avn0_ren_o         = bfu_avn0_ren;
            // a r 1
            bfu_r_avn1_o           = bfu_r_avn1;
            bfu_avn1_ren_o         = bfu_avn1_ren;
            // a w
            bfu_a_w_mapping_mode_o = bfu_a_w_mapping_mode;
            bfu_a_base_waddr_o     = bfu_a_base_waddr;
            // a w 0
            bfu_avn0_wen_o         = bfu_avn0_wen;
            bfu_w_avn0_o           = bfu_w_avn0;
            bfu_w_av0_o            = bfu_w_av0;
            // a w 1
            bfu_avn1_wen_o         = bfu_avn1_wen;
            bfu_w_avn1_o           = bfu_w_avn1;
            bfu_w_av1_o            = bfu_w_av1;
            // b r
            bfu_b_r_mapping_mode_o = bfu_b_r_mapping_mode;
            bfu_b_base_raddr_o     = bfu_b_base_raddr;
            // b r 0
            bfu_r_bvn0_o           = bfu_r_bvn0;
            bfu_bvn0_ren_o         = bfu_bvn0_ren;
            // b r 1
            bfu_r_bvn1_o           = bfu_r_bvn1;
            bfu_bvn1_ren_o         = bfu_bvn1_ren;
            // b w
            bfu_b_w_mapping_mode_o = bfu_b_w_mapping_mode;
            bfu_b_base_waddr_o     = bfu_b_base_waddr;
            // b w 0
            bfu_bvn0_wen_o         = bfu_bvn0_wen;
            bfu_w_bvn0_o           = bfu_w_bvn0;
            bfu_w_bv0_o            = bfu_w_bv0;
            // b w 1
            bfu_bvn1_wen_o         = bfu_bvn1_wen;
            bfu_w_bvn1_o           = bfu_w_bvn1;
            bfu_w_bv1_o            = bfu_w_bv1;
            // finish
            bfu_finish_o           = bfu_finish;
        end
    endcase
end

always_comb begin
    if (task_div) begin
        bfu_av0_vld_i = bfu_div_av0_vld_i;
        bfu_av1_vld_i = bfu_div_av1_vld_i;
        bfu_bv0_vld_i = bfu_div_bv0_vld_i;
        bfu_bv1_vld_i = bfu_div_bv1_vld_i;
    end
    else begin
        bfu_av0_vld_i = bfu_ctrl_av0_vld_i;
        bfu_av1_vld_i = bfu_ctrl_av1_vld_i;
        bfu_bv0_vld_i = bfu_ctrl_bv0_vld_i;
        bfu_bv1_vld_i = bfu_ctrl_bv1_vld_i;
    end
end

assign vrfy_pass = msum1_eq_msum2;

endmodule
