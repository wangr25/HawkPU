`include "../defines/defines.sv"

module poly2gf2_top (
    input  logic clk,
    input  logic rstn,
    input  logic security_level,

    // taskcode
    input  logic [`TC_W-1:0] taskcode,
    input  logic taskcode_vld,

    // read buffer
    output logic p2g_b_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] p2g_b_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    p2g_r_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    p2g_r_bvn1,
    input  logic [`VEC_BITS-1:0]         p2g_r_bv0,
    input  logic [`VEC_BITS-1:0]         p2g_r_bv1,
    output logic p2g_bvn0_ren,
    output logic p2g_bvn1_ren,

    // write buffer
    output logic p2g_b_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] p2g_b_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    p2g_w_bvn0,
    output logic [`VEC_BITS-1:0]         p2g_w_bv0,
    output logic p2g_bvn0_wen,

    output logic p2g_finish_o
);

// taskcode interface
wire [2:0]             op              = taskcode[ 2: 0];
wire [`ADDR_WIDTH-1:0] src1_addr       = taskcode[11: 3];
wire [`ADDR_WIDTH-1:0] dst_addr        = taskcode[51:43];
wire                   src1_mapping_mode = taskcode[52];
wire [1:0]             format_sub_op   = taskcode[63:62];

wire task_poly2gf2   = (op=='d5) && (format_sub_op==`FORM_FUNCT_P2G);

// poly2gf2 core signals
logic        p2g_start;
logic        p2g_finish;

logic [`ADDR_WIDTH-1:0] p2g_roffset;
logic [2*`VEC_BITS-1:0] p2g_rdata;
logic        p2g_ren;
logic        p2g_vld_i;

logic [`ADDR_WIDTH-1:0] p2g_woffset;
logic [1*`VEC_BITS-1:0] p2g_wdata;
logic        p2g_wen;

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) p2g_start <= 1'b0;
    else if (p2g_start == 1'b1) p2g_start <= 1'b0;
    else if ( task_poly2gf2 && taskcode_vld) p2g_start <= 1'b1;
end
dffe_pipe #(
    .WIDTH(1'b1),
    .DELAY(`FORMAT_RD_LATENCY)
) u_dffe_pipe_p2g_vld_i (
    .clk,
    .en(1'b1),
    .d(p2g_ren),
    .q(p2g_vld_i)
);

// top interface
assign p2g_b_r_mapping_mode = src1_mapping_mode;
assign p2g_b_base_raddr     = src1_addr;
assign p2g_r_bvn0 = {p2g_roffset,1'b0};
assign p2g_r_bvn1 = p2g_r_bvn0 | 1'b1;
assign p2g_rdata = {p2g_r_bv1, p2g_r_bv0};
assign p2g_bvn0_ren = p2g_ren;
assign p2g_bvn1_ren = p2g_ren;

assign p2g_b_w_mapping_mode = 1'b0;
assign p2g_b_base_waddr = dst_addr + p2g_woffset;  // seed type
assign p2g_w_bvn0 = 'd1;
assign p2g_w_bv0 = p2g_wdata;
assign p2g_bvn0_wen = p2g_wen;
always_ff @(posedge clk) begin
    p2g_finish_o <= p2g_finish;
end

poly2gf2 u_poly2gf2 (
    .clk             (clk),
    .rstn            (rstn),
    .security_level  (security_level),
    
    .p2g_start       (p2g_start),
    .p2g_finish      (p2g_finish),
    
    .p2g_roffset     (p2g_roffset),
    .p2g_rdata       (p2g_rdata),
    .p2g_ren         (p2g_ren),
    .p2g_vld_i       (p2g_vld_i),
    
    .p2g_woffset     (p2g_woffset),
    .p2g_wdata       (p2g_wdata),
    .p2g_wen         (p2g_wen)
);

endmodule
