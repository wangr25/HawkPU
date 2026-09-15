`include "../defines/defines.sv"

// concatenate 2 vectors
// input 1 vector
// output 1 vector
module catstr (
    input  logic clk,
    input  logic rstn,
    input  logic security_level,

    //// control interface
    input  logic cat_start,
    output logic cat_finish,
    // in terms of 512-bit line
    input  logic [4:0] src1_length,
    input  logic [5:0] src1_validbytes,
    input  logic [4:0] src2_length,
    input  logic [5:0] src2_validbytes,
    input  logic [6:0] wr_length,

    //// r/w interface
    // offset for str1 and str2 both count from 0
    output logic [7:0] cat_roffset,
    output logic cat_rd_flag,  // 0-the current ren reads src1; 1-read src2
    input  logic [`VEC_BITS-1:0] cat_rdata,
    output logic cat_ren,
    input  logic cat_vld_i,

    output logic [7:0] cat_woffset,
    output logic [`VEC_BITS-1:0] cat_wdata,
    output logic cat_wen

);

localparam VBW = 4; // width for num of bytes in a vector

// count in terms of 128-bit vector
logic [$bits(src1_length)+2 -1:0]     str1_vecnum;  // [6:0]
logic [VBW-1:0]                       str1_lastvecvalidbytes;
logic [$bits(src2_length)+2 -1:0]     str2_vecnum;  // [6:0]
logic [VBW-1:0]                       str2_lastvecvalidbytes;
logic [$bits(wr_length)+2 -1:0]       wr_vecnum;    // [8:0]
logic [1:0] str1_lastline_vecnum;
logic [1:0] str2_lastline_vecnum;

assign str1_lastvecvalidbytes = src1_validbytes[3:0];
assign str2_lastvecvalidbytes = src2_validbytes[3:0];

assign str1_lastline_vecnum = src1_validbytes >> 4;
assign str2_lastline_vecnum = src2_validbytes >> 4;

assign str1_vecnum = {src1_length , 2'b0} | str1_lastline_vecnum;
assign str2_vecnum = {src2_length , 2'b0} | str2_lastline_vecnum;
assign wr_vecnum   = {wr_length   , 2'b0};

//------------------------------------------
// counters and control
//------------------------------------------

logic wen;  // inner wen
logic catstr_en;  // the catstr module is working

// read src1 counter
logic rd_cnt1_start;
logic [7:0] rd_cnt1_num;
logic [7:0] rd_cnt1;  // 0~63/127
logic rd_cnt1_en;
logic rd_cnt1_done;

// read src2 counter
logic rd_cnt2_start;
logic [7:0] rd_cnt2_num;
logic [7:0] rd_cnt2;  // 0~63/127
logic rd_cnt2_en;
logic rd_cnt2_done;

assign rd_cnt1_start = cat_start;
assign rd_cnt1_num = str1_vecnum + (str1_lastvecvalidbytes!='0);

assign rd_cnt2_start = rd_cnt1_done;
assign rd_cnt2_num = str2_vecnum + (str2_lastvecvalidbytes!='0);

  counter_ce #(
    .BW($bits(rd_cnt1_num))
  ) u_cat_rd_cnt1 (
    .clk,
    .rst_n (rstn),
    .start (rd_cnt1_start),
    .num   (rd_cnt1_num),
    .run   (1'b1),
    .cnt   (rd_cnt1),
    .cnt_en(rd_cnt1_en),
    .last  (),
    .done  (rd_cnt1_done)
  );

  counter_ce #(
    .BW($bits(rd_cnt2_num))
  ) u_cat_rd_cnt2 (
    .clk,
    .rst_n (rstn),
    .start (rd_cnt2_start),
    .num   (rd_cnt2_num),
    .run   (1'b1),
    .cnt   (rd_cnt2),
    .cnt_en(rd_cnt2_en),
    .last  (),
    .done  (rd_cnt2_done)
  );

// wr counter
// i
logic wr_cnt_start;
logic [$bits(wr_vecnum)-1:0] wr_cnt_num;  // [8:0]
logic wr_cnt_run;
// o
logic [$bits(wr_cnt_num)-2:0] wr_cnt;     // [7:0]
logic wr_cnt_en;
logic wr_cnt_done;

dffre_pipe #(
    .WIDTH(1'b1),
    .DELAY(`FORMAT_RD_LATENCY+1)
) u_dffe_pipe_catstr_wr_cnt_start (
    .clk,
    .rstn,
    .en(1'b1),
    .d(rd_cnt1_start),
    .q(wr_cnt_start)
);

assign wen = wr_cnt_en;
assign wr_cnt_num = wr_vecnum;
assign wr_cnt_run = wen;

  counter_ce #(
    .BW($bits(wr_cnt_num))
  ) u_cat_wr_cnt (
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

// flags
logic flag_normal_str1_vec_vld_i;  // the current vld_i is not the last vec of string1
logic flag_last_str1_vec_vld_i;    // the current vld_i indicates the last vec of string1
logic flag_last_str1_vec_in_buff;  // the last vec of string1 is in the buff

dffe_pipe #(
    .WIDTH(1'b1),
    .DELAY(`FORMAT_RD_LATENCY)
) u_dffe_pipe_flag_normal_str1_vec_vld_i(
    .clk,
    .en(1'b1),
    .d(rd_cnt1_en && (!rd_cnt1_done)),
    .q(flag_normal_str1_vec_vld_i)
);
dffe_pipe #(
    .WIDTH(1'b1),
    .DELAY(`FORMAT_RD_LATENCY)
) u_dffe_pipe_flag_last_str1_vec_vld_i (
    .clk,
    .en(1'b1),
    .d(rd_cnt1_done),
    .q(flag_last_str1_vec_vld_i)
);
always_ff @(posedge clk) flag_last_str1_vec_in_buff <= flag_last_str1_vec_vld_i;

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) catstr_en <= 1'b0;
    else if (cat_finish) catstr_en <= 1'b0;
    else if (cat_start) catstr_en <= 1'b1;
end

//------------------------------------------
// datapath
//------------------------------------------
logic [`VEC_BITS-1:0] d_i;
logic [`VEC_BITS-1:0] buff;
logic [`VEC_BITS-1:0] d_o;
logic [`VEC_BITS-1:0] d_o_1;  // from buff
logic [`VEC_BITS-1:0] d_o_2;  // from d_i

logic [VBW:0] vld_bytes_buff;  // valid bytes in the buffer
logic [VBW:0] vld_bytes_2;  // valid bytes in d_i
logic [VBW:0] str1_lastvecvalidbytes_1;  // map vecvldbytes from [0,15] to [1:16]
logic [VBW:0] str2_vecvldbytes_offset;
assign str1_lastvecvalidbytes_1 = (str1_lastvecvalidbytes=='d0) ? 'd16 : str1_lastvecvalidbytes;
assign str2_vecvldbytes_offset = 'd16 - str1_lastvecvalidbytes_1;

always_ff @(posedge clk) begin
    unique case (1'b1)
        flag_normal_str1_vec_vld_i: vld_bytes_buff <= 'd16;
        flag_last_str1_vec_vld_i:   vld_bytes_buff <= str1_lastvecvalidbytes_1;
        default: vld_bytes_buff <= str1_lastvecvalidbytes_1;
    endcase
end

assign vld_bytes_2 = 'd16 - vld_bytes_buff;

always_ff @(posedge clk) begin
    if (cat_vld_i) buff <= d_i;
end

always_comb begin
    if (flag_last_str1_vec_in_buff) begin
        case (vld_bytes_buff)
            'd1:  d_o_1 = buff[ 1*8-1:0];
            'd2:  d_o_1 = buff[ 2*8-1:0];
            'd3:  d_o_1 = buff[ 3*8-1:0];
            'd4:  d_o_1 = buff[ 4*8-1:0];
            'd5:  d_o_1 = buff[ 5*8-1:0];
            'd6:  d_o_1 = buff[ 6*8-1:0];
            'd7:  d_o_1 = buff[ 7*8-1:0];
            'd8:  d_o_1 = buff[ 8*8-1:0];
            'd9:  d_o_1 = buff[ 9*8-1:0];
            'd10: d_o_1 = buff[10*8-1:0];
            'd11: d_o_1 = buff[11*8-1:0];
            'd12: d_o_1 = buff[12*8-1:0];
            'd13: d_o_1 = buff[13*8-1:0];
            'd14: d_o_1 = buff[14*8-1:0];
            'd15: d_o_1 = buff[15*8-1:0];
            'd16: d_o_1 = buff[16*8-1:0];
            default : d_o_1 = '0;
        endcase
    end
    else begin
        case (vld_bytes_buff)
            'd1:  d_o_1 = buff[`VEC_BITS-1 -:  1*8];
            'd2:  d_o_1 = buff[`VEC_BITS-1 -:  2*8];
            'd3:  d_o_1 = buff[`VEC_BITS-1 -:  3*8];
            'd4:  d_o_1 = buff[`VEC_BITS-1 -:  4*8];
            'd5:  d_o_1 = buff[`VEC_BITS-1 -:  5*8];
            'd6:  d_o_1 = buff[`VEC_BITS-1 -:  6*8];
            'd7:  d_o_1 = buff[`VEC_BITS-1 -:  7*8];
            'd8:  d_o_1 = buff[`VEC_BITS-1 -:  8*8];
            'd9:  d_o_1 = buff[`VEC_BITS-1 -:  9*8];
            'd10: d_o_1 = buff[`VEC_BITS-1 -: 10*8];
            'd11: d_o_1 = buff[`VEC_BITS-1 -: 11*8];
            'd12: d_o_1 = buff[`VEC_BITS-1 -: 12*8];
            'd13: d_o_1 = buff[`VEC_BITS-1 -: 13*8];
            'd14: d_o_1 = buff[`VEC_BITS-1 -: 14*8];
            'd15: d_o_1 = buff[`VEC_BITS-1 -: 15*8];
            'd16: d_o_1 = buff[`VEC_BITS-1 -: 16*8];
            default : d_o_1 = '0;
        endcase
    end
end

always_comb begin
    case (vld_bytes_2)
        'd1:  d_o_2 = { d_i[ 1*8-1:0] , 120'b0 };
        'd2:  d_o_2 = { d_i[ 2*8-1:0] , 112'b0 };
        'd3:  d_o_2 = { d_i[ 3*8-1:0] , 104'b0 };
        'd4:  d_o_2 = { d_i[ 4*8-1:0] , 96'b0 };
        'd5:  d_o_2 = { d_i[ 5*8-1:0] , 88'b0 };
        'd6:  d_o_2 = { d_i[ 6*8-1:0] , 80'b0 };
        'd7:  d_o_2 = { d_i[ 7*8-1:0] , 72'b0 };
        'd8:  d_o_2 = { d_i[ 8*8-1:0] , 64'b0 };
        'd9:  d_o_2 = { d_i[ 9*8-1:0] , 56'b0 };
        'd10: d_o_2 = { d_i[10*8-1:0] , 48'b0 };
        'd11: d_o_2 = { d_i[11*8-1:0] , 40'b0 };
        'd12: d_o_2 = { d_i[12*8-1:0] , 32'b0 };
        'd13: d_o_2 = { d_i[13*8-1:0] , 24'b0 };
        'd14: d_o_2 = { d_i[14*8-1:0] , 16'b0 };
        'd15: d_o_2 = { d_i[15*8-1:0] , 8'b0 };
        'd16: d_o_2 = { d_i[16*8-1:0] };
        default : d_o_2 = '0;
    endcase
end

assign d_o = d_o_2 | d_o_1;


//------------------------------------------
// interface
//------------------------------------------

// rd
assign cat_ren = (rd_cnt1_en | rd_cnt2_en) && catstr_en;
assign d_i = cat_rdata;
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) cat_rd_flag <= 1'b0;
    else if (cat_start) cat_rd_flag <= 1'b0;     // read src1
    else if (rd_cnt1_done) cat_rd_flag <= 1'b1;  // read src2
end
assign cat_roffset = cat_rd_flag ? rd_cnt2 : rd_cnt1;

// wr
// 1 cycle pipeline
always_ff @(posedge clk) cat_wdata <= d_o;
always_ff @(posedge clk) cat_woffset <= wr_cnt;
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) cat_wen <= 1'b0;
    else cat_wen <= wen;
end

// finish
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) cat_finish <= 1'b0;
    else if (cat_finish==1'b1) cat_finish <= 1'b0;
    else if (wr_cnt_done) cat_finish <= 1'b1;
end

endmodule
