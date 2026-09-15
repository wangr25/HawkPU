// 4 stages per round, with 1 internal pipeline

module div_round_multi_stages_pipe #(
  parameter int M = 64,
  parameter int N = 32
) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         start,
  output logic         done,
  output logic         done_1,
  input  logic [M-1:0] x_in,
  input  logic [N-1:0] y_in,
  output logic [N-1:0] q_out
);

localparam S = 4;  // round 4 stages
localparam L = 2;  // 2 stage pipeline

logic div_en;
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) div_en <= 1'b0;
  else if (start) div_en <= 1'b1;
  else if (done_1) div_en <= 1'b0;
end

logic start_d1, start_d2, start_d3;
logic start1;  // start for the second data
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    start_d1 <= 1'b0;
    start_d2 <= 1'b0;
    start_d3 <= 1'b0;
  end
  else begin
    start_d1 <= start;
    start_d2 <= start_d1;
    start_d3 <= start_d2;
  end
end
assign start1 = start_d3;

// sel
logic div_core_i_sel;
logic div_core_o_sel;
always_ff @(posedge clk) begin
  if (start) div_core_i_sel <= 1'b0;
  else if (div_en) div_core_i_sel <= ~div_core_i_sel;
end
always_ff @(posedge clk) begin
  if (start) div_core_o_sel <= 1'b1;
  else if (div_en) div_core_o_sel <= ~div_core_o_sel;
end

// buffer
  logic [N-1:0] y_reg[2];  // dividend
  logic [N:0] x_calc_reg[2];  // internal remainder
  logic [M-1:0] x_reg[2];  // init input, and store quotient

  logic [N+S-1:0] x_calc_in;
  logic [N-1:0] x_calc_out;
  logic [N-1:0] y_calc_in;

// div round stages
  logic [3:0] q_calc;

  always_ff @(posedge clk) if (start) y_reg[0] <= y_in;
  always_ff @(posedge clk) if (start_d3) y_reg[1] <= y_in;

  logic cnt_en, cnt_done, q_calc_out;
  logic cnt_en1, cnt_done1;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) done <= 1'b0;
    else done <= cnt_done;
  end
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) done_1 <= 1'b0;
    else done_1 <= cnt_done1;
  end
  always_ff @(posedge clk) begin
    if (start) x_reg[0] <= x_in;
    else if (cnt_en && (!div_core_o_sel)) x_reg[0] <= {x_reg[0][M-5:0], q_calc};
  end
  always_ff @(posedge clk) begin
    if (start1) x_reg[1] <= x_in;
    else if (cnt_en1 && div_core_o_sel) x_reg[1] <= {x_reg[1][M-5:0], q_calc};
  end


  logic [5:0] div_cnt, div_cnt1;


  always_ff @(posedge clk) begin
    if (start) x_calc_reg[0] <= '0;
    else if (cnt_en && (!div_core_o_sel)) x_calc_reg[0] <= {1'b0,x_calc_out};  //remain number
  end
  always_ff @(posedge clk) begin
    if (start1) x_calc_reg[1] <= '0;
    else if (cnt_en1 && div_core_o_sel) x_calc_reg[1] <= {1'b0,x_calc_out};  //remain number
  end


  assign x_calc_in = div_core_i_sel ? 
                    {x_calc_reg[1][N-1:0], x_reg[1][M-1:M-4]} : 
                    {x_calc_reg[0][N-1:0], x_reg[0][M-1:M-4]}; //iteration x

  assign y_calc_in = div_core_i_sel ? y_reg[1] : y_reg[0];

  assign q_out     = div_core_o_sel ? x_reg[1][N-1:0] : x_reg[0][N-1:0];


  counter_ce #(
    .BW($clog2(M))
  ) u_cnt_i (
    .clk,
    .rst_n,
    .start (start),
    .num   (L*M/S+1),
    .run   (1'b1),
    .cnt   (div_cnt),
    .cnt_en(cnt_en),
    .last  (),
    .done  (cnt_done)
  );
  counter_ce #(
    .BW($clog2(M))
  ) u_cnt_j (
    .clk,
    .rst_n,
    .start (start1),
    .num   (L*M/S+1),
    .run   (1'b1),
    .cnt   (div_cnt1),
    .cnt_en(cnt_en1),
    .last  (),
    .done  (cnt_done1)
  );

  div_round_4_stages_cascade_pipe #(
    .N(N),
    .M(M)
  ) u_div_core_multiple (
    .clk,
    .rst_n,
    .x_calc_in(x_calc_in),
    .y_reg(y_calc_in),
    .x_calc_out(x_calc_out),
    .q_calc_out(q_calc)
  );

endmodule

module div_round_4_stages_cascade_pipe #(
  parameter int N = 32,
  parameter int M = 64
) (
  input logic clk,
  input logic rst_n,
  input logic [N+3:0] x_calc_in,
  input logic [N-1:0] y_reg,
  output logic [N-1:0] x_calc_out,
  output logic [3:0] q_calc_out
);

// div round stages
  logic [N  :0] x_calc_i[0:3];
  logic [N-1:0] x_calc_o[0:3];
  logic [3:0] q_calc;

// pipeline
  logic [N+3:0] x_calc_in_q;  // only bit [0] is used
  logic [N-1:0] y_reg_q;
  logic [3:0] q_calc_q;


assign x_calc_i[0] = x_calc_in[N+3:3];

  div_core #(
    .N(N)
  ) i_div_core_0 (
    .x_in (x_calc_i[0]),
    .y_in (y_reg),
    .x_out(x_calc_o[0]),
    .q_out(q_calc[3])
  );

assign x_calc_i[1] = {x_calc_o[0], x_calc_in[2]};

  div_core #(
    .N(N)
  ) i_div_core_1 (
    .x_in (x_calc_i[1]),
    .y_in (y_reg),
    .x_out(x_calc_o[1]),
    .q_out(q_calc[2])
  );

always_ff @(posedge clk) x_calc_i[2] = {x_calc_o[1], x_calc_in[1]};
always_ff @(posedge clk) x_calc_in_q <= x_calc_in;
always_ff @(posedge clk) y_reg_q <= y_reg;
always_ff @(posedge clk) q_calc_q[3:2] <= q_calc[3:2];

  div_core #(
    .N(N)
  ) i_div_core_2 (
    .x_in (x_calc_i[2]),
    .y_in (y_reg_q),
    .x_out(x_calc_o[2]),
    .q_out(q_calc_q[1])
  );

assign x_calc_i[3] = {x_calc_o[2], x_calc_in_q[0]};

  div_core #(
    .N(N)
  ) i_div_core_3 (
    .x_in (x_calc_i[3]),
    .y_in (y_reg_q),
    .x_out(x_calc_o[3]),
    .q_out(q_calc_q[0])
  );

  assign x_calc_out = x_calc_o[3];
  assign q_calc_out = q_calc_q;

endmodule

module div_core #(
  parameter int N = 32
) (
  input  logic [N  :0] x_in,
  input  logic [N-1:0] y_in,
  output logic [N-1:0] x_out,
  output logic         q_out
);

  logic signed [N:0] subres;

  assign subres = x_in - y_in;

  assign q_out  = (subres >= 0);

  assign x_out  = q_out ? subres[N-1:0] : x_in;

endmodule
