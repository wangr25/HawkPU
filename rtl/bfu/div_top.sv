
module div_top #(
  parameter int P = 2,
  parameter int M = 64,
  parameter int N = 32
) (
  input   logic           clk,
  input   logic           rst_n,
  input   logic           start,
  output  logic           done_o,
  input   logic [9:0]     rd_base_addr,
  input   logic [9:0]     wr_base_addr,
  input   logic [9:0]     depth, //depth = NUM / P
  output  logic           rd_mem_en_x,
  output  logic           rd_mem_en_y,
  output  logic           wr_memen,
  output  logic [9:0]     rd_mem_addr_x,
  output  logic [9:0]     rd_mem_addr_y,
  output  logic [9:0]     wr_mem_addr,
  input   logic [P*M-1:0] x_in,
  input   logic [P*N-1:0] y_in,
  output  logic [P*N-1:0] q_out
);

localparam L = 2;  // 2 stage pipeline


  logic [9:0] rd_base_addr_r, wr_base_addr_r;

  always_ff @(posedge clk) begin
      if(start) begin
          rd_base_addr_r <= rd_base_addr;
          wr_base_addr_r <= wr_base_addr;
      end
  end

  logic [P-1:0] div_done;
  logic [P-1:0] div_done_1;

  logic [9:0] depth_cnt;
  logic [9:0] depth_cnt_x2;

  logic [9:0] wr_cnt;
  logic wr_cnt_done;
  wire done;


  wire div_start = (start | div_done[0]) && (!done);


  logic div_start_d,div_start_2d,div_start_3d,div_start_4d,div_start_5d;
  (* dont_touch = "true" *)  logic [P:0] div_start_6d;
  logic div_start_7d;

  always_ff @(posedge clk,negedge rst_n) begin
        if(!rst_n) begin
          div_start_d  <= 'd0;
          div_start_2d <= 'd0;
          div_start_3d <= 'd0;
          div_start_4d <= 'd0;
          div_start_5d <= 'd0;
          div_start_7d <= 'd0;
        end else begin
          div_start_d <= div_start;
          div_start_2d <= div_start_d;
          div_start_3d <= div_start_2d;
          div_start_4d <= div_start_3d;
          div_start_5d <= div_start_4d;
          div_start_7d <= div_start_6d[0];
        end
  end

int ii;
  always_ff @(posedge clk,negedge rst_n) begin
    for (ii=0; ii<=P; ii=ii+1) begin
        if (!rst_n) begin
          div_start_6d[ii] <= 1'b0;
        end else begin
          div_start_6d[ii] <= div_start_5d;
        end
    end
  end

  assign rd_mem_en_x = div_start_d | div_start_3d;

  assign rd_mem_en_y = div_start_2d | div_start_4d;

  assign rd_mem_addr_x = rd_base_addr_r + depth_cnt_x2 + div_start_3d;

  assign rd_mem_addr_y = rd_base_addr_r + depth_cnt_x2 + div_start_4d;

  counter_ce #(
    .BW(10)
  ) u_cnt_i (
    .clk,
    .rst_n,
    .start (start),
    .num   (depth/L),  // 2 stage pipeline
    .run   (div_done[0]),
    .cnt   (depth_cnt),
    .cnt_en(),
    .last  (),
    .done  (done)
  );

  assign depth_cnt_x2 = depth_cnt << 1;

  counter_ce #(
    .BW(10)
  ) u_div_wr_cnt (
    .clk,
    .rst_n,
    .start (start),
    .num   (depth),
    .run   (wr_memen),
    .cnt   (wr_cnt),
    .cnt_en(),
    .last  (),
    .done  (wr_cnt_done)
  );

  assign wr_memen = div_done[0] | div_done_1[0];

  assign wr_mem_addr = wr_base_addr_r + wr_cnt;



  logic [P*M-1:0] x_in_reg;
  logic [P*N-1:0] y_in_reg;

  always_ff @(posedge clk) begin
      if(div_start_5d | div_start_7d)
        x_in_reg <= x_in;
  end
  always_ff @(posedge clk) begin
      if(div_start_5d | div_start_7d)
        y_in_reg <= y_in;
  end

logic [P*M-1:0] div_x_in;
logic [P*N-1:0] div_y_in;

assign div_x_in = x_in_reg;
assign div_y_in = y_in_reg;

   genvar i;


   generate
      for(i=0;i<P;i=i+1) begin
      div_round_multi_stages_pipe u_div
      (
        .clk,
        .rst_n,
        .start(div_start_6d[i+1]),
        .done (div_done[i]),
        .done_1 (div_done_1[i]),
        .x_in (div_x_in[M*i+:M]),
        .y_in (div_y_in[N*i+:N]),
        .q_out(q_out[N*i+:N])
      );
    end
  endgenerate


assign done_o = wr_cnt_done;

endmodule
