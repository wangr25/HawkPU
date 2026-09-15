`include "../defines/defines.sv"

module encode (

    input   wire    clk,
    input   wire    rstn,               // async, low active reset
    input   wire    security_level,     // 0-hawk512, 1-hawk1024

    input   wire    start,              // pulse
    output  logic   finish,

    output  logic   rdy_o,

    // read buffer
    output  logic                           ren,
    output  logic   [`ADDR_WIDTH-1:0]       r_offset_addr,
    input   logic                           vld_i,          // the read vector is valid
    input   logic   [`VEC_BITS*2-1:0]       r_data,           // vn="vector number"
    
    // write buffer
    output  logic                           wen,
    output  logic   [`ADDR_WIDTH-1:0]       w_offset_addr,
    output  logic   [`VEC_BITS*2-1:0]       w_data
);

parameter POLY_SIZE_512  = 512  + 1;
parameter POLY_SIZE_1024 = 1024 + 1;

wire [`ADDR_WIDTH-1:0] w_base_addr = 200;
wire [`ADDR_WIDTH-1:0] salt_addr = 0;
wire [`ADDR_WIDTH-1:0] r_base_addr = (security_level == 0)? (1+salt_addr):(2+salt_addr);

wire start_delay_1;
wire start_delay_2;
wire salt_update_en;

reg       encode_en;
wire      encode_update_en_pre;
wire      encode_update_en;
wire      normal_finish;
wire      last_high_bits_write;
wire      pre_last_high_bits_write;
wire      last_normal_wen;

reg [`VEC_BITS * 2 - 1:0] reg_for_input;
reg [2:0] remain_cnt_for_reg_for_input;  // 7~0 represents 8~1, only 3 bits are enough
    
reg [`VEC_BITS * 2 - 1:0] reg_for_sign_bits;
reg [`VEC_BITS * 2 - 1 + 5:0] reg_for_low_bits;
reg [`VEC_BITS * 2 - 1 + 15:0] reg_for_high_bits;

reg [13:0] cnt_for_sign_bits;
reg [13:0] cnt_for_low_bits;
reg [13:0] cnt_for_high_bits;

wire [8:0] data_last_out_high_bits_shift_block_num = (14'd256 - cnt_for_high_bits)/16;
wire [4:0] data_last_out_high_bits_shift_bit_num = (14'd256 - cnt_for_high_bits)%16;

reg  last_high_bits_write_cnt_en;

reg [8:0] cnt_for_data_last_out_high_bits_shift_block;
reg       en_for_data_last_out_high_bits_shift_block;
reg       done_for_data_last_out_high_bits_shift_block;
wire      cnt_for_data_last_out_high_bits_shift_block_finish = (cnt_for_data_last_out_high_bits_shift_block == data_last_out_high_bits_shift_block_num) & last_high_bits_write_cnt_en;

reg [4:0] cnt_for_data_last_out_high_bits_shift_bit;
reg       en_for_data_last_out_high_bits_shift_bit;
reg       done_for_data_last_out_high_bits_shift_bit;
wire      cnt_for_data_last_out_high_bits_shift_bit_finish = (cnt_for_data_last_out_high_bits_shift_bit == data_last_out_high_bits_shift_bit_num) & last_high_bits_write_cnt_en;

reg [10:0] read_cnt;
reg [10:0] last_write_cnt;

logic encode_last_en;

logic encode_finish;
logic padding_finish;

logic rdy_flag;

//////////////////////////////////////////////////////////////////////
enc_pipeline_delay #(
    1
) u_start_delay_1(
    .clk,
    .rstn,
    .data_in(start),
    .data_out(start_delay_1)
);

enc_pipeline_delay #(
    1
) u_start_delay_2(
    .clk,
    .rstn,
    .data_in(start_delay_1),
    .data_out(start_delay_2)
);

enc_pipeline_delay #(
    1
) u_salt_update_en(
    .clk,
    .rstn,
    .data_in(start_delay_2),
    .data_out(salt_update_en)
);

enc_pipeline_delay #(
    2
) u_encode_update_en(
    .clk,
    .rstn,
    .data_in(encode_en),
    .data_out(encode_update_en_pre)
);

enc_pipeline_delay #(
    4
) u_last_high_bits_write(
    .clk,
    .rstn,
    .data_in(normal_finish),
    .data_out(last_high_bits_write)
);
enc_pipeline_delay #(
    3
) u_pre_last_high_bits_write(
    .clk,
    .rstn,
    .data_in(normal_finish),
    .data_out(pre_last_high_bits_write)
);

wire write_sign_bits_en = (cnt_for_sign_bits >= 256);
wire write_low_bits_en = (cnt_for_low_bits >= 256);
wire write_high_bits_en = (cnt_for_high_bits >= 256) | last_normal_wen;   
wire write_multiple_en = (write_sign_bits_en + write_low_bits_en + write_high_bits_en >= 2);
wire write_multiple_en_delay_2;
wire write_low_bits_en_delay_1;
wire write_high_bits_en_delay_2;

assign encode_update_en = encode_update_en_pre & (write_multiple_en == 0);

logic [`ADDR_WIDTH-1:0] w_sign_offset_addr;
logic [`ADDR_WIDTH-1:0] w_low_offset_addr;
logic [`ADDR_WIDTH-1:0] w_high_offset_addr;

logic [`ADDR_WIDTH-1:0] w_sign_addr_cnt;
logic [`ADDR_WIDTH-1:0] w_low_addr_cnt;
logic [`ADDR_WIDTH-1:0] w_high_addr_cnt;

logic [5:0] max_w_num;
logic [`ADDR_WIDTH-1:0] padding_base_addr;
wire [2:0] padding_num = max_w_num - padding_base_addr;
logic [2:0] padding_cnt;
logic padding_cnt_en;

enc_pipeline_delay #(
    2
) u_write_multiple_en_delay_2(
    .clk,
    .rstn,
    .data_in(write_multiple_en),
    .data_out(write_multiple_en_delay_2)
);

enc_pipeline_delay #(
    1
) u_write_low_bits_en_delay_1(
    .clk,
    .rstn,
    .data_in(write_low_bits_en & write_multiple_en),
    .data_out(write_low_bits_en_delay_1)
);

enc_pipeline_delay #(
    2
) u_write_high_bits_en_delay_2(
    .clk,
    .rstn,
    .data_in(write_high_bits_en & write_multiple_en),
    .data_out(write_high_bits_en_delay_2)
);

always_ff@(posedge clk or negedge rstn) begin
    if(!rstn)               encode_en <= 0;
    else if(start_delay_2)  encode_en <= 1;
    else if(normal_finish)  encode_en <= 0;
end 

//last read and write
always_ff@(posedge clk) begin
    if(start)              encode_last_en <= 0;
    else if(done_for_data_last_out_high_bits_shift_bit) encode_last_en <= 1;
    else if(encode_finish)        encode_last_en <= 0;
end

always_ff@(posedge clk) begin
    if(start | normal_finish) last_write_cnt <= 0;
    else if(encode_finish)           last_write_cnt <= 0;
    else if(encode_last_en)   last_write_cnt <= last_write_cnt + 1;
end

assign last_normal_wen = last_write_cnt == 1;

//read signal generate
always_ff@(posedge clk or negedge rstn) begin
    if(!rstn)                 read_cnt <= 0;
    else if(normal_finish)    read_cnt <= 0; 
    else if(encode_en & (write_multiple_en == 0)) read_cnt <= read_cnt + 1; 
end

always_comb begin
    if(encode_last_en) ren = (last_write_cnt == 3)|(last_write_cnt == 6);
    else if(start_delay_1) ren = 1;
    else if(start_delay_2 & (security_level == 1)) ren = 1;
    else if(((read_cnt%8 == 0)&encode_en)) ren = 1;
    else ren = 0;
end 
  
always_comb begin
    if(encode_last_en & (last_write_cnt == 3))       r_offset_addr = (security_level == 0)? (2 + w_base_addr) : (5 + w_base_addr);
    else if (encode_last_en & (last_write_cnt == 6)) r_offset_addr = (security_level == 0)? (12  + w_base_addr) : (29  + w_base_addr);
    else if (encode_en)                              r_offset_addr = read_cnt / 8 + r_base_addr;
    else if (start_delay_1)                          r_offset_addr = salt_addr;
    else if (start_delay_2 & (security_level == 1))  r_offset_addr = salt_addr + 1;
    else                                             r_offset_addr = 'x;
end

assign normal_finish = (security_level == 0)?  (read_cnt == 511) : (read_cnt == 1023);

assign encode_finish = (last_write_cnt == 9);

//write signal generate
wire [13:0] data_out_low_bits_index = cnt_for_low_bits - 14'd256;
wire [13:0] data_out_high_bits_index = (cnt_for_high_bits >= 14'd256) & (last_normal_wen != 1)? (cnt_for_high_bits - 14'd256) : 0;

always_ff @(posedge clk or negedge rstn) begin
     if(!rstn)   last_high_bits_write_cnt_en <= 0;
     else if(start) last_high_bits_write_cnt_en <= 0;
     else if(last_high_bits_write) last_high_bits_write_cnt_en <= 1;
     else if(encode_finish) last_high_bits_write_cnt_en <= 0;
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)  begin 
        cnt_for_data_last_out_high_bits_shift_block <= 0; 
        en_for_data_last_out_high_bits_shift_block <= 0;
        done_for_data_last_out_high_bits_shift_block <= 0; 
    end
    else if(pre_last_high_bits_write)  begin 
        cnt_for_data_last_out_high_bits_shift_block <= 0; 
        en_for_data_last_out_high_bits_shift_block <= 0;
        done_for_data_last_out_high_bits_shift_block <= 0; 
    end
    else if(last_high_bits_write) begin 
        if (data_last_out_high_bits_shift_block_num=='d0) begin  // no need shift block
            cnt_for_data_last_out_high_bits_shift_block <= data_last_out_high_bits_shift_block_num + 'd1; // prevent asserting cnt_for_data_last_out_high_bits_shift_block_finish
            en_for_data_last_out_high_bits_shift_block <= 0;
            done_for_data_last_out_high_bits_shift_block <= 1;
        end
        else begin
            cnt_for_data_last_out_high_bits_shift_block <= cnt_for_data_last_out_high_bits_shift_block + 1; 
            en_for_data_last_out_high_bits_shift_block <= 1;
            done_for_data_last_out_high_bits_shift_block <= 0;
        end
    end
    else if(cnt_for_data_last_out_high_bits_shift_block_finish) begin 
        cnt_for_data_last_out_high_bits_shift_block <= data_last_out_high_bits_shift_block_num + 'd1;  // prevent asserting cnt_for_data_last_out_high_bits_shift_block_finish
        en_for_data_last_out_high_bits_shift_block <= 0;
        done_for_data_last_out_high_bits_shift_block <= 1;
    end
    else if(en_for_data_last_out_high_bits_shift_block) begin 
        cnt_for_data_last_out_high_bits_shift_block <= cnt_for_data_last_out_high_bits_shift_block + 1; 
        en_for_data_last_out_high_bits_shift_block <= 1;
        done_for_data_last_out_high_bits_shift_block <= 0;
    end
    else begin 
        cnt_for_data_last_out_high_bits_shift_block <= data_last_out_high_bits_shift_block_num + 'd1;  // prevent asserting cnt_for_data_last_out_high_bits_shift_block_finish
        en_for_data_last_out_high_bits_shift_block <= 0;
        done_for_data_last_out_high_bits_shift_block <= 0;
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn)  begin 
        cnt_for_data_last_out_high_bits_shift_bit <= 0; 
        en_for_data_last_out_high_bits_shift_bit <= 0;
        done_for_data_last_out_high_bits_shift_bit <= 0; 
    end
    else if(start)  begin 
        cnt_for_data_last_out_high_bits_shift_bit <= 0; 
        en_for_data_last_out_high_bits_shift_bit <= 0;
        done_for_data_last_out_high_bits_shift_bit <= 0; 
    end
    else if(done_for_data_last_out_high_bits_shift_block) begin 
        if (data_last_out_high_bits_shift_bit_num=='d0) begin  // no need shift bit
            cnt_for_data_last_out_high_bits_shift_bit <= data_last_out_high_bits_shift_bit_num + 'd1;
            en_for_data_last_out_high_bits_shift_bit <= 0;
            done_for_data_last_out_high_bits_shift_bit <= 1;
        end
        else begin
            cnt_for_data_last_out_high_bits_shift_bit <= cnt_for_data_last_out_high_bits_shift_bit + 1; 
            en_for_data_last_out_high_bits_shift_bit <= 1;
            done_for_data_last_out_high_bits_shift_bit <= 0;
        end
    end
    else if(cnt_for_data_last_out_high_bits_shift_bit_finish) begin 
        cnt_for_data_last_out_high_bits_shift_bit <= data_last_out_high_bits_shift_bit_num + 'd1;  // prevent asserting cnt_for_data_last_out_high_bits_shift_bit_finish
        en_for_data_last_out_high_bits_shift_bit <= 0;
        done_for_data_last_out_high_bits_shift_bit <= 1;
    end
    else if(en_for_data_last_out_high_bits_shift_bit) begin 
        cnt_for_data_last_out_high_bits_shift_bit <= cnt_for_data_last_out_high_bits_shift_bit + 1; 
        en_for_data_last_out_high_bits_shift_bit <= 1;
        done_for_data_last_out_high_bits_shift_bit <= 0;
    end
    else begin 
        cnt_for_data_last_out_high_bits_shift_bit <= 0; 
        en_for_data_last_out_high_bits_shift_bit <= 0;
        done_for_data_last_out_high_bits_shift_bit <= 0;
    end
end

logic [`VEC_BITS * 2 - 1:0] data_out_low_bits;
logic [`VEC_BITS * 2 - 1:0] data_out_high_bits;

always_comb begin
    case(data_out_low_bits_index)
        14'd1: data_out_low_bits = reg_for_low_bits[`VEC_BITS * 2 - 1 + 4 :4];
        14'd2: data_out_low_bits = reg_for_low_bits[`VEC_BITS * 2 - 1 + 3 :3];
        14'd3: data_out_low_bits = reg_for_low_bits[`VEC_BITS * 2 - 1 + 2 :2];
        14'd4: data_out_low_bits = reg_for_low_bits[`VEC_BITS * 2 - 1 + 1 :1];
        14'd5: data_out_low_bits = reg_for_low_bits[`VEC_BITS * 2 - 1 + 0 :0];
        default: data_out_low_bits = reg_for_low_bits[`VEC_BITS * 2 - 1 + 5:5];
    endcase       
end

always_comb begin
    case(data_out_high_bits_index)
        14'd15: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 :0];
        14'd14: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 1:1];
        14'd13: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 2:2];
        14'd12: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 3:3];
        14'd11: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 4:4];
        14'd10: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 5:5];
        14'd9: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 6:6];
        14'd8: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 7:7];
        14'd7: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 8:8];
        14'd6: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 9:9];
        14'd5: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 10:10];
        14'd4: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 11:11];
        14'd3: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 12:12];
        14'd2: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 13:13];
        14'd1: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 14:14];
        default: data_out_high_bits = reg_for_high_bits[`VEC_BITS * 2 - 1 + 15:15];
    endcase       
end

logic last_write_en;
logic [`ADDR_WIDTH-1:0] last_write_addr;
logic [`VEC_BITS * 2 - 1:0] last_write_data;

always_comb begin
    if((last_write_cnt == 5)&(security_level == 0)) begin last_write_en = 1; last_write_addr = 2; last_write_data = {r_data[`VEC_BITS * 2 - 1:192], reg_for_sign_bits[`VEC_BITS * 2 - 1:`VEC_BITS * 2 - 1 - 191]}; end
    else if((last_write_cnt == 8) & (security_level == 0)) begin last_write_en = 1; last_write_addr = 12; last_write_data = {r_data[`VEC_BITS * 2 - 1:192], reg_for_low_bits[`VEC_BITS * 2 - 1 + 5:`VEC_BITS * 2 - 1 + 5 - 191]}; end
    else if((last_write_cnt == 5) & (security_level == 1)) begin last_write_en = 1; last_write_addr = 5; last_write_data = {r_data[`VEC_BITS * 2 - 1:64], reg_for_sign_bits[`VEC_BITS * 2 - 1:`VEC_BITS * 2 - 1 - 63]}; end
    else if((last_write_cnt == 8) & (security_level == 1)) begin last_write_en = 1; last_write_addr = 29; last_write_data = {r_data[`VEC_BITS * 2 - 1:64], reg_for_low_bits[`VEC_BITS * 2 - 1 + 5:`VEC_BITS * 2 - 1 + 5 - 63]}; end 
    else begin last_write_en = 0; last_write_addr = 0; last_write_data = 0; end
end

always_comb begin
    casex({write_sign_bits_en, write_low_bits_en, write_high_bits_en, write_low_bits_en_delay_1, write_high_bits_en_delay_2, padding_cnt_en, encode_last_en })
        7'b1xxxxxx: begin wen = 1'b1;  w_data = reg_for_sign_bits; w_offset_addr = w_sign_offset_addr + w_base_addr + w_sign_addr_cnt; end
        7'b01xxxxx: begin wen = 1'b1;  w_data = data_out_low_bits ; w_offset_addr = w_low_offset_addr + w_base_addr + w_low_addr_cnt; end
        7'b001xxxx: begin wen = 1'b1;  w_data = data_out_high_bits; w_offset_addr = w_high_offset_addr + w_base_addr + w_high_addr_cnt; end
        7'b0001xxx: begin wen = 1'b1;  w_data = data_out_low_bits ; w_offset_addr = w_low_offset_addr + w_base_addr + w_low_addr_cnt; end
        7'b00001xx: begin wen = 1'b1;  w_data = data_out_high_bits; w_offset_addr = w_high_offset_addr + w_base_addr + w_high_addr_cnt; end
        7'b000001x: begin wen = 1'b1;  w_data = '0; w_offset_addr =  padding_base_addr + w_base_addr + padding_cnt ; end
        7'b0000001: begin wen = last_write_en;  w_data = last_write_data; w_offset_addr =  last_write_addr  + w_base_addr ; end
        default:  begin wen = 1'b0;  w_data = 256'b0; w_offset_addr = 0; end
    endcase
end

always_comb begin
    w_sign_offset_addr = (security_level == 0)? 0: 0;
    w_low_offset_addr = (security_level == 0)? 2: 5;
    w_high_offset_addr = (security_level == 0)? 12: 29;
end

always_comb begin
    max_w_num = (security_level == 1'b0) ? 18 : 39;
end

always_ff @(posedge clk) begin
    if (start) padding_base_addr <= 'd0;
    else if (last_normal_wen) padding_base_addr <= w_high_offset_addr + w_high_addr_cnt + 'd1;
end

//////////////////////////////////////////////////////////////////////  
//encode processing

always_ff@(posedge clk) begin
    if(encode_en & vld_i & rdy_o) begin
        reg_for_input <= r_data;
        remain_cnt_for_reg_for_input <= 3'd7;
    end
    else if(encode_update_en) begin
        reg_for_input <= {32'b0, reg_for_input[`VEC_BITS * 2 - 1:32]}; 
        remain_cnt_for_reg_for_input <= remain_cnt_for_reg_for_input - 3'd1;
    end
end   
    
wire [32 -1 :0] element_select     =  reg_for_input[31:0];  
wire [32 -1 :0] element_select_inv = ~reg_for_input[31:0]; 
wire [32 -1 :0] element_to_encode  =  (reg_for_input[31] == 1'b1) ? element_select_inv : element_select ;

wire       element_to_encode_sign_bits = element_select[31];
wire [4:0] element_to_encode_low_bits_512 = element_to_encode[4:0];
wire [5:0] element_to_encode_low_bits_1024 = element_to_encode[5:0];

//first: salt and sign bit
always_ff@(posedge clk or negedge rstn) begin
    if (!rstn)                              cnt_for_sign_bits <= 0; 
    else if(start )                         cnt_for_sign_bits <= 0;
    else if(start_delay_1 & (security_level == 1)) cnt_for_sign_bits <= 256;  
    else if(start_delay_2 & (security_level == 1)) cnt_for_sign_bits <= 64; 
    else if(start_delay_1 & (security_level == 0)) cnt_for_sign_bits <= 192; 
    else if((encode_update_en == 1) & write_sign_bits_en) cnt_for_sign_bits <= cnt_for_sign_bits - 256 + 1; 
    else if(encode_update_en == 1)                        cnt_for_sign_bits <= cnt_for_sign_bits + 1; 
    else if((encode_update_en == 0) & write_sign_bits_en) cnt_for_sign_bits <= cnt_for_sign_bits - 256; 
end 

always_ff@(posedge clk or negedge rstn) begin
    if (!rstn)                              w_sign_addr_cnt <= 0; 
    else if(start )                         w_sign_addr_cnt <= 0;
    else if(start_delay_1 & (security_level == 1)) w_sign_addr_cnt <= 0;  
    else if(start_delay_2 & (security_level == 1)) w_sign_addr_cnt <= 1; 
    else if(start_delay_1 & (security_level == 0)) w_sign_addr_cnt <= 0; 
    else if((encode_update_en == 1) & write_sign_bits_en) w_sign_addr_cnt <= w_sign_addr_cnt + 1; 
    else if(encode_update_en == 1)                        w_sign_addr_cnt <= w_sign_addr_cnt; 
    else if((encode_update_en == 0) & write_sign_bits_en) w_sign_addr_cnt <= w_sign_addr_cnt + 1; 
end 
    
always_ff@(posedge clk) begin
    if(start)                   reg_for_sign_bits <= 0;
    else if(encode_update_en)   reg_for_sign_bits <= {element_to_encode_sign_bits, reg_for_sign_bits[`VEC_BITS * 2 - 1 :1]};   
    else if(start_delay_2  & (security_level == 1))    reg_for_sign_bits <= r_data;
    else if(salt_update_en & (security_level == 1) )   reg_for_sign_bits <= {r_data[63:0], 192'd0};
    else if(salt_update_en & (security_level == 0) )   reg_for_sign_bits <= {r_data[191:0], 64'd0};
end     
    
//second: low bit
always_ff@(posedge clk  or negedge rstn) begin
    if (!rstn)      cnt_for_low_bits <= 0; 
    else if(start & (security_level == 0)) cnt_for_low_bits <= 192;
    else if(start & (security_level == 1)) cnt_for_low_bits <= 64;
    else if((encode_update_en == 1) & write_low_bits_en & (security_level == 0)) cnt_for_low_bits <= cnt_for_low_bits - 256 + 5; 
    else if((encode_update_en == 1) & (security_level == 0))                     cnt_for_low_bits <= cnt_for_low_bits + 5; 
    else if((encode_update_en == 1) & write_low_bits_en & (security_level == 1)) cnt_for_low_bits <= cnt_for_low_bits - 256 + 6; 
    else if((encode_update_en == 1) & (security_level == 1))                     cnt_for_low_bits <= cnt_for_low_bits + 6; 
    else if((encode_update_en == 0) & write_low_bits_en_delay_1)                 cnt_for_low_bits <= cnt_for_low_bits - 256; 
end  

always_ff@(posedge clk  or negedge rstn) begin
    if (!rstn)      w_low_addr_cnt <= 0; 
    else if(start ) w_low_addr_cnt <= 0;
    else if((encode_update_en == 1) & write_low_bits_en) w_low_addr_cnt <= w_low_addr_cnt + 1; 
    else if(encode_update_en == 1)                       w_low_addr_cnt <= w_low_addr_cnt; 
    else if((encode_update_en == 0) & write_low_bits_en_delay_1) w_low_addr_cnt <= w_low_addr_cnt + 1; 
end   
    
always_ff@(posedge clk) begin
    if(encode_update_en & (security_level == 0))      reg_for_low_bits <= {element_to_encode_low_bits_512, reg_for_low_bits[`VEC_BITS * 2 - 1 + 5:5]};
    else if(encode_update_en & (security_level == 1)) reg_for_low_bits <= {element_to_encode_low_bits_1024, reg_for_low_bits[`VEC_BITS * 2 - 1 + 5:6]};
end    

//third: high bit
logic [5:0] element_to_encode_high_bits;

always_ff@(posedge clk  or negedge rstn) begin
    if (!rstn)                        cnt_for_high_bits <= 0; 
    else if(start & (security_level == 0)) cnt_for_high_bits <= 192;
    else if(start & (security_level == 1)) cnt_for_high_bits <= 64;
    else if((encode_update_en == 1) & write_high_bits_en) cnt_for_high_bits <= cnt_for_high_bits - 256 + element_to_encode_high_bits + 1; 
    else if(encode_update_en == 1)                        cnt_for_high_bits <= cnt_for_high_bits + element_to_encode_high_bits + 1; 
    else if((encode_update_en == 0) & write_high_bits_en_delay_2) cnt_for_high_bits <= cnt_for_high_bits - 256; 
end 
 
always_ff@(posedge clk  or negedge rstn) begin
    if (!rstn)                        w_high_addr_cnt <= 0; 
    else if(start )                   w_high_addr_cnt <= 0;
    else if((encode_update_en == 1) & write_high_bits_en) w_high_addr_cnt <= w_high_addr_cnt + 1; 
    else if(encode_update_en == 1)                        w_high_addr_cnt <= w_high_addr_cnt; 
    else if((encode_update_en == 0) & write_high_bits_en_delay_2) w_high_addr_cnt <= w_high_addr_cnt + 1; 
end 
 
logic [`VEC_BITS * 2 - 1 + 15:0] reg_for_high_bits_pre;

assign element_to_encode_high_bits = (security_level == 0)? element_to_encode[10:5]: element_to_encode[11:6];
    
always_comb begin
    case(element_to_encode_high_bits)
        6'd0: reg_for_high_bits_pre = {1'b1,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :1]};
        6'd1: reg_for_high_bits_pre = {2'b10,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :2]};
        6'd2: reg_for_high_bits_pre = {3'b100,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :3]};
        6'd3: reg_for_high_bits_pre = {4'b1000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :4]};
        6'd4: reg_for_high_bits_pre = {5'b10000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :5]};
        6'd5: reg_for_high_bits_pre = {6'b100000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :6]};
        6'd6: reg_for_high_bits_pre = {7'b1000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :7]};
        6'd7: reg_for_high_bits_pre = {8'b10000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :8]};
        6'd8: reg_for_high_bits_pre = {9'b100000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :9]};
        6'd9: reg_for_high_bits_pre = {10'b1000000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :10]};
        6'd10: reg_for_high_bits_pre = {11'b1000000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :11]};
        6'd11: reg_for_high_bits_pre = {12'b10000000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :12]};
        6'd12: reg_for_high_bits_pre = {13'b100000000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :13]};
        6'd13: reg_for_high_bits_pre = {14'b1000000000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :14]};
        6'd14: reg_for_high_bits_pre = {15'b10000000000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :15]};
        6'd15: reg_for_high_bits_pre = {16'b100000000000000,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :6]};
        default: reg_for_high_bits_pre = {reg_for_high_bits[`VEC_BITS * 2 - 1 + 15 :0]};
    endcase       
end
    
always_ff@(posedge clk) begin
    if(encode_update_en)                                reg_for_high_bits <= reg_for_high_bits_pre;
    else if(en_for_data_last_out_high_bits_shift_block) reg_for_high_bits <= {16'b0,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15:16]};
    else if(en_for_data_last_out_high_bits_shift_bit)   reg_for_high_bits <= {1'b0,reg_for_high_bits[`VEC_BITS * 2 - 1 + 15:1]};
end 
    
//////////////////////////////////////////////////////
// padding
//////////////////////////////////////////////////////
  counter_ce_cntclear #(
    .BW($bits(padding_num))
  ) u_padding_cnt (
    .clk,
    .rst_n (rstn),
    .start (encode_finish),
    .num   (padding_num),
    .run   (1'b1),
    .cnt   (padding_cnt),
    .cnt_en(padding_cnt_en),
    .last  (),
    .done  (padding_finish)
  );

//////////////////////////////////////////////////////
// rdy, finish
//////////////////////////////////////////////////////
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) rdy_flag <= 1'b0;
    else if (last_high_bits_write) rdy_flag <= 1'b0;
    else if (encode_update_en) rdy_flag <= 1'b1;
end
assign rdy_o = rdy_flag ? (encode_update_en && (remain_cnt_for_reg_for_input==3'd0)) : 1'b1;

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) finish <= 1'b0;
    else if (start) finish <= 1'b0;
    else finish <= padding_finish;
end

endmodule
