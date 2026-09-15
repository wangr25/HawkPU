`include "../defines/defines.sv"

// receive data from SHAKE256
// and output T0/T1 and c to vec_compare
module sampler(

    input wire clk,
    input wire rstn,

	input wire security_level,
	input wire sampler_en,		// should remain high when performing sampling

	// to upstream
	output wire samp_rdy_o,

    // t
    input wire [3:0] t_in,
    input wire t_vld_i,

    // c from shake
    input wire [319:0] c_in,
    input wire c_vld_i,

    // to cmp
	output logic [77:0] T [12:0],
    output logic [77:0] c_data,
	output logic vld2cmp,

	// from cmp
	input wire cmp_rdy,

	///////////////////////////////

	// to cmp
	output logic rdy2cmp,

	// from cmp
	input logic [12:0] lt_i,
	input logic cmp_vld_i,

	// from downstream
	input logic rdy_i,

	// output sampled vector
	output logic [127:0] vec_out,
	output logic samp_vec_vld_o,
	output logic sample_finish,
	// to control
	output logic [9:0] samp_cnt_o,

	output logic sample_exception

);

////////////////////////////////////////////////
// format:
// choose 1 of 4 input `c`s
// and output it to cmp
////////////////////////////////////////////////

// have output all 4 valid `c`s to cmp
logic fmt_finish;
logic [1:0] fmt_cnt;
logic have;
wire input_dff_en;

pipe_handshake u_pipe_handshake_sample_format (
    .clk(clk),
    .rstn(rstn),
    .vld_i(t_vld_i && c_vld_i),
    .rdy_o(samp_rdy_o),
    .vld_o(),
    .rdy_i(cmp_rdy),
    .finish(fmt_finish),
    .d_en(input_dff_en),
	.have(have)
);

always_ff @(posedge clk or negedge rstn) begin
	if ((!rstn) || (!sampler_en)) begin
		fmt_finish <= 1'b1;
	end
	else if (t_vld_i && c_vld_i && samp_rdy_o) begin
		fmt_finish <= 1'b0;
	end
	else if (fmt_cnt=='d2) begin
		fmt_finish <= 1'b1;
	end
end
		
always_ff @(posedge clk or negedge rstn) begin
	if ((!rstn) || (!sampler_en)) begin
		fmt_cnt <= 'd0;
	end
	else if (fmt_finish) begin
		fmt_cnt <= 'd0;
	end
	else begin
		fmt_cnt <= fmt_cnt + 'd1;
	end
end

always_comb begin
	if (fmt_cnt=='d0) begin
		vld2cmp = have;
	end else begin
		vld2cmp = 1'b1;
	end
end
		
logic [319:0] c;
logic [3:0] t_inner;

always_ff @(posedge clk) begin
	if (input_dff_en) begin
		c <= c_in;
		t_inner <= t_in;
	end
end

logic [14:0] b [0:3];
logic [62:0] a [0:3];
logic [3:0] s;

assign a[0] = c[62:0];
assign a[1] = c[126:64];
assign a[2] = c[190:128];
assign a[3] = c[254:192];
assign s[0] = c[63];
assign s[1] = c[127];
assign s[2] = c[191];
assign s[3] = c[255];
assign b[0] = c[270:256];
assign b[1] = c[286:272];
assign b[2] = c[302:288];
assign b[3] = c[318:304];

logic a_sign;
logic t;

always@(*) begin
	case (fmt_cnt)
		'd0: begin
			c_data = {b[0],a[0]};
			a_sign = s[0];
			t = t_inner[0];
		end
		'd1: begin
			c_data = {b[1],a[1]};
			a_sign = s[1];
			t = t_inner[1];
		end
		'd2: begin
			c_data = {b[2],a[2]};
			a_sign = s[2];
			t = t_inner[2];
		end
		'd3: begin
			c_data = {b[3],a[3]};
			a_sign = s[3];
			t = t_inner[3];
		end
	endcase
end


    logic [77:0] mux_out [12:0]; 
    always_comb begin
		mux_out[0 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h2C058C27920A04F8F267 : 78'h1AFCBC689D9213449DC9) : ((t == 1'b0) ? 78'h2C583AAA2EB76504E560 : 78'h1B7F01AE2B17728DF2DE);
		mux_out[1 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h0E9A1C4FF17C204AA058 : 78'h06EBFB908C81FCE3524F) : ((t == 1'b0) ? 78'h0F1D70E1C03E49BB683E : 78'h07506A00B82C69624C93);
		mux_out[2 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h02DBDE63263BE0098FFD : 78'h01064EBEFD8FF4F07378) : ((t == 1'b0) ? 78'h031955CDA662EF2D1C48 : 78'h01252685DB30348656A4);
		mux_out[3 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h005156AEDFB0876A3BD8 : 78'h0015C628BC6B23887196) : ((t == 1'b0) ? 78'h005E31E874B355421BB7 : 78'h001A430192770E205503);
		mux_out[4 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h0005061E21D588CC61CC : 78'h0000FF769211F07B326F) : ((t == 1'b0) ? 78'h000657C0676C029895A7 : 78'h00015353BD4091AA96DB);
		mux_out[5 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h00002BA568D92EEC18E7 : 78'h00000668F461693DFF8F) : ((t == 1'b0) ? 78'h00003D4D67696E51F820 : 78'h000009915A53D8667BEE);
		mux_out[6 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h000000CF0F8687D3B009 : 78'h0000001670DB65964485) : ((t == 1'b0) ? 78'h0000014A1A8A93F20738 : 78'h00000026670030160D5F);
		mux_out[7 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h0000000216A0C344EB45 : 78'h000000002AB6E11C2552) : ((t == 1'b0) ? 78'h00000003DAF47E8DFB21 : 78'h00000000557CD1C5F797);
		mux_out[8 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h0000000002EDF0B98A84 : 78'h00000000002C253C7E81) : ((t == 1'b0) ? 78'h0000000006634617B3FF : 78'h00000000006965E15B13);
		mux_out[9 ] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h0000000000023AF3B2E7 : 78'h00000000000018C14ABF) : ((t == 1'b0) ? 78'h000000000005DBEFB646 : 78'h00000000000047E9AB38);
		mux_out[10] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h00000000000000EBCC6A : 78'h0000000000000007876E) : ((t == 1'b0) ? 78'h00000000000002F93038 : 78'h000000000000001B2445);
		mux_out[11] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h000000000000000034CF : 78'h0000000000000000013D) : ((t == 1'b0) ? 78'h0000000000000000D5A7 : 78'h000000000000000005AA);
		mux_out[12] = (security_level==1'b0) ? ((t == 1'b0) ? 78'h00000000000000000006 : 78'h00000000000000000000) : ((t == 1'b0) ? 78'h00000000000000000021 : 78'h00000000000000000000);
    end

    always_comb begin
        for (int i = 0; i < 13; i++) begin
            T[i] = mux_out[i];
        end
    end


//////////////////////////////////////////
// update:
// input cmp result
// output vector data
//////////////////////////////////////////

logic update_dff_en;
logic vldu;
logic update_have;

pipe_handshake u_pipe_handshake_sample_update (
    .clk(clk),
    .rstn(rstn),
    .vld_i(cmp_vld_i),
    .rdy_o(rdy2cmp),
    .vld_o(vldu),
    .rdy_i(rdy_i),
    .finish(1'b1),
    .d_en(update_dff_en),
	.have(update_have)
);

logic [12:0] lt;
logic a_sign_q0;
logic t_q0;

always_ff @(posedge clk) begin
	if (update_dff_en) begin
		lt <= lt_i;
		a_sign_q0 <= a_sign;
		t_q0 <= t;
	end
end

	logic [3:0] sum;
	assign sum = {3'b0, lt[0 ]}
				+{3'b0, lt[1 ]}
				+{3'b0, lt[2 ]}
				+{3'b0, lt[3 ]}
				+{3'b0, lt[4 ]}
				+{3'b0, lt[5 ]}
				+{3'b0, lt[6 ]}
				+{3'b0, lt[7 ]}
				+{3'b0, lt[8 ]}
				+{3'b0, lt[9 ]}
				+{3'b0, lt[10]}
				+{3'b0, lt[11]}
				+{3'b0, lt[12]};

	logic [4:0] v_t;
	// 2*sum + t
	assign v_t = t_q0 + ({1'b0,sum}<<1);

	logic [31:0] v;
	always_comb begin
		if (v_t=='0) v = `P0;
		else v = a_sign_q0 ? `P0-v_t : v_t; 
	end

	//////////////////////////////////////////

	logic [31:0] x0,x1,x2,x3;
	logic [1:0] vec_cnt;
	logic [9:0] samp_cnt;		// counter of sampled vectors
	logic [14:0] norm;
	logic [9:0] v_2;			// (unsigned) v*v

	assign v_2 = v_t*v_t;

    always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			vec_cnt <= 'd0;
		end else if (sampler_en && vldu) begin
			vec_cnt <= vec_cnt + 'd1;
		end
    end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			norm <= 'd0;
		end
		else if (sampler_en && vldu) begin
			norm <= norm + v_2;
		end
	end

	always_ff @(posedge clk) begin
		if (sampler_en && vldu) begin
			case (vec_cnt)
				2'b00: x0 <= v;
				2'b01: x1 <= v;
				2'b10: x2 <= v;
				2'b11: x3 <= v;
			endcase
		end
	end

    always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			samp_vec_vld_o <= 1'b0;
			samp_cnt <= '0;
		end else if ((samp_vec_vld_o!=1'b1) && sampler_en && (vec_cnt==2'b11) && rdy2cmp) begin
			samp_vec_vld_o <= 1'b1;
			samp_cnt <= samp_cnt + 'd1;
		end else
			samp_vec_vld_o <= 1'b0;
    end

	assign vec_out = {x3, x2, x1, x0};

	assign samp_cnt_o = samp_cnt;

	assign sample_finish = security_level ? (samp_cnt==512) : (samp_cnt==256);

	assign sample_exception = sample_finish && (norm >= (security_level ? 20218:8316));

endmodule
