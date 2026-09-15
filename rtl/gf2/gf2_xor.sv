`include "../defines/defines.sv"

module gf2_xor (
    input wire clk,
    input wire rstn,

    input wire [`VEC_BITS-1:0] gf2_xor_a,
    input wire [`VEC_BITS-1:0] gf2_xor_b,

    output logic [`VEC_BITS-1:0] gf2_xor_result
);

always_ff @(posedge clk) gf2_xor_result <= gf2_xor_a ^ gf2_xor_b;

endmodule