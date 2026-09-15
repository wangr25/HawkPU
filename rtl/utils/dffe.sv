// dff with enable, but without reset

module dffe #(
	parameter DATA_WIDTH = 32
)(

	input wire clk,

	input wire en,
	input wire [DATA_WIDTH-1:0] d,

	output reg [DATA_WIDTH-1:0] q

);

always @(posedge clk) begin
	if (en) begin
		q <= d;
	end 
end

endmodule
