module counter_ce  // counter with configurable end number
#(
  parameter int unsigned BW = 8
) (
  input                 clk,
  input                 rst_n,
  input                 start,
  input        [BW-1:0] num,
  input                 run,
  output logic [BW-1:0] cnt,
  output logic          cnt_en,
  output logic          last,
  output logic          done
);

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) cnt_en <= 1'b0;
    else if (start) cnt_en <= 1'b1;
    else if (done) cnt_en <= 1'b0;
  end

  wire [BW-1:0] cnt_nxt = cnt + 1'd1;

  assign last = (cnt_nxt == num) & cnt_en;

  assign done = last & run;

  always_ff @(posedge clk) begin
    if (start) cnt <= '0;
    else if (cnt_en & run & ~last) cnt <= cnt_nxt;
  end

endmodule

// if done, clear counter
module counter_ce_cntclear
#(
  parameter int unsigned BW = 8
) (
  input                 clk,
  input                 rst_n,
  input                 start,
  input        [BW-1:0] num,
  input                 run,
  output logic [BW-1:0] cnt,
  output logic          cnt_en,
  output logic          last,
  output logic          done
);

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) cnt_en <= 1'b0;
    else if (start) cnt_en <= 1'b1;
    else if (done) cnt_en <= 1'b0;
  end

  wire [BW-1:0] cnt_nxt = cnt + 1'd1;

  assign last = (cnt_nxt == num) & cnt_en;

  assign done = last & run;

  always_ff @(posedge clk) begin
    if (start | done) cnt <= '0;
    else if (cnt_en & run & ~last) cnt <= cnt_nxt;
  end

endmodule