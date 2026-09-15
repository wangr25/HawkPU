`include "../defines/defines.sv"

module datagen_top (

    input wire clk,
    input wire rstn,
    input wire security_level,

    // taskcode
    input wire [`TC_W-1:0] taskcode,
    input wire taskcode_vld,
   
    // from top
	  input wire [`ADDR_WIDTH-1:0] m_lines,		// (512-bit) lines of m
	  input wire [5:0] m_bytes,		// valid bytes in m's last (512-bit) line, range 0~63
    input logic [6:0] m_outlen,     // adapt m||hpub output length
    input logic [6:0] m_outbytes,     // adapt m||hpub output last-row bytes

    // read buffer
    output logic dg_a_r_mapping_mode,
    output logic dg_b_r_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] dg_a_base_raddr,
    output logic [`ADDR_WIDTH-1:0] dg_b_base_raddr,
    output logic [`VEC_NUM_WIDTH-1:0]    dg_r_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    dg_r_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    dg_r_avn1,
    output logic [`VEC_NUM_WIDTH-1:0]    dg_r_bvn1,
    input  logic [`VEC_BITS-1:0]         dg_r_av0,
    input  logic [`VEC_BITS-1:0]         dg_r_bv0,
    input  logic [`VEC_BITS-1:0]         dg_r_av1,
    input  logic [`VEC_BITS-1:0]         dg_r_bv1,
    output logic dg_avn0_ren,
    output logic dg_bvn0_ren,
    output logic dg_avn1_ren,
    output logic dg_bvn1_ren,

    // write buffer
    output logic dg_a_w_mapping_mode,
    output logic dg_b_w_mapping_mode,
    output logic [`ADDR_WIDTH-1:0] dg_a_base_waddr,
    output logic [`ADDR_WIDTH-1:0] dg_b_base_waddr,
    output logic [`VEC_NUM_WIDTH-1:0]    dg_w_avn0,
    output logic [`VEC_NUM_WIDTH-1:0]    dg_w_bvn0,
    output logic [`VEC_NUM_WIDTH-1:0]    dg_w_avn1,
    output logic [`VEC_NUM_WIDTH-1:0]    dg_w_bvn1,
    output logic [`VEC_BITS-1:0]         dg_w_av0,
    output logic [`VEC_BITS-1:0]         dg_w_bv0,
    output logic [`VEC_BITS-1:0]         dg_w_av1,
    output logic [`VEC_BITS-1:0]         dg_w_bv1,
    output logic dg_avn0_wen,
    output logic dg_bvn0_wen,
    output logic dg_avn1_wen,
    output logic dg_bvn1_wen,

    // to top control
    output logic dg_finish
);

////////////////////////////////////////////////////////////////////////////////

    // from taskcode
    logic dg_start;
    logic [2:0] dg_funct;
    logic [`ADDR_WIDTH-1:0] seed_base_raddr;
    logic [`ADDR_WIDTH-1:0] seed_base_waddr;
    logic [`ADDR_WIDTH-1:0] another_addr;
    logic [`ADDR_WIDTH-1:0] hpub_base_raddr;   // when shake(m||hpub), seed_base_raddr is m's addr
    logic [`ADDR_WIDTH-1:0] t_base_raddr;   // sampler will read t
    logic [8:0] dg_length;
    logic [5:0] valid_bytes_in;
    logic [6:0] valid_bytes_converted;
    logic [6:0] dg_valid_bytes;

logic task_dg;
assign task_dg = taskcode[2:0] == 3'b001;

wire dg_funct_gen_M = (dg_funct==`DG_GEN_M);

assign dg_start = taskcode_vld && task_dg;
assign seed_base_raddr = taskcode[11:3];
assign seed_base_waddr = taskcode[20:12];
assign dg_funct = taskcode[23:21];
assign another_addr    = taskcode[32:24];
assign hpub_base_raddr = another_addr;
assign t_base_raddr    = another_addr;
assign dg_length       = dg_funct_gen_M ? m_outlen : taskcode[41:33];
assign valid_bytes_in  = taskcode[47:42];
assign valid_bytes_converted[5:0] = valid_bytes_in[5:0];  // valid_bytes_in==0 is 64
assign valid_bytes_converted[6] = (valid_bytes_in == 6'b0) ? 1'b1 : 1'b0;
assign dg_valid_bytes  = dg_funct_gen_M ? m_outbytes : valid_bytes_converted;

////////////////////////////////////////////////////////////////////////////////
// regenfg signals

logic regenfg_start;
logic [127:0] regenfg_d_i;
logic regenfg_vld_i;

logic regenfg_keccak_start;
logic [1:0] regenfg_cnt_j;
logic regenfg_rdy_o;
logic flag_wr_g;
logic regenfg_v0_wen;
logic regenfg_v1_wen;
logic [`VEC_BITS-1:0] regenfg_v0;
logic [`VEC_BITS-1:0] regenfg_v1;
logic [`VEC_NUM_WIDTH-1:0] regenfg_wvn0;
logic [`VEC_NUM_WIDTH-1:0] regenfg_wvn1;
logic regenfg_finish;


////////////////////////////////////////////////////////////////////////////////
wire task_regenfg = task_dg && (dg_funct==`DG_REGEN_FG);

logic [`VEC_NUM_WIDTH-1:0] n1;
logic [`VEC_NUM_WIDTH-1:0] n2;
assign n1 = (security_level ? 'd128 : 'd64);
assign n2 = (security_level ? 'd129 : 'd65);


// state
  typedef enum logic [3:0] {
    st_idle             ,
    // read seed and write seed directly from keccak: M/salt/hpub
    st_shake_seed_dir       ,
    // read seed and write seed from out_align: (h0,h1)
    st_shake_seed_outalign    ,
    // gauss sampler
    st_samp_read_t      ,
    st_samp_read_seed   ,
    st_samp_x0          ,
    st_samp_x1
  } state_e;

  state_e state, next_state;

//////////////////////////////////////////////////
`ifdef FPGA_SYN
//(* dont_touch = "true" *) logic [3:0] keccak_start;  // [3:1] each drive 512-bit buff, [0] drives others
(* dont_touch = "true" *) logic [12:0] keccak_start;  // [12:1] each drive 128-bit buff, [0] drives others
`else
//logic [3:0] keccak_start;
logic [12:0] keccak_start;
`endif
integer k;
always_ff @(posedge clk) begin
  if (task_regenfg) begin
    foreach (keccak_start[k]) keccak_start[k] <= regenfg_keccak_start; 
  end
  else begin
  case (dg_funct)
    `DG_GEN_SAMP: begin
      foreach (keccak_start[k]) keccak_start[k] <= (state==st_samp_read_t) && (next_state==st_samp_read_seed); 
    end
    default: begin
      foreach (keccak_start[k]) keccak_start[k] <= dg_start;
    end
  endcase
  end
end

logic keccak_first;
logic keccak_last;
// 0-abs 1-squ
logic       mode;
logic       keccak_mode;

logic       keccak_i_req;
logic       keccak_o_req;
logic [1087:0] keccak_i;
logic [1087:0] keccak_i_1;
logic [1087:0] keccak_o;

logic if_buff_rd_en;
logic [11:0] if_buff_rd_addr;

    pipeline_delay_bit #(
      .R(1),
      .P(0),
      .D(`BUFF_RD_LATENCY)
    ) i_mode_delay (
      .c(clk),
      .r(rstn),
      .i(mode),
      .o(keccak_mode)
    );

logic [1:0] samp_seed_cnt;
logic [1:0] samp_seed_cnt_plus1;
assign samp_seed_cnt_plus1 = samp_seed_cnt + 2'd1;

always_ff @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    samp_seed_cnt <= 2'b11;  // -1
  end
  else if ((state==st_samp_read_seed)&&(next_state==st_samp_x0)) begin
    samp_seed_cnt <= samp_seed_cnt_plus1;
  end
end

logic [511:0] buff_rd_seed;
logic [71:0] buff_rd_seed_maskj;    // concatenate j for sampler's seed
logic [511:0] buff_rd_seed_inner;

assign buff_rd_seed        = {dg_r_bv1, dg_r_av1, dg_r_bv0, dg_r_av0};
// when sampling, 4 different seeds are used
always_ff @(posedge clk) begin
  if (dg_funct==`DG_GEN_SAMP) begin
    if ((state==st_samp_read_t)&&(next_state==st_samp_read_seed)) begin
      buff_rd_seed_maskj <= '0;
    end
    else begin
      case (security_level)
        1'b1: begin  // security_level=1
          if (if_buff_rd_addr==(`ADDR_SAMP_SEED_SG1_ADAPTED+'d3)) begin // reading the last line of sampler's seed
              buff_rd_seed_maskj <= {{6'b0,samp_seed_cnt_plus1},64'b0};  // samp_seed_cnt counts from -1
          end
        end
        default: begin  // security_level=0
          if (if_buff_rd_addr==(`ADDR_SAMP_SEED_SG0+'d2)) begin // reading the last line of sampler's seed
              buff_rd_seed_maskj <= {6'b0,samp_seed_cnt_plus1};
          end
        end
      endcase
    end
  end
  else begin
    buff_rd_seed_maskj <= '0;
  end
end

assign buff_rd_seed_inner = buff_rd_seed | {buff_rd_seed_maskj,32'b0};
padding u_padding (
    .clk                 (clk),  // input
    .rst_n               (rstn),  // input
    .start               (keccak_start[12:0]),  // input
    .src_addr            ({3'b0, seed_base_raddr}),
    .src_length          ({3'b0, dg_length}),
    .valid_bytes         (dg_valid_bytes),
    .first               (keccak_first),  // output [3:0]
    .last                (keccak_last),  // output [3:0]
    .mode                (mode),  // output [3:0]
    .d_o                 (keccak_i),  // output logic [1087:0]
    .d_o_vld             (keccak_i_req),  // output logic [3:0]
    // to buffer
    .if_buff_rd_addr     ,  // output logic [11:0]
    .if_buff_rd_en       ,  // output logic
    .if_buff_rd_data(buff_rd_seed_inner)        // input logic [511:0]
);

    logic ready2keccak;   // ready to keccak core
    logic                   align_ready;    // rdy from align

always_comb begin
  if (task_regenfg) begin
    if (security_level==1'b1) keccak_i_1 = keccak_i | {regenfg_cnt_j,320'b0};
    else keccak_i_1 = keccak_i | {regenfg_cnt_j,192'b0};
  end
  else keccak_i_1 = keccak_i;
end

  keccak_statepermute_shake256_round2stage i_keccak_statepermute (
    .clk,
    .rst_n(rstn),
    .init     (keccak_start[0]),    // i
    .first    (keccak_first),  // i
    .last     (keccak_last),   // i
    .mode     (keccak_mode),   // i
    .d_i_req  (keccak_i_req),  // i
    .d_i      (keccak_i_1),      // i [1087:0]
    .d_o_req  (keccak_o_req),  // o
    .d_o_rdy  (ready2keccak),  // i
    .d_o      (keccak_o)       // o [1087:0]
  );
  assign ready2keccak = ((dg_funct==`DG_GEN_H) || (dg_funct==`DG_GEN_SAMP) || task_regenfg) ? align_ready : 1'b1;

//////////////////////////////////////////////////
// mask for salt, M and hpub
logic [511:0] keccak_o_masked;
always_comb begin
  if (security_level==1'b1) begin
    case (dg_funct)
      `DG_GEN_SALT: keccak_o_masked = {192'b0, keccak_o[319:0]};
      default: keccak_o_masked = keccak_o;
    endcase
  end
  else begin    // security_level==1'b0
    case (dg_funct)
      `DG_GEN_SALT: keccak_o_masked = {320'b0, keccak_o[191:0]};
      `DG_GEN_HPUB: keccak_o_masked = {256'b0, keccak_o[255:0]};
      default: keccak_o_masked = keccak_o;
    endcase
  end
end

//////////////////////////////////////////////////
    logic          align_valid_in;
    logic   [8:0]  align_cnt;
    logic          align_type;  // 1-128 0-320
    logic align_flush;
    logic                   align_valid_out;
    logic ready2align;
    logic                   samp_rdy_o;
    logic  [319:0]          align_d_320_o;
    logic  [127:0]          align_d_128_o;
    logic align_start;

    always_comb begin
      align_cnt = 'd0;
      if (security_level==1'b0) begin 
      case (dg_funct)
        `DG_GEN_SAMP: align_cnt = 'd64;
        `DG_GEN_H:    align_cnt = 'd8;
      endcase
      end
      else begin  // hawk-1024
      case (dg_funct)
        `DG_GEN_SAMP: align_cnt = 'd128;
        `DG_GEN_H:    align_cnt = 'd16;
      endcase
      end
    end

    assign align_type = task_regenfg || (dg_funct==`DG_GEN_H);  // 1-128 0-320

    always_comb begin
      align_valid_in = 1'b0;
      if (task_regenfg) align_valid_in = keccak_o_req;
      else begin
      case (state)
        st_shake_seed_outalign: align_valid_in = keccak_o_req;  // gen (h0,h1)
        st_samp_x0: align_valid_in = keccak_o_req;
        st_samp_x1: align_valid_in = keccak_o_req;
        default: align_valid_in = 1'b0;
      endcase
      end
    end

    assign align_flush = (state==st_samp_read_t) && (next_state==st_samp_read_seed);

    wire gen_h_use_align = dg_funct==`DG_GEN_H;

    always_ff @(posedge clk or negedge rstn) begin
      if (!rstn) align_start <= 1'b0;
      else if (align_start==1'b1) align_start <= 1'b0;
      else if (task_regenfg && regenfg_keccak_start) align_start <= 1'b1;
      else if ((dg_start&&gen_h_use_align)||align_flush) align_start <= 1'b1;
    end

    keccak_outalign u_keccak_outalign (
        .clk,
        .rst_n(rstn),
        .start(align_start),
        .align_type(align_type),
        .wr_num(align_cnt),
        .dg_finish(dg_finish),
        .d_i_req(align_valid_in),
        .d_i_rdy(align_ready),
        .d_i(keccak_o),
        .d_o_req(align_valid_out),
        .d_o_rdy(ready2align),
        .d_320_o(align_d_320_o),
        .d_128_o(align_d_128_o)
    );

always_comb begin
  if (task_regenfg) ready2align = regenfg_rdy_o;
  else ready2align = (dg_funct==`DG_GEN_SAMP) ? samp_rdy_o : 1'b1;
end

// output wdata from align_data
// align_data output 1 vectors, so vn set to h's bank
logic [`ADDR_WIDTH-1:0] keccak_outalign_waddr;
logic [`VEC_NUM_WIDTH-1:0] keccak_outalign_wvn;
logic keccak_outalign_wr_finish;

// h0 and h1 are stored in bank 0 and bank 1, respectively.
always_ff @(posedge clk) begin
    if (dg_start || keccak_outalign_wr_finish) begin
      keccak_outalign_waddr <= seed_base_waddr;
      keccak_outalign_wvn <= 'd0;
      keccak_outalign_wr_finish <= 1'b0;
    end
    else if (align_valid_out) begin
      case (security_level)
        1'b0: begin
          if (keccak_outalign_waddr==(seed_base_waddr+'d3)) begin
            keccak_outalign_waddr <= seed_base_waddr;
            if (keccak_outalign_wvn==1'b1) keccak_outalign_wr_finish <= 1'b1; // if finish writing bank1
            else keccak_outalign_wvn <= 'd1;
          end
          else begin
            keccak_outalign_waddr <= keccak_outalign_waddr + 'd1;
          end
        end
        1'b1: begin
          if (keccak_outalign_waddr==(seed_base_waddr+'d7)) begin
            keccak_outalign_waddr <= seed_base_waddr;
            if (keccak_outalign_wvn==1'b1) keccak_outalign_wr_finish <= 1'b1; // if finish writing bank1
            else keccak_outalign_wvn <= 'd1;
          end
          else begin
            keccak_outalign_waddr <= keccak_outalign_waddr + 'd1;
          end
        end
      endcase
    end
end

//////////////////////////////////////////////////
// sampler
    logic sampler_en;
    logic            [77:0] cmp_T   [12:0];
    logic            [77:0] cmp_c   [12:0];
    logic                   vld2cmp;
    logic                   rdy2cmp;
    logic     [12:0]        cmp_lt;
    logic                   cmp_vld_o;
    logic                   cmp_rdy_o;

	logic [77:0] c_data;

    logic [127:0] samp_vec_out;
    logic samp_vec_vld_o;
    logic         sample_finish;
    logic         sample_exception;
    logic [9:0] samp_cnt;  // counter of sampled vectors, range 0~256/512
    logic [9:0] samp_cnt_last;  // when enter samp_x0/x1 state, record the last samp_cnt

    logic samp_x01;
    logic [`VEC_NUM_WIDTH-1:0] samp_w_vn;
    logic [`ADDR_WIDTH-1:0] samp_base_waddr;

assign sampler_en = (state==st_samp_x0) || (state==st_samp_x1);
assign samp_x01 = (state==st_samp_x1);

always_ff @(posedge clk or negedge rstn) begin
  if (!rstn) samp_cnt_last <= 'd0;
  else if ((next_state==st_samp_x0)||(next_state==st_samp_x1)) samp_cnt_last <= samp_cnt;
end

always_ff @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    samp_w_vn <= 'd0;
  end
  else begin
    case (security_level)
      1'b1: begin
        if ((samp_w_vn>='d252)&&dg_avn0_wen) begin    // after writing the last vector of this seed
          if (state==st_samp_x0) samp_w_vn <= samp_seed_cnt;
          else samp_w_vn <= samp_seed_cnt_plus1;
        end
        else if (samp_vec_vld_o) begin
          samp_w_vn <= samp_w_vn + 'd4;
        end
      end
      default: begin
        if ((samp_w_vn>='d124)&&dg_avn0_wen) begin
          if (state==st_samp_x0) samp_w_vn <= samp_seed_cnt;
          else samp_w_vn <= samp_seed_cnt_plus1;
        end
        else if (samp_vec_vld_o) begin
          samp_w_vn <= samp_w_vn + 'd4;
        end
      end
    endcase
  end
end

always_comb begin
  case (security_level)
    1'b1: begin
      if (samp_x01==1'b0) begin   // x0
        samp_base_waddr = `ADDR_SG0_X0;
      end
      else begin                  // x1
        samp_base_waddr = `ADDR_SG1_X1;
      end
    end
    default: begin
      if (samp_x01==1'b0) begin   // x0
        samp_base_waddr = `ADDR_SG0_X0;
      end
      else begin                  // x1
        samp_base_waddr = `ADDR_SG0_X1;
      end
    end
  endcase
end

logic load_t;
logic send_t_raddr;
always_ff @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    send_t_raddr <= 1'b0;
  end
  else if (send_t_raddr==1'b1) begin
    send_t_raddr <= 1'b0;
  end
  else if ((state==st_samp_read_t)&&(load_t==1'b0)) begin
    send_t_raddr <= 1'b1;
  end
end
always_ff @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    load_t <= 1'b0;
  end
  else if (load_t==1'b1) begin
    load_t <= 1'b0;
  end
  else if (send_t_raddr) begin
    load_t <= 1'b1;
  end
end

logic [255:0] samp_rd_t;
logic [3:0] t_in;
logic [15:0] t_vld_reg;
logic t_vld_i;
logic initial_load_t;   // initially, samp_seed_cnt==-1, so the first load of t should use cnt+1.
assign initial_load_t = (load_t && (next_state==st_samp_read_seed)) ? 1'b1 : 1'b0;
always_ff @(posedge clk) begin
  if (load_t) begin
    samp_rd_t <= ({dg_r_bv0,dg_r_av0} >> {(samp_seed_cnt+initial_load_t),2'b0});
    t_vld_reg <= 16'hffff;
  end
  else if (samp_rdy_o && align_valid_out) begin
    samp_rd_t <= samp_rd_t >> 16;
    t_vld_reg <= (t_vld_reg >> 1);
  end
end
assign t_in = samp_rd_t[3:0];
assign t_vld_i = t_vld_reg[0];

logic [`VEC_NUM_WIDTH-1:0] samp_r_t_vn;
// t0 and t1 stay in bank 2 and bank 3; the address selects the active vector.
assign samp_r_t_vn = n1;
logic [`ADDR_WIDTH-1:0] samp_r_t_addr;
always_ff @(posedge clk) begin
  if (dg_start) begin
    samp_r_t_addr <= t_base_raddr;
  end
  else if (load_t) begin
    if (samp_r_t_addr == (t_base_raddr + (security_level ? 'd7 : 'd3)) ) begin
      samp_r_t_addr <= t_base_raddr;
    end
    else begin
      samp_r_t_addr <= samp_r_t_addr+'d1;
    end
  end
end


logic samp_rdy;
assign samp_rdy_o = samp_rdy && sampler_en && t_vld_i;
    sampler U_SAMPLER (
        .clk              (clk),
        .rstn             (rstn),
        .security_level   (security_level),
        .sampler_en       (sampler_en),
        .samp_rdy_o       (samp_rdy),
        .t_in             (t_in),
        .t_vld_i          (t_vld_i),
        .c_in             (align_d_320_o),
        .c_vld_i          (align_valid_out),
        // to cmp
        .T                (cmp_T),
        .c_data           (c_data), 
        .vld2cmp          (vld2cmp),
        // from cmp
        .cmp_rdy         (cmp_rdy_o),
        // to cmp
        .rdy2cmp         (rdy2cmp),
        // from cmp
        .lt_i            (cmp_lt),
        .cmp_vld_i       (cmp_vld_o),
        // downstream
        .rdy_i           (1'b1),
        // output
        .vec_out         (samp_vec_out),
        .samp_vec_vld_o  (samp_vec_vld_o),
        .sample_finish   (sample_finish),
        .samp_cnt_o      (samp_cnt),
        .sample_exception(sample_exception)
    );

always_comb begin
	for (int i=0; i<13; i=i+1) begin
		cmp_c[i] = c_data;
	end
end
    unsigned_cmp_lt_78bit_13 U_CMP (
        .clk    (clk),
        .rstn   (rstn),
        .vld_i  (vld2cmp),
        .a      (cmp_c),
        .b      (cmp_T),
        .lt     (cmp_lt),
        .vld_o  (cmp_vld_o),
        .rdy_i  (rdy2cmp),
        .rdy_o  (cmp_rdy_o)
    );

//////////////////////////////////////////////////
// regenerate fg

assign regenfg_start = dg_start && task_regenfg;
assign regenfg_d_i = align_d_128_o;
assign regenfg_vld_i = task_regenfg && align_valid_out;

regen_fg u_regen_fg (
    .clk                      (clk),
    .rstn                     (rstn),
    .security_level           (security_level),
    
    .regenfg_start            (regenfg_start),
    .regenfg_finish           (regenfg_finish),
    
    .regenfg_keccak_start     (regenfg_keccak_start),
    .regenfg_cnt_j            (regenfg_cnt_j),
    
    .d_i                      (regenfg_d_i),
    .vld_i                    (regenfg_vld_i),
    .rdy_o                    (regenfg_rdy_o),
    
    .flag_wr_g                (flag_wr_g),
    .regenfg_v0_wen           (regenfg_v0_wen),
    .regenfg_v1_wen           (regenfg_v1_wen),
    .regenfg_v0               (regenfg_v0),
    .regenfg_v1               (regenfg_v1),
    .regenfg_wvn0             (regenfg_wvn0),
    .regenfg_wvn1             (regenfg_wvn1)
);

//////////////////////////////////////////////////
// read buffer select
localparam keccak_rd  = 1'b0;
localparam t_rd       = 1'b1;

logic dg_rd_buf_sel;

always_comb begin
  case (dg_rd_buf_sel)
    t_rd:begin  // read t when sampling
    // use port av0, bv0 to read t
      dg_a_r_mapping_mode = 1'b0;
      dg_b_r_mapping_mode = dg_a_r_mapping_mode;
      dg_a_base_raddr     = samp_r_t_addr;
      dg_b_base_raddr     = dg_a_base_raddr;
      dg_r_avn0           = samp_r_t_vn;
      dg_r_bvn0           = n2;
      dg_r_avn1           = n1;
      dg_r_bvn1           = n2;
      dg_avn0_ren         = send_t_raddr;
      dg_bvn0_ren         = send_t_raddr;
      dg_avn1_ren         = 1'b0;
      dg_bvn1_ren         = 1'b0;
    end

    default:begin     // keccak-padding module read buffer
      dg_a_r_mapping_mode = 1'b0;
      dg_b_r_mapping_mode = dg_a_r_mapping_mode;
      dg_a_base_raddr     = if_buff_rd_addr;
      dg_b_base_raddr     = dg_a_base_raddr;
      dg_r_avn0           = 'd0;
      dg_r_bvn0           = 'd1;
      dg_r_avn1           = n1;
      dg_r_bvn1           = n2;
      dg_avn0_ren         = if_buff_rd_en;
      dg_bvn0_ren         = if_buff_rd_en;
      dg_avn1_ren         = if_buff_rd_en;
      dg_bvn1_ren         = if_buff_rd_en;
    end
  
  endcase
end

//////////////////////////////////////////////////
// write buffer select
localparam keccak_wr            = 2'b00;
localparam keccak_out_align_wr  = 2'b10;    // write h0,h1
localparam sampler_wr           = 2'b11;
logic [1:0] dg_wr_buf_sel;

always_comb begin
  // default value:
  // keccak_wr: keccak core wr 512-bit seed data (after mask)
    dg_a_w_mapping_mode = 1'b0;
    dg_b_w_mapping_mode = dg_a_w_mapping_mode;
    dg_a_base_waddr     = seed_base_waddr;    // all write-seeds fit in with 512 bits, so 1 waddr is enough
    dg_b_base_waddr     = dg_a_base_waddr;
    dg_w_avn0           = 'd0;
    dg_w_bvn0           = 'd1;
    dg_w_avn1           = (security_level ? 'd128:'d64);
    dg_w_bvn1           = (security_level ? 'd129:'d65);
    dg_w_av0            = keccak_o_masked[(1*128-1) -: 128];
    dg_w_bv0            = keccak_o_masked[(2*128-1) -: 128];
    dg_w_av1            = keccak_o_masked[(3*128-1) -: 128];
    dg_w_bv1            = keccak_o_masked[(4*128-1) -: 128];
    dg_avn0_wen         = keccak_o_req && (state!=st_idle);
    dg_bvn0_wen         = keccak_o_req && (state!=st_idle);
    dg_avn1_wen         = keccak_o_req && (state!=st_idle);
    dg_bvn1_wen         = keccak_o_req && (state!=st_idle);
  if (task_regenfg) begin  // use bv0, bv1
    dg_a_w_mapping_mode = 1'b0;
    dg_b_w_mapping_mode = flag_wr_g ? `MAP_g_SIGN : `MAP_f_SIGN;
    dg_b_base_waddr     = flag_wr_g ? another_addr : seed_base_waddr;
    dg_w_bvn0           = regenfg_wvn0;
    dg_w_bvn1           = regenfg_wvn1;
    dg_w_bv0            = regenfg_v0;
    dg_w_bv1            = regenfg_v1;
    dg_avn0_wen         = 1'b0;
    dg_bvn0_wen         = regenfg_v0_wen;
    dg_avn1_wen         = 1'b0;
    dg_bvn1_wen         = regenfg_v1_wen;
  end
  else begin
  case (dg_wr_buf_sel)
    // for now, only used to write h0,h1
    // write 1 vector at a time; port av0 is used
    keccak_out_align_wr:begin
      dg_a_w_mapping_mode = 1'b0;
      dg_b_w_mapping_mode = dg_a_w_mapping_mode;
      dg_a_base_waddr     = keccak_outalign_waddr;
      dg_b_base_waddr     = dg_a_base_waddr;
      dg_w_avn0           = keccak_outalign_wvn;
      dg_w_av0            = align_d_128_o[(1*128-1) -: 128];
      dg_avn0_wen         = align_valid_out && (state!=st_idle);
      dg_bvn0_wen         = 1'b0;
      dg_avn1_wen         = 'b0;
      dg_bvn1_wen         = 'b0;
    end

    sampler_wr:begin  // wr 1 vector at a time
      dg_a_w_mapping_mode = (samp_x01 ? `MAP_X1_SIGN:`MAP_X0_SIGN);
      dg_b_w_mapping_mode = 1'b0;
      dg_a_base_waddr     = samp_base_waddr;
      dg_b_base_waddr     = dg_a_base_waddr;
      dg_w_avn0           = samp_w_vn;
      dg_w_av0            = samp_vec_out;
      dg_avn0_wen         = samp_vec_vld_o;
      dg_bvn0_wen         = 'b0;
      dg_avn1_wen         = 'b0;
      dg_bvn1_wen         = 'b0;
    end

    default:begin     
    end
  
  endcase
  end
end

//////////////////////////////////////////////////
// keccak_o counter

//////////////////////////////////////////////////
// FSM
  // ------------------------------
  // state driver
  // ------------------------------
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn)
      state <= st_idle;
    else
      state <= next_state;
  end

  // ------------------------------
  // state transition
  // ------------------------------
  always_comb begin
    next_state = state;
    case (state)
      st_idle: begin
        if (dg_start) begin
          case (dg_funct)
            `DG_GEN_SAMP: next_state = st_samp_read_t; // start sample
            `DG_GEN_H:    next_state = st_shake_seed_outalign;    // gen h0,h1
            default:      next_state = st_shake_seed_dir;    // if gen M/salt/hpub, directly start shake256
          endcase
        end
      end
      st_shake_seed_dir: begin
        // only M, salt, hpub(vrfy) use st_shake_seed_dir, and these 3 seeds all fit in with 1 512-bit line
        // so once keccak generates a valid output data, then go to st_idle
        if (keccak_o_req && (!keccak_start[0])) next_state = st_idle;
      end
      st_shake_seed_outalign: begin
        // only (h0,h1) use st_shake_seed_outalign
        if (keccak_outalign_wr_finish) next_state = st_idle;
      end
      st_samp_read_t: begin
        if (load_t) begin
          case (security_level)
            1'b1: begin
              if ((samp_cnt=='d0) || (samp_cnt=='d128) || (samp_cnt=='d256) || (samp_cnt=='d384)) begin
                next_state = st_samp_read_seed;
              end
              else if ((samp_cnt[6]==1'b1)&&(samp_cnt[3:0]==5'b0000)) begin
                next_state = st_samp_x1;
              end
              else begin
                next_state = st_samp_x0;
              end
            end
            default: begin
              if ((samp_cnt=='d0) || (samp_cnt=='d64) || (samp_cnt=='d128) || (samp_cnt=='d192)) begin
                next_state = st_samp_read_seed;
              end
              else if ((samp_cnt[5]==1'b1)&&(samp_cnt[3:0]==4'b0000)) begin
                next_state = st_samp_x1;
              end
              else begin
                next_state = st_samp_x0;
              end
            end
          endcase
        end
      end

      st_samp_read_seed: begin
        case (security_level)
          1'b1: begin     // hawk1024
            if (if_buff_rd_addr==(seed_base_raddr+'d4)) next_state = st_samp_x0;
          end
          default: begin  // hawk512
            if (if_buff_rd_addr==(seed_base_raddr+'d3)) next_state = st_samp_x0;
          end
        endcase
      end

      st_samp_x0: begin
        if ((samp_cnt[3:0]==4'b0)&&(samp_cnt!=samp_cnt_last)) next_state = st_samp_read_t;
      end

      st_samp_x1: begin
        if (sample_finish) next_state = st_idle;
        else if ((samp_cnt[3:0]==4'b0)&&(samp_cnt!=samp_cnt_last)) next_state = st_samp_read_t;
      end

      default: next_state = st_idle;
    endcase
  end

  // ------------------------------
  // fsm output: r/w buf_sel
  // ------------------------------
  always_comb begin
    dg_wr_buf_sel = keccak_wr;
    dg_rd_buf_sel = keccak_rd;
    case (state)
      st_shake_seed_dir: begin
        dg_wr_buf_sel = keccak_wr;
        dg_rd_buf_sel = keccak_rd;
      end
      st_shake_seed_outalign: begin
        dg_wr_buf_sel = keccak_out_align_wr;
        dg_rd_buf_sel = keccak_rd;
      end
      st_samp_read_t: begin
        dg_wr_buf_sel = sampler_wr;
        dg_rd_buf_sel = t_rd;
      end
      st_samp_read_seed: begin
        dg_wr_buf_sel = sampler_wr;
        dg_rd_buf_sel = keccak_rd;
      end
      st_samp_x0: begin
        dg_wr_buf_sel = sampler_wr;
        dg_rd_buf_sel = keccak_rd;
      end
      st_samp_x1: begin
        dg_wr_buf_sel = sampler_wr;
        dg_rd_buf_sel = keccak_rd;
      end
      default: begin
        dg_wr_buf_sel = keccak_wr;
        dg_rd_buf_sel = keccak_rd;
      end
    endcase
  end

// gen dg_finish
always_ff @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    dg_finish <= 1'b0;
  end
  else if (dg_finish==1'b1) dg_finish <= 1'b0;
  else if (task_regenfg) dg_finish <= regenfg_finish;
  else if ((state!=st_idle)&&(next_state==st_idle)) dg_finish <= 1'b1;
end

//////////////////////////////////////////////////

endmodule
