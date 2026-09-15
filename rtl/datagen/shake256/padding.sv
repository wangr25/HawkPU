`include "../../defines/defines.sv"

module padding
(
  input                             clk,
  input                             rst_n,
  input                    [  12:0] start,
  input                    [  11:0] src_addr,
  input                    [  11:0] src_length,
  input                    [   6:0] valid_bytes,
  output                            first,
  output                            last,
  output                            mode,
  output logic             [1087:0] d_o,
  output logic                      d_o_vld,
  output logic [11:0] if_buff_rd_addr,
  output logic  if_buff_rd_en,
  input logic [511:0] if_buff_rd_data
);
  wire       keccak_rdy;

  wire                pad_choose;
  wire                buf_update;
  wire        [  1:0] buf_index;  // choose the buffer to write
  wire        [  2:0] pad_type;  // the type of padding
  wire        [511:0] data_o;

  logic               pad_start;
  logic               buf_vld;
  wire                pad_null;

  wire                padding_buff_rd_en;
  logic [11:0]         padding_buff_rd_addr;

  pipeline_delay_bit #(
    .R(1),
    .P(0),
    .D(`BUFF_RD_LATENCY)
  ) i_start_delay (
    .c(clk),
    .r(rst_n),
    .i(start[0]),
    .o(pad_start)
  );

  logic         rd_data_vld;

  wire  [511:0] data_i = rd_data_vld ? ((pad_null) ? '0 : if_buff_rd_data) : '0;

  wire  [511:0] pad_data = pad_choose ? data_o : data_i;

  logic [511:0] buffer [3];

  always_ff @(posedge clk) begin
    if (start[1])                          buffer[0][(128*1-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==0)) buffer[0][(128*1-1)-:128] <= pad_data[(128*1-1)-:128];
  end
  always_ff @(posedge clk) begin
    if (start[2])                          buffer[0][(128*2-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==0)) buffer[0][(128*2-1)-:128] <= pad_data[(128*2-1)-:128];
  end
  always_ff @(posedge clk) begin
    if (start[3])                          buffer[0][(128*3-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==0)) buffer[0][(128*3-1)-:128] <= pad_data[(128*3-1)-:128];
  end
  always_ff @(posedge clk) begin
    if (start[4])                          buffer[0][(128*4-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==0)) buffer[0][(128*4-1)-:128] <= pad_data[(128*4-1)-:128];
  end

  always_ff @(posedge clk) begin
    if (start[5])                          buffer[1][(128*1-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==1)) buffer[1][(128*1-1)-:128] <= pad_data[(128*1-1)-:128];
  end
  always_ff @(posedge clk) begin
    if (start[6])                          buffer[1][(128*2-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==1)) buffer[1][(128*2-1)-:128] <= pad_data[(128*2-1)-:128];
  end
  always_ff @(posedge clk) begin
    if (start[7])                          buffer[1][(128*3-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==1)) buffer[1][(128*3-1)-:128] <= pad_data[(128*3-1)-:128];
  end
  always_ff @(posedge clk) begin
    if (start[8])                          buffer[1][(128*4-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==1)) buffer[1][(128*4-1)-:128] <= pad_data[(128*4-1)-:128];
  end

  always_ff @(posedge clk) begin
    if (start[9])                          buffer[2][(128*1-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==2)) buffer[2][(128*1-1)-:128] <= pad_data[(128*1-1)-:128];
  end
  always_ff @(posedge clk) begin
    if (start[10])                         buffer[2][(128*2-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==2)) buffer[2][(128*2-1)-:128] <= pad_data[(128*2-1)-:128];
  end
  always_ff @(posedge clk) begin
    if (start[11])                         buffer[2][(128*3-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==2)) buffer[2][(128*3-1)-:128] <= pad_data[(128*3-1)-:128];
  end
  always_ff @(posedge clk) begin
    if (start[12])                         buffer[2][(128*4-1)-:128] <= 128'd0;
    else if (buf_update && (buf_index==2)) buffer[2][(128*4-1)-:128] <= pad_data[(128*4-1)-:128];
  end

  assign d_o          = {buffer[2], buffer[1], buffer[0]};

  assign if_buff_rd_en   = padding_buff_rd_en;
  assign if_buff_rd_addr = padding_buff_rd_addr;


logic [6:0] len_base;
logic [1:0] pad_append_row;
logic [5:0] read_blocks;
assign len_base = src_length[6:0];

div3 u_calc_readblocks (
  .clk(clk),
  .x  ( (valid_bytes =='0) ? len_base : (len_base-7'd1) ),
  .q  (read_blocks)
);
mod3 u_calc_pad_append_row (
  .clk(clk),
  .x  (len_base),
  .r  (pad_append_row)
);


  //////////////////////////////////////////////////////////////////////////////////
  // Instance

  padding_control i_padding_control_rd (
    .clk,
    .rst_n,
    .start (start[0]),
    .src_addr,
    .src_length,
    .keccak_valid_byte(valid_bytes),
    .pad_append_row,
    .read_blocks ({1'b0,read_blocks[5:0]}),
    .buff_rd_en  (padding_buff_rd_en),
    .buff_rd_addr(padding_buff_rd_addr)
  );

  padding_control i_padding_control_wr (
    .clk,
    .rst_n,
    .start     (pad_start),
    .src_addr,
    .src_length,
    .keccak_valid_byte(valid_bytes),
    .pad_append_row,
    .read_blocks ({1'b0,read_blocks[5:0]}),
    .first     (first),
    .last      (last),
    .mode      (mode),
    .pad_choose,
    .pad_type,
    .buf_update,
    .buf_vld,
    .buf_index,
    .keccak_rdy,
    .pad_null,
    .buff_rd_en(rd_data_vld)
  );

  padding_datapath_haw i_padding_datapath (
    .pad_type,
    .addr  (valid_bytes[5:0]),
    .data_i,
    .data_o
  );
  assign d_o_vld = buf_vld & keccak_rdy;

endmodule

module div3 (
  input  logic       clk,
  input  logic [6:0] x,
  output logic [5:0] q
);

  logic [12:0] prod;
  logic [5:0]  q_comb;

  always_comb begin
    prod   = x * 7'd43;
    q_comb = prod >> 7;

  end

  always_ff @(posedge clk) begin
    q <= q_comb;
  end

endmodule

module mod3 (
  input  logic       clk,
  input  logic [6:0] x,
  output logic [1:0] r
);

  logic [2:0] even_sum;
  logic [1:0] odd_sum;
  logic [3:0] diff;

  always_comb begin
    even_sum = x[0] + x[2] + x[4] + x[6]; // 0..4
    odd_sum  = x[1] + x[3] + x[5];         // 0..3

    // +3 : to ensure even_sum-odd_sum is positive
    diff = even_sum + 3 - odd_sum;          // 0..7
  end
  always_ff @(posedge clk) begin
    r <= diff % 3;
  end

endmodule
