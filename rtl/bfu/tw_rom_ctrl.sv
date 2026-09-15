`include "../defines/defines.sv"

module tw_rom_ctrl (

	input logic clk,
	input logic rstn,
	input logic sys_mode,			// 0-sign, 1-vrfy
	input logic security_level,
	input logic [1:0] tw_rom_mode,		// 00-fft, 01-ntt, 10-ifft, 11-intt
	input logic polyqround,
	input logic tw_rom_start,
	input logic tw_rom_en,
	// to tw_rom
	output logic [10:0] tw_rom_ptr,
    output logic [1:0] tw_rom_strb,
	output logic [1:0] tw_rom_pat_grp,
	output logic [1:0] tw_rom_pat_sel
               	
);

localparam NTT_P1_BASE_PTR  = 'd0		;		// NTT in vrfy
localparam NTT_P2_BASE_PTR  = 'd512		;		// NTT in vrfy
localparam FFT_BASE_PTR     = 'd1024	;		// FFT/IFFT in vrfy
localparam NTT_P0_BASE_PTR  = 'd1536  	;		// NTT/INTT in sign

logic [10:0] tw_cnt;
logic [10:0] tw_invcnt;
always_comb begin
	// default value
	tw_rom_ptr = FFT_BASE_PTR + tw_cnt;
	case (tw_rom_mode)
		2'b00: tw_rom_ptr = FFT_BASE_PTR + tw_cnt;
		2'b01: begin
			if (sys_mode==0) begin		// NTT in sign
				tw_rom_ptr = NTT_P0_BASE_PTR + tw_cnt;
			end
			else begin					// NTT in vrfy
				if (polyqround==0) begin
					tw_rom_ptr = NTT_P1_BASE_PTR + tw_cnt;
				end
				else begin
					tw_rom_ptr = NTT_P2_BASE_PTR + tw_cnt;
				end
			end
		end
		2'b10: tw_rom_ptr = FFT_BASE_PTR + tw_invcnt;
		2'b11: tw_rom_ptr = NTT_P0_BASE_PTR + tw_invcnt;
	endcase
end

logic [3:0] tw_stage;
logic [3:0] tw_cnt_stage;
logic [3:0] tw_invcnt_stage;

logic tw_rom_mode_bit1;
assign tw_rom_mode_bit1 = tw_rom_mode[1];

assign tw_stage = tw_rom_mode_bit1 ? tw_invcnt_stage : tw_cnt_stage;

// access tw rom for fft/ntt
logic        tw_cnt_start;
logic        tw_cnt_finish;
logic        tw_cnt_busy;

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		tw_cnt_start <= 1'b0; 
	end else if (tw_rom_en && tw_rom_start && (tw_rom_mode_bit1==1'b0)) begin
		tw_cnt_start <= 1'b1;
	end else if (tw_rom_en && (tw_cnt_start == 1'b1)) begin
		tw_cnt_start <= 1'b0;
	end
end

counter_tw u_counter_tw (
    .clk            (clk),
    .rstn           (rstn),
    .en             (tw_rom_en),
    .start          (tw_cnt_start),
    .security_level (security_level),
    .tw_ntt_mode    (tw_rom_mode[0]),	// 0-fft, 1-ntt
    .tw_cnt         (tw_cnt),
	.tw_cnt_stage   (tw_cnt_stage),
    .tw_cnt_finish  (tw_cnt_finish),
    .tw_cnt_busy    (tw_cnt_busy)
);

// access tw rom for ifft/intt
logic        tw_invcnt_start;
logic        tw_invcnt_finish;
logic        tw_invcnt_busy;

always_ff @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		tw_invcnt_start <= 1'b0; 
	end else if (tw_rom_en && tw_rom_start && (tw_rom_mode_bit1==1'b1)) begin
		tw_invcnt_start <= 1'b1;
	end else if (tw_rom_en && (tw_invcnt_start == 1'b1)) begin
		tw_invcnt_start <= 1'b0;
	end
end

invcounter_tw u_invcounter_tw (
    .clk            (clk),
    .rstn           (rstn),
    .en             (tw_rom_en),
    .start          (tw_invcnt_start),
    .security_level (security_level),
    .tw_intt_mode    (tw_rom_mode[0]),	// 0-ifft, 1-intt
    .tw_invcnt         (tw_invcnt),
	.tw_invcnt_stage   (tw_invcnt_stage),
    .tw_invcnt_finish  (tw_invcnt_finish),
    .tw_invcnt_busy    (tw_invcnt_busy)
);



// gen strb

always_comb begin
	// default value
	tw_rom_strb = 2'b11;
	case (sys_mode)
		1'b0: begin
			case (tw_rom_mode_bit1)
				1'b0: tw_rom_strb = 2'b01;		// ntt
				1'b1: tw_rom_strb = 2'b10;		// intt
			endcase
		end
		1'b1: begin
			tw_rom_strb = 2'b11;
		end
	endcase
end

// gen pat_grp

always_ff @(posedge clk) begin
	case (security_level)
		1'b0: begin
			case (tw_stage)
				'd8: tw_rom_pat_grp     <= 2'b10;
				'd7: tw_rom_pat_grp     <= 2'b01;
				default: tw_rom_pat_grp <= 2'b00;
			endcase
		end
		1'b1: begin
			case (tw_stage)
				'd9: tw_rom_pat_grp     <= 2'b10;
				'd8: tw_rom_pat_grp     <= 2'b01;
				default: tw_rom_pat_grp <= 2'b00;
			endcase
		end
	endcase
end

always_ff @(posedge clk) begin
	tw_rom_pat_sel <= tw_rom_ptr[1:0];
end

endmodule

