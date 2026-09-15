module mul_const_P (
    input  logic        sys_mode,
    input  logic        polyqround,
    input  logic [31:0] a,
    output logic [62:0] r
);

logic [63:0] b;

    always_comb begin
        if (sys_mode == 1'b0) begin
            // ---------------- P0 = 2^14+2^11+1 ----------------
            b = {a,14'b0} + {a,11'b0} + a;
        end
        else begin
            if (polyqround == 1'b0) begin
                // ---------------- P1 = 2^31-2^13-2^11+1 ----------------
                b = {a,31'b0} - {a,13'b0} - {a,11'b0} + a;
            end
            else begin
                // ---------------- P2 = 2^31+2^15+2^12+1-2^17 ----------------
                b = {a,31'b0} + {a,15'b0} + {a,12'b0} + a - {a,17'b0};
            end
        end
    end

    assign r = b[62:0];

endmodule

module mul_const_P_I (
    input  logic        sys_mode,
    input  logic        polyqround,
    input  logic [31:0] a,
    output logic [63:0] r
);

logic [64:0] b;

    always_comb begin
        if (sys_mode == 1'b0) begin
            // P0_I = 2^32+2^14+2^11-2^28-2^26-2^22-1 
            b = {a,32'b0} + {a,14'b0} + {a,11'b0} - {a,28'b0} - {a,26'b0} - {a,22'b0} - a;
        end
        else begin
            if (polyqround == 1'b0) begin
                // P1_I = 2^31-2^27+2^25-2^22-2^13-2^11-1
                b = {a,31'b0} - {a,27'b0} + {a,25'b0} - {a,22'b0} - {a,13'b0} - {a,11'b0} - a;
            end
            else begin
                // P2_I = 2^31-2^28-2^24-2^17+2^15+2^12-1
                b = {a,31'b0} - {a,28'b0} - {a,24'b0} - {a,17'b0} + {a,15'b0} + {a,12'b0} - a;
            end
        end
    end

    assign r = b[63:0];

endmodule
