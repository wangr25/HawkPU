module padding_control
(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic       [11:0] src_addr,
  input  logic       [11:0] src_length,
  input  logic       [ 6:0] keccak_valid_byte,
  input  logic       [ 1:0] pad_append_row,
  input  logic       [ 6:0] read_blocks,
  output logic              first,
  output logic              last,
  output logic              mode,
  output logic              pad_choose,
  output logic       [ 2:0] pad_type,
  output logic              buf_update,
  output logic              buf_vld,
  output logic       [ 1:0] buf_index,
  output logic              buff_rd_en,
  output logic              keccak_rdy,
  output logic              pad_null,
  output logic       [11:0] buff_rd_addr
);

  typedef enum {
    IDLE,
    READ_FIRST,
    READ_SECOND,
    READ_THIRD,
    PAD_FIRST,
    PAD_SECOND,
    PAD_THIRD
  } fsm_state_t;

  localparam bit [2:0] ONLY_TOP = 3'b000;
  localparam bit [2:0] ONLY_TAIL = 3'b001;
  localparam bit [2:0] TOP_TAIL_ROW1 = 3'b010;
  localparam bit [2:0] TOP_TAIL_ROW2 = 3'b011;

  fsm_state_t state, state_nxt;

  wire pad_en = (state != IDLE);
  logic pad_done;
  wire equl_zero = (keccak_valid_byte == '0);

  wire [6:0] len_base = src_length;

  wire rowfull = (keccak_valid_byte == 7'b100_0000);
  wire zero2one = (pad_append_row == 2'b01);
  wire one2two = (pad_append_row == 2'b10);
  wire two2three = (pad_append_row == 2'b00) & (~equl_zero);

  logic [1:0] mes_cnt;
  logic [1:0] mes_cnt_nxt;
  logic [11:0] mes_sum;
  logic [11:0] mes_sum_nxt;
  logic read_done_i;
  wire mes_cnt_done = (mes_cnt_nxt == 2'd3);
  wire read_done_flag = (mes_sum_nxt == read_blocks) & mes_cnt_done;
  wire short = (read_blocks == '0);
  logic restore;
  always_ff @(posedge clk) begin
    if (start) buf_vld <= 1'b0;
    else if (buf_vld & keccak_rdy) buf_vld <= 1'b0;
    else if (mes_cnt_done & ~pad_done) buf_vld <= 1'b1;
  end

  always_ff @(posedge clk) begin
    if (start) read_done_i <= 1'b0;
    else if (read_done_flag) read_done_i <= 1'b1;
  end
  wire read_done = read_done_i | read_done_flag;

  assign mes_cnt_nxt = mes_cnt + 1'd1;
  always_ff @(posedge clk) begin
    if (start | mes_cnt_done) mes_cnt <= '0;
    else if (pad_en) mes_cnt <= mes_cnt_nxt;
  end
  assign mes_sum_nxt = mes_sum + 1'd1;
  always_ff @(posedge clk) begin
    if (start) mes_sum <= '0;
    else if (buf_vld & keccak_rdy) mes_sum <= mes_sum_nxt;
  end

  always_ff @(posedge clk) begin
    if (start) first <= '0;
    else first <= (mes_sum == 12'd0);
  end
  always_ff @(posedge clk) begin
    if (start) last <= '0;
    else if (short) last <= (mes_sum == 12'd0);
    else last <= (mes_sum == read_blocks);
  end

  always_ff @(posedge clk) begin
    if (!rst_n) pad_done <= 1'b0;
    if (start) pad_done <= 1'b0;
    else if (mes_cnt_done & pad_en & ((state == PAD_THIRD) | (state == PAD_SECOND)))
      pad_done <= 1'b1;
  end

  always_ff @(posedge clk) begin
    if (start) mode <= 1'b0;
    else if (pad_done & buf_vld & keccak_rdy) mode <= 1'b1;
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= state_nxt;
  end

  always_comb begin
    state_nxt = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (short) state_nxt = PAD_FIRST;
          else state_nxt = READ_FIRST;
        end else if (restore) begin
          if (read_done) state_nxt = PAD_FIRST;
          else state_nxt = READ_FIRST;
        end
      end
      READ_FIRST:    state_nxt = READ_SECOND;
      READ_SECOND:   state_nxt = READ_THIRD;
      READ_THIRD: begin
        if (!keccak_rdy) state_nxt = IDLE;
        else if (!read_done) state_nxt = READ_FIRST;
        else state_nxt = PAD_FIRST;
      end
      PAD_FIRST:     state_nxt = PAD_SECOND;
      PAD_SECOND:    state_nxt = PAD_THIRD;
      PAD_THIRD: begin
        if (!pad_done & keccak_rdy) state_nxt = PAD_FIRST;
        else state_nxt = IDLE;
      end
    endcase
  end

  always_comb begin
    pad_choose = 1'b0;
    pad_type   = ONLY_TAIL;
    case (state)
      PAD_FIRST: if (equl_zero | (zero2one & (~rowfull))) pad_choose = 1'b1;
      PAD_SECOND: begin
        if (zero2one & rowfull) begin
          pad_choose = 1'b1;
        end else if (one2two & (~rowfull)) begin
          pad_choose = 1'b1;
        end
      end
      PAD_THIRD: begin
        if (rowfull & one2two) begin
          pad_choose = 1'b1;
          pad_type   = TOP_TAIL_ROW2;
        end else if (two2three) begin
          pad_choose = 1'b1;
          pad_type   = TOP_TAIL_ROW1;
        end else if (~two2three) begin
          pad_choose = 1'b1;
          pad_type   = ONLY_TOP;
        end
      end
    endcase
  end

  logic [11:0] addr_sum;
  logic [11:0] addr_sum_nxt;

  assign addr_sum_nxt = addr_sum + 12'd1;
  always_ff @(posedge clk) begin
    if (start) addr_sum <= '0;
    else if (pad_en) addr_sum <= addr_sum_nxt;
  end
  assign buff_rd_addr = addr_sum + src_addr;

  assign buff_rd_en   = pad_en & (addr_sum < len_base);
  assign pad_null     = pad_en & (addr_sum >= len_base);

  assign buf_index = pad_en ? mes_cnt : 'x;
  assign buf_update = pad_en & ~pad_done;
  keccak_state_haw i_keccas_state (
    .clk,
    .rst_n,
    .start,
    .pad_done,
    .buf_vld,
    .mes_cnt_done,
    .keccak_rdy,
    .restore
  );

endmodule

module keccak_state_haw (
  input              clk,
  input              rst_n,
  input              start,
  input              pad_done,
  input              buf_vld,
  input              mes_cnt_done,
  output logic       keccak_rdy,
  output             restore
);
  localparam cnt_done = 4'd12;
  logic [3:0] cnt, cnt_nxt;
  logic  cnt_en;

  assign restore               = (cnt == cnt_done - 4'd1) & ~pad_done;
  assign cnt_nxt               = cnt + 4'd1;
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) cnt_en <= 1'b0;
    else if ((mes_cnt_done & keccak_rdy) | (buf_vld & keccak_rdy)) begin
      cnt_en <= 1'b1;
    end else if (cnt_nxt == cnt_done) begin
      cnt_en <= 1'b0;
    end
  end
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) cnt <= 4'd0;
    else if (cnt_en) begin
      if (cnt_nxt == cnt_done) cnt <= 4'd0;
      else cnt <= cnt_nxt;
    end
  end
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) keccak_rdy <= 1'd0;
    else if (start) begin
        keccak_rdy <= 1'b1;
    end else if (buf_vld & (keccak_rdy)) begin
        keccak_rdy <= 1'b0;
    end else if (cnt == cnt_done - 4'd1) keccak_rdy <= 1'b1;
  end

endmodule
