

module rconst (
  input        [23:0] i,
  output logic [63:0] rc
);

  always_comb begin
    rc[00]                                           = |{i[22], i[20], i[15:12], i[10], i[7:4], i[0]};
    rc[01]                                           = |{i[19:18], i[16:15], i[13:11], i[8], i[4], i[2:1]};
    rc[03]                                           = |{i[23], i[19:18], i[14:7], i[4], i[2]};
    rc[07]                                           = |{i[21:20], i[17], i[14:12], i[9:8], i[6], i[4], i[2:1]};
    rc[15]                                           = |{i[23], i[21:20], i[18], i[16:14], i[12], i[10], i[7:6], i[4:1]};
    rc[31]                                           = |{i[23:22], i[20:19], i[12:10], i[6:5], i[3]};
    rc[63]                                           = |{i[23], i[21:19], i[17:13], i[7:6], i[3:2]};

    {rc[62:32], rc[30:16], rc[14:8], rc[6:4], rc[2]} = '0;
  end

endmodule

module round (
  input        [1599:0] in,
  input        [  63:0] rconst,
  output logic [1599:0] out
);

  logic [63:0] A [ 5];
  logic [63:0] B [ 5];

  logic [63:0] C [25];
  logic [63:0] D [25];

  logic [63:0] Si[25];
  logic [63:0] So[25];

  for (genvar i = 0; i < 25; i++) begin : gen_data_io
    assign Si[i]         = in[64*i+:64];
    assign out[64*i+:64] = So[i];
  end

  always_comb begin
    A[0]   = Si[00] ^ Si[05] ^ Si[10] ^ Si[15] ^ Si[20];
    A[1]   = Si[01] ^ Si[06] ^ Si[11] ^ Si[16] ^ Si[21];
    A[2]   = Si[02] ^ Si[07] ^ Si[12] ^ Si[17] ^ Si[22];
    A[3]   = Si[03] ^ Si[08] ^ Si[13] ^ Si[18] ^ Si[23];
    A[4]   = Si[04] ^ Si[09] ^ Si[14] ^ Si[19] ^ Si[24];

    B[0]   = A[4] ^ {A[1][62:0], A[1][63]};
    B[1]   = A[0] ^ {A[2][62:0], A[2][63]};
    B[2]   = A[1] ^ {A[3][62:0], A[3][63]};
    B[3]   = A[2] ^ {A[4][62:0], A[4][63]};
    B[4]   = A[3] ^ {A[0][62:0], A[0][63]};

    C[00]  = B[0] ^ Si[00];
    C[01]  = B[1] ^ Si[06];
    C[02]  = B[2] ^ Si[12];
    C[03]  = B[3] ^ Si[18];
    C[04]  = B[4] ^ Si[24];
    C[05]  = B[3] ^ Si[03];
    C[06]  = B[4] ^ Si[09];
    C[07]  = B[0] ^ Si[10];
    C[08]  = B[1] ^ Si[16];
    C[09]  = B[2] ^ Si[22];
    C[10]  = B[1] ^ Si[01];
    C[11]  = B[2] ^ Si[07];
    C[12]  = B[3] ^ Si[13];
    C[13]  = B[4] ^ Si[19];
    C[14]  = B[0] ^ Si[20];
    C[15]  = B[4] ^ Si[04];
    C[16]  = B[0] ^ Si[05];
    C[17]  = B[1] ^ Si[11];
    C[18]  = B[2] ^ Si[17];
    C[19]  = B[3] ^ Si[23];
    C[20]  = B[2] ^ Si[02];
    C[21]  = B[3] ^ Si[08];
    C[22]  = B[4] ^ Si[14];
    C[23]  = B[0] ^ Si[15];
    C[24]  = B[1] ^ Si[21];

    D[00]  = {C[00][63:00]};
    D[01]  = {C[01][19:0], C[01][63:20]};
    D[02]  = {C[02][20:0], C[02][63:21]};
    D[03]  = {C[03][42:0], C[03][63:43]};
    D[04]  = {C[04][49:0], C[04][63:50]};
    D[05]  = {C[05][35:0], C[05][63:36]};
    D[06]  = {C[06][43:0], C[06][63:44]};
    D[07]  = {C[07][60:0], C[07][63:61]};
    D[08]  = {C[08][18:0], C[08][63:19]};
    D[09]  = {C[09][02:0], C[09][63:03]};
    D[10]  = {C[10][62:0], C[10][63:63]};
    D[11]  = {C[11][57:0], C[11][63:58]};
    D[12]  = {C[12][38:0], C[12][63:39]};
    D[13]  = {C[13][55:0], C[13][63:56]};
    D[14]  = {C[14][45:0], C[14][63:46]};
    D[15]  = {C[15][36:0], C[15][63:37]};
    D[16]  = {C[16][27:0], C[16][63:28]};
    D[17]  = {C[17][53:0], C[17][63:54]};
    D[18]  = {C[18][48:0], C[18][63:49]};
    D[19]  = {C[19][07:0], C[19][63:08]};
    D[20]  = {C[20][01:0], C[20][63:02]};
    D[21]  = {C[21][08:0], C[21][63:09]};
    D[22]  = {C[22][24:0], C[22][63:25]};
    D[23]  = {C[23][22:0], C[23][63:23]};
    D[24]  = {C[24][61:0], C[24][63:62]};

    So[00] = D[00] ^ (~D[01] & D[02]) ^ rconst;
    So[01] = D[01] ^ (~D[02] & D[03]);
    So[02] = D[02] ^ (~D[03] & D[04]);
    So[03] = D[03] ^ (~D[04] & D[00]);
    So[04] = D[04] ^ (~D[00] & D[01]);
    So[05] = D[05] ^ (~D[06] & D[07]);
    So[06] = D[06] ^ (~D[07] & D[08]);
    So[07] = D[07] ^ (~D[08] & D[09]);
    So[08] = D[08] ^ (~D[09] & D[05]);
    So[09] = D[09] ^ (~D[05] & D[06]);
    So[10] = D[10] ^ (~D[11] & D[12]);
    So[11] = D[11] ^ (~D[12] & D[13]);
    So[12] = D[12] ^ (~D[13] & D[14]);
    So[13] = D[13] ^ (~D[14] & D[10]);
    So[14] = D[14] ^ (~D[10] & D[11]);
    So[15] = D[15] ^ (~D[16] & D[17]);
    So[16] = D[16] ^ (~D[17] & D[18]);
    So[17] = D[17] ^ (~D[18] & D[19]);
    So[18] = D[18] ^ (~D[19] & D[15]);
    So[19] = D[19] ^ (~D[15] & D[16]);
    So[20] = D[20] ^ (~D[21] & D[22]);
    So[21] = D[21] ^ (~D[22] & D[23]);
    So[22] = D[22] ^ (~D[23] & D[24]);
    So[23] = D[23] ^ (~D[24] & D[20]);
    So[24] = D[24] ^ (~D[20] & D[21]);
  end

endmodule

module keccak_statepermute_shake256_round2stage (
  input                 clk,
  input                 rst_n,
  input                 init,
  input                 first,
  input                 last,
  input                 mode,       // 0:abs 1:squ
  input                 d_i_req,
  input        [1087:0] d_i,
  output logic          d_o_req,
  input                 d_o_rdy,
  output logic [1087:0] d_o
);

  logic do_req;

  logic [1087:0] do_dat;

  assign d_o_req = do_req;
  assign d_o = do_dat;

    round_2stage u_round_2stage (
      .clk,
      .rst_n,
      .init,
      .first  (first),   // i
      .last   (last),    // i
      .mode   (mode),    // i
      .d_i_req(d_i_req),  // i
      .d_i,  // i [1087:0]
      .d_o_req(do_req),  // o
      .d_o_rdy(d_o_rdy),  // i
      .d_o    (do_dat)   // o [1087:0]
    );

endmodule

module round_2stage (
  input                 clk,
  input                 rst_n,
  input                 init,
  input                 first,    // ABS first data
  input                 last,     // ABS last data
  input                 mode,     // 0:ABS 1:SQU
  input                 d_i_req,
  input        [1087:0] d_i,
  output logic          d_o_req,
  input                 d_o_rdy,
  output logic [1087:0] d_o
);

  logic [23:0] idx, idx_r;

  logic idx_done;

  logic state;  //0:abs 1:squ

  wire  d_i_vld = d_i_req;
  wire  d_o_vld = d_o_req & d_o_rdy;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) d_o_req <= 1'b0;
    else if (init) d_o_req <= 1'b0;
    else if (state & idx_done) d_o_req <= 1'b1;
    else if (d_o_vld) d_o_req <= 1'b0;
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) state <= 1'b0;
    else if (init) state <= 1'b0;
    else if (d_i_vld) begin
      if (last) state <= 1'b1;
      else if (first) state <= 1'b0;
    end
  end

  logic idx_start;

  always_comb begin
    if (state) begin  // squ
      if (mode) idx_start = d_o_vld;  // shake
      else idx_start = 1'b0;  // sha-3
    end else begin  // abs
      idx_start = d_i_vld;
    end
  end

  logic idx_run;

  assign idx_done = idx[22] & idx_run;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) idx_run <= 1'b0;
    else if (init) idx_run <= 1'b0;
    else if (idx_start) idx_run <= 1'b1;
    else if (idx_done) idx_run <= 1'b0;
  end

  assign idx = idx_start ? 'b1 : idx_r;

  always_ff @(posedge clk) begin
    if (idx_start) idx_r <= 'b100;
    else if (idx_run) idx_r <= idx_r << 2;
  end

  logic [63:0] rc_0, rc_1;
  logic [1599:0] s_0, s_1;

  logic [1599:0] in, out;

  always_comb begin
    if (d_i_vld) begin
      if (first) in = {512'b0, d_i};
      else in = {512'b0, d_i} ^ out;
    end else in = out;
  end

  rconst u_rconst_0 (
    (idx << 0),
    rc_0
  );
  round u_round_0 (
    in,
    rc_0,
    s_0
  );
  rconst u_rconst_1 (
    (idx << 1),
    rc_1
  );
  round u_round_1 (
    s_0,
    rc_1,
    s_1
  );

  wire out_cg = idx_start | idx_run;

  always_ff @(posedge clk) if (out_cg) out <= s_1;

  assign d_o = out[1087:0];

endmodule
