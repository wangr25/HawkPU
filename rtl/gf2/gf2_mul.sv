module gf2_mul
  import gf2_mul_pkg::*;
(
  input  logic          clk,
  input  logic          rst_n,
  input  logic          start,
  input  logic          security_level,
  output logic          done,
  output logic          rd_en_a,
  output logic [AW-1:0] rd_addr_a,
  input  logic [ K-1:0] rd_dat_a,
  output logic          rd_en_b,
  output logic [BW-1:0] rd_addr_b,
  input  logic [ K-1:0] rd_dat_b,
  output logic          rd_en_c,
  output logic [CW-1:0] rd_addr_c,
  input  logic [ K-1:0] rd_dat_c,
  output logic          wr_en_c,
  output logic [CW-1:0] wr_addr_c,
  output logic [ K-1:0] wr_dat_c
);

  logic [$clog2(L    )-1:0] cnt_i;
  logic [$clog2(L + 1)-1:0] cnt_j;
  wire [$clog2(L    )-1:0] cnt_i_num = security_level ? L : (L>>1);
  wire [$clog2(L + 1)-1:0] cnt_j_num = security_level ? (L+1) : ((L>>1) + 1);

  logic cnt_i_start, cnt_i_run, cnt_i_en, cnt_i_done, cnt_i_last;
  logic cnt_j_start, cnt_j_en, cnt_j_done, cnt_j_last;

  assign cnt_i_start = start;
  assign cnt_j_start = cnt_i_start | (cnt_j_done & ~cnt_i_last);

  assign cnt_i_run   = cnt_j_done;

  counter_ce #(
    .BW($clog2(L))
  ) u_cnt_i (
    .clk,
    .rst_n,
    .start (cnt_i_start),
    .num   (cnt_i_num),
    .run   (cnt_i_run),
    .cnt   (cnt_i),
    .cnt_en(cnt_i_en),
    .last  (cnt_i_last),
    .done  (cnt_i_done)
  );

  counter_ce #(
    .BW($clog2(L + 1))
  ) u_cnt_j (
    .clk,
    .rst_n,
    .start (cnt_j_start),
    .num   (cnt_j_num),
    .run   (1'b1),
    .cnt   (cnt_j),
    .cnt_en(cnt_j_en),
    .last  (cnt_j_last),
    .done  (cnt_j_done)
  );

  assign rd_en_a   = cnt_i_en & rd_en_b & (cnt_j == '0);
  assign rd_en_b   = cnt_j_en & ~cnt_j_last;
  assign rd_en_c   = cnt_j_en;

  assign rd_addr_a = AW'(cnt_i);
  assign rd_addr_b = BW'(cnt_j);
  assign rd_addr_c = CW'(cnt_i + cnt_j);

  logic rd_dat_a_vld, rd_dat_b_vld, rd_dat_c_vld;

  pipeline_delay #(
    .R (1),              //asynchronous reset
    .DW(3),              //bit width
    .D (GF2_MEM_RD_LATENCY)  //delay cycle
  ) i_rd_en_delay (
    .clk,
    .rst_n,
    .en (1'b1),
    .in ({rd_en_a, rd_en_b, rd_en_c}),                // in
    .out({rd_dat_a_vld, rd_dat_b_vld, rd_dat_c_vld})  // out
  );

  logic [K-1:0] A, B, R, C_I, C_L, C_H, C_O;

  always_ff @(posedge clk) if (rd_dat_a_vld) A <= rd_dat_a;
  always_ff @(posedge clk) if (rd_dat_b_vld) B <= rd_dat_b;
  always_ff @(posedge clk) if (rd_dat_c_vld) C_I <= rd_dat_c;

  gf_mul_core #(
    .DW(K)
  ) u_mul_core (
    .A(A),
    .B(B),
    .C({C_H, C_L})
  );

  logic cnt_j_zero, cnt_j_norm;
  logic cnt_j_zero_en, cnt_j_last_en, cnt_j_norm_en;

  assign cnt_j_zero = cnt_j_en & (cnt_j == '0);
  assign cnt_j_norm = cnt_j_en & ~(cnt_j_zero | cnt_j_last);

  pipeline_delay #(
    .R (1),                  //asynchronous reset
    .DW(3),                  //bit width
    .D (GF2_MEM_RD_LATENCY + 1)  //delay cycle
  ) i_cnt_j_delay (
    .clk,
    .rst_n,
    .en (1'b1),
    .in ({cnt_j_zero, cnt_j_norm, cnt_j_last}),          // in
    .out({cnt_j_zero_en, cnt_j_norm_en, cnt_j_last_en})  // out
  );

  always_ff @(posedge clk) begin
    if (cnt_j_zero_en) C_O <= C_L ^ C_I;
    else if (cnt_j_last_en) C_O <= R ^ C_I;
    else if (cnt_j_norm_en) C_O <= C_L ^ R ^ C_I;
  end

  assign wr_dat_c = C_O;

  always_ff @(posedge clk) if (cnt_j_zero_en | cnt_j_norm_en) R <= C_H;

  pipeline_delay #(
    .R (1),  //asynchronous reset
    .DW(1),  //bit width
    .D (2)   //delay cycle
  ) i_wr_en_c_delay (
    .clk,
    .rst_n,
    .en (1'b1),          // enable
    .in (rd_dat_c_vld),  // in
    .out(wr_en_c)        // out
  );

  pipeline_delay #(
    .R (0),                  //asynchronous reset
    .DW(CW),                 //bit width
    .D (GF2_MEM_RD_LATENCY + 2)  //delay cycle
  ) i_rd_addr_c_delay (
    .clk,
    .rst_n,
    .en (cnt_j_en),   // enable
    .in (rd_addr_c),  // in
    .out(wr_addr_c)   // out
  );

  pipeline_delay #(
    .R (1),                  //asynchronous reset
    .DW(1),                  //bit width
    .D (GF2_MEM_RD_LATENCY + 2)  //delay cycle
  ) i_cnt_i_done_delay (
    .clk,
    .rst_n,
    .en (1'b1),
    .in (cnt_i_done),  // in
    .out(done)         // out
  );

endmodule

module gf_mul_core #(
  parameter int DW = 64
) (
  input  logic [DW-1 : 0] A,
  input  logic [DW-1 : 0] B,
  output logic [DW*2-1:0] C
);

  logic [DW*2-1:0] P[DW];
  logic [DW*2-1:0] S[DW];

  always_comb foreach (P[i]) P[i] = B[i] ? (A << i) : '0;

  always_comb foreach (S[i]) S[i] = ((i == 0) ? '0 : S[i-1]) ^ P[i];

  assign C = S[DW-1];

endmodule

module pipeline_delay #(
  parameter bit R  = 0,  //asynchronous reset
  parameter int DW = 0,  //bit width
  parameter int D  = 1   //delay cycle
) (
  input  logic          clk,    // clk
  input  logic          rst_n,  // rst_n
  input  logic          en,     // enable
  input  logic [DW-1:0] in,     // in
  output logic [DW-1:0] out     // out
);

  if (D == 0) begin : gen_feedthrough

    assign out = in;

  end else begin : gen_shift_pipe

    logic [DW-1:0] out_r[D+1];

    assign out_r[0] = in;
    assign out      = out_r[D];

    logic en_r[D];

    assign en_r[0] = en;

    for (genvar i = 1; i <= D; i++) begin : gen_pipe

      always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) en_r[i] <= 1'b0;
        else en_r[i] <= en_r[i-1];
      end

      if (R) begin : gen_rst_pipe

        always_ff @(posedge clk, negedge rst_n) begin
          if (!rst_n) out_r[i] <= '0;
          else if (en_r[i-1]) out_r[i] <= out_r[i-1];
        end

      end else begin : gen_none_rst_pipe

        always_ff @(posedge clk) if (en_r[i-1]) out_r[i] <= out_r[i-1];

      end

    end

  end

endmodule
