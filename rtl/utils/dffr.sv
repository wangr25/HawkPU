// dff with reset
// reset value can be 0 or 1

module dffr #(
	parameter DATA_WIDTH = 32,
	parameter RESET_VALUE = 1'b0
)(

	input wire clk,
	input wire rstn,

	input wire [DATA_WIDTH-1:0] d,

	output reg [DATA_WIDTH-1:0] q

);

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		q <= {DATA_WIDTH{RESET_VALUE}};
	end else begin
		q <= d;
	end
end

endmodule
