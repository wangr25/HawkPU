`include "../defines/defines.sv"

module msum4 #(
    parameter PW = 31
    )(
    input  logic clk,
    input  logic rstn,
    input  logic security_level,
    input  logic [PW-1:0] d_i_0,
    input  logic [PW-1:0] d_i_1,
    input  logic [PW-1:0] d_i_2,
    input  logic [PW-1:0] d_i_3,
    input  logic vld_i,
    output logic [PW-1:0] msum1,
    output logic msum1_vld,
    output logic [PW-1:0] msum2,
    output logic msum2_vld
);

localparam int C1 = 32+32;  // hawk512  counter max value
localparam int C2 = 64+64;  // hawk1024 counter max value
localparam int CW = $clog2(C2);

logic [PW-1:0] P;
assign P = msum1_vld ? `P2 : `P1;

logic [CW:0] cnt;
wire cnt_is_max = (cnt==(security_level ? C2 : C1));

logic msum_vld;
dffre_pipe #(
    .WIDTH(1),
    .DELAY(1)
) u_dffre_pipe_msum_vld (
    .clk,
    .rstn,
    .en(1'b1),
    .d(vld_i),
    .q(msum_vld)
);

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) cnt <= 'd0;
    else if (cnt_is_max) cnt <= 'd0;
    else if (msum_vld) cnt <= cnt + 'd1;
end

logic [PW-1:0] msum;
logic [PW-1:0] next_msum1, next_msum2;

madd32 #(PW) u_madd32_msum1 (
    .a(msum1),
    .b(msum),
    .P,
    .out(next_msum1)
);
madd32 #(PW) u_madd32_msum2 (
    .a(msum2),
    .b(msum),
    .P,
    .out(next_msum2)
);

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        msum1 <= 1'b0;
    end
    else if (msum_vld && (msum1_vld==1'b0)) begin
        msum1 <= next_msum1;
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        msum2 <= 1'b0;
    end
    else if (msum_vld && (msum2_vld==1'b0) && (msum1_vld==1'b1)) begin
        msum2 <= next_msum2;
    end
end


always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        msum1_vld <= 1'b0;
    end
    else if ( cnt_is_max && (msum1_vld==1'b0) ) begin  // round1
        msum1_vld <= 1'b1;
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        msum2_vld <= 1'b0;
    end
    else if ( cnt_is_max && (msum2_vld==1'b0) && (msum1_vld==1'b1)) begin  // round2
        msum2_vld <= 1'b1;
    end
end

msum4_core u_msum4_core (.*);

endmodule
module msum4_core #(
    parameter PW = 31
    )(
    input  logic clk,
    input  logic [PW-1:0] d_i_0,
    input  logic [PW-1:0] d_i_1,
    input  logic [PW-1:0] d_i_2,
    input  logic [PW-1:0] d_i_3,
    input  logic [PW-1:0] P,
    output logic [PW-1:0] msum
);
// sum max is 4*7FFF_FFFFF = 1_FFFF_FFFC
logic [PW+1:0] sum;
assign sum = d_i_0 + d_i_1 + d_i_2 + d_i_3;

logic [PW-1:0] msum_0;
// msum < 4*P
// do msub for at most three times

always_comb begin
    if (sum>=3*{2'b0,P})
        msum_0 = sum - 3*{2'b0,P};
    else if (sum>=2*{2'b0,P})
        msum_0 = sum - 2*{2'b0,P};
    else if (sum>=P)
        msum_0 = sum - P;
    else
        msum_0 = sum;
end

always_ff @(posedge clk) begin
    msum <= msum_0;
end


endmodule

module madd32 #(
    parameter PW = 31
) (
    input  logic [PW-1:0] a,
    input  logic [PW-1:0] b,
    input  logic [PW-1:0] P,
    output logic [PW-1:0] out
);

logic [PW:0] sum;
assign sum = a+b;

assign out = sum - ((sum >= P) ? P : 'd0);

endmodule
