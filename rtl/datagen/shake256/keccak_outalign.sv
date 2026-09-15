module keccak_outalign
(
  input                             clk,
  input                             rst_n,
  input                             start,
  input               align_type,
  input         [8:0] wr_num,
  input dg_finish,
  // upstream
  input                             d_i_req,
  output logic                      d_i_rdy,
  input                    [1087:0] d_i,
  // downstream
  output logic                      d_o_req,
  input                             d_o_rdy,
  output logic              [319:0] d_320_o,
  output logic              [127:0] d_128_o
);

  wire d_i_vld = d_i_req & d_i_rdy;

  logic active;
  logic grp_token_run;
  logic wr_cnt_en;
  wire grp_token_en = active & wr_cnt_en;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) active <= 1'b0;
    else if (start) active <= 1'b1;
    else if (dg_finish) active <= 1'b0;
  end

  logic ali_cnt_done;

  logic [$clog2(17)-1:0] ali_cnt;

// LCM(136,40) = 680 = 40*17
// LCM(136,16) = 272 = 16*17
  //counter_ce
  counter_ce_cntclear
  #(
    .BW($bits(ali_cnt))
  ) i_ali_cnt (
    .clk,
    .rst_n,
    .start (start | ali_cnt_done), // i
    .num   (5'd17),          // i [BW-1:0]
    .run   (active & grp_token_run), // i
    .cnt   (ali_cnt),        // o [BW-1:0]
    .cnt_en(),               // o
    .done  (ali_cnt_done)
  );

  counter_ce  // counter with configurable end number
  #(
    .BW(9)
  ) i_wr_cnt (
    .clk,
    .rst_n,
    .start (start),         // i
    .num   (wr_num),        // i [BW-1:0]
    .run   (active & grp_token_run), // i
    .cnt   (),              // o [BW-1:0]
    .cnt_en(wr_cnt_en),     // o
    .done  ()
  );

  always_comb begin
    grp_token_run = grp_token_en && d_o_rdy;
    if (align_type) begin  // 128
      case (ali_cnt)
        5'd00, 5'd08: begin
          grp_token_run = d_i_vld && wr_cnt_en && d_o_rdy;
        end
      endcase
    end else begin  // 320
      case (ali_cnt)
        5'd00, 5'd03, 5'd06, 5'd10, 5'd13: begin
          grp_token_run = d_i_vld && wr_cnt_en && d_o_rdy;
        end
      endcase
    end
  end

  logic [1087:0] align_buff;

  always_ff @(posedge clk) if (d_i_vld & active) align_buff <= d_i;

  shake_align i_shake_align (
    .align_cnt (ali_cnt),
    .align_type(align_type),
    .d_i       (d_i),
    .buff_i    (align_buff),
    .d_320_o,
    .d_128_o
  );

  assign d_o_req   = grp_token_run;

// handshake
  always_comb begin
    d_i_rdy       = 1'b0;
    if (align_type) begin  // 128
      case (ali_cnt)
        5'd00, 5'd08: begin
          d_i_rdy       = grp_token_en && d_o_rdy;
        end
      endcase
    end else begin  // 320
      case (ali_cnt)
        5'd00, 5'd03, 5'd06, 5'd10, 5'd13: begin
          d_i_rdy       = grp_token_en && d_o_rdy;
        end
      endcase
    end
  end

endmodule

// align_type:
// 0 - 320 bits out, for gen(x)
// 1 - 128 bits out, for gen(t)
module shake_align (
  input        [   4:0] align_cnt,
  input                 align_type,  // 1 for 128, 0 for shake 320
  input        [1087:0] d_i,
  input        [1087:0] buff_i,
  output logic [ 319:0] d_320_o,
  output logic [ 127:0] d_128_o
);

  logic [319:0] data_320;
  logic [127:0] data_128;

  always_comb begin
    data_128 = 'x;
    case (align_cnt)
      5'd00: data_128 = d_i[127:0];
      5'd01: data_128 = buff_i[255:128];
      5'd02: data_128 = buff_i[383:256];
      5'd03: data_128 = buff_i[511:384];
      5'd04: data_128 = buff_i[639:512];
      5'd05: data_128 = buff_i[767:640];
      5'd06: data_128 = buff_i[895:768];
      5'd07: data_128 = buff_i[1023:896];
      5'd08: data_128 = {d_i[63:0], buff_i[1087:1024]};  // 64 + 64
      5'd09: data_128 = buff_i[191:64];
      5'd10: data_128 = buff_i[319:192];
      5'd11: data_128 = buff_i[447:320];
      5'd12: data_128 = buff_i[575:448];
      5'd13: data_128 = buff_i[703:576];
      5'd14: data_128 = buff_i[831:704];
      5'd15: data_128 = buff_i[959:832];
      5'd16: data_128 = buff_i[1087:960];
    endcase
  end

  always_comb begin
    data_320 = 'x;
    case (align_cnt)
      5'd00: data_320 = d_i[319:0];
      5'd01: data_320 = buff_i[639:320];
      5'd02: data_320 = buff_i[959:640];
      5'd03: data_320 = {d_i[191:0], buff_i[1087:960]};  // 192 + 128
      5'd04: data_320 = buff_i[511:192];
      5'd05: data_320 = buff_i[831:512];
      5'd06: data_320 = {d_i[63:0], buff_i[1087:832]};  // 64 + 256
      5'd07: data_320 = buff_i[383:64];
      5'd08: data_320 = buff_i[703:384];
      5'd09: data_320 = buff_i[1024:704];
      5'd10: data_320 = {d_i[255:0], buff_i[1087:1024]}; // 256 + 64
      5'd11: data_320 = buff_i[575:256];
      5'd12: data_320 = buff_i[895:576];
      5'd13: data_320 = {d_i[127:0], buff_i[1087:896]};  // 128 + 192
      5'd14: data_320 = buff_i[447:128];
      5'd15: data_320 = buff_i[767:448];
      5'd16: data_320 = buff_i[1087:768];
    endcase
  end

assign d_320_o = data_320;
assign d_128_o = data_128;

endmodule
