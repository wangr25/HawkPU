module pipeline_delay_bit #(
  parameter bit R = 0,  //asynchronous reset
  parameter bit P = 0,  //parallel out
  parameter int D = 1   //delay cycle
) (
  c,  // clk
  r,  // rst_n
  i,  // in
  o  // out
);

  localparam int BW = P ? D : 1;

  input c;  // clk
  input r;  // rst_n
  input i;  // in
  output logic [BW:1] o;  // out

  logic [D:1] o_r;

  if (R & (D == 1)) begin : gen_1bit_rst
    always_ff @(posedge c, negedge r)
      if (!r) o_r <= '0;
      else o_r <= i;
  end else if (R & (D >= 2)) begin : gen_nbit_rst
    always_ff @(posedge c, negedge r)
      if (!r) o_r <= '0;
      else o_r <= {o_r[D-1:1], i};
  end else if (!R & (D == 1)) begin : gen_1bit
    always_ff @(posedge c) o_r <= i;
  end else if (!R & (D >= 2)) begin : gen_nbit
    always_ff @(posedge c) o_r <= {o_r[D-1:1], i};
  end

  if (P) assign o = o_r;
  else assign o = o_r[D];

endmodule
