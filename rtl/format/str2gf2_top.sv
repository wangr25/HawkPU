`include "../defines/defines.sv"

module str2gf2_top (
    input  logic clk,
    input  logic rstn,
    input  logic security_level,

    // taskcode
    input  logic [`TC_W-1:0] taskcode,
    input  logic taskcode_vld,

    // read buffer
    output logic s2g_a_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] s2g_a_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    s2g_r_avn0,
    input  logic [`VEC_BITS-1:0]         s2g_r_av0,
    output logic s2g_avn0_ren,

    // write buffer
    output logic s2g_b_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] s2g_b_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    s2g_w_bvn1,
    output logic [`VEC_BITS-1:0]         s2g_w_bv1,
    output logic s2g_bvn1_wen,

    output logic s2g_finish_o
);

// taskcode interface
wire [2:0]             op              = taskcode[ 2: 0];
wire [`ADDR_WIDTH-1:0] src1_addr       = taskcode[11: 3];
wire [4:0]             src1_length     = taskcode[16:12];
wire [`ADDR_WIDTH-1:0] dst_addr        = taskcode[51:43];
wire [6:0]             wr_length       = taskcode[61:55];
wire [1:0]             format_sub_op   = taskcode[63:62];

wire task_str2gf2   = (op=='d5) && (format_sub_op==`FORM_FUNCT_S2G);

// str2gf2 core signals
logic        s2g_start;
logic        s2g_en;
logic        s2g_finish;

logic [`VEC_BITS-1:0] s2g_rdata;
logic        s2g_ren;
logic        s2g_vld_i;

logic        s2g_wen;

// buffer
logic [`VEC_BITS-1:0] buff;

// rd_cnt
wire [4:0] rd_cnt_num = {src1_length[2:0], 2'b0};  // 4~16
logic [4:0] rd_cnt;  // 0~3/15
logic rd_cnt_en;
logic rd_cnt_done;

// wr_cnt
wire [4:0] wr_cnt_num = wr_length[4:0];  // 4~16
logic [4:0] wr_cnt;  // 0~4/16
logic wr_cnt_run;
logic wr_cnt_en;
logic wr_cnt_done;

// start, vld_i, en
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) s2g_start <= 1'b0;
    else if (s2g_start == 1'b1) s2g_start <= 1'b0;
    else if ( task_str2gf2 && taskcode_vld) s2g_start <= 1'b1;
end
dffe_pipe #(
    .WIDTH(1'b1),
    .DELAY(`FORMAT_RD_LATENCY)
) u_dffe_pipe_s2g_vld_i (
    .clk,
    .en(1'b1),
    .d(s2g_ren),
    .q(s2g_vld_i)
);
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) s2g_en <= 1'b0;
    else if (s2g_finish) s2g_en <= 1'b0;
    else if (s2g_start) s2g_en <= 1'b1;
end

// rd_cnt
  counter_ce_cntclear #(
    .BW($bits(rd_cnt_num))
  ) u_p2g_rd_cnt (
    .clk,
    .rst_n(rstn),
    .start (s2g_start),
    .num   (rd_cnt_num),
    .run   (1'b1),
    .cnt   (rd_cnt),
    .cnt_en(rd_cnt_en),
    .last  (),
    .done  (rd_cnt_done)
  );
assign s2g_ren = rd_cnt_en;

// wr_cnt
assign wr_cnt_run = s2g_wen;

  counter_ce #(
    .BW($bits(wr_cnt_num))
  ) u_p2g_wr_cnt (
    .clk,
    .rst_n(rstn),
    .start (s2g_start),
    .num   (wr_cnt_num),
    .run   (wr_cnt_run),
    .cnt   (wr_cnt),
    .cnt_en(wr_cnt_en),
    .last  (),
    .done  (wr_cnt_done)
  );

assign s2g_finish = wr_cnt_done;


// str2gf2 core
always_ff @(posedge clk) begin
    if (s2g_vld_i) buff <= s2g_rdata;
end

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) s2g_wen <= 1'b0;
    else s2g_wen <= s2g_vld_i;
end

// top interface
assign s2g_a_r_mapping_mode = 1'b0;
assign s2g_a_base_raddr = src1_addr + (rd_cnt>>2);
always_comb begin
    case(rd_cnt[1:0])
        2'd0: s2g_r_avn0 = 'd0;
        2'd1: s2g_r_avn0 = 'd1;
        2'd2: s2g_r_avn0 = security_level ? 'd128 : 'd64;
        2'd3: s2g_r_avn0 = security_level ? 'd129 : 'd65;
        default: s2g_r_avn0 = 'd0;
    endcase
end
assign s2g_rdata = s2g_r_av0;
assign s2g_avn0_ren = s2g_ren;

assign s2g_b_w_mapping_mode = 1'b0;
assign s2g_b_base_waddr = dst_addr + wr_cnt;
assign s2g_w_bvn1 = 'd0;
assign s2g_w_bv1 = buff;
assign s2g_bvn1_wen = s2g_wen;

always_ff @(posedge clk or negedge rstn) begin
  if (!rstn) s2g_finish_o <= 1'b0;
  else s2g_finish_o <= s2g_finish;
end

endmodule
