module hawk_inv_2round_datapath #(
  parameter int M = 31,
  parameter int N = 32,
  parameter int B1  = 2147473409,
  parameter int B2  = 2147389441
 )(
  input  logic         clk,
  input  logic         en,
  input  logic [M-1:0] x_in,
  input  logic         B_mode,
  input  logic         in_sel,  // 0-from input,  1-from inner
  output logic [N-1:0] q_out
);

 //this module is to calculate the inversion of x_in mod B



	logic signed [N  :0] x1 [M+1:0];

	logic signed [N  :0] y1 [M+1:0];

	logic signed [N-1:0] x3 [M+1:0];

	logic signed [N-1:0] y3 [M+1:0];



	wire [M-1:0] B_in = B_mode ? B2 : B1;



	assign x1[0] = in_sel ? x1[M+1] : 'd1;
	assign y1[0] = in_sel ? y1[M+1] : 'd0;
	assign x3[0] = in_sel ? x3[M+1] : x_in;
	assign y3[0] = in_sel ? y3[M+1] : B_in;



	 
	 genvar i;

	 generate
	 	  for(i=0;i<M;i=i+1) begin

	 	  	hawk_inv_core  u_inv_core
	 	  	(
	  			.clk    (	clk			),
	  			.B_mode (	B_mode 		),
	  			.en 	(	en       	),
	  			.x1_in	(	x1[i]		),
	  			.y1_in	(	y1[i]		),
	  			.x3_in	(	x3[i]		),
	  			.y3_in	(	y3[i]		),
	  			.x1_out	(	x1[i+1]		),
	  			.y1_out	(	y1[i+1]		),
	  			.x3_out	(	x3[i+1]		),
	  			.y3_out	(	y3[i+1]		)
	 	  	);
	 	  end
	 endgenerate

  always_ff @(posedge clk) begin
    if (en) begin
      x1[M+1] <= x1[M];
      y1[M+1] <= y1[M];
      x3[M+1] <= x3[M];
      y3[M+1] <= y3[M];
    end
  end
 	

	inv_postprocess  u_post
	(
  		.res           (y1[M]),
  		.B_mode        (B_mode),
  		.unsigned_res  (q_out)
	);

endmodule

module hawk_inv_core #(
  parameter int X1 = 32,
  parameter int X3 = 32,
  parameter int B1  = 2147473409,
  parameter int B2  = 2147389441
) (
  input  logic                 clk,
  input  logic                 en,
  input  logic                 B_mode,
  input  logic signed [X1  :0] x1_in,
  input  logic signed [X1  :0] y1_in,
  input  logic signed [X3-1:0] x3_in,
  input  logic signed [X3-1:0] y3_in,
  output logic signed [X1  :0] x1_out,
  output logic signed [X1  :0] y1_out,
  output logic signed [X3-1:0] x3_out,
  output logic signed [X3-1:0] y3_out
);


 wire [30:0] B_val = B_mode ? B2 : B1;

  logic s;

  assign s = x3_in[0] & y3_in[0];

  logic signed [X3:0] subres;

  assign subres = x3_in - y3_in;

  logic negflag;

  assign negflag = subres < 0;

  logic [X3-1:0] subres_abs;

  assign subres_abs = negflag ? -subres : subres;

  logic signed [X1 :0] x1swap, y1swap;

  logic signed [X3-1:0] y3swap;

  always_comb begin
    if (negflag & s) begin
      x1swap = y1_in;
      y1swap = x1_in;
      y3swap = x3_in;
    end else begin
      x1swap = x1_in;
      y1swap = y1_in;
      y3swap = y3_in;
    end
  end

  logic signed [X3-1:0] x3calc;

  assign x3calc = s ? subres_abs : x3_in;

  logic signed [X1+1:0] x1calc;

  assign x1calc = x1swap - (s ? y1swap : 0);

  logic signed [X1+1:0] B_ext;
  assign B_ext = $signed({1'b0, B_val});

  logic signed [X1+1:0] x1norm;

  always_comb begin
    // when x3 no need div by 2, x1calc already in [0,B)
    x1norm = x1calc;

    if (!x3calc[0]) begin
      if (x1calc[0]) begin
        // odd: c+B is even, and eq to c * inv(2) mod B
        x1norm = (x1calc + B_ext) >>> 1;
      end
      else if (x1calc < 0) begin
        // negative and even: >>1 and map result into [0,B)
        x1norm = (x1calc >>> 1) + B_ext;
      end
      else begin
        // non-negtive and even
        x1norm = x1calc >>> 1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (en) begin
      x1_out <= x1norm;
      x3_out <= x3calc[0] ? x3calc : (x3calc >>> 1);
    end
  end

  always_ff @(posedge clk)
    if (en) begin
      y1_out <= y1swap;
      y3_out <= y3swap;
    end

endmodule



module inv_postprocess #(
  parameter int X1 = 32,
  parameter int B1 = 2147473409,
  parameter int B2 = 2147389441
) (

  input  logic signed [X1  :0] res,
  input  logic        B_mode,
  output logic        [X1-1:0] unsigned_res
);


 	wire [30:0] B_val = B_mode ? B2 : B1;

	always_comb begin
		unsigned_res = res;
		if(res < 0)
			unsigned_res = res + B_val;
		else if(res >= B_val)
			unsigned_res = res - B_val;
	end

endmodule
