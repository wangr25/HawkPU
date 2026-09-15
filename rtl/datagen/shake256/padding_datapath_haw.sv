module padding_datapath_haw (
  input        [  2:0] pad_type,
  input        [  5:0] addr,
  input        [511:0] data_i,
  output logic [511:0] data_o
);
  localparam bit [2:0] ONLY_TOP = 3'b000;
  localparam bit [2:0] ONLY_TAIL = 3'b001;
  localparam bit [2:0] TOP_TAIL_ROW1 = 3'b010;
  localparam bit [2:0] TOP_TAIL_ROW2 = 3'b011;

  wire pad_top = (pad_type == ONLY_TOP) | (pad_type == TOP_TAIL_ROW1) | (pad_type == TOP_TAIL_ROW2);
  wire pad_tail = (pad_type == ONLY_TAIL) | (pad_type == TOP_TAIL_ROW1) | (pad_type == TOP_TAIL_ROW2);

  always_comb begin
    data_o = data_i;
    if (pad_top) data_o[63] = 1'b1;
    if (pad_tail) data_o[addr*8+:5] = 5'b11111;
  end

endmodule
