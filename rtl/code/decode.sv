`include "../defines/defines.sv"

module decode (

    input   wire    clk,
    input   wire    rstn,               // async, low active reset
    input   wire    security_level,     // 0-hawk512, 1-hawk1024

    input   wire    dec_funct,          // 0-input is sig, 1-input is pub
    input   wire    q00_mode,           // 0-q00[0] = 0, 1- Normaol Adjust q00
    input   wire    q00_only,           // 0-decode q00 and q01, 1-only decode q00

    output  logic   dec_flag,           // if decoding pub (dec_funct==1):
                                        // 0-output polynomial is q00
                                        // 1-output polynomial is q01
                                        // else if decoding sig (dec_funct==0):
                                        // 0-output bitstring salt
                                        // 1-output polynomial s1

    input   wire    start,              // pulse
    output  logic   finish,

    output logic decode_salt_en,
    output logic decode_sig_en,
    output logic decode_q00_en,
    output logic adjust_q00_en,
    output logic decode_q01_en,
    output logic [31:0] q00_0,
    output logic       q00_adjust_valid,

    // read buffer
    output  logic                           ren,
    output  logic   [`ADDR_WIDTH-1:0]       r_offset_addr,
    input   logic                           vld_i,
    input   logic   [`VEC_BITS*2-1:0]       r_data,
    
    // write buffer
    output  logic                           wen,
    output  logic   [`ADDR_WIDTH-1:0]       w_offset_addr,
    output  logic   [`VEC_BITS*2-1:0]       w_data
);

wire [`ADDR_WIDTH-1:0] w_base_addr = 100;
wire [`ADDR_WIDTH-1:0] r_base_addr_salt_sig = 0;
wire [`ADDR_WIDTH-1:0] r_base_addr_q00q01 = 0;

// reg for information   
reg [`VEC_BITS * 2 - 1:0] reg_for_sign_bits;
reg [`VEC_BITS * 2 - 1 + 9:0] reg_for_low_bits;
reg [`VEC_BITS * 2 - 1 + 15:0] reg_for_high_bits;

logic [`VEC_BITS * 2 - 1 + 15:0] reg_for_high_bits_nxt, reg_for_high_bits_fill;


reg [`VEC_BITS * 2 - 1:0] reg_for_out;

// counter
reg [13:0] cnt_for_sign_bits;
reg [13:0] cnt_for_low_bits;
reg [13:0] cnt_for_high_bits;

logic [13:0] cnt_for_sign_bits_nxt;
logic [13:0] cnt_for_low_bits_nxt;
logic [13:0] cnt_for_high_bits_nxt;
    
reg [13:0] cnt_for_output;


reg [10:0] read_cnt_salt;
reg [10:0] read_cnt_sign;
reg [10:0] read_cnt_low;
reg [10:0] read_cnt_high;

reg [10:0] write_cnt_output;

//enable signal
logic data_process_en;

logic decode_q01_init_en;
logic q01_sign_init_data_process_en;
logic q01_low_init_data_process_en;
logic q01_high_init_data_process_en;

//ready signal to indicate the data remaining in sign/low/high bits reg is enough to continue decoding
logic ready_for_sign_bits;
logic ready_for_low_bits;
logic ready_for_high_bits;

//start and finish signal for  every special processing
logic start_decode_salt_pre, start_decode_salt, finish_decode_salt;
logic                        start_decode_sig,  finish_decode_sig;
logic start_decode_q00_pre,  start_decode_q00,  finish_decode_q00;

logic start_q00_adjust,  finish_q00_adjust;
logic start_decode_q01_init_pre,  start_decode_q01_init,  finish_decode_q01_init;
logic start_decode_q01_pre,  start_decode_q01,  finish_decode_q01;

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)                                   finish <= 0;
    else if(dec_funct == 0)                     finish <= finish_decode_sig;
    else if((dec_funct == 1) & (q00_only == 1)) finish <= finish_q00_adjust;
    else if((dec_funct == 1) & (q00_only == 0)) finish <= finish_decode_q01;
    else                                        finish <= 0;
end

//ren and wen signal for  every special processing

logic ren_for_salt_pre;

logic ren_for_sign_bits_pre;
logic rdata_sign_bits_valid_pre;
logic rdata_sign_bits_valid;
logic rdata_sign_bits_valid_first;

logic ren_for_low_bits_pre;
logic rdata_low_bits_valid_pre;
logic rdata_low_bits_valid;
logic rdata_low_bits_valid_first;

logic ren_for_high_bits_pre;
logic rdata_high_bits_valid_pre;
logic rdata_high_bits_valid;
logic rdata_high_bits_valid_first;

logic rdata_sign_low_high_bits_valid_filter;

logic ren_for_q00_adjust_pre;
logic wen_for_q00_adjust_pre;
logic [3:0] cnt_q00_adjust;
logic [13:0] start_point_for_q01_cnt_bits;
logic [10:0] start_point_for_q01_read_cnt_sign;
//cnt_q00_adjust = 1:  if data of reg_for_high_bits is not enough, read reg_for_high_bits
//cnt_q00_adjust = 2: 
//cnt_q00_adjust = 3: if data of reg_for_high_bits is not enough, reg reg_for_high_bitsread q00[0], And if read q00[0] 
//cnt_q00_adjust = 4: reg q00[0] and extact adjust factor 
//cnt_q00_adjust = 5: adjust q00[0] and shift reg_for_high_bits
//cnt_q00_adjust = 6: write adjust q00[0] 

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)      rdata_sign_low_high_bits_valid_filter <= 0;
    else if(start) rdata_sign_low_high_bits_valid_filter <= 0;
    else if(start_decode_sig | start_decode_q00 | start_decode_q01_init | start_decode_q01) rdata_sign_low_high_bits_valid_filter <= 0;
    else if((decode_sig_en | decode_q00_en | decode_q01_init_en | decode_q01_en) & (rdata_sign_bits_valid_pre | rdata_low_bits_valid_pre | rdata_high_bits_valid_pre )) rdata_sign_low_high_bits_valid_filter <= rdata_sign_low_high_bits_valid_filter + 1;
end

enc_pipeline_delay #(
    1
) u_rdata_sign_bits_valid(
    .clk,
    .rstn,
    .data_in(rdata_sign_bits_valid_pre),
    .data_out(rdata_sign_bits_valid)
);

enc_pipeline_delay #(
    1
) u_rdata_low_bits_valid(
    .clk,
    .rstn,
    .data_in(rdata_low_bits_valid_pre),
    .data_out(rdata_low_bits_valid)
);

enc_pipeline_delay #(
    1
) u_rdata_high_bits_valid(
    .clk,
    .rstn,
    .data_in(rdata_high_bits_valid_pre),
    .data_out(rdata_high_bits_valid)
);

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                                    rdata_sign_bits_valid_first <= 0;
    else if(start_decode_sig | start_decode_q00) rdata_sign_bits_valid_first <= 1;
    else if(rdata_sign_bits_valid)               rdata_sign_bits_valid_first <= 0;
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                                    rdata_low_bits_valid_first <= 0;
    else if(start_decode_sig | start_decode_q00) rdata_low_bits_valid_first <= 1;
    else if(rdata_low_bits_valid)                rdata_low_bits_valid_first <= 0;
end
    
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                                    rdata_high_bits_valid_first <= 0;
    else if(start_decode_sig | start_decode_q00) rdata_high_bits_valid_first <= 1;
    else if(rdata_high_bits_valid)               rdata_high_bits_valid_first <= 0;
end  
    
//////////////////////////////////////////////////////////////////////    
//decode salt
logic w_en_part1;
logic w_en_part2;
logic start_decode_salt_1;
logic start_decode_salt_2;
logic start_decode_salt_3;

assign start_decode_salt_pre = start & (dec_funct == 0);
assign finish_decode_salt = (security_level == 0)? w_en_part1 : w_en_part2;

enc_pipeline_delay #(
    1
) u_start_decode_salt(
    .clk,
    .rstn,
    .data_in(start_decode_salt_pre),
    .data_out(start_decode_salt)
);

enc_pipeline_delay #(
    1
) u_start_decode_salt_1(
    .clk,
    .rstn,
    .data_in(start_decode_salt),
    .data_out(start_decode_salt_1)
);

enc_pipeline_delay #(
    1
) u_start_decode_salt_2(
    .clk,
    .rstn,
    .data_in(start_decode_salt_1),
    .data_out(start_decode_salt_2)
);

enc_pipeline_delay #(
    1
) u_start_decode_salt_3(
    .clk,
    .rstn,
    .data_in(start_decode_salt_2),
    .data_out(start_decode_salt_3)
);

assign w_en_part1 = start_decode_salt_2;
assign w_en_part2 = start_decode_salt_3 & (security_level == 1) & (dec_funct == 0);

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                      decode_salt_en <= 0;
    else if(start_decode_salt_pre) decode_salt_en <= 1; 
    else if(finish_decode_salt)    decode_salt_en <= 0; 
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                     read_cnt_salt <= 0;
    else if(start)                read_cnt_salt <= r_base_addr_salt_sig;
    else if(decode_salt_en & ren) read_cnt_salt <= read_cnt_salt + 1;
end
 
//////////////////////////////////////////////////////////////////////    
//decode signature
enc_pipeline_delay #(
    1
) u_start_decode_sig(
    .clk,
    .rstn,
    .data_in(finish_decode_salt),
    .data_out(start_decode_sig)
);
 
assign finish_decode_sig = ((security_level == 0)? (wen & (write_cnt_output == (64 + 0))) :  (wen & (write_cnt_output == (128 + 1))))
                           & (decode_sig_en & (dec_funct == 0) );

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                  decode_sig_en <= 0;
    else if(start_decode_sig)  decode_sig_en <= 1; 
    else if(finish_decode_sig) decode_sig_en <= 0; 
end

//////////////////////////////////////////////////////////////////////    
//decode q00
assign start_decode_q00_pre = start  & (dec_funct == 1);

enc_pipeline_delay #(
    1
) u_start_decode_q00(
    .clk,
    .rstn,
    .data_in(start_decode_q00_pre),
    .data_out(start_decode_q00)
);  
 
assign finish_decode_q00 = ((security_level == 0)? (wen & (write_cnt_output == (32 - 1))) :  (wen & (write_cnt_output == (64 - 1))))
                           & (decode_q00_en & (dec_funct == 1) );

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                  decode_q00_en <= 0;
    else if(start_decode_q00)  decode_q00_en <= 1; 
    else if(finish_decode_q00) decode_q00_en <= 0; 
end 
                                                                                                                                                          
//////////////////////////////////////////////////////////////////////    
//q00_adjust

enc_pipeline_delay #(
    1
) u_start_q00_adjust(
    .clk,
    .rstn,
    .data_in(finish_decode_q00),
    .data_out(start_q00_adjust)
);  

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                  adjust_q00_en <= 0;
    else if(start_q00_adjust)  adjust_q00_en <= 1; 
    else if(finish_q00_adjust) adjust_q00_en <= 0; 
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                  cnt_q00_adjust <= 0;
    else if(start_q00_adjust)  cnt_q00_adjust <= 0; 
    else if(finish_q00_adjust) cnt_q00_adjust <= 0; 
    else if(adjust_q00_en)     cnt_q00_adjust <= cnt_q00_adjust + 1; 
end

assign ren_for_q00_adjust_pre = (cnt_q00_adjust == 3) & adjust_q00_en;

assign wen_for_q00_adjust_pre = (cnt_q00_adjust == 6) & adjust_q00_en;

assign finish_q00_adjust = (cnt_q00_adjust == 6) & adjust_q00_en;

//q00[0] adjust
logic [3:0] shift_length_of_adjust_factor_extraction;
logic [6:0] adjust_factor;
logic       q00_original_valid;
logic [31:0] q00_adjust_result;

wire [8:0] cnt_for_consumed_high_bits = 9'd256 - cnt_for_high_bits[8:0];
wire [8:0] q00_end_point = cnt_for_consumed_high_bits + (security_level ? 'd6 : 'd7);
// After adjustment, q00 is padded with zeros to align to an 8-bit boundary;
// q00_padding_point indicates the first value greater than or equal to q00_end_point that is divisible by 8.
wire [8:0] q00_padding_point = { q00_end_point[8:3] + ((q00_end_point[2:0]==3'b0) ? 'd0 : 'd1) , 3'b000 };

assign adjust_factor = reg_for_high_bits[6:0];
logic [5:0] adjust_factor_hawk1024;
assign adjust_factor_hawk1024 = reg_for_high_bits[5:0];
logic [31:0] q00_adjust_result_if_q00_mode_1;
assign q00_adjust_result_if_q00_mode_1 = security_level ? {reg_for_out[31 -7:0], adjust_factor_hawk1024}
                                                        : {reg_for_out[31 -7:0], adjust_factor};

assign q00_original_valid = (cnt_q00_adjust == 4) & adjust_q00_en;

assign q00_adjust_valid = (cnt_q00_adjust == 5) & adjust_q00_en;

assign shift_length_of_adjust_factor_extraction = (cnt_for_high_bits[2:0] == 7)? 7 : (cnt_for_high_bits[2:0] + 8);

assign q00_adjust_result = (q00_mode == 1)? q00_adjust_result_if_q00_mode_1 : 32'b0;

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                  start_point_for_q01_cnt_bits <= 0;
    else if(start_q00_adjust)  start_point_for_q01_cnt_bits <= 0; 
    else if(q00_adjust_valid)  start_point_for_q01_cnt_bits <= 'd256 - q00_padding_point; 
end   

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                  start_point_for_q01_read_cnt_sign <= 0;
    else if(start_q00_adjust)  start_point_for_q01_read_cnt_sign <= 0; 
    else if(q00_adjust_valid) start_point_for_q01_read_cnt_sign <= read_cnt_high - 1 ; 
end  

//////////////////////////////////////////////////////////////////////    
//decode q01 init
assign start_decode_q01_init_pre = finish_q00_adjust & (q00_only == 0) & (dec_funct == 1);
 
 enc_pipeline_delay #(
    1
) u_start_decode_q01_init(
    .clk,
    .rstn,
    .data_in(start_decode_q01_init_pre),
    .data_out(start_decode_q01_init)
); 
 
assign finish_decode_q01_init = decode_q01_init_en & (cnt_for_high_bits == start_point_for_q01_cnt_bits);  

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                       decode_q01_init_en <= 0;
    else if(start_decode_q01_init)  decode_q01_init_en <= 1; 
    else if(finish_decode_q01_init) decode_q01_init_en <= 0; 
end   

assign q01_sign_init_data_process_en = (cnt_for_sign_bits > start_point_for_q01_cnt_bits) & decode_q01_init_en ;
assign q01_low_init_data_process_en = (cnt_for_low_bits > start_point_for_q01_cnt_bits) & decode_q01_init_en ;
assign q01_high_init_data_process_en = (cnt_for_high_bits > start_point_for_q01_cnt_bits) & decode_q01_init_en ;

//////////////////////////////////////////////////////////////////////    
//decode q01
assign start_decode_q01_pre = finish_decode_q01_init & (q00_only == 0) & (dec_funct == 1);
 
enc_pipeline_delay #(
    1
) u_start_decode_q01(
    .clk,
    .rstn,
    .data_in(start_decode_q01_pre),
    .data_out(start_decode_q01)
);  
 
assign finish_decode_q01 = (security_level == 0)? (wen & (write_cnt_output == (32 + 64 - 1))) :  (wen & (write_cnt_output == (64 + 128 - 1)))
                            & (decode_q01_en & (dec_funct == 1) );


always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                  decode_q01_en <= 0;
    else if(start_decode_q01)  decode_q01_en <= 1; 
    else if(finish_decode_q01) decode_q01_en <= 0; 
end   

//////////////////////////////////////////////////////////////////////    
//data processing
logic ready_for_low_bits_normal;
logic ready_for_low_bits_decode_q01;

//sign bits
assign data_process_en = ready_for_sign_bits & ready_for_low_bits & ready_for_high_bits & (decode_sig_en | decode_q00_en | decode_q01_en);
assign ready_for_sign_bits = (cnt_for_sign_bits >= 1);

assign ready_for_low_bits_normal = ((security_level == 0)? (cnt_for_low_bits >= 5): (cnt_for_low_bits >= 6));
assign ready_for_low_bits_decode_q01 = ((security_level == 0)? (cnt_for_low_bits >= 9): (cnt_for_low_bits >= 10));
assign ready_for_low_bits = (decode_q01_en == 1)? ready_for_low_bits_decode_q01: ready_for_low_bits_normal;

assign ready_for_high_bits = (cnt_for_high_bits >= 15);

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                      cnt_for_sign_bits <= 0;
    else if(start)                 cnt_for_sign_bits <= 0;
    else if(rdata_sign_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_sign_bits_valid_first & decode_sig_en & (security_level == 0))  cnt_for_sign_bits <= 64;
    else if(rdata_sign_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_sign_bits_valid_first & decode_sig_en & (security_level == 1))  cnt_for_sign_bits <= 192;
    else if(rdata_sign_bits_valid & rdata_sign_low_high_bits_valid_filter) cnt_for_sign_bits <= cnt_for_sign_bits + 256;
    else if(finish_decode_salt)    cnt_for_sign_bits <= 0;
    else if(finish_decode_sig)     cnt_for_sign_bits <= 0;
    else if(finish_q00_adjust)     cnt_for_sign_bits <= 0;
    else if(finish_decode_q01)     cnt_for_sign_bits <= 0;
    else if(finish)                cnt_for_sign_bits <= 0;
    else if(q01_sign_init_data_process_en)  cnt_for_sign_bits <= cnt_for_sign_bits - 4;
    else if(data_process_en)       cnt_for_sign_bits <= cnt_for_sign_bits_nxt;
end

always_comb begin 
    cnt_for_sign_bits_nxt = cnt_for_sign_bits - 1;
end

always_ff @(posedge clk) begin
    if(decode_salt_en & rdata_sign_bits_valid)                                                                                                   reg_for_sign_bits <= r_data;
    else if(rdata_sign_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_sign_bits_valid_first & decode_sig_en & (security_level == 0)) reg_for_sign_bits <= { 192'b0,r_data[`VEC_BITS * 2- 1:192] };
    else if(rdata_sign_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_sign_bits_valid_first & decode_sig_en & (security_level == 1)) reg_for_sign_bits <= { 64'b0,r_data[`VEC_BITS * 2- 1:64] };
    else if(rdata_sign_bits_valid & rdata_sign_low_high_bits_valid_filter) reg_for_sign_bits <= r_data;
    else if(q01_sign_init_data_process_en)  reg_for_sign_bits <= {4'b0, reg_for_sign_bits[`VEC_BITS * 2- 1: 4]};
    else if(data_process_en)       reg_for_sign_bits <= {1'b0, reg_for_sign_bits[`VEC_BITS * 2- 1: 1]};
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                                                            read_cnt_sign <= 0;
    else if(start | finish_decode_salt | finish_decode_sig | finish_decode_q00 | finish_decode_q01) read_cnt_sign <= 0;
    else if(start_decode_sig & (security_level == 0) & (dec_funct == 0))    read_cnt_sign <= r_base_addr_salt_sig;
    else if(start_decode_sig & (security_level == 1) & (dec_funct == 0))    read_cnt_sign <= r_base_addr_salt_sig + 1;
    else if(start_decode_q00                         & (dec_funct == 1))    read_cnt_sign <= r_base_addr_q00q01;
    else if(finish_q00_adjust)                                              read_cnt_sign <= start_point_for_q01_read_cnt_sign;
    else if(rdata_sign_bits_valid & rdata_sign_low_high_bits_valid_filter ) read_cnt_sign <= read_cnt_sign + 1;
end

//low bits
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                      cnt_for_low_bits <= 0;
    else if(start)                 cnt_for_low_bits <= 0;
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_low_bits_valid_first & decode_sig_en & (security_level == 0))  cnt_for_low_bits <= 64;
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_low_bits_valid_first & decode_sig_en & (security_level == 1))  cnt_for_low_bits <= 192;
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter)                                                                       cnt_for_low_bits <= cnt_for_low_bits + 256;
    else if(finish_decode_sig)     cnt_for_low_bits <= 0;
    else if(finish_q00_adjust)     cnt_for_low_bits <= 0;
    else if(finish)                cnt_for_low_bits <= 0;
    else if(q01_low_init_data_process_en) cnt_for_low_bits <= cnt_for_low_bits_nxt;
    else if(data_process_en)       cnt_for_low_bits <= cnt_for_low_bits_nxt;
end

always_comb begin 
    if(q01_low_init_data_process_en)                      cnt_for_low_bits_nxt = cnt_for_low_bits - 4;
    else if((decode_q01_en == 1) & (security_level == 0)) cnt_for_low_bits_nxt = cnt_for_low_bits - 9;
    else if((decode_q01_en == 1) & (security_level == 1)) cnt_for_low_bits_nxt = cnt_for_low_bits - 10;
    else if(security_level == 0)                          cnt_for_low_bits_nxt = cnt_for_low_bits - 5;
    else                                                  cnt_for_low_bits_nxt = cnt_for_low_bits - 6;
end

always_ff @(posedge clk) begin
    if((rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_low_bits_valid_first & decode_sig_en & (security_level == 0)))  reg_for_low_bits <= {9'b0, 192'b0,r_data[`VEC_BITS * 2- 1:192] };
    else if((rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_low_bits_valid_first & decode_sig_en & (security_level == 1)))  reg_for_low_bits <= {9'b0, 64'b0,r_data[`VEC_BITS * 2- 1:64] };
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 0 )) reg_for_low_bits <= {9'b0, r_data};
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 1 )) reg_for_low_bits <= {8'b0, r_data, reg_for_low_bits[0:0] };
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 2 )) reg_for_low_bits <= {7'b0, r_data, reg_for_low_bits[1:0] };
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 3 )) reg_for_low_bits <= {6'b0, r_data, reg_for_low_bits[2:0] };
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 4 )) reg_for_low_bits <= {5'b0, r_data, reg_for_low_bits[3:0] };
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 5 )) reg_for_low_bits <= {4'b0, r_data, reg_for_low_bits[4:0] };
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 6 )) reg_for_low_bits <= {3'b0, r_data, reg_for_low_bits[5:0] };
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 7 )) reg_for_low_bits <= {2'b0, r_data, reg_for_low_bits[6:0] };
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 8 )) reg_for_low_bits <= {1'b0, r_data, reg_for_low_bits[7:0] };
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter &(cnt_for_low_bits == 9 )) reg_for_low_bits <= {      r_data, reg_for_low_bits[8:0] };
    else if(q01_low_init_data_process_en)                                          reg_for_low_bits <= {4'b0, reg_for_low_bits[`VEC_BITS * 2- 1 + 9: 4]};
    else if(data_process_en & (decode_q01_en == 1) & (security_level == 0))        reg_for_low_bits <= {9'b0, reg_for_low_bits[`VEC_BITS * 2- 1 + 9: 9]};
    else if(data_process_en & (decode_q01_en == 1) & (security_level == 1))        reg_for_low_bits <= {10'b0, reg_for_low_bits[`VEC_BITS * 2- 1 + 9: 10]};
    else if(data_process_en & (security_level == 0))        reg_for_low_bits <= {5'b0, reg_for_low_bits[`VEC_BITS * 2- 1 + 9: 5]};
    else if(data_process_en & (security_level == 1))        reg_for_low_bits <= {6'b0, reg_for_low_bits[`VEC_BITS * 2- 1 + 9: 6]};
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                                                              read_cnt_low <= 0;
    else if(start & (security_level == 0) & (dec_funct == 0))              read_cnt_low <= r_base_addr_salt_sig + 2;
    else if(start & (security_level == 1) & (dec_funct == 0))              read_cnt_low <= r_base_addr_salt_sig + 5;
    else if(start & (security_level == 0) & (dec_funct == 1))              read_cnt_low <= r_base_addr_q00q01 + 1;
    else if(start & (security_level == 1) & (dec_funct == 1))              read_cnt_low <= r_base_addr_q00q01 + 2;
    else if(finish_q00_adjust & (security_level == 0))                     read_cnt_low <= start_point_for_q01_read_cnt_sign + 2;
    else if(finish_q00_adjust & (security_level == 1))                     read_cnt_low <= start_point_for_q01_read_cnt_sign + 4;
    else if(rdata_low_bits_valid & rdata_sign_low_high_bits_valid_filter ) read_cnt_low <= read_cnt_low + 1;
end

//high bits
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                      cnt_for_high_bits <= 0;
    else if(start)                 cnt_for_high_bits <= 0;
    else if(rdata_high_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_high_bits_valid_first & decode_sig_en & (security_level == 0))  cnt_for_high_bits <= 64;
    else if(rdata_high_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_high_bits_valid_first & decode_sig_en & (security_level == 1))  cnt_for_high_bits <= 192;
    else if(rdata_high_bits_valid & rdata_sign_low_high_bits_valid_filter)                                                                        cnt_for_high_bits <= cnt_for_high_bits + 256;
    else if(finish_decode_sig)     cnt_for_high_bits <= 0;
    else if(finish_decode_q01)     cnt_for_high_bits <= 0;
    else if(finish_q00_adjust)     cnt_for_high_bits <= 0;
    else if(q01_high_init_data_process_en)  cnt_for_high_bits <= cnt_for_high_bits - 4;
    else if(data_process_en)       cnt_for_high_bits <= cnt_for_high_bits_nxt;
end

always_comb begin 
    casex(reg_for_high_bits[15:0])
        16'bXXXXXXXXXXXXXXX1: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 1 ; reg_for_high_bits_nxt = { 1'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15: 1] }; end
        16'bXXXXXXXXXXXXXX10: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 2 ; reg_for_high_bits_nxt = { 2'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15: 2] };  end
        16'bXXXXXXXXXXXXX100: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 3 ; reg_for_high_bits_nxt = { 3'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15: 3] };  end
        16'bXXXXXXXXXXXX1000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 4 ; reg_for_high_bits_nxt = { 4'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15: 4] };  end
        16'bXXXXXXXXXXX10000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 5 ; reg_for_high_bits_nxt = { 5'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15: 5] };  end
        16'bXXXXXXXXXX100000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 6 ; reg_for_high_bits_nxt = { 6'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15: 6] };  end
        16'bXXXXXXXXX1000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 7 ; reg_for_high_bits_nxt = { 7'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15: 7] };  end
        16'bXXXXXXXX10000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 8 ; reg_for_high_bits_nxt = { 8'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15: 8] };  end
        16'bXXXXXXX100000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 9 ; reg_for_high_bits_nxt = { 9'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15: 9] };  end
        16'bXXXXXX1000000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 10; reg_for_high_bits_nxt = {10'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15:10] };  end
        16'bXXXXX10000000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 11; reg_for_high_bits_nxt = {11'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15:11] };  end
        16'bXXXX100000000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 12; reg_for_high_bits_nxt = {12'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15:12] };  end
        16'bXXX1000000000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 13; reg_for_high_bits_nxt = {13'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15:13] };  end
        16'bXX10000000000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 14; reg_for_high_bits_nxt = {14'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15:14] };  end
        16'bX100000000000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 15; reg_for_high_bits_nxt = {15'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15:15] };  end
        16'b1000000000000000: begin cnt_for_high_bits_nxt = cnt_for_high_bits - 16; reg_for_high_bits_nxt = {16'b0, reg_for_high_bits[`VEC_BITS * 2- 1+ 15:16] };  end       
        default: begin cnt_for_high_bits_nxt = cnt_for_high_bits; reg_for_high_bits_nxt = reg_for_high_bits; end
    endcase
end

always_ff @(posedge clk) begin
    if(rdata_high_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_high_bits_valid_first & decode_sig_en & (security_level == 0))       reg_for_high_bits <= { 15'b0, 192'b0,r_data[`VEC_BITS * 2- 1:192] };
    else if(rdata_high_bits_valid & rdata_sign_low_high_bits_valid_filter & rdata_high_bits_valid_first & decode_sig_en & (security_level == 1))  reg_for_high_bits <= { 15'b0, 64'b0,r_data[`VEC_BITS * 2- 1:64] };
    else if(rdata_high_bits_valid  & rdata_sign_low_high_bits_valid_filter )  reg_for_high_bits <= reg_for_high_bits_fill;
    else if(q01_high_init_data_process_en)                                    reg_for_high_bits <= {4'b0, reg_for_high_bits[`VEC_BITS * 2- 1 + 15 : 4]};
    else if(data_process_en)                                                  reg_for_high_bits <= reg_for_high_bits_nxt;
end
 
logic [3:0] consume_bits_of_reg_for_high_bits;
 
always_comb begin 
    casex(cnt_for_high_bits[3:0])
        4'd1 : begin reg_for_high_bits_fill = { 15'b0, r_data,reg_for_high_bits[ 0: 0] }; end
        4'd2 : begin reg_for_high_bits_fill = { 14'b0, r_data,reg_for_high_bits[ 1: 0] }; end
        4'd3 : begin reg_for_high_bits_fill = { 13'b0, r_data,reg_for_high_bits[ 2: 0] }; end
        4'd4 : begin reg_for_high_bits_fill = { 12'b0, r_data,reg_for_high_bits[ 3: 0] }; end
        4'd5 : begin reg_for_high_bits_fill = { 11'b0, r_data,reg_for_high_bits[ 4: 0] }; end
        4'd6 : begin reg_for_high_bits_fill = { 10'b0, r_data,reg_for_high_bits[ 5: 0] }; end
        4'd7 : begin reg_for_high_bits_fill = {  9'b0, r_data,reg_for_high_bits[ 6: 0] }; end
        4'd8 : begin reg_for_high_bits_fill = {  8'b0, r_data,reg_for_high_bits[ 7: 0] }; end
        4'd9 : begin reg_for_high_bits_fill = {  7'b0, r_data,reg_for_high_bits[ 8: 0] }; end
        4'd10: begin reg_for_high_bits_fill = {  6'b0, r_data,reg_for_high_bits[ 9: 0] }; end
        4'd11: begin reg_for_high_bits_fill = {  5'b0, r_data,reg_for_high_bits[10: 0] }; end
        4'd12: begin reg_for_high_bits_fill = {  4'b0, r_data,reg_for_high_bits[11: 0] }; end
        4'd13: begin reg_for_high_bits_fill = {  3'b0, r_data,reg_for_high_bits[12: 0] }; end
        4'd14: begin reg_for_high_bits_fill = {  2'b0, r_data,reg_for_high_bits[13: 0] }; end
        4'd15: begin reg_for_high_bits_fill = {  1'b0, r_data,reg_for_high_bits[14: 0] }; end
        default: begin reg_for_high_bits_fill = { 16'b0, r_data} ; end
    endcase
end 


always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                                                 read_cnt_high <= 0;
    else if(start & (security_level == 0) & (dec_funct == 0)) read_cnt_high <= r_base_addr_salt_sig + 12;
    else if(start & (security_level == 1) & (dec_funct == 0)) read_cnt_high <= r_base_addr_salt_sig + 29;
    else if(start & (security_level == 0) & (dec_funct == 1)) read_cnt_high <= r_base_addr_q00q01 + 6;
    else if(start & (security_level == 1) & (dec_funct == 1)) read_cnt_high <= r_base_addr_q00q01 + 14;
    else if(finish_q00_adjust & (security_level == 0))        read_cnt_high <= start_point_for_q01_read_cnt_sign + 2 + 18;
    else if(finish_q00_adjust & (security_level == 1))        read_cnt_high <= start_point_for_q01_read_cnt_sign + 4 + 40;
    else if(rdata_high_bits_valid  & rdata_sign_low_high_bits_valid_filter ) read_cnt_high <= read_cnt_high + 1;
end

//decodone elements
logic [31:0] decode_one_element_result;
logic [31:0] decode_one_element_result_512;
logic [31:0] decode_one_element_result_1024;
logic [31:0] decode_one_element_q01_result;
logic [31:0] decode_one_element_q01_result_512;
logic [31:0] decode_one_element_q01_result_1024;

logic       decode_one_element_sign_result;

logic [5:0] decode_one_element_low_result;
logic [9:0] decode_one_element_q01_low_result;

logic [3:0] decode_one_element_high_result;

assign decode_one_element_sign_result = reg_for_sign_bits[0];

assign decode_one_element_low_result = (security_level == 0)? {1'b0, reg_for_low_bits[4:0]} : reg_for_low_bits[5:0];
assign decode_one_element_q01_low_result = (security_level == 0)? {1'b0, reg_for_low_bits[8:0]} : reg_for_low_bits[9:0];

always_comb begin 
    casex(reg_for_high_bits[15:0])
        16'bXXXXXXXXXXXXXXX1: begin decode_one_element_high_result = 0; end
        16'bXXXXXXXXXXXXXX10: begin decode_one_element_high_result = 1; end
        16'bXXXXXXXXXXXXX100: begin decode_one_element_high_result = 2; end
        16'bXXXXXXXXXXXX1000: begin decode_one_element_high_result = 3; end
        16'bXXXXXXXXXXX10000: begin decode_one_element_high_result = 4; end
        16'bXXXXXXXXXX100000: begin decode_one_element_high_result = 5; end
        16'bXXXXXXXXX1000000: begin decode_one_element_high_result = 6; end
        16'bXXXXXXXX10000000: begin decode_one_element_high_result = 7; end
        16'bXXXXXXX100000000: begin decode_one_element_high_result = 8; end
        16'bXXXXXX1000000000: begin decode_one_element_high_result = 9; end
        16'bXXXXX10000000000: begin decode_one_element_high_result = 10; end
        16'bXXXX100000000000: begin decode_one_element_high_result = 11; end
        16'bXXX1000000000000: begin decode_one_element_high_result = 12; end
        16'bXX10000000000000: begin decode_one_element_high_result = 13; end
        16'bX100000000000000: begin decode_one_element_high_result = 14; end
        16'b1000000000000000: begin decode_one_element_high_result = 15; end
        default: begin decode_one_element_high_result = 0; end
    endcase
end

assign consume_bits_of_reg_for_high_bits = decode_one_element_high_result + 1;

assign decode_one_element_result_512  = (decode_one_element_sign_result == 0)? {23'b0 ,decode_one_element_high_result, decode_one_element_low_result[4:0]}: (~{23'b0 ,decode_one_element_high_result, decode_one_element_low_result[4:0]});
assign decode_one_element_result_1024 = (decode_one_element_sign_result == 0)? {22'b0 ,decode_one_element_high_result, decode_one_element_low_result[5:0]}: (~{22'b0 ,decode_one_element_high_result, decode_one_element_low_result[5:0]}); 
assign decode_one_element_result = (security_level == 0)? decode_one_element_result_512: decode_one_element_result_1024;

assign decode_one_element_q01_result_512  = (decode_one_element_sign_result == 0)? {19'b0 ,decode_one_element_high_result, decode_one_element_q01_low_result[8:0]}: (~{19'b0 ,decode_one_element_high_result, decode_one_element_q01_low_result[8:0]});
assign decode_one_element_q01_result_1024 = (decode_one_element_sign_result == 0)? {18'b0 ,decode_one_element_high_result, decode_one_element_q01_low_result[9:0]}: (~{18'b0 ,decode_one_element_high_result, decode_one_element_q01_low_result[9:0]}); 
assign decode_one_element_q01_result = (security_level == 0)? decode_one_element_q01_result_512: decode_one_element_q01_result_1024;

always_ff @(posedge clk) begin
    if(q00_original_valid)                      reg_for_out <= r_data;
    else if(q00_adjust_valid)                   reg_for_out <= {reg_for_out[`VEC_BITS * 2 - 1 :32], q00_adjust_result};
    else if(data_process_en  & (decode_q01_en == 1)) reg_for_out <= {decode_one_element_q01_result, reg_for_out[`VEC_BITS * 2 - 1 :32]};
    else if(data_process_en)                    reg_for_out <= {decode_one_element_result, reg_for_out[`VEC_BITS * 2 - 1 :32]};
end

//updata cnt_for_output
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                      cnt_for_output <= 0;
    else if(start)                 cnt_for_output <= 0;
    else if(finish_decode_sig)     cnt_for_output <= 0;
    else if(finish_decode_q00)     cnt_for_output <= 0;
    else if(finish_decode_q01)     cnt_for_output <= 0;
    else if((data_process_en == 1) & (wen == 1)) cnt_for_output <= 32;
    else if((data_process_en == 0) & (wen == 1)) cnt_for_output <= 0;
    else if(data_process_en == 1)                cnt_for_output <= cnt_for_output + 32;
end

//generate ren and wen

assign ren_for_salt_pre = (decode_salt_en & ( start_decode_salt | start_decode_salt_1 & (security_level == 1)));
assign ren_for_sign_bits_pre = ((~ready_for_sign_bits) & (decode_sig_en | decode_q00_en | decode_q01_init_en | decode_q01_en)) ;                      
assign ren_for_low_bits_pre = (~ready_for_low_bits) & (decode_sig_en | decode_q00_en | decode_q01_init_en | decode_q01_en);
assign ren_for_high_bits_pre = (~ready_for_high_bits) & (decode_sig_en | decode_q00_en | decode_q01_init_en | decode_q01_en);
 

always_comb begin
    casex({ren_for_q00_adjust_pre, ren_for_salt_pre, ren_for_sign_bits_pre, ren_for_low_bits_pre, ren_for_high_bits_pre})
        5'b1xxxx: begin ren = 1'b1; r_offset_addr = w_base_addr; rdata_sign_bits_valid_pre = 0; rdata_low_bits_valid_pre = 0; rdata_high_bits_valid_pre = 0;end
        5'b01xxx: begin ren = 1'b1; r_offset_addr = read_cnt_salt; rdata_sign_bits_valid_pre = 1; rdata_low_bits_valid_pre = 0; rdata_high_bits_valid_pre = 0;end
        5'b001xx: begin ren = 1'b1; r_offset_addr = read_cnt_sign ; rdata_sign_bits_valid_pre = 1; rdata_low_bits_valid_pre = 0; rdata_high_bits_valid_pre = 0;end
        5'b0001x: begin ren = 1'b1; r_offset_addr = read_cnt_low ;  rdata_sign_bits_valid_pre = 0; rdata_low_bits_valid_pre = 1; rdata_high_bits_valid_pre = 0; end
        5'b00001: begin ren = 1'b1; r_offset_addr = read_cnt_high ; rdata_sign_bits_valid_pre = 0; rdata_low_bits_valid_pre = 0; rdata_high_bits_valid_pre = 1; end
        default:  begin ren = 1'b0;  r_offset_addr = 0; rdata_sign_bits_valid_pre = 0; rdata_low_bits_valid_pre = 0; rdata_high_bits_valid_pre = 0; end
    endcase
end 
 
 
assign wen = (adjust_q00_en == 1)?    wen_for_q00_adjust_pre 
                                  : ((decode_salt_en == 1)?  (w_en_part1 | w_en_part2) : cnt_for_output == 256);

assign w_offset_addr = (adjust_q00_en == 1)? w_base_addr : write_cnt_output + w_base_addr;

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)                                                                       write_cnt_output <= 0;
    else if(start)                                                                  write_cnt_output <= 0;
    else if(wen & (decode_salt_en | decode_sig_en | decode_q00_en | decode_q01_en)) write_cnt_output <= write_cnt_output + 1;
end

always_comb begin
    if((decode_salt_en == 1) & (security_level == 0) & (w_en_part1 == 1))        w_data = {64'd0  ,reg_for_sign_bits[191:0]};
    else if(((decode_salt_en == 1) & (security_level == 1) & (w_en_part1 == 1))) w_data = reg_for_sign_bits;
    else if(((decode_salt_en == 1) & (security_level == 1) & (w_en_part2 == 1))) w_data = {192'd0, reg_for_sign_bits[63:0]};
    else                                                                         w_data = reg_for_out;
end

assign q00_0 = q00_adjust_result_if_q00_mode_1;

endmodule
