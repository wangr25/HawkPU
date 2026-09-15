`include "../defines/defines.sv"

module symbreak (
    input wire clk,
    input wire rstn,
    input wire vld_i,
    input wire symbreak_en,

    input wire [`VEC_BITS-1:0] v0,
    input wire [`VEC_BITS-1:0] v1,

    // if the first non-zero element of v > 0, symbreak_result == 1, then do sub
    output logic symbreak_result
);

logic [31:0] v [0:7];
assign v[0] = v0[1*32-1-:32];
assign v[1] = v0[2*32-1-:32];
assign v[2] = v0[3*32-1-:32];
assign v[3] = v0[4*32-1-:32];
assign v[4] = v1[1*32-1-:32];
assign v[5] = v1[2*32-1-:32];
assign v[6] = v1[3*32-1-:32];
assign v[7] = v1[4*32-1-:32];

reg [7:0] gt_d;
reg [7:0] eq_d;

genvar gv;
generate
    for (gv=0; gv<8; gv=gv+1) begin: gen_symbreak_cmp
        assign gt_d[gv] = !v[gv][31];
        assign eq_d[gv] = (v[gv]=='0);
    end
endgenerate

reg [7:0] gt_q;
reg [7:0] eq_q;

dff #(8) U_symbreak_gt_dff (
	.clk(clk),
	.d(gt_d),
	.q(gt_q)
);
dff #(8) U_symbreak_eq_dff (
	.clk(clk),
	.d(eq_d),
	.q(eq_q)
);

// sym-break
// (1) when Sign, the result is used to choose add/sub
// (2) when Verify, the result goes to exception handler only

wire vec_symbreak_result;		// sym-break result of this vector
wire poly_symbreak_result_d;	// sym-break result of the whole poly, return 1 if first non-zero value > 0
reg poly_symbreak_result_q;		// sym-break result of the whole poly, return 1 if first non-zero value > 0
wire vec_all_zero;				// all elements in this vector are zero
wire poly_all_zero_d;			// all elements in the whole poly are zero
reg poly_all_zero_q;			// all elements in the whole poly are zero, the reset value is 1
wire poly_symbreak_valid_d;		// result of poly sym-break is valid
reg poly_symbreak_valid_q;		// result of poly sym-break is valid, this signal should be a pulse

assign vec_symbreak_result = | ((eq_q ^ (eq_q+1)) & gt_q);
assign vec_all_zero = (&eq_d) & (symbreak_en);
assign poly_symbreak_result_d = vec_symbreak_result & poly_symbreak_valid_q | poly_symbreak_result_q;
assign poly_all_zero_d = vec_all_zero & poly_all_zero_q;
assign poly_symbreak_valid_d = (~vec_all_zero&poly_all_zero_q);

dffr #(
	.DATA_WIDTH(1),
	.RESET_VALUE(1'b0)	
) U_dffr_polysbresult (
	.clk(clk),
	.rstn(rstn),
	.d(poly_symbreak_result_d),
	.q(poly_symbreak_result_q)
);

dffre #(
	.DATA_WIDTH(1),
	.RESET_VALUE(1'b1)	
) U_dffre_polyallzero (
	.clk(clk),
	.rstn(rstn),
	.en(symbreak_en && vld_i),
	.d(poly_all_zero_d),
	.q(poly_all_zero_q)
);

dffre #(
	.DATA_WIDTH(1),
	.RESET_VALUE(1'b0)	
) U_dffre_polysbresultvalid (
	.clk(clk),
	.rstn(rstn),
	.en(symbreak_en && vld_i),
	.d(poly_symbreak_valid_d),
	.q(poly_symbreak_valid_q)
);

assign symbreak_result = poly_symbreak_result_q;

endmodule
