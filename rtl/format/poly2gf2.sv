`include "../defines/defines.sv"

// convert poly to gf2
// input 2 vectors
// output 1 vector to a signle bank
module poly2gf2 (
    input  logic clk,
    input  logic rstn,
    input  logic security_level,

    input  logic p2g_start,
    output logic p2g_finish,

    // offset count from 0
    output logic [`ADDR_WIDTH-1:0] p2g_roffset,
    input  logic [2*`VEC_BITS-1:0] p2g_rdata,
    output logic p2g_ren,
    input  logic p2g_vld_i,

    output logic [`ADDR_WIDTH-1:0] p2g_woffset,
    output logic [1*`VEC_BITS-1:0] p2g_wdata,
    output logic p2g_wen

);

wire [7:0] rd_cnt_num = security_level ? 'd128 : 'd64;
logic [7:0] rd_cnt;  // 0~63/127
logic rd_cnt_en;
logic rd_cnt_done;

  counter_ce_cntclear #(
    .BW($bits(rd_cnt_num))
  ) u_p2g_rd_cnt (
    .clk,
    .rst_n(rstn),
    .start (p2g_start),
    .num   (rd_cnt_num),
    .run   (1'b1),
    .cnt   (rd_cnt),
    .cnt_en(rd_cnt_en),
    .last  (),
    .done  (rd_cnt_done)
  );

assign p2g_roffset = rd_cnt;
assign p2g_ren = rd_cnt_en;

wire [3:0] wr_cnt_num = security_level ? 'd8 : 'd4;
logic [3:0] wr_cnt;  // 0~3/7
logic wr_cnt_run;
logic wr_cnt_en;
logic wr_cnt_done;
assign wr_cnt_run = p2g_wen;

  counter_ce #(
    .BW($bits(wr_cnt_num))
  ) u_p2g_wr_cnt (
    .clk,
    .rst_n(rstn),
    .start (p2g_start),
    .num   (wr_cnt_num),
    .run   (wr_cnt_run),
    .cnt   (wr_cnt),
    .cnt_en(wr_cnt_en),
    .last  (),
    .done  (wr_cnt_done)
  );

assign p2g_woffset = wr_cnt;

logic [7:0] rd_cnt_q;
dffe_pipe #(
    .WIDTH($bits(rd_cnt_q)),
    .DELAY(`FORMAT_RD_LATENCY)
) u_dffe_pipe_p2g_rd_cnt_q (
    .clk,
    .en(1'b1),
    .d(rd_cnt),
    .q(rd_cnt_q)
);

wire [3:0] rd_cnt_q_lo = rd_cnt_q[3:0];
logic [7:0] buff [16];
logic [7:0] poly2gf2_data;
logic p2g_en;
logic wen;  // inner wen

assign poly2gf2_data = {
    p2g_rdata[7*32],
    p2g_rdata[6*32],
    p2g_rdata[5*32],
    p2g_rdata[4*32],
    p2g_rdata[3*32],
    p2g_rdata[2*32],
    p2g_rdata[1*32],
    p2g_rdata[0*32]
};

always_ff @(posedge clk) begin
    if (p2g_vld_i) begin
        buff[rd_cnt_q_lo] <= poly2gf2_data;
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) p2g_en <= 1'b0;
    else if (p2g_finish) p2g_en <= 1'b0;
    else if (p2g_start) p2g_en <= 1'b1;
end

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) wen <= 1'b0;
    else if (rd_cnt_q_lo==4'b1111) wen <= 1'b1;
    else wen <= 1'b0;
end
assign p2g_wen = wen && p2g_en;

assign p2g_wdata = {
    buff[15],
    buff[14],
    buff[13],
    buff[12],
    buff[11],
    buff[10],
    buff[ 9],
    buff[ 8],
    buff[ 7],
    buff[ 6],
    buff[ 5],
    buff[ 4],
    buff[ 3],
    buff[ 2],
    buff[ 1],
    buff[ 0]
};

assign p2g_finish = wr_cnt_done;

endmodule
