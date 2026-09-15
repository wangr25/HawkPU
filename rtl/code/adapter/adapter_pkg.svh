package adapter_pkg;
    
  localparam int unsigned ROW_BW = 512;
  typedef logic [ROW_BW      -1:0] row_data_t;

  localparam int unsigned VEC_BW = 32; 
  typedef logic [VEC_BW-1:0] vect_t;
  localparam int unsigned VEC_PER_ROW = 16;
  typedef logic [VEC_PER_ROW-1:0][VEC_BW-1:0] row_data_pack_t;

  typedef logic [9:0] buff_addr_t;

  localparam int adw_buff_rd_latency = 3;

 
endpackage