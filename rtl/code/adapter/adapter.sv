`include "../../defines/defines.sv"
`include "adapter_pkg.svh"

module adapter
  import adapter_pkg::*;
(
  input logic                         clk,
  input logic                         rst_n,
  input logic [9:0] in_row_num_indirect,
  input logic [9:0] out_row_num_indirect,
  input logic adw_start,
  output logic adw_op_done,
  input logic indirect_mode,
  input logic [9:0] len,
  input logic [9:0] dst,
  input logic [9:0] src1,
  input logic [9:0] src0,
  input logic [9:0] reg_len,
  input  logic [511:0] adw_buff_rd_data,
  output logic adw_buff_rd_en,
  output logic [9:0] adw_buff_rd_addr,
  output logic [511:0] adw_buff_wr_data,
  output logic adw_buff_wr_en,
  output logic [9:0] adw_buff_wr_addr
);

  typedef logic [$clog2(ROW_BW+1)-1:0] row_bit_num_t;

  logic [9:0] in_len, out_len;

  assign in_len  = indirect_mode ? in_row_num_indirect : len;
  assign out_len = indirect_mode ? out_row_num_indirect : reg_len;

  //flag
  logic adw_flag;
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) adw_flag <= 1'b0;
    else if (adw_start) adw_flag <= 1'd1;
    else if (adw_op_done) adw_flag <= 1'd0;
  end

  //--------------------------------------------------- load the src1, process the indirect method
  localparam int unsigned SRC1_LEN = 4;

  logic                        rd_cnt_1_start[2];
  logic                        rd_cnt_1_done [2];
  logic                        rd_cnt_1_en   [2];  //ld from src1

  logic [$clog2(SRC1_LEN)-1:0] rd_cnt_1      [2];

  assign rd_cnt_1_start[0] = adw_start & indirect_mode;

  pipeline_delay_bit #(
    .R(1),
    .P(0),
    .D(adw_buff_rd_latency)
  ) i_delay_0 (
    .c(clk),
    .r(rst_n),
    .i(rd_cnt_1_start[0]),
    .o(rd_cnt_1_start[1])
  );  //rd_cnt_1_start[1]: rd_out signal

  for (genvar i = 0; i < 2; i++) begin : gen_rd_cnt_1  //two counters: rd_cnt_1: rd_en_cnt; and rdout_cnt;
    counter_ce  // counter with configurable end number
    #(
      .BW($clog2(SRC1_LEN))
    ) i_rd_cnt_1 (
      .clk,  // i
      .rst_n,  // i
      .start (rd_cnt_1_start[i]),            // i
      .num   (SRC1_LEN),  // i [BW-1:0]
      .run   (1'b1),                         // i
      .cnt   (rd_cnt_1[i]),                  // o [BW-1:0]
      .cnt_en(rd_cnt_1_en[i]),               // o
      .done  (rd_cnt_1_done[i])
    );
  end

  logic [1007:0] out_arr;

  always_ff @(posedge clk)
    if (rd_cnt_1_en[1]) begin
      unique case (rd_cnt_1[1])
        2'd2: out_arr[503:0] <= adw_buff_rd_data[503:0];
        2'd3: out_arr[504+:504] <= adw_buff_rd_data[503:0];
        default: ;
      endcase
    end

  //---------------------------------------------------  in_en and out_en; assign from the in,out_bw and remain_cnt
  logic in_arr_en, out_arr_en;
  buff_addr_t in_arr_cnt, out_arr_cnt;

  row_bit_num_t                          remain_cnt;
  logic         [$bits(row_bit_num_t):0] remain_add_in_len;

  wire [$clog2(ROW_BW)-1:0] out_bw = indirect_mode ? out_arr[out_arr_cnt[6:0]*$clog2(ROW_BW)+:$clog2(ROW_BW)] : '0;


  row_bit_num_t                          in_len_n;
  assign in_len_n = in_arr_en ? ROW_BW : '0;
  row_bit_num_t out_len_n;
  assign out_len_n         = {$bits(row_bit_num_t) {out_arr_en}} & {(out_bw == '0), out_bw};  //next length of output

  assign remain_add_in_len = remain_cnt + in_len_n;

  wire in_en_n = remain_add_in_len <= (out_len_n + ROW_BW);  // next data  in en, active when the input data can be stored in the reg
  wire out_en_n = remain_add_in_len >=(out_len_n);  // next data out en, active when the data (next in and reg) is enough to output

  //---------------------------------------------------
  wire adapter_proc_start = (adw_start & ~indirect_mode) | rd_cnt_1_done[1];

  counter_ce  // counter with configurable end number; cnt to index the src1
  #(
    .BW($bits(buff_addr_t))
  ) i_in_arr_cnt (
    .clk,  // i
    .rst_n,  // i
    .start (adapter_proc_start),  // i
    .num   (in_len),              // i [BW-1:0]
    .run   (in_en_n),             // i
    .cnt   (in_arr_cnt),          // o [BW-1:0]
    .cnt_en(in_arr_en),           // o
    .last  (),                    // o
    .done  ()                     // o
  );

  counter_ce  // counter with configurable end number; cnt to index the src1
  #(
    .BW($bits(buff_addr_t))
  ) i_out_arr_cnt (
    .clk,  // i
    .rst_n,  // i
    .start (adapter_proc_start),  // i
    .num   (out_len),             // i [BW-1:0]
    .run   (out_en_n),            // i
    .cnt   (out_arr_cnt),         // o [BW-1:0]
    .cnt_en(out_arr_en),          // o
    .done  ()                     // o
  );

  logic in_en, out_en;  //cur data in vld

  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) in_en <= 1'b0;
    else in_en <= in_en_n & in_arr_en;
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) out_en <= 1'b0;
    else out_en <= out_en_n & out_arr_en;

  //remain_cnt
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) remain_cnt <= '0;
    else if (adapter_proc_start) remain_cnt <= '0;
    else if (out_arr_en) begin
      case ({
        in_en_n, out_en_n
      })
        2'b01: remain_cnt <= remain_cnt - out_len_n;
        2'b10: remain_cnt <= remain_cnt + in_len_n;
        2'b11: remain_cnt <= remain_cnt + in_len_n - out_len_n;
      endcase
    end
  end

  logic in_en_vld;

  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) in_en_vld <= 1'b0;
    else in_en_vld <= in_arr_en;

  //-------------------------------------------------------------  src0 read
  logic       rd_cnt_0_start;
  logic       rd_cnt_0_en;
  buff_addr_t rd_cnt_0;

  pipeline_delay_bit #(
    .R(1),
    .P(0),
    .D(1)
  ) i_rdcnt_en_delay (
    .c(clk),
    .r(rst_n),
    .i(adapter_proc_start),
    .o(rd_cnt_0_start)
  );

  wire rd_cnt_0_done;

  counter_ce  // counter with configurable end number;
  #(
    .BW($bits(buff_addr_t))
  ) i_ld_in0_addr (
    .clk,  // i
    .rst_n,  // i
    .start (rd_cnt_0_start),  // i
    .num   (in_len),          // i [BW-1:0]
    .run   (in_en_vld & in_en), // i
    .cnt   (rd_cnt_0),        // o [BW-1:0]
    .cnt_en(rd_cnt_0_en),     // o
    .last  (),                // o
    .done  (rd_cnt_0_done)    // o
  );

  logic rd_src0_done_d3;

  pipeline_delay_bit #(
    .R(1),
    .P(0),
    .D(adw_buff_rd_latency)
  ) i_rd_cnt_delay (
    .c(clk),
    .r(rst_n),
    .i(rd_cnt_0_done),
    .o(rd_src0_done_d3)
  );

  //-------------------------------------------------------------------
  //en delay
  logic out_en_d3;

  pipeline_delay_bit #(
    .R(1),
    .P(0),
    .D(adw_buff_rd_latency)
  ) i_out_en_delay (
    .c(clk),
    .r(rst_n),
    .i(out_en),
    .o(out_en_d3)
  );

  row_bit_num_t out_bw_d    [3];
  row_bit_num_t remain_cnt_d[4];

  always_ff @(posedge clk)
    if (adw_flag) begin
      out_bw_d[0] <= {(out_bw == '0), out_bw};
      out_bw_d[1] <= out_en ? out_bw_d[0] : '0;
      out_bw_d[2] <= out_bw_d[1];
    end

  always_ff @(posedge clk)
    if (adw_flag) begin
      remain_cnt_d[0] <= remain_cnt;
      remain_cnt_d[1] <= out_en ? remain_cnt_d[0] : '0;
      remain_cnt_d[2] <= remain_cnt_d[1];
      remain_cnt_d[3] <= remain_cnt_d[2];
    end

  //rm in shift
  wire  rm_in_en_l = rd_cnt_0_en & in_en;

  logic rm_in_en;

  pipeline_delay_bit #(
    .R(1),
    .P(0),
    .D(adw_buff_rd_latency)
  ) i_rm_in_en_delay (
    .c(clk),
    .r(rst_n),
    .i(rm_in_en_l),
    .o(rm_in_en)
  );

  row_data_t io_shift, ro_shift;

  row_data_t rm;
  always_ff @(posedge clk) if (rm_in_en) rm <= adw_buff_rd_data;

  row_data_t out_msk;
  logic [9:0] msk_i;
  always_ff @(posedge clk) begin
    if (adw_flag) begin
      foreach (out_msk[msk_i]) begin
        if (out_bw_d[2]>msk_i) out_msk[msk_i] <= 1'b1;
        else out_msk[msk_i] <= 1'b0;
      end
    end
  end
  row_data_t out_vec;
  assign out_vec = (ro_shift | io_shift) & out_msk;  // out vec

  //---------------------------------------------
  buff_addr_t st_addr;  //wr_addr

  always_ff @(posedge clk) begin
    if (adapter_proc_start) st_addr <= '0;
    else if (adw_flag & out_en_d3) st_addr <= st_addr + 1;
  end

  wire  end_flag = ((st_addr == out_len - 1) && out_en_d3) || (rd_src0_done_d3 & (remain_cnt < out_len_n));

  ///////////////////////////////////////

  logic buff_rd_en                                                                                         [2];

  assign buff_rd_en[0]   = rd_cnt_0_en & adw_flag;
  assign buff_rd_en[1]   = rd_cnt_1_en[0] & indirect_mode & adw_flag;

  pipeline_delay_bit #(
    .R(1),
    .P(0),
    .D(adw_buff_rd_latency-`BUFF_RD_LATENCY)
  ) i_adw_buff_rd_en_delay (
    .c(clk),
    .r(rst_n),
    .i(buff_rd_en[0] | buff_rd_en[1]),
    .o(adw_buff_rd_en)
  );

  buff_addr_t buff_rd_addr[2];

  assign buff_rd_addr[0] = rd_cnt_0 + src0;
  assign buff_rd_addr[1] = rd_cnt_1[0] + src1;

logic [9:0] adw_buff_rd_addr_inn;
dffre_pipe #(
	.WIDTH(10),
	.DELAY(adw_buff_rd_latency-`BUFF_RD_LATENCY)
) u_dffre_pipe_adw_buff_rd_addr (
	.clk,
	.rstn(rst_n),
	.en(1'b1),
	.d(adw_buff_rd_addr_inn),
	.q(adw_buff_rd_addr)
);
  always_comb begin
    unique case (1'b1)
      buff_rd_en[0]: adw_buff_rd_addr_inn = buff_rd_addr[0];
      buff_rd_en[1]: adw_buff_rd_addr_inn = buff_rd_addr[1];
      default:       adw_buff_rd_addr_inn = 'x;
    endcase
  end

  assign adw_buff_wr_en     = out_en_d3;
  assign adw_buff_wr_addr   = st_addr + dst;
  assign adw_buff_wr_data   = out_vec;

  assign adw_op_done  = end_flag;

  assign io_shift          = adw_buff_rd_data << remain_cnt_d[3];
  assign ro_shift          = rm >> (ROW_BW - remain_cnt_d[3]);


endmodule
