`timescale 1ns / 1ps

module enc_pipeline_delay #(
    parameter int DELAY = 1
)(
    input  logic clk,
    input  logic rstn,    
    input  logic data_in, 
    output logic data_out 
);

generate
    if (DELAY == 0) begin : GEN_NO_DELAY
        assign data_out = data_in;
    end
    else begin : GEN_DELAY
        logic [DELAY-1:0] shift_reg;
        
        always_ff @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                shift_reg <= '0;
            end else begin
                if (DELAY == 1) begin
                    shift_reg[0] <= data_in;
                end 
                else begin
                    shift_reg <= {shift_reg[DELAY-2:0], data_in};
                end
            end
        end
        
        assign data_out = shift_reg[DELAY-1];
    end
endgenerate

endmodule
