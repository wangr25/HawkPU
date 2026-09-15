`include "../defines/defines.sv"

module bfu_datapath (
	input wire clk,
	input wire rstn,
	input wire security_level,
	input wire sys_mode,
	input wire polyqround,
	input wire sys_init,

    input wire vrfy_post_process,
    input wire vrfy_post_process_vld,
    output logic vrfy_finish,

	// to upstream
	output logic rdy_o,
	// input data
    input  logic [127:0] bfu_av0_i,
    input  logic [127:0] bfu_av1_i,
    input  logic [127:0] bfu_bv0_i,
    input  logic [127:0] bfu_bv1_i,
    input  logic bfu_av0_vld_i,
    input  logic bfu_av1_vld_i,
    input  logic bfu_bv0_vld_i,
    input  logic bfu_bv1_vld_i,
    // str sub vec
    input  logic bfu_a_str, // 0-av0/av1 is vector, 1-av0/av1 is string
    input  logic bfu_load_str,
	// to pre-shifter
    input  wire [4:0]   a_pre_shift_len,
    input  wire [4:0]   b_pre_shift_len,
	// to in_permut_network
	input wire in_permut_sel,
	// to BFU core
	input wire [3:0] bfu_mode,
	input wire [31:0] bfu_const,
	input wire bfu_sel_const,
	input wire symbreak_en,
	input wire symbreak_calc,
	input wire [31:0] tw_rom_d0a,
	input wire [31:0] tw_rom_d0b,
	input wire [31:0] tw_rom_d1a,
	input wire [31:0] tw_rom_d1b,
	input wire [31:0] tw_rom_d2a,
	input wire [31:0] tw_rom_d2b,
	input wire [31:0] tw_rom_d3a,
	input wire [31:0] tw_rom_d3b,
    // set q00[0] as 0
    input wire q00_0_set0,
	// to out_permut_network
	input wire out_permut_sel,
	// to and from msum 
    output logic msum1_vld,
    output logic msum2_vld,
    output logic msum1_eq_msum2,
	// to post-shifter
    input  wire [4:0]   a_post_shift_len,
    input  wire [4:0]   b_post_shift_len,
    input  wire         post_shift_even,
    // to divider
    output logic [63:0] Xre[0:3],
    output logic [63:0] Xim[0:3],
    output logic [31:0] divisor[0:3],
    // output to control
    output logic symbreak_result,
	// output data
    output  logic [127:0] bfu_av0_o,
    output  logic [127:0] bfu_av1_o,
    output  logic [127:0] bfu_bv0_o,
    output  logic [127:0] bfu_bv1_o,
    output  logic bfu_av0_vld_o,
    output  logic bfu_av1_vld_o,
    output  logic bfu_bv0_vld_o,
    output  logic bfu_bv1_vld_o

);

// vrfy post process
logic [30:0] msum1;
logic [30:0] msum2;

// set q00[0] as 0
logic [`VEC_BITS-1:0] bfu_av0_i_msked;
assign bfu_av0_i_msked = q00_0_set0 ? {bfu_av0_i[`VEC_BITS-1:32],32'b0} : bfu_av0_i;

// string reg
logic [`VEC_BITS-1:0] str_reg;
always_ff @(posedge clk) begin
    if (bfu_load_str) str_reg <= bfu_av0_i_msked;
    else if (bfu_bv0_vld_i && bfu_a_str) str_reg <= (str_reg >> 8);
end
logic [`VEC_BITS-1:0] av0_str_vec;
logic [`VEC_BITS-1:0] av1_str_vec;
assign av0_str_vec = {31'b0,str_reg[3], 31'b0,str_reg[2], 31'b0,str_reg[1], 31'b0,str_reg[0]};
assign av1_str_vec = {31'b0,str_reg[7], 31'b0,str_reg[6], 31'b0,str_reg[5], 31'b0,str_reg[4]};

logic [`VEC_BITS-1:0] v0_tmp;
logic [`VEC_BITS-1:0] v2_tmp;

assign v0_tmp = bfu_a_str ? av0_str_vec : bfu_av0_i_msked;
assign v2_tmp = bfu_a_str ? av1_str_vec : bfu_av1_i;
	

logic [127:0] av0_pre_shifted;
logic [127:0] bv0_pre_shifted;
logic [127:0] av1_pre_shifted;
logic [127:0] bv1_pre_shifted;

vec_pre_shift u_vec_pre_shift (
    .av0                  (v0_tmp),
    .av1                  (v2_tmp),
    .bv0                  (bfu_bv0_i),
    .bv1                  (bfu_bv1_i),

    .a_pre_shift_len      (a_pre_shift_len),
    .b_pre_shift_len      (b_pre_shift_len),

    .av0_pre_shifted      (av0_pre_shifted),
    .bv0_pre_shifted      (bv0_pre_shifted),
    .av1_pre_shifted      (av1_pre_shifted),
    .bv1_pre_shifted      (bv1_pre_shifted)
);

logic [127:0] v0_pre_permut;
logic [127:0] v1_pre_permut;
logic [127:0] v2_pre_permut;
logic [127:0] v3_pre_permut;
	
in_permut_network u_in_permut_network (
    .v0    (av0_pre_shifted),
    .v1    (bv0_pre_shifted),
    .v2    (av1_pre_shifted),
    .v3    (bv1_pre_shifted),
    .sel   (in_permut_sel),
    .out0  (v0_pre_permut),
    .out1  (v1_pre_permut),
    .out2  (v2_pre_permut),
    .out3  (v3_pre_permut)
);

logic bfu_vld_i;
assign bfu_vld_i = bfu_av0_vld_i
                   || bfu_av1_vld_i
                   || bfu_bv0_vld_i
                   || bfu_bv1_vld_i
				   ;

// BFUs
logic [3:0] bfu_rdy_o;
logic [31:0] bfu_v0_o[0:3];
logic [31:0] bfu_v1_o[0:3];
logic [31:0] bfu_v2_o[0:3];
logic [31:0] bfu_v3_o[0:3];
logic bfu_vld_o[0:3];
logic [31:0] w0 [0:3];
logic [31:0] w1 [0:3];

assign w0[0] = tw_rom_d0a;
assign w0[1] = tw_rom_d1a;
assign w0[2] = tw_rom_d2a;
assign w0[3] = tw_rom_d3a;
assign w1[0] = tw_rom_d0b;
assign w1[1] = tw_rom_d1b;
assign w1[2] = tw_rom_d2b;
assign w1[3] = tw_rom_d3b;

assign rdy_o = | bfu_rdy_o;
 
re_bfu u_bfu_core0 (
    .clk            (clk),
    .rstn           (rstn),
    
    .sys_mode_in    (sys_mode),
    .bfu_mode_in    (vrfy_post_process ? `BFU_MMUL_MODE : bfu_mode),
    .polyqround_in  (vrfy_post_process ? 1'b0 : polyqround),
	.bfu_sel_const_in(bfu_sel_const),
    .bfu_const_in   (bfu_const),
    .symbreak_result(symbreak_result),
    
    .a_i            (v0_pre_permut[31:0  ]),
    .b_i            (v0_pre_permut[63:32 ]),
    .c_i            (vrfy_post_process ? msum1  : v0_pre_permut[95:64 ]),
    .d_i            (vrfy_post_process ? `P1_R3 : v0_pre_permut[127:96]),
    .w0_i           (w0[0]),
    .w1_i           (w1[0]),
    
    .vld_i          (vrfy_post_process ? vrfy_post_process_vld : bfu_vld_i),
    .rdy_o          (bfu_rdy_o[0]),
    
    .Xre            (Xre[0]),
    .Xim            (Xim[0]),
    .divisor        (divisor[0]),
    
    .a_o            (bfu_v0_o[0]),
    .b_o            (bfu_v0_o[1]),
    .c_o            (bfu_v0_o[2]),
    .d_o            (bfu_v0_o[3]),
    .vld_o        	(bfu_vld_o[0]),
    .rdy_i          (1'b1)
);
re_bfu u_bfu_core1 (
    .clk            (clk),
    .rstn           (rstn),
    
    .sys_mode_in    (sys_mode),
    .bfu_mode_in    (vrfy_post_process ? `BFU_MMUL_MODE : bfu_mode),
    .polyqround_in  (vrfy_post_process ? 1'b1 : polyqround),
	.bfu_sel_const_in(bfu_sel_const),
    .bfu_const_in   (bfu_const),
    .symbreak_result(symbreak_result),
    
    .a_i            (v1_pre_permut[31:0  ]),
    .b_i            (v1_pre_permut[63:32 ]),
    .c_i            (vrfy_post_process ? msum2 : v1_pre_permut[95:64 ]),
    .d_i            (vrfy_post_process ? `P2_R3 : v1_pre_permut[127:96]),
    .w0_i           (w0[1]),
    .w1_i           (w1[1]),
    
    .vld_i          (vrfy_post_process ? vrfy_post_process_vld : bfu_vld_i),
    .rdy_o          (bfu_rdy_o[1]),
    
    .Xre            (Xre[1]),
    .Xim            (Xim[1]),
    .divisor        (divisor[1]),
    
    .a_o            (bfu_v1_o[0]),
    .b_o            (bfu_v1_o[1]),
    .c_o            (bfu_v1_o[2]),
    .d_o            (bfu_v1_o[3]),
    .vld_o        	(bfu_vld_o[1]),
    .rdy_i          (1'b1)
);
re_bfu u_bfu_core2 (
    .clk            (clk),
    .rstn           (rstn),
    
    .sys_mode_in    (sys_mode),
    .bfu_mode_in    (bfu_mode),
    .polyqround_in  (polyqround),
	.bfu_sel_const_in(bfu_sel_const),
    .bfu_const_in   (bfu_const),
    .symbreak_result(symbreak_result),
    
    .a_i            (v2_pre_permut[31:0  ]),
    .b_i            (v2_pre_permut[63:32 ]),
    .c_i            (v2_pre_permut[95:64 ]),
    .d_i            (v2_pre_permut[127:96]),
    .w0_i           (w0[2]),
    .w1_i           (w1[2]),
    
    .vld_i          (bfu_vld_i),
    .rdy_o          (bfu_rdy_o[2]),
    
    .Xre            (Xre[2]),
    .Xim            (Xim[2]),
    .divisor        (divisor[2]),
    
    .a_o            (bfu_v2_o[0]),
    .b_o            (bfu_v2_o[1]),
    .c_o            (bfu_v2_o[2]),
    .d_o            (bfu_v2_o[3]),
    .vld_o        	(bfu_vld_o[2]),
    .rdy_i          (1'b1)
);
re_bfu u_bfu_core3 (
    .clk            (clk),
    .rstn           (rstn),
    
    .sys_mode_in    (sys_mode),
    .bfu_mode_in    (bfu_mode),
    .polyqround_in  (polyqround),
	.bfu_sel_const_in(bfu_sel_const),
    .bfu_const_in   (bfu_const),
    .symbreak_result(symbreak_result),
    
    .a_i            (v3_pre_permut[31:0  ]),
    .b_i            (v3_pre_permut[63:32 ]),
    .c_i            (v3_pre_permut[95:64 ]),
    .d_i            (v3_pre_permut[127:96]),
    .w0_i           (w0[3]),
    .w1_i           (w1[3]),
    
    .vld_i          (bfu_vld_i),
    .rdy_o          (bfu_rdy_o[3]),
    
    .Xre            (Xre[3]),
    .Xim            (Xim[3]),
    .divisor        (divisor[3]),
    
    .a_o            (bfu_v3_o[0]),
    .b_o            (bfu_v3_o[1]),
    .c_o            (bfu_v3_o[2]),
    .d_o            (bfu_v3_o[3]),
    .vld_o        	(bfu_vld_o[3]),
    .rdy_i          (1'b1)
);

// bfu cores have valid output
logic bfu_core_vld_o;
assign bfu_core_vld_o = bfu_vld_o[0]
							|    bfu_vld_o[1]
							|    bfu_vld_o[2]
							|    bfu_vld_o[3];

logic [127:0] av0_post_permut;
logic [127:0] bv0_post_permut;
logic [127:0] av1_post_permut;
logic [127:0] bv1_post_permut;

out_permut_network u_out_permut_network (
    .v0    ({bfu_v0_o[3],bfu_v0_o[2],bfu_v0_o[1],bfu_v0_o[0]}),
    .v1    ({bfu_v1_o[3],bfu_v1_o[2],bfu_v1_o[1],bfu_v1_o[0]}),
    .v2    ({bfu_v2_o[3],bfu_v2_o[2],bfu_v2_o[1],bfu_v2_o[0]}),
    .v3    ({bfu_v3_o[3],bfu_v3_o[2],bfu_v3_o[1],bfu_v3_o[0]}),
    .sel   (out_permut_sel),
    .out0  (av0_post_permut),
    .out1  (bv0_post_permut),
    .out2  (av1_post_permut),
    .out3  (bv1_post_permut)
);

// sym-break
logic [`VEC_BITS-1:0] symbreak_v0;
logic [`VEC_BITS-1:0] symbreak_v1;

// from gf2cf (madd)
assign symbreak_v0 = av0_post_permut;
assign symbreak_v1 = av1_post_permut;

symbreak u_symbreak (
    .clk,
    .rstn,
    .vld_i(bfu_core_vld_o),
    .symbreak_en,
    .v0(symbreak_v0),
    .v1(symbreak_v1),
    .symbreak_result
);

// msum
wire msum_vld_i = (bfu_mode==`BFU_MMAC_MODE) && bfu_core_vld_o;
msum4 #(31) u_msum4 (
    .clk,
    .rstn,
    .security_level,
    .d_i_0(bfu_v0_o[2]),
    .d_i_1(bfu_v1_o[2]),
    .d_i_2(bfu_v2_o[2]),
    .d_i_3(bfu_v3_o[2]),
    .vld_i(msum_vld_i),
    .msum1,
    .msum2,
    .msum1_vld,
    .msum2_vld
);


// post shifter
logic [127:0] av0_post_shifted, bv0_post_shifted, av1_post_shifted, bv1_post_shifted;

vec_post_shift u_vec_post_shift (
    .v0                (av0_post_permut),
    .v1                (bv0_post_permut),
    .v2                (av1_post_permut),
    .v3                (bv1_post_permut),

    .v0_post_shift_len (a_post_shift_len),
    .v1_post_shift_len (b_post_shift_len),
    .v2_post_shift_len (a_post_shift_len),
    .v3_post_shift_len (b_post_shift_len),
    .post_shift_even,

    .v0_post_shifted   (av0_post_shifted),
    .v1_post_shifted   (bv0_post_shifted),
    .v2_post_shifted   (av1_post_shifted),
    .v3_post_shifted   (bv1_post_shifted)
);

assign bfu_av0_o = av0_post_shifted;
assign bfu_bv0_o = bv0_post_shifted;
assign bfu_av1_o = av1_post_shifted;
assign bfu_bv1_o = bv1_post_shifted;
	
// Output-valid selection depends on bfu_vld_o[0:3] and bfu_mode.
// e.g. when madd, only av0 and av1 are valid.
// when symbreak_calc, depends on symbreak_result
always_comb begin
    bfu_av0_vld_o = bfu_core_vld_o;
    bfu_bv0_vld_o = bfu_core_vld_o;
    bfu_av1_vld_o = bfu_core_vld_o;
    bfu_bv1_vld_o = bfu_core_vld_o;
    case (bfu_mode)
        `BFU_GF2CF_MODE, 
        `BFU_ADD_MODE,
        `BFU_MADD_MODE: begin
            bfu_av0_vld_o = bfu_core_vld_o;
            bfu_bv0_vld_o = 1'b0;
            bfu_av1_vld_o = bfu_core_vld_o;
            bfu_bv1_vld_o = 1'b0;
        end
        `BFU_MSUB_MODE,
        `BFU_MUL_MODE,
        `BFU_MMUL_MODE: begin
            bfu_av0_vld_o = 1'b0;
            bfu_bv0_vld_o = bfu_core_vld_o;
            bfu_av1_vld_o = 1'b0;
            bfu_bv1_vld_o = bfu_core_vld_o;
        end
        `BFU_SUB_MODE: begin
            if (symbreak_calc && (symbreak_result==1'b0)) begin // symbreak_result==1'b0 if false, then do add
                bfu_av0_vld_o = bfu_core_vld_o;
                bfu_bv0_vld_o = 1'b0;
                bfu_av1_vld_o = bfu_core_vld_o;
                bfu_bv1_vld_o = 1'b0;
            end
            else begin
                bfu_av0_vld_o = 1'b0;
                bfu_bv0_vld_o = bfu_core_vld_o;
                bfu_av1_vld_o = 1'b0;
                bfu_bv1_vld_o = bfu_core_vld_o;
            end
        end
        `BFU_DIV_MODE: begin
                bfu_av0_vld_o = 1'b0;
                bfu_bv0_vld_o = 1'b0;
                bfu_av1_vld_o = 1'b0;
                bfu_bv1_vld_o = 1'b0;
        end
    endcase
end

logic [30:0] msum1_r,msum2_r;  // msum*(R3 mod P)
assign msum1_r = bfu_v0_o[3];
assign msum2_r = bfu_v1_o[3];
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) msum1_eq_msum2 <= 1'b0;
    else if (sys_init) msum1_eq_msum2 <= 1'b0;
    else if (vrfy_post_process && bfu_vld_o[0] && (msum1_r==msum2_r)) msum1_eq_msum2 <= 1'b1;
end
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) vrfy_finish <= 1'b0;
    else if (sys_init) vrfy_finish <= 1'b0;
    else if (vrfy_finish==1'b1) vrfy_finish <= 1'b0;
    else if (vrfy_post_process && bfu_vld_o[0]) vrfy_finish <= 1'b1;
end

endmodule
