`include "../defines/defines.sv"

// fetch taskcode
module task_fetcher
(
    input wire clk,
    input wire rstn,
    input wire fetch_en,

    input wire sys_mode,
    input wire sys_init,
    input wire security_level,
    input wire sys_finish,

    output logic [`TC_W-1:0] taskcode,
    output logic taskcode_vld
);

`ifdef USE_ARR_FOR_TC
localparam int taskrom_lines      = 196;
localparam int taskrom_addr_width = $clog2(taskrom_lines);

logic [$clog2(taskrom_lines)-1:0] taskrom_addr;
logic [$clog2(taskrom_lines)-1:0] taskrom_offset_addr;
logic [$clog2(taskrom_lines)-1:0] taskrom_base_addr;

always_comb begin
    case ({sys_mode,security_level})
        2'b00: taskrom_base_addr = 'd0;            // hawk512-sign
        2'b01: taskrom_base_addr = 'd42;           // hawk1024-sign
        2'b10: taskrom_base_addr = 'd86;           // hawk512-vrfy
        default: taskrom_base_addr = 'd140;        // hawk1024-vrfy
    endcase
end
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) taskrom_offset_addr <= 'd0;
    else if (sys_init) taskrom_offset_addr <= 'd0;
    else if (sys_finish) taskrom_offset_addr <= 'd195;  // NOP
    else if (fetch_en) taskrom_offset_addr <= taskrom_offset_addr + 'd1;
end
assign taskrom_addr = taskrom_base_addr + taskrom_offset_addr;

`else
localparam int taskrom_lines      = 63;
localparam int taskrom_addr_width = $clog2(taskrom_lines);

logic [$clog2(taskrom_lines)-1:0] taskrom_addr;

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) taskrom_addr <= 'd0;
    else if (sys_init) taskrom_addr <= 'd0;
    else if (fetch_en) taskrom_addr <= taskrom_addr + 'd1;
end
`endif

`ifdef USE_ARR_FOR_TC
taskmem_arr  #(
    .MEM_SIZE   (taskrom_lines),  // num of lines
    .DATA_WIDTH (`TC_W),
    .ADDR_WIDTH (taskrom_addr_width)
) taskcode_rom (
    .clk   (clk),
    .en    (fetch_en),
    .addr  (taskrom_addr),
    .dout  (taskcode)
);

`else

`ifdef FPGA_SYN
blk_mem_gen_2 taskcode_rom (
  .clka		(clk),
  .ena		(fetch_en),
  .addra	(taskrom_addr),
  .douta	(taskcode)
);
`else
sim_sprom_coreoutreg #(
    .MEM_SIZE   (taskrom_lines),  // num of lines
    .DATA_WIDTH (`TC_W),
    .ADDR_WIDTH (taskrom_addr_width)

`ifdef TEST_SIGN_512
    ,.INIT_FILE  ("hex_taskcode_sign_512.mem")
`endif
`ifdef TEST_VRFY_512
    ,.INIT_FILE  ("hex_taskcode_vrfy_512.mem")
`endif
`ifdef TEST_SIGN_1024
    ,.INIT_FILE  ("hex_taskcode_sign_1024.mem")
`endif
`ifdef TEST_VRFY_1024
    ,.INIT_FILE  ("hex_taskcode_vrfy_1024.mem")
`endif

) taskcode_rom (
    .clka   (clk),
    .ena    (fetch_en),
    .addra  (taskrom_addr),
    .douta  (taskcode)
);
`endif  // ifdef FPGA_SYN

`endif  // ifdef USE_ARR_FOR_TC

dffre_pipe #(
	.WIDTH(1),
`ifdef USE_ARR_FOR_TC
	.DELAY(1)
`else
	.DELAY(2)  // task ROM use core output register
`endif
) u_dffre_pipe_taskcode_vld (
	.clk,
	.rstn,
	.en(1'b1),
	.d(fetch_en),
	.q(taskcode_vld)
);

endmodule

