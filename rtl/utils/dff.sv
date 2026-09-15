// dff without reset

module dff #(
  parameter DATA_WIDTH = 32
) (

  input wire clk,

  input wire [DATA_WIDTH-1:0] d,

  output reg [DATA_WIDTH-1:0] q

);

  always @(posedge clk) begin
    q <= d;
  end

endmodule
