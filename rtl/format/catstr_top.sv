`include "../defines/defines.sv"

module catstr_top (
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
    output logic cat_a_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] cat_a_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    cat_r_avn1,
    input  logic [`VEC_BITS-1:0]         cat_r_av1,
    output logic cat_avn1_ren,

    // write buffer
    output logic cat_a_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] cat_a_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    cat_w_avn1,
    output logic [`VEC_BITS-1:0]         cat_w_av1,
    output logic cat_avn1_wen,

    output logic cat_finish_o
);

// taskcode interface
wire [2:0]             op              = taskcode[ 2: 0];
wire [`ADDR_WIDTH-1:0] src1_addr       = taskcode[11: 3];
wire [4:0]             src1_length     = taskcode[16:12];  // should be 0 when cat message
wire [5:0]             src1_validbytes = taskcode[22:17];
wire [`ADDR_WIDTH-1:0] src2_addr       = taskcode[31:23];
wire [4:0]             src2_length     = taskcode[36:32];
wire [5:0]             src2_validbytes = taskcode[42:37];
wire [`ADDR_WIDTH-1:0] dst_addr        = taskcode[51:43];
wire [6:0]             wr_length       = taskcode[61:55];
wire [1:0]             format_sub_op   = taskcode[63:62];

wire task_catstr   = (op=='d5) && (format_sub_op[0]==1'b0);
wire cat_message   = (format_sub_op[1]==1'b1);

wire [`ADDR_WIDTH-1:0] src1_addr_mes = src1_addr + m_lines - ((m_bytes=='d0) ? 'd1 : 'd0);  // if last line is full, src1 points to the last line of m
wire [`ADDR_WIDTH-1:0] src1_addr_dyn = cat_message ? src1_addr_mes : src1_addr;
wire [4:0] src1_length_dyn = cat_message ? ((m_bytes=='d0) ? 'd1 : 'd0) : src1_length;
wire [5:0] src1_validbytes_dyn = cat_message ? m_bytes : src1_validbytes;
wire [`ADDR_WIDTH-1:0] dst_addr_dyn = cat_message ? src1_addr_mes : dst_addr;

// catstr core signals
logic        cat_start;
logic        cat_finish;
logic [7:0]  cat_roffset;
logic        cat_rd_flag;
logic [`VEC_BITS-1:0] cat_rdata;
logic        cat_ren;
logic        cat_vld_i;
logic [7:0]  cat_woffset;
logic [`VEC_BITS-1:0] cat_wdata;
logic        cat_wen;

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) cat_start <= 1'b0;
    else if (cat_start == 1'b1) cat_start <= 1'b0;
    else if ( task_catstr && taskcode_vld) cat_start <= 1'b1;
end
dffe_pipe #(
    .WIDTH(1'b1),
    .DELAY(`FORMAT_RD_LATENCY)
) u_dffe_pipe_cat_vld_i (
    .clk,
    .en(1'b1),
    .d(cat_ren),
    .q(cat_vld_i)
);
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) cat_finish_o <= 1'b0;
    else cat_finish_o <= cat_finish;
end

// top interface

wire [1:0] cat_roffset_lo = cat_roffset[1:0];
wire [5:0] cat_roffset_hi = cat_roffset >> 2;
wire [1:0] cat_woffset_lo = cat_woffset[1:0];
wire [5:0] cat_woffset_hi = cat_woffset >> 2;

assign cat_a_r_mapping_mode = 1'b0;
assign cat_a_base_raddr = (cat_rd_flag ? src2_addr : src1_addr_dyn) + cat_roffset_hi;
always_comb begin
    case (cat_roffset_lo)
        'd1: begin
            cat_r_avn1 = 'd1;
        end
        'd2: begin
            cat_r_avn1 = security_level ? 'd128 : 'd64;
        end
        'd3: begin
            cat_r_avn1 = security_level ? 'd129 : 'd65;
        end
        default: begin  // 0
            cat_r_avn1 = 'd0;
        end
    endcase
end
assign cat_rdata = cat_r_av1;
assign cat_avn1_ren = cat_ren;

assign cat_a_w_mapping_mode = 1'b0;
assign cat_a_base_waddr = dst_addr_dyn + cat_woffset_hi;
always_comb begin
    case (cat_woffset_lo)
        'd1: begin
            cat_w_avn1 = 'd1;
        end
        'd2: begin
            cat_w_avn1 = security_level ? 'd128 : 'd64;
        end
        'd3: begin
            cat_w_avn1 = security_level ? 'd129 : 'd65;
        end
        default: begin  // 0
            cat_w_avn1 = 'd0;
        end
    endcase
end
assign cat_w_av1 = cat_wdata;
assign cat_avn1_wen = cat_wen;

// core

catstr u_catstr (
    
    .clk              (clk),
    .rstn             (rstn),
    .security_level   (security_level),
    
    .cat_start        (cat_start),
    .cat_finish       (cat_finish),
    .src1_length      (src1_length_dyn),
    .src1_validbytes  (src1_validbytes_dyn),
    .src2_length      (src2_length),
    .src2_validbytes  (src2_validbytes),
    .wr_length        (wr_length),
    
    .cat_roffset      (cat_roffset),
    .cat_rd_flag      (cat_rd_flag),
    .cat_rdata        (cat_rdata),
    .cat_ren          (cat_ren),
    .cat_vld_i        (cat_vld_i),
    .cat_woffset      (cat_woffset),
    .cat_wdata        (cat_wdata),
    .cat_wen          (cat_wen)
);

endmodule
