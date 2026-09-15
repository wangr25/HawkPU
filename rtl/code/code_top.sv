`include "../defines/defines.sv"

module code_top
  import adapter_pkg::*;
(
    input wire clk,
    input wire rstn,
    input wire security_level,
    input wire sys_mode,

    // taskcode
    input wire [`TC_W-1:0] taskcode,
    input wire taskcode_vld,

	input logic [`ADDR_WIDTH-1:0] m_lines,
	input logic [5:0] m_bytes,
    input logic [6:0] m_outlen,
    input logic [6:0] m_outbytes,

    // to top control
    output logic code_flag,    // decode flag
    output logic code_finish,

    // to BFU
    output logic [31:0] q00_cstup,

    // read buffer
    output logic code_a_r_mapping_mode,
    output logic code_b_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] code_a_base_raddr,
    output logic [`ADDR_WIDTH-1:0] code_b_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    code_r_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    code_r_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    code_r_avn1,
    output logic [`VEC_NUM_WIDTH-1:0]    code_r_bvn1,
    input  logic [`VEC_BITS-1:0]         code_r_av0,
    input  logic [`VEC_BITS-1:0]         code_r_bv0,
    input  logic [`VEC_BITS-1:0]         code_r_av1,
    input  logic [`VEC_BITS-1:0]         code_r_bv1,
    output logic code_avn0_ren,
    output logic code_bvn0_ren,
    output logic code_avn1_ren,
    output logic code_bvn1_ren,

    // write buffer
    output logic code_a_w_mapping_mode_o,
    output logic code_b_w_mapping_mode_o,
    output logic [`ADDR_WIDTH-1:0] code_a_base_waddr_o,
    output logic [`ADDR_WIDTH-1:0] code_b_base_waddr_o,
    output logic [`VEC_NUM_WIDTH-1:0]    code_w_avn0_o,
    output logic [`VEC_NUM_WIDTH-1:0]    code_w_bvn0_o,
    output logic [`VEC_NUM_WIDTH-1:0]    code_w_avn1_o,
    output logic [`VEC_NUM_WIDTH-1:0]    code_w_bvn1_o,
    output logic [`VEC_BITS-1:0]         code_w_av0_o,
    output logic [`VEC_BITS-1:0]         code_w_bv0_o,
    output logic [`VEC_BITS-1:0]         code_w_av1_o,
    output logic [`VEC_BITS-1:0]         code_w_bv1_o,
    output logic code_avn0_wen_o,
    output logic code_bvn0_wen_o,
    output logic code_avn1_wen_o,
    output logic code_bvn1_wen_o

);

////////////////////////////////////////////////////////////////////////////////

    // from taskcode

logic code_start;
logic [1:0] code_funct;
logic task_encdec;
logic [`ADDR_WIDTH-1:0] code_base_raddr;
logic [`ADDR_WIDTH-1:0] code_base_waddr;
logic [`ADDR_WIDTH-1:0] another_addr;
logic [8:0] code_length;  // 
// decoder
logic dec_funct;
logic q00_mode;
logic q00_only;
// additional funct
logic cp_funct;
logic adw_funct;

assign task_encdec = taskcode[2:0] == 3'b000;
assign code_start  = taskcode_vld && task_encdec;

assign code_base_raddr = taskcode[11: 3];
assign code_base_waddr = taskcode[20:12];
assign code_funct      = taskcode[22:21];
assign another_addr    = taskcode[31:23];
assign code_length     = taskcode[40:32];
assign dec_funct       = taskcode[41];
assign q00_mode        = 1'b1;
assign q00_only        = taskcode[43];
assign cp_funct        = taskcode[44];
assign adw_funct       = taskcode[45];

logic use_adw;
assign use_adw = task_encdec && ( (code_funct==`CODE_FUNCT_ADW) || (code_funct==`CODE_FUNCT_MOV) );

////////////////////////////////////////////////////////////////////////////////
logic                           code_a_w_mapping_mode;
logic                           code_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0]         code_a_base_waddr;
logic [`ADDR_WIDTH-1:0]         code_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0]      code_w_avn0;
logic [`VEC_NUM_WIDTH-1:0]      code_w_bvn0;
logic [`VEC_NUM_WIDTH-1:0]      code_w_avn1;
logic [`VEC_NUM_WIDTH-1:0]      code_w_bvn1;
logic [`VEC_BITS-1:0]           code_w_av0;
logic [`VEC_BITS-1:0]           code_w_bv0;
logic [`VEC_BITS-1:0]           code_w_av1;
logic [`VEC_BITS-1:0]           code_w_bv1;
logic                           code_avn0_wen;
logic                           code_bvn0_wen;
logic                           code_avn1_wen;
logic                           code_bvn1_wen;
////////////////////////////////////////////////////////////////////////////////


logic [`VEC_NUM_WIDTH-1:0] N1;
logic [`VEC_NUM_WIDTH-1:0] N2;
assign N1 = security_level ? 'd128 : 'd64;
assign N2 = security_level ? 'd129 : 'd65;

// ----------------------------------------------------
// encoder
// ----------------------------------------------------

logic enc_start;
logic enc_finish;

logic                             enc_a_r_mapping_mode;
logic                             enc_b_r_mapping_mode;
logic [`ADDR_WIDTH-1:0]           enc_a_base_raddr;
logic [`ADDR_WIDTH-1:0]           enc_b_base_raddr;
logic [`VEC_NUM_WIDTH-1:0]        enc_r_avn0;
logic [`VEC_NUM_WIDTH-1:0]        enc_r_bvn0;
logic [`VEC_NUM_WIDTH-1:0]        enc_r_avn1;
logic [`VEC_NUM_WIDTH-1:0]        enc_r_bvn1;
logic [`VEC_BITS-1:0]             enc_r_av0;
logic [`VEC_BITS-1:0]             enc_r_bv0;
logic [`VEC_BITS-1:0]             enc_r_av1;
logic [`VEC_BITS-1:0]             enc_r_bv1;
logic                             enc_avn0_ren;
logic                             enc_bvn0_ren;
logic                             enc_avn1_ren;
logic                             enc_bvn1_ren;

logic                             enc_a_w_mapping_mode;
logic                             enc_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0]           enc_a_base_waddr;
logic [`ADDR_WIDTH-1:0]           enc_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0]        enc_w_avn0;
logic [`VEC_NUM_WIDTH-1:0]        enc_w_bvn0;
logic [`VEC_NUM_WIDTH-1:0]        enc_w_avn1;
logic [`VEC_NUM_WIDTH-1:0]        enc_w_bvn1;
logic [`VEC_BITS-1:0]             enc_w_av0;
logic [`VEC_BITS-1:0]             enc_w_bv0;
logic [`VEC_BITS-1:0]             enc_w_av1;
logic [`VEC_BITS-1:0]             enc_w_bv1;
logic                             enc_avn0_wen;
logic                             enc_bvn0_wen;
logic                             enc_avn1_wen;
logic                             enc_bvn1_wen;

assign enc_r_av0 = code_r_av0;
assign enc_r_bv0 = code_r_bv0;
assign enc_r_av1 = code_r_av1;
assign enc_r_bv1 = code_r_bv1;

assign enc_start = (code_funct==`CODE_FUNCT_ENC) && code_start;

enc_top u_encode_top (
    .clk,
    .rstn,
    .security_level,

    .code_base_raddr,
    .code_base_waddr,
    .another_addr,
    .code_length,
    .enc_start,
    .enc_finish,

    .enc_a_r_mapping_mode,
    .enc_b_r_mapping_mode,
    .enc_a_base_raddr,
    .enc_b_base_raddr,
    .enc_r_avn0,
    .enc_r_bvn0,
    .enc_r_avn1,
    .enc_r_bvn1,
    .enc_r_av0,
    .enc_r_bv0,
    .enc_r_av1,
    .enc_r_bv1,
    .enc_avn0_ren,
    .enc_bvn0_ren,
    .enc_avn1_ren,
    .enc_bvn1_ren,

    .enc_a_w_mapping_mode,
    .enc_b_w_mapping_mode,
    .enc_a_base_waddr,
    .enc_b_base_waddr,
    .enc_w_avn0,
    .enc_w_bvn0,
    .enc_w_avn1,
    .enc_w_bvn1,
    .enc_w_av0,
    .enc_w_bv0,
    .enc_w_av1,
    .enc_w_bv1,
    .enc_avn0_wen,
    .enc_bvn0_wen,
    .enc_avn1_wen,
    .enc_bvn1_wen

);

// adapter

logic                         adw_start;
logic                         adw_op_done;

logic [9:0]                   adw_in_row_num_indirect;
logic [9:0]                   adw_out_row_num_indirect;

logic [9:0]                   adw_len;
logic [9:0]                   adw_dst;
logic [9:0]                   adw_src1;
logic [9:0]                   adw_src0;
logic [9:0]                   adw_reg_len;
logic [511:0]                 adw_buff_rd_data;
// adw output
logic                         adw_buff_rd_en;
logic [9:0]                   adw_buff_rd_addr;
logic [511:0]                 adw_buff_wr_data;
logic                         adw_buff_wr_en;
logic [9:0]                   adw_buff_wr_addr;
logic [511:0]                 adw_w_data;
// adw output delay
logic                         adw_op_done_q;
logic [511:0]                 adw_buff_wr_data_q;
logic                         adw_buff_wr_en_q;
logic [9:0]                   adw_buff_wr_addr_q;
//
logic [9:0]                   adw_in_row_num_fixed;
logic [9:0]                   adw_in_row_num_dyn;
logic [`ADDR_WIDTH-1:0]       m_lines_all;

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        adw_op_done_q    <= 1'b0;
        adw_buff_wr_en_q <= 1'b0;
    end
    else begin
        adw_op_done_q    <= adw_op_done;
        adw_buff_wr_en_q <= adw_buff_wr_en;
    end
end
always_ff @(posedge clk) begin
    adw_buff_wr_data_q <= adw_buff_wr_data;
    adw_buff_wr_addr_q <= adw_buff_wr_addr;   
end
always_comb begin
    if (cp_funct==1'b0) begin
        adw_w_data = adw_buff_wr_data_q;
    end else begin
        if (security_level==1'b0) adw_w_data = {320'b0, adw_buff_wr_data_q[191:0]};
        else adw_w_data = {192'b0, adw_buff_wr_data_q[319:0]};
    end
end

/////////////////////////////////////////
// adw
/////////////////////////////////////////
assign adw_start = use_adw && code_start;

/////////////////////////////////////////
// adw in row num
always_comb begin
    if (security_level==1'b1) begin
        if (sys_mode==1'b0) begin // samp seed
            adw_in_row_num_fixed  = 'd3;
        end
        else begin // pub
            adw_in_row_num_fixed  = 'd39;
        end
    end
    else begin  // pub
        adw_in_row_num_fixed  = 'd16;
    end
end
assign m_lines_all = m_lines + 'd1;
always_comb begin
    if (security_level==1'b1) begin
        // m||hpub leads to an extra line
        adw_in_row_num_dyn = m_lines_all + (m_bytes != 6'b0);
    end else begin
        // if m_bytes>32, m||hpub leads to an extra line
        adw_in_row_num_dyn = m_lines_all + (m_bytes > 'd32);
    end
end
assign adw_in_row_num_indirect  = adw_funct ? adw_in_row_num_dyn : adw_in_row_num_fixed;
/////////////////////////////////////////
// adw out row num
assign adw_out_row_num_indirect = adw_funct ? m_outlen : code_length;

assign adw_len = code_length;
assign adw_dst = code_base_waddr;
assign adw_src1 = another_addr;
assign adw_src0 = code_base_raddr;
assign adw_reg_len = another_addr;

assign adw_buff_rd_data        = {code_r_bv1, code_r_av1, code_r_bv0, code_r_av0};

adapter u_adapter (
  .clk                (clk),
  .rst_n              (rstn),

  .in_row_num_indirect(adw_in_row_num_indirect),
  .out_row_num_indirect(adw_out_row_num_indirect),

  .adw_start          (adw_start),
  .adw_op_done        (adw_op_done),

  .indirect_mode      (code_funct==`CODE_FUNCT_ADW),
  .len                (adw_len),
  .dst                (adw_dst),
  .src1               (adw_src1),
  .src0               (adw_src0),
  .reg_len            (adw_reg_len),
  .adw_buff_rd_data   (adw_buff_rd_data),
  .adw_buff_rd_en     (adw_buff_rd_en),
  .adw_buff_rd_addr   (adw_buff_rd_addr),
  .adw_buff_wr_data   (adw_buff_wr_data),
  .adw_buff_wr_en     (adw_buff_wr_en),
  .adw_buff_wr_addr   (adw_buff_wr_addr)
);

// decoder

logic dec_start;
logic dec_finish;

// buffer - read buffer
logic dec_a_r_mapping_mode;
logic [`ADDR_WIDTH-1:0] dec_a_base_raddr;
logic [`VEC_NUM_WIDTH-1:0] dec_r_avn0;
logic [`VEC_NUM_WIDTH-1:0] dec_r_avn1;
logic [`VEC_BITS-1:0] dec_r_av0;
logic [`VEC_BITS-1:0] dec_r_av1;
logic dec_avn0_ren;
logic dec_avn1_ren;

// buffer - write buffer
logic dec_a_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] dec_a_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] dec_w_avn0;
logic [`VEC_NUM_WIDTH-1:0] dec_w_avn1;
logic [`VEC_BITS-1:0] dec_w_av0;
logic [`VEC_BITS-1:0] dec_w_av1;
logic dec_avn0_wen;
logic dec_avn1_wen;
logic dec_b_w_mapping_mode;
logic [`ADDR_WIDTH-1:0] dec_b_base_waddr;
logic [`VEC_NUM_WIDTH-1:0] dec_w_bvn0;
logic [`VEC_NUM_WIDTH-1:0] dec_w_bvn1;
logic [`VEC_BITS-1:0] dec_w_bv0;
logic [`VEC_BITS-1:0] dec_w_bv1;
logic dec_bvn0_wen;
logic dec_bvn1_wen;

assign dec_start = (code_funct==`CODE_FUNCT_DEC) && code_start;
assign dec_r_av0 = code_r_av0;
assign dec_r_av1 = code_r_av1;

// decoder
dec_top u_dec_top (
    .clk                    (clk),
    .rstn                   (rstn),
    .security_level         (security_level),
    
    // from taskcode
    .code_base_raddr        (code_base_raddr),
    .code_base_waddr        (code_base_waddr),
    .another_addr           (another_addr),
    .dec_start              (dec_start),
    .dec_funct              (dec_funct),
    .q00_mode               (q00_mode),
    .q00_only               (q00_only),
    // to control
    .dec_finish             (dec_finish),
    .q00_cstup,
    
    // buffer - read buffer
    .dec_a_r_mapping_mode   (dec_a_r_mapping_mode),
    .dec_a_base_raddr       (dec_a_base_raddr),
    .dec_r_avn0             (dec_r_avn0),
    .dec_r_avn1             (dec_r_avn1),
    .dec_r_av0              (dec_r_av0),
    .dec_r_av1              (dec_r_av1),
    .dec_avn0_ren           (dec_avn0_ren),
    .dec_avn1_ren           (dec_avn1_ren),
    
    // buffer - write buffer
    .dec_a_w_mapping_mode   (dec_a_w_mapping_mode),
    .dec_a_base_waddr       (dec_a_base_waddr),
    .dec_w_avn0             (dec_w_avn0),
    .dec_w_avn1             (dec_w_avn1),
    .dec_w_av0              (dec_w_av0),
    .dec_w_av1              (dec_w_av1),
    .dec_avn0_wen           (dec_avn0_wen),
    .dec_avn1_wen           (dec_avn1_wen),
    .dec_b_w_mapping_mode   (dec_b_w_mapping_mode),
    .dec_b_base_waddr       (dec_b_base_waddr),
    .dec_w_bvn0             (dec_w_bvn0),
    .dec_w_bvn1             (dec_w_bvn1),
    .dec_w_bv0              (dec_w_bv0),
    .dec_w_bv1              (dec_w_bv1),
    .dec_bvn0_wen           (dec_bvn0_wen),
    .dec_bvn1_wen           (dec_bvn1_wen)
);

// BUS

always_comb begin
    // default value

    case (code_funct)

    // encoder read: use bv0,bv1 to read poly, string and sig
    // encoder write: use bv0, bv1 to write sig
        `CODE_FUNCT_ENC: begin
            // port_a connect to decoder
            code_a_r_mapping_mode = dec_a_r_mapping_mode;
            code_a_base_raddr = dec_a_base_raddr;
            code_r_avn0 = dec_r_avn0;
            code_r_avn1 = dec_r_avn1;
            code_avn0_ren = 1'b0;
            code_avn1_ren = 1'b0;
            code_a_w_mapping_mode = dec_a_w_mapping_mode;
            code_a_base_waddr = dec_a_base_waddr;
            code_w_avn0 = dec_w_avn0;
            code_w_avn1 = dec_w_avn1;
            code_w_av0 = dec_w_av0;
            code_w_av1 = dec_w_av1;
            code_avn0_wen = 1'b0;
            code_avn1_wen = 1'b0;

            code_b_r_mapping_mode = enc_b_r_mapping_mode;
            code_b_base_raddr = enc_b_base_raddr;
            code_r_bvn0 = enc_r_bvn0;
            code_r_bvn1 = enc_r_bvn1;
            code_bvn0_ren = enc_bvn0_ren;
            code_bvn1_ren = enc_bvn1_ren;
            code_b_w_mapping_mode = enc_b_w_mapping_mode;
            code_b_base_waddr = enc_b_base_waddr;
            code_w_bvn0 = enc_w_bvn0;
            code_w_bvn1 = enc_w_bvn1;
            code_w_bv0 = enc_w_bv0;
            code_w_bv1 = enc_w_bv1;
            code_bvn0_wen = enc_bvn0_wen;
            code_bvn1_wen = enc_bvn1_wen;

            code_finish = enc_finish;
        end
        `CODE_FUNCT_MOV,
        `CODE_FUNCT_ADW: begin  // 2'b11-adw
            code_a_r_mapping_mode = 1'b0;
            code_b_r_mapping_mode = 1'b0;
            code_a_base_raddr = adw_buff_rd_addr;
            code_b_base_raddr = adw_buff_rd_addr;
            code_r_avn0 = 'd0;
            code_r_bvn0 = 'd1;
            code_r_avn1 = N1;
            code_r_bvn1 = N2;
            code_avn0_ren = adw_buff_rd_en;
            code_bvn0_ren = adw_buff_rd_en;
            code_avn1_ren = adw_buff_rd_en;
            code_bvn1_ren = adw_buff_rd_en;
            code_a_w_mapping_mode = 1'b0;
            code_b_w_mapping_mode = 1'b0;
            code_a_base_waddr = adw_buff_wr_addr_q;
            code_b_base_waddr = adw_buff_wr_addr_q;
            code_w_avn0 = 'd0;
            code_w_bvn0 = 'd1;
            code_w_avn1 = N1;
            code_w_bvn1 = N2;
            code_w_av0 = adw_w_data[1*128-1 -: 128];
            code_w_bv0 = adw_w_data[2*128-1 -: 128];
            code_w_av1 = adw_w_data[3*128-1 -: 128];
            code_w_bv1 = adw_w_data[4*128-1 -: 128];
            code_avn0_wen = adw_buff_wr_en_q;
            code_bvn0_wen = adw_buff_wr_en_q;
            code_avn1_wen = adw_buff_wr_en_q;
            code_bvn1_wen = adw_buff_wr_en_q;

            code_finish = adw_op_done_q;
        end

        // decoder
        // decoder read: use av0,av1 to read string and poly(q00[0])
        // decoder write: use av0, av1 to write salt and poly, bv0,bv1 to write adj(q00)
        default: begin
            code_a_r_mapping_mode = dec_a_r_mapping_mode;
            code_a_base_raddr = dec_a_base_raddr;
            code_r_avn0 = dec_r_avn0;
            code_r_avn1 = dec_r_avn1;
            code_avn0_ren = dec_avn0_ren;
            code_avn1_ren = dec_avn1_ren;

            // read port_b connect to encoder
            code_b_r_mapping_mode = enc_b_r_mapping_mode;
            code_b_base_raddr = enc_b_base_raddr;
            code_r_bvn0 = enc_r_bvn0;
            code_r_bvn1 = enc_r_bvn1;
            code_bvn0_ren = 1'b0;
            code_bvn1_ren = 1'b0;

            code_a_w_mapping_mode = dec_a_w_mapping_mode;
            code_a_base_waddr = dec_a_base_waddr;
            code_w_avn0 = dec_w_avn0;
            code_w_avn1 = dec_w_avn1;
            code_w_av0 = dec_w_av0;
            code_w_av1 = dec_w_av1;
            code_avn0_wen = dec_avn0_wen;
            code_avn1_wen = dec_avn1_wen;

            code_b_w_mapping_mode = dec_b_w_mapping_mode;
            code_b_base_waddr = dec_b_base_waddr;
            code_w_bvn0 = dec_w_bvn0;
            code_w_bvn1 = dec_w_bvn1;
            code_w_bv0 = dec_w_bv0;
            code_w_bv1 = dec_w_bv1;
            code_bvn0_wen = dec_bvn0_wen;
            code_bvn1_wen = dec_bvn1_wen;

            code_finish = dec_finish;
        end

    endcase
end

// pipeline
always_ff @(posedge clk) begin
    code_a_w_mapping_mode_o  <= code_a_w_mapping_mode;
    code_b_w_mapping_mode_o  <= code_b_w_mapping_mode;
    code_a_base_waddr_o      <= code_a_base_waddr;
    code_b_base_waddr_o      <= code_b_base_waddr;
    code_w_avn0_o            <= code_w_avn0;
    code_w_bvn0_o            <= code_w_bvn0;
    code_w_avn1_o            <= code_w_avn1;
    code_w_bvn1_o            <= code_w_bvn1;
    code_w_av0_o             <= code_w_av0;
    code_w_bv0_o             <= code_w_bv0;
    code_w_av1_o             <= code_w_av1;
    code_w_bv1_o             <= code_w_bv1;
end
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        code_avn0_wen_o          <= 1'b0;
        code_bvn0_wen_o          <= 1'b0;
        code_avn1_wen_o          <= 1'b0;
        code_bvn1_wen_o          <= 1'b0;
    end
    else begin
        code_avn0_wen_o          <= code_avn0_wen;
        code_bvn0_wen_o          <= code_bvn0_wen;
        code_avn1_wen_o          <= code_avn1_wen;
        code_bvn1_wen_o          <= code_bvn1_wen;
    end
end


endmodule
