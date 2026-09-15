module unsigned_cmp_lt_78bit_13 (
    input  logic               clk,
    input  logic               rstn,
    input  logic               vld_i,
    input  logic  [77:0] a [12:0],
    input  logic  [77:0] b [12:0],
    output logic        [12:0] lt,  // a < b
    output logic               vld_o,
	input  logic			   rdy_i,
    output logic               rdy_o
);

assign vld_o = vld_i;
assign rdy_o = rdy_i;

logic [12:0] lt_next;

always_comb begin
	for (int i = 0; i < 13; i++) begin
		lt_next[i] = (a[i] < b[i]);
		lt[i] = lt_next[i];
	end
end

endmodule