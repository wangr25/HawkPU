module in_permut_network (
    input  [127:0] v0, v1, v2, v3,
    input          sel,              // 0: permut0, 1: permut1
    output [127:0] out0, out1, out2, out3
);

    wire [31:0] in[15:0];
    reg  [31:0] out[15:0];

    assign in[0]  = v0[31:0];
    assign in[1]  = v0[63:32];
    assign in[2]  = v0[95:64];
    assign in[3]  = v0[127:96];
    assign in[4]  = v1[31:0];
    assign in[5]  = v1[63:32];
    assign in[6]  = v1[95:64];
    assign in[7]  = v1[127:96];
    assign in[8]  = v2[31:0];
    assign in[9]  = v2[63:32];
    assign in[10] = v2[95:64];
    assign in[11] = v2[127:96];
    assign in[12] = v3[31:0];
    assign in[13] = v3[63:32];
    assign in[14] = v3[95:64];
    assign in[15] = v3[127:96];

    always_comb begin
        if (sel == 1'b0) begin
            // in_permut_network_0
            out[0]  = in[0];
            out[1]  = in[4];
            out[2]  = in[8];
            out[3]  = in[12];
            out[4]  = in[1];
            out[5]  = in[5];
            out[6]  = in[9];
            out[7]  = in[13];
            out[8]  = in[2];
            out[9]  = in[6];
            out[10] = in[10];
            out[11] = in[14];
            out[12] = in[3];
            out[13] = in[7];
            out[14] = in[11];
            out[15] = in[15];
        end else begin
            // in_permut_network_1
            out[0]  = in[0];
            out[1]  = in[1];
            out[2]  = in[8];
            out[3]  = in[9];
            out[4]  = in[2];
            out[5]  = in[3];
            out[6]  = in[10];
            out[7]  = in[11];
            out[8]  = in[4];
            out[9]  = in[5];
            out[10] = in[12];
            out[11] = in[13];
            out[12] = in[6];
            out[13] = in[7];
            out[14] = in[14];
            out[15] = in[15];
        end
    end

    assign out0 = {out[3],  out[2],  out[1],  out[0]};
    assign out1 = {out[7],  out[6],  out[5],  out[4]};
    assign out2 = {out[11], out[10], out[9],  out[8]};
    assign out3 = {out[15], out[14], out[13], out[12]};

endmodule

module out_permut_network (
    input  [127:0] v0, v1, v2, v3,
    input          sel,              // 0: permut0, 1: permut1
    output [127:0] out0, out1, out2, out3
);

    wire [31:0] in[15:0];
    reg  [31:0] out[15:0];

    assign in[0]  = v0[31:0];
    assign in[1]  = v0[63:32];
    assign in[2]  = v0[95:64];
    assign in[3]  = v0[127:96];
    assign in[4]  = v1[31:0];
    assign in[5]  = v1[63:32];
    assign in[6]  = v1[95:64];
    assign in[7]  = v1[127:96];
    assign in[8]  = v2[31:0];
    assign in[9]  = v2[63:32];
    assign in[10] = v2[95:64];
    assign in[11] = v2[127:96];
    assign in[12] = v3[31:0];
    assign in[13] = v3[63:32];
    assign in[14] = v3[95:64];
    assign in[15] = v3[127:96];

    always_comb begin
        if (sel == 1'b0) begin
            // out_permut_network_0
            out[0]  = in[0];
            out[1]  = in[1];
            out[2]  = in[4];
            out[3]  = in[5];
            out[4]  = in[8];
            out[5]  = in[9];
            out[6]  = in[12];
            out[7]  = in[13];
            out[8]  = in[2];
            out[9]  = in[3];
            out[10] = in[6];
            out[11] = in[7];
            out[12] = in[10];
            out[13] = in[11];
            out[14] = in[14];
            out[15] = in[15];
        end else begin
            // out_permut_network_1
            out[0]  = in[0];
            out[1]  = in[4];
            out[2]  = in[8];
            out[3]  = in[12];
            out[4]  = in[1];
            out[5]  = in[5];
            out[6]  = in[9];
            out[7]  = in[13];
            out[8]  = in[2];
            out[9]  = in[6];
            out[10] = in[10];
            out[11] = in[14];
            out[12] = in[3];
            out[13] = in[7];
            out[14] = in[11];
            out[15] = in[15];
        end
    end

    assign out0 = {out[3],  out[2],  out[1],  out[0]};
    assign out1 = {out[7],  out[6],  out[5],  out[4]};
    assign out2 = {out[11], out[10], out[9],  out[8]};
    assign out3 = {out[15], out[14], out[13], out[12]};

endmodule
