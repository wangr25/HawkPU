module dffe_pipe #(
    parameter int WIDTH = 1,
    parameter int DELAY = 2
)(
    input  logic               clk,
    input  logic               en,
    input  logic [WIDTH-1:0]   d, 
    output logic [WIDTH-1:0]   q
);

    generate
        if (DELAY == 0) begin : gen_bypass
            assign q = d;
        end else begin : gen_pipe
            logic [WIDTH-1:0] stage [0:DELAY-1];

            always_ff @(posedge clk) begin
                if (en) begin
                    stage[0] <= d;
                    for (int i = 1; i < DELAY; i++) begin
                        stage[i] <= stage[i-1];
                    end
                end
            end

            assign q = stage[DELAY-1];
        end
    endgenerate

endmodule

