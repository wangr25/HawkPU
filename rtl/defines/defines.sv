`define USE_ARR_FOR_TC
`define USE_ARR_FOR_TW

// taskcode width
`define TC_W 64

// modular
// in hawk_sign
`define P0 		18433
// (P0+1)/2
`define HP0		9217
// -1/p mod 2^32
`define P0_I	32'd3955247103
// R^2 mod P
`define P0_R2   806 

// in hawk_verify
`define P1 		2147473409
`define P1_I   	2042615807
// R^3 mod P
`define P1_R3	1819566170
`define P2 		2147389441
`define P2_I   	1862176767
// R^3 mod P
`define P2_R3	976758995

// BFU
`define BFU_PIPE_STAGES 7
// bfu_mode
`define BFU_NTT_MODE       'd0
`define BFU_INTT_MODE      'd1
`define BFU_FFT_MODE       'd2
`define BFU_IFFT_MODE      'd3
`define BFU_MMUL_MODE      'd4
`define BFU_MUL_MODE       'd5
`define BFU_GF2CF_MODE     'd6
`define BFU_MADD_MODE      'd7
`define BFU_MSUB_MODE      'd8
`define BFU_ADD_MODE       'd9
`define BFU_SUB_MODE       'd10
`define BFU_MMAC_MODE      'd11
`define BFU_DIV_MODE       'd12
`define BFU_INV_MODE       'd13

// a polynomial has 2**8 vectors at most
`define VEC_BITS 128
`define VEC_NUM_WIDTH 8
// buffer depth
`define ADDR_WIDTH 9
`define BRAM_DEPTH 512

// dg_funct
`define DG_GEN_M       2'b000
`define DG_GEN_SALT    3'b001
`define DG_GEN_H       3'b010
`define DG_GEN_SAMP    3'b011
`define DG_GEN_HPUB    3'b100
`define DG_REGEN_FG    3'b101

// gf2_funct
`define GF2_FUNCT_MUL   2'b00
`define GF2_FUNCT_MOD   2'b01
`define GF2_FUNCT_ADD   2'b10

// code
`define CODE_FUNCT_MOV  2'b00
`define CODE_FUNCT_ENC  2'b01
`define CODE_FUNCT_DEC  2'b10
`define CODE_FUNCT_ADW  2'b11

// format
`define FORM_FUNCT_CAT           2'b00
`define FORM_FUNCT_P2G           2'b01
`define FORM_FUNCT_CAT_MES_HPUB  2'b10
`define FORM_FUNCT_S2G           2'b11

// buffer read latency
`define BUFF_RD_LATENCY 1
`define FORMAT_RD_LATENCY 1

// 512 sign
`define ADDR_SK_SG0        160
`define ADDR_MES_SG0       256
`define ADDR_SAMP_SEED_SG0 145
`define ADDR_SG0_X0    0
`define ADDR_SG0_X1    32
`define ADDR_SG0_SIG    64

// 1024 sign
`define ADDR_SK_SG1    300
`define ADDR_MES_SG1   320
`define ADDR_SAMP_SEED_SG1_ADAPTED 285
`define ADDR_SG1_X1    64
`define ADDR_SG1_SIG    64

// 512 vrfy
`define ADDR_PUB_VF0 256
`define ADDR_SIG_VF0 272
`define ADDR_MES_VF0 320
`define ADDR_ADW_CONST_VF0 128
`define ADDR_ADW_CONST_MES_VF0 160
`define ADDR_FFT_Z00 128
`define ADDR_FFT_Z00_VF1 320

// 1024 vrfy
`define ADDR_PUB_VF1  0
`define ADDR_SIG_VF1  39
`define ADDR_MES_VF1  320
`define ADDR_ADW_CONST_VF1 128
`define ADDR_ADW_CONST_MES_VF1 132

// mapping
`define MAP_X0_SIGN     0
`define MAP_X1_SIGN     1
`define MAP_f_SIGN     0
`define MAP_g_SIGN     1
`define MAP_gX0_SIGN     `MAP_X0_SIGN
`define MAP_fX1_SIGN     `MAP_X1_SIGN
`define MAP_W1_SIGN      `MAP_gX0_SIGN
`define MAP_S1_SIGN      `MAP_W1_SIGN

`define MAP_Q01_VF0 1
`define MAP_Q00_VF0 0
`define MAP_Q00_INV_VF0 1
