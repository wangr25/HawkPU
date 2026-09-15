module pipe_handshake (
	input logic clk,
	input logic rstn,
	// upstream
	input logic vld_i,
	output logic rdy_o,
	// downstream
	output logic vld_o,
	input logic rdy_i,
	// to and from data regs
	input logic finish,		// calculation of this stage finishes
	output logic d_en,		// enable data dffs (usually with type 'dffe')
	// 
	output logic have
);

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		have <= 1'b0;
	end
	else if (rdy_o) begin
		have <= vld_i;
	end
end

assign vld_o = finish && have;

assign rdy_o = (!have) || (finish && rdy_i);

assign d_en = vld_i && rdy_o;

endmodule
