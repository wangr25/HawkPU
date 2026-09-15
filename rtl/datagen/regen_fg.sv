`include "../defines/defines.sv"

module regen_fg (

    input wire clk,
    input wire rstn,
    input wire security_level,

    input  logic regenfg_start,

    // to keccak
    output logic regenfg_keccak_start,
    output logic [1:0] regenfg_cnt_j,

    // input data
    input  logic [127:0] d_i,
    input  logic vld_i,
    output logic rdy_o,

    // output data
    output logic flag_wr_g,  // when 0, write f; when 1, write g
    output logic regenfg_v0_wen,
    output logic regenfg_v1_wen,
    output logic [`VEC_BITS-1:0] regenfg_v0,
    output logic [`VEC_BITS-1:0] regenfg_v1,
    output logic [`VEC_NUM_WIDTH-1:0] regenfg_wvn0,
    output logic [`VEC_NUM_WIDTH-1:0] regenfg_wvn1,

    output logic regenfg_finish
);

wire vld_rdy = vld_i && rdy_o;  // upstream handshake success

//------------------- control -------------------------
logic regenfg_en;
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) regenfg_en <= 1'b0;
    else if (regenfg_finish) regenfg_en <= 1'b0;
    else if (regenfg_start) regenfg_en <= 1'b1;
end

// write counter
// i
logic wr_cnt_start;
logic [9:0] wr_cnt_num;  // write vector num, 128/512, [9:0]
logic wr_cnt_run;
// o
logic [9:0] wr_cnt;
logic wr_cnt_en;
logic wr_cnt_done;

logic reload_seed;
assign reload_seed = security_level ? (wr_cnt[6:0]=='1) : (wr_cnt[4:0]=='1);
logic flush_inner;
assign flush_inner = security_level ? (wr_cnt[6:0]==7'b1111110) : (wr_cnt[4:0]==5'b11110);

logic buff_sel;
always_ff @(posedge clk) begin
    if (vld_rdy) buff_sel <= 1'b0;
    else if (buff_sel==1'b0) buff_sel <= 1'b1;
end

logic have;
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) have <= 1'b0;
    else if (flush_inner) have <= 1'b0;
    else if (vld_rdy && regenfg_en) have <= 1'b1;
    else if (buff_sel==1'b1) have <= 1'b0;
end

logic wen;
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) wen <= 1'b0;
    else wen <= have;
end

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) rdy_o <= 1'b1;
    else if (flush_inner || reload_seed) rdy_o <= 1'b0;
    else if (rdy_o==1'b0) rdy_o <= 1'b1;
    else if (vld_i) rdy_o <= 1'b0;
end


always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) wr_cnt_start <= 1'b0;
    else if (wr_cnt_start==1'b1) wr_cnt_start <= 1'b0;
    else if (regenfg_start) wr_cnt_start <= 1'b1;
end
// in hawk512, wr 2 vectors, 1024/(2*4)=128
assign wr_cnt_num = security_level ? 'd512 : 'd128;
assign wr_cnt_run = wen;

  counter_ce_cntclear #(
    .BW($bits(wr_cnt_num))
  ) u_regenfg_wr_cnt (
    .clk,
    .rst_n (rstn),
    .start (wr_cnt_start),
    .num   (wr_cnt_num),
    .run   (wr_cnt_run),
    .cnt   (wr_cnt),
    .cnt_en(wr_cnt_en),
    .last  (),
    .done  (wr_cnt_done)
  );


//------------------- datapath -------------------------
logic [127:0] buff;
logic [63:0] buff_i;

always_ff @(posedge clk) begin
    if (vld_rdy) buff <= d_i;
end

assign buff_i = (buff_sel==1'b1) ? buff[127:64] : buff[63:0];

logic [7:0] bit_8 [8];  // 64 bits from buff_i

genvar ii,jj,kk;
generate
    for (jj=0; jj<8; jj=jj+1) begin: regenfg_gen_bit_8
        assign bit_8[jj] = buff_i[((jj+1)*8-1) -: 8];
    end
endgenerate

logic [3:0] sum_8bits[8];
logic signed [4:0] sum_8bits_m4[8];  // minus 4
logic signed [4:0] sum_16bits_m8[4];

generate
    for (ii=0; ii<8; ii=ii+1) begin: regenfg_gen_sum8m4
        assign sum_8bits[ii] = {3'b0, bit_8[ii][0]}
                            +  {3'b0, bit_8[ii][1]}
                            +  {3'b0, bit_8[ii][2]}
                            +  {3'b0, bit_8[ii][3]}
                            +  {3'b0, bit_8[ii][4]}
                            +  {3'b0, bit_8[ii][5]}
                            +  {3'b0, bit_8[ii][6]}
                            +  {3'b0, bit_8[ii][7]}
                            ;
        assign sum_8bits_m4[ii] = sum_8bits[ii] - 4'd4;
    end
endgenerate

generate
    for (kk=0; kk<4; kk=kk+1) begin: regenfg_gen_sum16m8
        assign sum_16bits_m8[kk] = sum_8bits_m4[2*kk] + sum_8bits_m4[2*kk+1];
    end
endgenerate

// pipeline write data
logic signed [4:0] sum_8bits_m4_q[8];
logic signed [4:0] sum_16bits_m8_q[4];

integer i,j;
always_ff @(posedge clk) begin
    for (i=0;i<8;i=i+1) begin
        sum_8bits_m4_q[i] <= sum_8bits_m4[i];
    end
end
always_ff @(posedge clk) begin
    for (j=0;j<4;j=j+1) begin
        sum_16bits_m8_q[j] <= sum_16bits_m8[j]; 
    end
end

//------------------------- output interface -------------------------

// hawk512: write 2 vectors, use v1, v0
// hawk1024: write 1 vector, use v0
logic [`VEC_BITS-1:0] v0_1024;
logic [`VEC_BITS-1:0] v0_512;
logic [`VEC_BITS-1:0] v1_512;
assign v1_512 = {
    { {27{sum_8bits_m4_q[7][4]}}, sum_8bits_m4_q[7][4:0] },
    { {27{sum_8bits_m4_q[6][4]}}, sum_8bits_m4_q[6][4:0] },
    { {27{sum_8bits_m4_q[5][4]}}, sum_8bits_m4_q[5][4:0] },
    { {27{sum_8bits_m4_q[4][4]}}, sum_8bits_m4_q[4][4:0] }
};
assign v0_512 = {
    { {27{sum_8bits_m4_q[3][4]}}, sum_8bits_m4_q[3][4:0] },
    { {27{sum_8bits_m4_q[2][4]}}, sum_8bits_m4_q[2][4:0] },
    { {27{sum_8bits_m4_q[1][4]}}, sum_8bits_m4_q[1][4:0] },
    { {27{sum_8bits_m4_q[0][4]}}, sum_8bits_m4_q[0][4:0] }
};
assign v0_1024 = {
    { {27{sum_16bits_m8_q[3][4]}}, sum_16bits_m8_q[3][4:0] },
    { {27{sum_16bits_m8_q[2][4]}}, sum_16bits_m8_q[2][4:0] },
    { {27{sum_16bits_m8_q[1][4]}}, sum_16bits_m8_q[1][4:0] },
    { {27{sum_16bits_m8_q[0][4]}}, sum_16bits_m8_q[0][4:0] }
};
assign regenfg_v0 = security_level ? v0_1024 : v0_512;
assign regenfg_v1 = v1_512;

// wr en
assign regenfg_v0_wen = wen;
assign regenfg_v1_wen = security_level ? 1'b0 : wen;

// wr f/g
always_comb begin
    if (security_level==1'b1) begin
        flag_wr_g = wr_cnt[6];
    end
    else begin // hawk512
        flag_wr_g = wr_cnt[4];
    end
end

// wr vector index
always_comb begin
    if (security_level==1'b1) begin
        regenfg_wvn0 = {wr_cnt[5:0], wr_cnt[8:7]};
    end
    else begin // hawk512
        regenfg_wvn0 = {wr_cnt[3:0], wr_cnt[6:5], 1'b0};
    end
end

assign regenfg_wvn1 = regenfg_wvn0 | 1'b1;  // only in hawk512 

assign regenfg_cnt_j = security_level ? wr_cnt[8:7] : wr_cnt[6:5];


assign regenfg_keccak_start = regenfg_start || (reload_seed && (!wr_cnt_done));


// finish
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) regenfg_finish <= 1'b0;
    else if (regenfg_finish==1'b1) regenfg_finish <= 1'b0;
    else if (wr_cnt_done) regenfg_finish <= 1'b1;
end

endmodule
