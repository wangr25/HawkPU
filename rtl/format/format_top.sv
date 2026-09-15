`include "../defines/defines.sv"

module format_top (

    input  logic clk,
    input  logic rstn,
    input  logic security_level,

    // taskcode
    input  logic [`TC_W-1:0] taskcode,
    input  logic taskcode_vld,
    // message
    input wire [`ADDR_WIDTH-1:0] m_lines,
    input wire [5:0] m_bytes,

    // read buffer
    output logic fmt_a_r_mapping_mode,
    output logic fmt_b_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] fmt_a_base_raddr,
    output logic [`ADDR_WIDTH-1:0] fmt_b_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    fmt_r_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    fmt_r_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    fmt_r_avn1,
    output logic [`VEC_NUM_WIDTH-1:0]    fmt_r_bvn1,
    input  logic [`VEC_BITS-1:0]         fmt_r_av0,
    input  logic [`VEC_BITS-1:0]         fmt_r_bv0,
    input  logic [`VEC_BITS-1:0]         fmt_r_av1,
    input  logic [`VEC_BITS-1:0]         fmt_r_bv1,
    output logic fmt_avn0_ren,
    output logic fmt_bvn0_ren,
    output logic fmt_avn1_ren,
    output logic fmt_bvn1_ren,

    // write buffer
    output logic fmt_a_w_mapping_mode,
    output logic fmt_b_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] fmt_a_base_waddr,
    output logic [`ADDR_WIDTH-1:0] fmt_b_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    fmt_w_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    fmt_w_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    fmt_w_avn1,
    output logic [`VEC_NUM_WIDTH-1:0]    fmt_w_bvn1,
    output logic [`VEC_BITS-1:0]         fmt_w_av0,
    output logic [`VEC_BITS-1:0]         fmt_w_bv0,
    output logic [`VEC_BITS-1:0]         fmt_w_av1,
    output logic [`VEC_BITS-1:0]         fmt_w_bv1,
    output logic fmt_avn0_wen,
    output logic fmt_bvn0_wen,
    output logic fmt_avn1_wen,
    output logic fmt_bvn1_wen,

    output logic fmt_finish

);

wire [2:0]             op              = taskcode[ 2: 0];
wire [1:0]             format_sub_op   = taskcode[63:62];
wire task_catstr   = (op=='d5) && (format_sub_op[0]==1'b0);
wire task_poly2gf2   = (op=='d5) && (format_sub_op==`FORM_FUNCT_P2G);

// catstr_top
logic        cat_a_r_mapping_mode;
logic [`ADDR_WIDTH-1:0] cat_a_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] cat_r_avn1;
logic [`VEC_BITS-1:0] cat_r_av1;
logic        cat_avn1_ren;

logic        cat_a_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] cat_a_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] cat_w_avn1;
logic [`VEC_BITS-1:0] cat_w_av1;
logic        cat_avn1_wen;
logic        cat_finish_o;

// poly2gf2_top
logic        p2g_b_r_mapping_mode;
logic [`ADDR_WIDTH-1:0] p2g_b_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] p2g_r_bvn0;
logic [`VEC_NUM_WIDTH-1:0] p2g_r_bvn1;
logic [`VEC_BITS-1:0] p2g_r_bv0;
logic [`VEC_BITS-1:0] p2g_r_bv1;
logic        p2g_bvn0_ren;
logic        p2g_bvn1_ren;

logic        p2g_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] p2g_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] p2g_w_bvn0;
logic [`VEC_BITS-1:0] p2g_w_bv0;
logic        p2g_bvn0_wen;
logic        p2g_finish_o;

// str2gf2_top
logic        s2g_a_r_mapping_mode;
logic [`ADDR_WIDTH-1:0] s2g_a_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] s2g_r_avn0;
logic [`VEC_BITS-1:0] s2g_r_av0;
logic        s2g_avn0_ren;

logic        s2g_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] s2g_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] s2g_w_bvn1;
logic [`VEC_BITS-1:0] s2g_w_bv1;
logic        s2g_bvn1_wen;
logic        s2g_finish_o;


// inst

catstr_top u_catstr_top (
    .clk                    (clk),
    .rstn                   (rstn),
    .security_level         (security_level),
    
    .taskcode               (taskcode),
    .taskcode_vld           (taskcode_vld),
    .m_lines                (m_lines),
    .m_bytes                (m_bytes),
    
    .cat_a_r_mapping_mode   (cat_a_r_mapping_mode),
    .cat_a_base_raddr       (cat_a_base_raddr),
    .cat_r_avn1             (cat_r_avn1),
    .cat_r_av1              (cat_r_av1),
    .cat_avn1_ren           (cat_avn1_ren),
    
    .cat_a_w_mapping_mode   (cat_a_w_mapping_mode),
    .cat_a_base_waddr       (cat_a_base_waddr),
    .cat_w_avn1             (cat_w_avn1),
    .cat_w_av1              (cat_w_av1),
    .cat_avn1_wen           (cat_avn1_wen),
    
    .cat_finish_o           (cat_finish_o)
);

poly2gf2_top u_poly2gf2_top (

    .clk                  (clk),
    .rstn                 (rstn),
    .security_level       (security_level),
    
    .taskcode             (taskcode),
    .taskcode_vld         (taskcode_vld),
    
    .p2g_b_r_mapping_mode (p2g_b_r_mapping_mode),
    .p2g_b_base_raddr     (p2g_b_base_raddr),
    .p2g_r_bvn0           (p2g_r_bvn0),
    .p2g_r_bvn1           (p2g_r_bvn1),
    .p2g_r_bv0            (p2g_r_bv0),
    .p2g_r_bv1            (p2g_r_bv1),
    .p2g_bvn0_ren         (p2g_bvn0_ren),
    .p2g_bvn1_ren         (p2g_bvn1_ren),
    
    .p2g_b_w_mapping_mode (p2g_b_w_mapping_mode),
    .p2g_b_base_waddr     (p2g_b_base_waddr),
    .p2g_w_bvn0           (p2g_w_bvn0),
    .p2g_w_bv0            (p2g_w_bv0),
    .p2g_bvn0_wen         (p2g_bvn0_wen),
    
    .p2g_finish_o         (p2g_finish_o)
);

str2gf2_top u_str2gf2_top (

    .clk                  (clk),
    .rstn                 (rstn),
    .security_level       (security_level),
    
    .taskcode             (taskcode),
    .taskcode_vld         (taskcode_vld),
    
    .s2g_a_r_mapping_mode (s2g_a_r_mapping_mode),
    .s2g_a_base_raddr     (s2g_a_base_raddr),
    .s2g_r_avn0           (s2g_r_avn0),
    .s2g_r_av0            (s2g_r_av0),
    .s2g_avn0_ren         (s2g_avn0_ren),
    
    .s2g_b_w_mapping_mode (s2g_b_w_mapping_mode),
    .s2g_b_base_waddr     (s2g_b_base_waddr),
    .s2g_w_bvn1           (s2g_w_bvn1),
    .s2g_w_bv1            (s2g_w_bv1),
    .s2g_bvn1_wen         (s2g_bvn1_wen),
    
    .s2g_finish_o         (s2g_finish_o)
);

// bus

assign fmt_a_r_mapping_mode = task_catstr ? cat_a_r_mapping_mode : s2g_a_r_mapping_mode;
assign fmt_a_base_raddr = task_catstr ? cat_a_base_raddr : s2g_a_base_raddr;
assign fmt_r_avn0 = s2g_r_avn0;
assign fmt_r_avn1 = cat_r_avn1;
assign fmt_avn0_ren = s2g_avn0_ren;
assign fmt_avn1_ren = cat_avn1_ren;

assign fmt_b_r_mapping_mode = p2g_b_r_mapping_mode;
assign fmt_b_base_raddr = p2g_b_base_raddr;
assign fmt_r_bvn0 = p2g_r_bvn0;
assign fmt_r_bvn1 = p2g_r_bvn1;
assign fmt_bvn0_ren = p2g_bvn0_ren;
assign fmt_bvn1_ren = p2g_bvn1_ren;

assign s2g_r_av0 = fmt_r_av0;
assign cat_r_av1 = fmt_r_av1;
assign p2g_r_bv0 = fmt_r_bv0;
assign p2g_r_bv1 = fmt_r_bv1;

assign fmt_a_w_mapping_mode = cat_a_w_mapping_mode;
assign fmt_a_base_waddr = cat_a_base_waddr;
assign fmt_w_avn1 = cat_w_avn1;
assign fmt_w_av1 = cat_w_av1;
assign fmt_avn0_wen = 1'b0;
assign fmt_avn1_wen = cat_avn1_wen;

assign fmt_b_w_mapping_mode = task_poly2gf2 ? p2g_b_w_mapping_mode : s2g_b_w_mapping_mode;  // 0
assign fmt_b_base_waddr = task_poly2gf2 ? p2g_b_base_waddr : s2g_b_base_waddr;
assign fmt_w_bvn0 = p2g_w_bvn0;
assign fmt_w_bvn1 = s2g_w_bvn1;
assign fmt_w_bv0 = p2g_w_bv0;
assign fmt_w_bv1 = s2g_w_bv1;
assign fmt_bvn0_wen = p2g_bvn0_wen;
assign fmt_bvn1_wen = s2g_bvn1_wen;

assign fmt_finish = task_catstr ? cat_finish_o : 
                    (task_poly2gf2 ? p2g_finish_o : s2g_finish_o);

endmodule
