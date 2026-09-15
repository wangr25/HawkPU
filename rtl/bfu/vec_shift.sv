// left shift only
module vec_pre_shift (
    input  logic [127:0] av0,
    input  logic [127:0] av1,
    input  logic [127:0] bv0,
    input  logic [127:0] bv1,

    input  logic [4:0]   a_pre_shift_len,
    input  logic [4:0]   b_pre_shift_len,

    output logic [127:0] av0_pre_shifted,
    output logic [127:0] bv0_pre_shifted,
    output logic [127:0] av1_pre_shifted,
    output logic [127:0] bv1_pre_shifted
);

    // ==== av0 ====
    logic [31:0] av0_e0, av0_e1, av0_e2, av0_e3;
    logic [31:0] av0_s0, av0_s1, av0_s2, av0_s3;

    assign av0_e0 = av0[127:96];
    assign av0_e1 = av0[95:64];
    assign av0_e2 = av0[63:32];
    assign av0_e3 = av0[31:0];

    assign av0_s0 = av0_e0 << a_pre_shift_len;
    assign av0_s1 = av0_e1 << a_pre_shift_len;
    assign av0_s2 = av0_e2 << a_pre_shift_len;
    assign av0_s3 = av0_e3 << a_pre_shift_len;

    assign av0_pre_shifted = {av0_s0, av0_s1, av0_s2, av0_s3};

    // ==== av1 ====
    logic [31:0] av1_e0, av1_e1, av1_e2, av1_e3;
    logic [31:0] av1_s0, av1_s1, av1_s2, av1_s3;

    assign av1_e0 = av1[127:96];
    assign av1_e1 = av1[95:64];
    assign av1_e2 = av1[63:32];
    assign av1_e3 = av1[31:0];

    assign av1_s0 = av1_e0 << a_pre_shift_len;
    assign av1_s1 = av1_e1 << a_pre_shift_len;
    assign av1_s2 = av1_e2 << a_pre_shift_len;
    assign av1_s3 = av1_e3 << a_pre_shift_len;

    assign av1_pre_shifted = {av1_s0, av1_s1, av1_s2, av1_s3};

    // ==== bv0 ====
    logic [31:0] bv0_e0, bv0_e1, bv0_e2, bv0_e3;
    logic [31:0] bv0_s0, bv0_s1, bv0_s2, bv0_s3;

    assign bv0_e0 = bv0[127:96];
    assign bv0_e1 = bv0[95:64];
    assign bv0_e2 = bv0[63:32];
    assign bv0_e3 = bv0[31:0];

    assign bv0_s0 = bv0_e0 << b_pre_shift_len;
    assign bv0_s1 = bv0_e1 << b_pre_shift_len;
    assign bv0_s2 = bv0_e2 << b_pre_shift_len;
    assign bv0_s3 = bv0_e3 << b_pre_shift_len;

    assign bv0_pre_shifted = {bv0_s0, bv0_s1, bv0_s2, bv0_s3};

    // ==== bv1 ====
    logic [31:0] bv1_e0, bv1_e1, bv1_e2, bv1_e3;
    logic [31:0] bv1_s0, bv1_s1, bv1_s2, bv1_s3;

    assign bv1_e0 = bv1[127:96];
    assign bv1_e1 = bv1[95:64];
    assign bv1_e2 = bv1[63:32];
    assign bv1_e3 = bv1[31:0];

    assign bv1_s0 = bv1_e0 << b_pre_shift_len;
    assign bv1_s1 = bv1_e1 << b_pre_shift_len;
    assign bv1_s2 = bv1_e2 << b_pre_shift_len;
    assign bv1_s3 = bv1_e3 << b_pre_shift_len;

    assign bv1_pre_shifted = {bv1_s0, bv1_s1, bv1_s2, bv1_s3};

endmodule

// signed right shift only

module vec_post_shift (
    input  logic [127:0] v0,
    input  logic [127:0] v1,
    input  logic [127:0] v2,
    input  logic [127:0] v3,

    input  logic [4:0]   v0_post_shift_len,
    input  logic [4:0]   v1_post_shift_len,
    input  logic [4:0]   v2_post_shift_len,
    input  logic [4:0]   v3_post_shift_len,

    // shift only even elements(0,2) in each vector, used in ifft
    input  logic         post_shift_even,

    output logic [127:0] v0_post_shifted,
    output logic [127:0] v1_post_shifted,
    output logic [127:0] v2_post_shifted,
    output logic [127:0] v3_post_shifted
);

    logic [4:0]   v0_post_shift_len_inner;
    logic [4:0]   v1_post_shift_len_inner;
    logic [4:0]   v2_post_shift_len_inner;
    logic [4:0]   v3_post_shift_len_inner;

    assign   v0_post_shift_len_inner = v0_post_shift_len;
    assign   v1_post_shift_len_inner = post_shift_even ? 'd0 : v1_post_shift_len;
    assign   v2_post_shift_len_inner = v2_post_shift_len;
    assign   v3_post_shift_len_inner = post_shift_even ? 'd0 : v3_post_shift_len;


    // ==== v0 ====
    logic signed [31:0] v0_e0, v0_e1, v0_e2, v0_e3;
    logic signed [31:0] v0_s0, v0_s1, v0_s2, v0_s3;

    assign v0_e0 = v0[127:96];
    assign v0_e1 = v0[95:64];
    assign v0_e2 = v0[63:32];
    assign v0_e3 = v0[31:0];

    assign v0_s0 = v0_e0 >>> v0_post_shift_len_inner;
    assign v0_s1 = v0_e1 >>> v0_post_shift_len_inner;
    assign v0_s2 = v0_e2 >>> v0_post_shift_len_inner;
    assign v0_s3 = v0_e3 >>> v0_post_shift_len_inner;

    assign v0_post_shifted = {v0_s0, v0_s1, v0_s2, v0_s3};

    // ==== v1 ====
    logic signed [31:0] v1_e0, v1_e1, v1_e2, v1_e3;
    logic signed [31:0] v1_s0, v1_s1, v1_s2, v1_s3;

    assign v1_e0 = v1[127:96];
    assign v1_e1 = v1[95:64];
    assign v1_e2 = v1[63:32];
    assign v1_e3 = v1[31:0];

    assign v1_s0 = v1_e0 >>> v1_post_shift_len_inner;
    assign v1_s1 = v1_e1 >>> v1_post_shift_len_inner;
    assign v1_s2 = v1_e2 >>> v1_post_shift_len_inner;
    assign v1_s3 = v1_e3 >>> v1_post_shift_len_inner;

    assign v1_post_shifted = {v1_s0, v1_s1, v1_s2, v1_s3};

    // ==== v2 ====
    logic signed [31:0] v2_e0, v2_e1, v2_e2, v2_e3;
    logic signed [31:0] v2_s0, v2_s1, v2_s2, v2_s3;

    assign v2_e0 = v2[127:96];
    assign v2_e1 = v2[95:64];
    assign v2_e2 = v2[63:32];
    assign v2_e3 = v2[31:0];

    assign v2_s0 = v2_e0 >>> v2_post_shift_len_inner;
    assign v2_s1 = v2_e1 >>> v2_post_shift_len_inner;
    assign v2_s2 = v2_e2 >>> v2_post_shift_len_inner;
    assign v2_s3 = v2_e3 >>> v2_post_shift_len_inner;

    assign v2_post_shifted = {v2_s0, v2_s1, v2_s2, v2_s3};

    // ==== v3 ====
    logic signed [31:0] v3_e0, v3_e1, v3_e2, v3_e3;
    logic signed [31:0] v3_s0, v3_s1, v3_s2, v3_s3;

    assign v3_e0 = v3[127:96];
    assign v3_e1 = v3[95:64];
    assign v3_e2 = v3[63:32];
    assign v3_e3 = v3[31:0];

    assign v3_s0 = v3_e0 >>> v3_post_shift_len_inner;
    assign v3_s1 = v3_e1 >>> v3_post_shift_len_inner;
    assign v3_s2 = v3_e2 >>> v3_post_shift_len_inner;
    assign v3_s3 = v3_e3 >>> v3_post_shift_len_inner;

    assign v3_post_shifted = {v3_s0, v3_s1, v3_s2, v3_s3};

endmodule
