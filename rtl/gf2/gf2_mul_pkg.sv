package gf2_mul_pkg;

  localparam int N = 1024;
  localparam int K = 64;
  localparam int GF2_MEM_RD_LATENCY = 1;

  localparam int L = N / K;
  localparam int AW = $clog2(L);
  localparam int BW = $clog2(L);
  localparam int CW = $clog2(L + L + 1);

endpackage
