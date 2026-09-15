`include "../defines/defines.sv"

module gf2_top 
  import gf2_mul_pkg::*;
(
    input wire clk,
    input wire rstn,
    input wire security_level,

    // taskcode
    input wire [`TC_W-1:0] taskcode,
    input wire taskcode_vld,

    // read buffer
    output logic [`ADDR_WIDTH-1:0] gf2_av0_raddr_dir,
    output logic [`ADDR_WIDTH-1:0] gf2_bv0_raddr_dir,
    output logic [`ADDR_WIDTH-1:0] gf2_av1_raddr_dir,
    output logic [`ADDR_WIDTH-1:0] gf2_bv1_raddr_dir,
    output logic gf2_avn0_ren,
    output logic gf2_bvn0_ren,
    output logic gf2_avn1_ren,
    output logic gf2_bvn1_ren,
    output logic [1:0] gf2_av0_r_bs_dir,
    output logic [1:0] gf2_bv0_r_bs_dir,
    output logic [1:0] gf2_av1_r_bs_dir,
    output logic [1:0] gf2_bv1_r_bs_dir,
    input  logic [`VEC_BITS-1:0]         gf2_r_av0,
    input  logic [`VEC_BITS-1:0]         gf2_r_bv0,
    input  logic [`VEC_BITS-1:0]         gf2_r_av1,
    input  logic [`VEC_BITS-1:0]         gf2_r_bv1,

    // write buffer
    output logic [`ADDR_WIDTH-1:0] gf2_av0_waddr_dir,
    output logic [`ADDR_WIDTH-1:0] gf2_bv0_waddr_dir,
    output logic [`ADDR_WIDTH-1:0] gf2_av1_waddr_dir,
    output logic [`ADDR_WIDTH-1:0] gf2_bv1_waddr_dir,
    output logic gf2_avn0_wen,
    output logic gf2_bvn0_wen,
    output logic gf2_avn1_wen,
    output logic gf2_bvn1_wen,
    output logic [1:0] gf2_av0_w_bs_dir,
    output logic [1:0] gf2_bv0_w_bs_dir,
    output logic [1:0] gf2_av1_w_bs_dir,
    output logic [1:0] gf2_bv1_w_bs_dir,
    output logic [`VEC_BITS-1:0]         gf2_w_av0,
    output logic [`VEC_BITS-1:0]         gf2_w_bv0,
    output logic [`VEC_BITS-1:0]         gf2_w_av1,
    output logic [`VEC_BITS-1:0]         gf2_w_bv1,

    // to top control
    output logic gf2_finish
);

////////////////////////////////////////////////////////////////////////////////

    // from taskcode
    logic gf2_start;
    logic [1:0] gf2_funct;
    logic [`ADDR_WIDTH-1:0] gf2_src1_base_raddr;
    logic [`ADDR_WIDTH-1:0] gf2_src2_base_raddr;
    logic [1:0] gf2_src1_banknum;
    logic [1:0] gf2_src2_banknum;
    logic [`ADDR_WIDTH-1:0] gf2_dst1_base_waddr;
    logic [`ADDR_WIDTH-1:0] gf2_dst2_base_waddr;
    logic [1:0] gf2_dst1_banknum;  // valid only in gf2_funct_mul and gf2_funct_mod
    logic [1:0] gf2_dst2_banknum;  // valid only in gf2_funct_mul

logic task_gf2;
assign task_gf2 = taskcode[2:0] == 3'b010;

assign gf2_start = taskcode_vld && task_gf2;

assign gf2_src1_base_raddr = taskcode[11:3];
assign gf2_src2_base_raddr = taskcode[20:12];
assign gf2_dst1_base_waddr = taskcode[29:21];
assign gf2_dst2_base_waddr = taskcode[38:30];
assign gf2_src1_banknum = taskcode[40:39];
assign gf2_src2_banknum = taskcode[42:41];
assign gf2_dst1_banknum = taskcode[44:43];
assign gf2_dst2_banknum = taskcode[46:45];
assign gf2_funct = taskcode[48:47];

////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////
// gf2_mul
////////////////////////////////////////

  logic gf2_mul_start;
  logic gf2_mul_done;
  logic          gf2_mul_rd_en_a;
  logic [AW-1:0] gf2_mul_rd_addr_a;
  logic [K-1:0]  gf2_mul_rd_dat_a;
  logic          gf2_mul_rd_en_b;
  logic [BW-1:0] gf2_mul_rd_addr_b;
  logic [K-1:0]  gf2_mul_rd_dat_b;
  logic          gf2_mul_rd_en_c;
  logic [CW-1:0] gf2_mul_rd_addr_c;
  logic [K-1:0]  gf2_mul_rd_dat_c;
  logic          gf2_mul_wr_en_c;
  logic [CW-1:0] gf2_mul_wr_addr_c;
  logic [K-1:0]  gf2_mul_wr_dat_c;

  assign gf2_mul_start = (gf2_funct==`GF2_FUNCT_MUL) && gf2_start;

  gf2_mul u_gf2_mul (
    .clk       (clk),
    .rst_n     (rstn),
    .start     (gf2_mul_start),
    .security_level,
    .done      (gf2_mul_done),
    .rd_en_a   (gf2_mul_rd_en_a),
    .rd_addr_a (gf2_mul_rd_addr_a),
    .rd_dat_a  (gf2_mul_rd_dat_a),
    .rd_en_b   (gf2_mul_rd_en_b),
    .rd_addr_b (gf2_mul_rd_addr_b),
    .rd_dat_b  (gf2_mul_rd_dat_b),
    .rd_en_c   (gf2_mul_rd_en_c),
    .rd_addr_c (gf2_mul_rd_addr_c),
    .rd_dat_c  (gf2_mul_rd_dat_c),
    .wr_en_c   (gf2_mul_wr_en_c),
    .wr_addr_c (gf2_mul_wr_addr_c),
    .wr_dat_c  (gf2_mul_wr_dat_c)
  );

  logic [`ADDR_WIDTH-1:0] gf2_mul_src1_raddr;
  logic [`ADDR_WIDTH-1:0] gf2_mul_src2_raddr;
  logic gf2_mul_src1_rdata_sel;
  logic gf2_mul_src2_rdata_sel;
  logic [`ADDR_WIDTH-1:0] gf2_mul_dst_waddr;
  logic [1:0] gf2_mul_dst_w_bs;
  logic [`ADDR_WIDTH-1:0] gf2_mul_dst_raddr;
  logic gf2_mul_dst_ren;
  logic [1:0] gf2_mul_dst_r_bs;

  assign gf2_mul_src1_raddr = gf2_src1_base_raddr + gf2_mul_rd_addr_a[AW-1:1];
  pipeline_delay #(
    .R (1),              //asynchronous reset
    .DW(1),              //bit width
    .D (GF2_MEM_RD_LATENCY)  //delay cycle
  ) u_pipe_delay_gf2_mul_src1_rdata_sel (
    .clk,
    .rst_n(rstn),
    .en (1'b1),
    .in (gf2_mul_rd_addr_a[0]),                // in
    .out(gf2_mul_src1_rdata_sel)  // out
  );
  assign gf2_mul_src2_raddr = gf2_src2_base_raddr + gf2_mul_rd_addr_b[AW-1:1];
  pipeline_delay #(
    .R (1),              //asynchronous reset
    .DW(1),              //bit width
    .D (GF2_MEM_RD_LATENCY)  //delay cycle
  ) u_pipe_delay_gf2_mul_src2_rdata_sel (
    .clk,
    .rst_n(rstn),
    .en (1'b1),
    .in (gf2_mul_rd_addr_b[0]),                // in
    .out(gf2_mul_src2_rdata_sel)  // out
  );
  always_comb begin
    if (security_level==1'b1) begin
      gf2_mul_dst_waddr = gf2_mul_wr_addr_c[3:0] + (gf2_mul_wr_addr_c[4] ? gf2_dst2_base_waddr : gf2_dst1_base_waddr);
    end
    else begin
      gf2_mul_dst_waddr = gf2_mul_wr_addr_c[2:0] + (gf2_mul_wr_addr_c[3] ? gf2_dst2_base_waddr : gf2_dst1_base_waddr);
    end
  end
  always_comb begin
    if (security_level==1'b1) begin
      gf2_mul_dst_w_bs = gf2_mul_wr_addr_c[4] ? gf2_dst2_banknum : gf2_dst1_banknum;
    end
    else begin
      gf2_mul_dst_w_bs = gf2_mul_wr_addr_c[3] ? gf2_dst2_banknum : gf2_dst1_banknum;
    end
  end
  always_comb begin
    if (security_level==1'b1) begin
      gf2_mul_dst_raddr = gf2_mul_rd_addr_c[3:0] + (gf2_mul_rd_addr_c[4] ? gf2_dst2_base_waddr : gf2_dst1_base_waddr);
    end
    else begin
      gf2_mul_dst_raddr = gf2_mul_rd_addr_c[2:0] + (gf2_mul_rd_addr_c[3] ? gf2_dst2_base_waddr : gf2_dst1_base_waddr);
    end
  end
  assign gf2_mul_dst_ren = gf2_mul_rd_en_c;
  always_comb begin
    if (security_level==1'b1) begin
      gf2_mul_dst_r_bs = gf2_mul_rd_addr_c[4] ? gf2_dst2_banknum : gf2_dst1_banknum;
    end
    else begin
      gf2_mul_dst_r_bs = gf2_mul_rd_addr_c[3] ? gf2_dst2_banknum : gf2_dst1_banknum;
    end
  end

  assign gf2_mul_rd_dat_b = gf2_mul_src2_rdata_sel ? gf2_r_bv1[127-:64] : gf2_r_bv1[63:0];
  assign gf2_mul_rd_dat_a = gf2_mul_src1_rdata_sel ? gf2_r_av1[127-:64] : gf2_r_av1[63:0];

  // in the first access, c rdata must be 0
  logic gf2_mul_rd_dat_c_mask0;
  always_comb begin
    if (gf2_mul_rd_dat_c_mask0)
      gf2_mul_rd_dat_c = '0;
    else
      gf2_mul_rd_dat_c = gf2_r_bv0;
  end

  logic gf2_mul_rd_dat_c_first_access[32];
  integer ii;
  always_ff @(posedge clk) begin
    if (gf2_start) begin
      for (ii=0; ii<32; ii=ii+1) begin
        gf2_mul_rd_dat_c_first_access[ii] <= 'b1;
        gf2_mul_rd_dat_c_mask0 <= 1'b1;
      end
    end
    else if (gf2_mul_rd_dat_c_first_access[gf2_mul_rd_addr_c]==1'b1) begin
      gf2_mul_rd_dat_c_mask0 <= 1'b1;
      gf2_mul_rd_dat_c_first_access[gf2_mul_rd_addr_c] <= 1'b0;
    end
    else begin
      gf2_mul_rd_dat_c_mask0 <= 1'b0;
    end
  end

////////////////////////////////////////
// gf2 xor
////////////////////////////////////////

// xor use port av0, bv0

  logic [`VEC_BITS-1:0] gf2_xor_result;

  gf2_xor u_gf2_xor (
    .clk,
    .rstn,
    .gf2_xor_a(gf2_r_av0),
    .gf2_xor_b(gf2_r_bv0),
    .gf2_xor_result
  );

////////////////////////////////////////
// gen gf2_xor r/w control logic
////////////////////////////////////////
  localparam cnt_gf2_width = 5;

  logic cnt_gf2_start;
  logic [cnt_gf2_width-1:0] cnt_gf2_num; // max cnt value, now 16
  logic cnt_gf2_run;
  logic [cnt_gf2_width-1:0] cnt_gf2;
  logic cnt_gf2_en;   // o
  logic cnt_gf2_done;

  assign cnt_gf2_start = gf2_start && cnt_gf2_run;
  always_comb begin
    cnt_gf2_num = 'd0;
    case (gf2_funct)
        `GF2_FUNCT_MOD: cnt_gf2_num = security_level ? 'd16 : 'd8;
        `GF2_FUNCT_ADD: cnt_gf2_num = security_level ? 'd8 : 'd4;
    endcase
  end
  assign cnt_gf2_run = gf2_funct!=`GF2_FUNCT_MUL;

  counter_ce #(
    .BW(cnt_gf2_width)
  ) u_cnt_gf2 (
    .clk,
    .rst_n(rstn),
    .start (cnt_gf2_start),
    .num   (cnt_gf2_num),
    .run   (cnt_gf2_run),   // i: enable
    .cnt   (cnt_gf2),
    .cnt_en(cnt_gf2_en),    // o: busy
    .last  (),
    .done  (cnt_gf2_done)
  );

  logic [`ADDR_WIDTH-1:0] gf2_xor_src1_raddr;
  logic [`ADDR_WIDTH-1:0] gf2_xor_src2_raddr;
  logic gf2_xor_ren;
  logic gf2_xor_vld_i;
  logic gf2_xor_vld_o;

  assign gf2_xor_src1_raddr = gf2_src1_base_raddr + cnt_gf2;
  assign gf2_xor_src2_raddr = gf2_src2_base_raddr + cnt_gf2;
  assign gf2_xor_ren = cnt_gf2_en;
  pipeline_delay #(
    .R (1),              //asynchronous reset
    .DW(1),              //bit width
    .D (GF2_MEM_RD_LATENCY)  //delay cycle
  ) u_pipe_delay_gf2_xor_ren (
    .clk,
    .rst_n(rstn),
    .en (1'b1),
    .in (gf2_xor_ren),   // in
    .out(gf2_xor_vld_i)  // out
  );
  localparam gf2_xor_delay_bits = 1;
  pipeline_delay #(
    .R (1),
    .DW(1),
    .D (gf2_xor_delay_bits)  // gf2_xor delay cycle
  ) u_pipe_delay_gf2_xor_vldo (
    .clk,
    .rst_n(rstn),
    .en (1'b1),
    .in (gf2_xor_vld_i),   // in
    .out(gf2_xor_vld_o)  // out
  );

//------------------------------------
// gf2_mod
//------------------------------------
  logic [63:0] mod_xor_buff;
  logic mod_xor_buff_vld;
  logic [`VEC_BITS-1:0] gf2_mod_wdata;
  logic [`ADDR_WIDTH-1:0] gf2_mod_dst_waddr;
  logic gf2_mod_wen;
  logic gf2_mod_finish;

  always_ff @(posedge clk) begin
    mod_xor_buff <= gf2_xor_result[63:0];
  end
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) mod_xor_buff_vld <= 1'b0;
    else if (mod_xor_buff_vld==1'b1) mod_xor_buff_vld <= 1'b0;
    else if (gf2_xor_vld_o) mod_xor_buff_vld <= 1'b1;
  end
  logic [cnt_gf2_width-2:0] cnt_gf2_delayed;
  assign gf2_mod_dst_waddr = gf2_dst1_base_waddr + cnt_gf2_delayed;
  assign gf2_mod_wdata = {gf2_xor_result[63:0], mod_xor_buff};
  assign gf2_mod_wen = mod_xor_buff_vld && (gf2_funct==`GF2_FUNCT_MOD);
  pipeline_delay #(
    .R (1),
    .DW(cnt_gf2_width-1),
    .D (gf2_xor_delay_bits + 2)  // wait cycles
  ) u_pipe_delay_gf2_mod_waddr_cnt (
    .clk,
    .rst_n(rstn),
    .en (1'b1),
    .in (cnt_gf2[cnt_gf2_width-1:1]),
    .out(cnt_gf2_delayed)
  );
  pipeline_delay #(
    .R (1),
    .DW(1),
    .D (gf2_xor_delay_bits + 2)  // wait cycles
  ) u_pipe_delay_gf2_mod_finish (
    .clk,
    .rst_n(rstn),
    .en (1'b1),
    .in (cnt_gf2_done),   // in
    .out(gf2_mod_finish)  // out
  );

//------------------------------------
// gf2_add
//------------------------------------
  logic [`VEC_BITS-1:0] gf2_add_wdata;
  logic [`ADDR_WIDTH-1:0] gf2_add_waddr;
  logic gf2_add_wen;
  logic gf2_add_finish;
  logic [1:0] gf2_add_w_bs;

  assign gf2_add_wdata = gf2_xor_result;
  assign gf2_add_wen = gf2_xor_vld_o && (gf2_funct==`GF2_FUNCT_ADD);
  pipeline_delay #(
    .R (1),
    .DW(1),
    .D (gf2_xor_delay_bits + 2)  // wait cycles
  ) u_pipe_delay_gf2_add_finish (
    .clk,
    .rst_n(rstn),
    .en (1'b1),
    .in (cnt_gf2_done),   // in
    .out(gf2_add_finish)  // out
  );
  // w_bs count between 2 and 3
  always_ff @(posedge clk) begin
    if (gf2_start) gf2_add_w_bs <= 'd2;
    else if (gf2_xor_vld_o && (gf2_funct==`GF2_FUNCT_ADD)) begin
      case (gf2_add_w_bs)
        'd3: gf2_add_w_bs <= 'd2;
        default: gf2_add_w_bs <= 'd3;
      endcase
    end
  end
  always_ff @(posedge clk) begin
    if (gf2_start) gf2_add_waddr <= gf2_dst1_base_waddr;
    else if (gf2_add_w_bs=='d3) gf2_add_waddr <= gf2_add_waddr + 'd1;
  end
  

////////////////////////////////////////
// buffer interface
////////////////////////////////////////
always_comb begin
  // default value
  gf2_av0_raddr_dir = gf2_xor_src1_raddr;
  gf2_bv0_raddr_dir = gf2_mul_dst_raddr;
  gf2_av1_raddr_dir = gf2_mul_src1_raddr;
  gf2_bv1_raddr_dir = gf2_mul_src2_raddr;
  gf2_avn0_ren = 1'b0;
  gf2_bvn0_ren = 1'b0;
  gf2_avn1_ren = 1'b0;
  gf2_bvn1_ren = 1'b0;
  gf2_av0_r_bs_dir = gf2_src1_banknum;
  gf2_bv0_r_bs_dir = gf2_mul_dst_r_bs;
  gf2_av1_r_bs_dir = gf2_src1_banknum;
  gf2_bv1_r_bs_dir = gf2_src2_banknum;
  gf2_bv0_waddr_dir = gf2_mod_dst_waddr; 
  gf2_av1_waddr_dir = gf2_add_waddr;
  gf2_bv1_waddr_dir = gf2_mul_dst_waddr;
  gf2_avn0_wen = 1'b0;
  gf2_bvn0_wen = 1'b0;
  gf2_avn1_wen = 1'b0;
  gf2_bvn1_wen = 1'b0;
  gf2_w_bv0 = gf2_mod_wdata;
  gf2_w_av1 = gf2_add_wdata;
  gf2_w_bv1 = gf2_mul_wr_dat_c;
  gf2_bv0_w_bs_dir = gf2_dst1_banknum;
  gf2_av1_w_bs_dir = gf2_add_w_bs;
  gf2_bv1_w_bs_dir = gf2_mul_dst_w_bs;
  gf2_finish = 1'b0;
  case (gf2_funct)
    `GF2_FUNCT_MUL: begin
      // read buffer
      // port: use av1,bv1 for src1,src2; use bv0 for additional src3
      gf2_bv0_raddr_dir = gf2_mul_dst_raddr;
      gf2_av1_raddr_dir = gf2_mul_src1_raddr;
      gf2_bv1_raddr_dir = gf2_mul_src2_raddr;
      gf2_bvn0_ren = gf2_mul_dst_ren;
      gf2_avn1_ren = gf2_mul_rd_en_a;
      gf2_bvn1_ren = gf2_mul_rd_en_b;
      gf2_bv0_r_bs_dir = gf2_mul_dst_r_bs;
      gf2_av1_r_bs_dir = gf2_src1_banknum;
      gf2_bv1_r_bs_dir = gf2_src2_banknum;
      // write buffer
      // port: use bv1 for dst1 and dst2
      gf2_bv1_waddr_dir = gf2_mul_dst_waddr;
      gf2_bvn1_wen = gf2_mul_wr_en_c;
      gf2_bv1_w_bs_dir = gf2_mul_dst_w_bs;
      gf2_w_bv1 = gf2_mul_wr_dat_c;
      // other control signals
      gf2_finish = gf2_mul_done;
    end
    `GF2_FUNCT_MOD: begin
      // read buffer
      // port: use av0,bv0 for src1,src2
      gf2_av0_raddr_dir = gf2_xor_src1_raddr;
      gf2_bv0_raddr_dir = gf2_xor_src2_raddr;
      gf2_avn0_ren = gf2_xor_ren;
      gf2_bvn0_ren = gf2_xor_ren;
      gf2_av0_r_bs_dir = gf2_src1_banknum;
      gf2_bv0_r_bs_dir = gf2_src2_banknum;
      // write buffer
      // port: use bv0 for dst1
      gf2_bv0_waddr_dir = gf2_mod_dst_waddr;
      gf2_bvn0_wen = gf2_mod_wen;
      gf2_bv0_w_bs_dir = gf2_dst1_banknum;
      gf2_w_bv0 = gf2_mod_wdata;
      // other control signals
      gf2_finish = gf2_mod_finish;
    end
    `GF2_FUNCT_ADD: begin
      // read buffer
      // port: use av0,bv0 for src1,src2
      gf2_av0_raddr_dir = gf2_xor_src1_raddr;
      gf2_bv0_raddr_dir = gf2_xor_src2_raddr;
      gf2_avn0_ren = gf2_xor_ren;
      gf2_bvn0_ren = gf2_xor_ren;
      gf2_av0_r_bs_dir = gf2_src1_banknum;
      gf2_bv0_r_bs_dir = gf2_src2_banknum;
      // write buffer
      // port: use av1 for wrting t
      gf2_av1_waddr_dir = gf2_add_waddr;
      gf2_avn1_wen = gf2_add_wen;
      gf2_av1_w_bs_dir = gf2_add_w_bs;
      gf2_w_av1 = gf2_add_wdata;
      // other control signals
      gf2_finish = gf2_add_finish;
    end
  endcase
end

endmodule
