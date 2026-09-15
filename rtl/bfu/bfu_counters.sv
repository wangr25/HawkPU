// counters used in control unit

// counter for fft
// reused by ntt
module counter_fft (
    input  logic        clk,
    input  logic        rstn,
    input  logic        security_level,
    input  logic        start,
    input  logic        en,
    output logic [6:0]  idx1,
    output logic [6:0]  idx2,
    output logic [3:0]  stage,
    output logic        finish,
	output logic 		almost_finish,
    output logic        busy_o
);

    // Determine log2(N): if security_level=0 -> log2(64)=6; if =1 -> log2(128)=7
    wire [3:0] log2N = (security_level == 1) ? 4'd7 : 4'd6;

    wire [3:0] real_stages = log2N;  

    // Two extra physical stages are processed after the real FFT stages.
    wire [3:0] phys_stages = real_stages + 4'd2;

    wire [5:0] half_N = 6'd1 << (log2N - 1);

    logic [5:0] i_counter;

    logic        busy;

    // Map idle and extra physical stages to a real FFT stage for indexing:
    //   - When stage==0, we are idle; treat as stage 1 for combinational math
    //   - When stage > real_stages, map it back to real_stages (extra stages repeat last)
    wire [3:0] current_stage_eff;
    assign current_stage_eff = (stage == 4'd0) 
                                ? 4'd1 
                                : ((stage > real_stages) ? real_stages : stage);

    // Compute distance D = N >> current_stage_eff
    // Because D is always a power of two, we extract shift1 = log2(D)
    //   log2(D) = log2N - current_stage_eff
    wire [3:0] shift1 = log2N - current_stage_eff; 

    // Break down i_counter into quotient and remainder w.r.t. D (power-of-two)
    //   quotient = i_counter >> shift1
    //   remainder = i_counter & ( (1<<shift1) - 1 )
    wire [5:0] quotient  = i_counter >> shift1;
    wire [5:0] remainder = (shift1 == 4'd0) 
                            ? 6'd0 
                            : (i_counter & ({6{1'b1}} >> (6 - shift1))); 
    // Explanation: when shift1=0, remainder=0. Otherwise, mask = (1<<shift1)-1 
    // expressed as lower shift1 bits of 6'h3F.

    // Compute idx1 and idx2 for the current pair
    //   idx1 = remainder + (quotient << (shift1 + 1))
    //   idx2 = idx1 + (1 << shift1)
    wire [6:0] temp1 = remainder + (quotient << (shift1 + 1));
    wire [6:0] wire_D = 7'd1 << shift1;
    assign idx1 = temp1;
    assign idx2 = temp1 + wire_D;

    always_ff @ (posedge clk or negedge rstn) begin
        if (!rstn) begin
            stage      <= 4'd0;
            i_counter  <= 6'd0;
            busy       <= 1'b0;
            finish     <= 1'b0;
        end else begin
            finish <= 1'b0;
            if (!busy) begin
                if (start) begin
                    busy      <= 1'b1;
                    stage     <= 4'd1;
                    i_counter <= 6'd0;
                end
            end else begin
                if (en) begin
                    if (i_counter < (half_N - 6'd1)) begin
                        i_counter <= i_counter + 6'd1;
                    end else begin
                        if (stage < phys_stages) begin
                            stage     <= stage + 4'd1;
                            i_counter <= 6'd0;
                        end else begin
                            busy    <= 1'b0;
                            finish  <= 1'b1;
							i_counter <= 6'd0;
                        end
                    end
                end
            end
        end
    end

	assign busy_o = busy;
	assign almost_finish = (stage==phys_stages) && (i_counter==(half_N-6'd1));

endmodule

// counter for ifft
// reused by intt
module counter_ifft (
    input  logic        clk,
    input  logic        rstn,
    input  logic        security_level,
    input  logic        start,
    input  logic        en,
    output logic [6:0]  idx1,
    output logic [6:0]  idx2,
    output logic [3:0]  stage,
    output logic        finish,
	output logic 		almost_finish,
    output logic        busy_o
);

	logic busy;
    logic [3:0] stage_m;

    // Determine log2(N): if security_level=0 -> log2(64)=6; if =1 -> log2(128)=7
    wire [3:0] log2N      = (security_level == 1) ? 4'd7 : 4'd6;

    wire [3:0] real_stages = log2N;

    // Two extra physical stages are processed before the real iFFT stages.
    wire [3:0] phys_stages = real_stages + 4'd2;

    wire [5:0] half_N      = 6'd1 << (log2N - 1);

    logic [5:0] i_counter;

    // Map physical stages to real iFFT stages for index generation:
    //   - When stage <= 3: effective_stage = 1 (repeat real stage 1)
    //   - When stage >= 4: effective_stage = stage - 2
    wire [3:0] effective_stage;
    assign effective_stage = (stage_m <= 4'd3) ? 4'd1 : (stage_m - 4'd2);

    // Compute distance D = 2^(effective_stage - 1)
    // Let R = effective_stage - 1
    wire [3:0] R = effective_stage - 4'd1; 
    wire [6:0] D;
    assign D = 7'd1 << R;

    // Break down i_counter into quotient and remainder w.r.t. D
    // quotient = i_counter >> R
    // remainder = i_counter & (D - 1)
    wire [5:0] quotient  = i_counter >> R;
    wire [5:0] remainder = (R == 4'd0) 
                            ? 6'd0 
                            : (i_counter & ((6'd1 << R) - 6'd1));

    // Compute base address = quotient * (2*D) = quotient << (R + 1)
    // Then idx1 = base + remainder
    //      idx2 = idx1 + D
    wire [6:0] base = quotient << (R + 1);
    assign idx1 = base + remainder;
    assign idx2 = idx1 + D;

    always_ff @ (posedge clk or negedge rstn) begin
        if (!rstn) begin
            stage_m     <= 4'd0;
            i_counter <= 6'd0;
            busy      <= 1'b0;
            finish    <= 1'b0;
        end else begin
            finish <= 1'b0;
            if (!busy) begin
                if (start) begin
                    busy      <= 1'b1;
                    stage_m     <= 4'd1;
                    i_counter <= 6'd0;
                end
            end else begin
                if (en) begin
                    if (i_counter < (half_N - 6'd1)) begin
                        i_counter <= i_counter + 6'd1;
                    end else begin
                        if (stage_m < phys_stages) begin
                            stage_m     <= stage_m + 4'd1;
                            i_counter <= 6'd0;
                        end else begin
                            busy   <= 1'b0;
                            finish <= 1'b1;
                            i_counter <= 6'd0;
                        end
                    end
                end
            end
        end
    end

    assign stage = security_level ? ('d10-stage_m) : ('d9-stage_m);
	assign busy_o = busy;
	assign almost_finish = (stage_m==phys_stages) && (i_counter==(half_N-6'd1));

endmodule


module counter_seq #(
	parameter CNT_WIDTH = 7
)(
    input  logic        			clk,
    input  logic        			rstn,
    input  logic        			start,
    input  logic        			en,
    input  logic [CNT_WIDTH-1:0]	cnt_max,
    output logic [CNT_WIDTH-1:0]	cnt,
    output logic        			almost_finish,
    output logic        			finish
);

    logic counting;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            cnt           <= 'd0;
            counting      <= 1'b0;
            finish        <= 1'b0;
        end
        else begin
            finish <= 1'b0;

            if (start) begin
                cnt      <= 'd0; 
                counting <= 1'b1;
            end
            else if (counting) begin
                if (en && (cnt < cnt_max)) begin
                    cnt <= cnt + 1'b1;
                end
                else if (cnt == cnt_max) begin
                    counting <= 1'b0;
                    finish   <= 1'b1;
                end
            end
        end
    end
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
			almost_finish <= 1'b0;
		end else begin
			almost_finish <= 1'b0;
			if (counting) begin
                if (cnt == cnt_max-1'b1) begin
					almost_finish <= 1'b1;
                end
                else if (cnt == cnt_max) begin
					almost_finish <= 1'b0;
                end
			end
		end
	end
endmodule



module counter_tw (
    input  logic        clk,
    input  logic        rstn,
    input  logic        en,
    input  logic        start,
    input  logic        security_level,
    input  logic        tw_ntt_mode,
    output logic [10:0] tw_cnt,
	output logic [ 3:0] tw_cnt_stage,
    output logic        tw_cnt_finish,
    output logic        tw_cnt_busy
);

    localparam int BASE0      = 32;
    localparam int BASE1      = 64;
    localparam int MAX_STAGE0 = 8;
    localparam int MAX_STAGE1 = 9;

    logic [6:0] base_target;
    int         L;
    int         max_stage;
    int         start_stage;
    int         end_stage;
	logic [10:0]  tw_cnt_initial_value;

    always_comb begin
        base_target  = security_level ? BASE1     : BASE0;
        L            = security_level ? 7         : 6;
        max_stage    = security_level ? MAX_STAGE1 : MAX_STAGE0;
        start_stage  = tw_ntt_mode   ? 0         : 1;
        end_stage    = max_stage;
		tw_cnt_initial_value = tw_ntt_mode ? 'd0 : 'd1;
    end

    logic [3:0] stage;
    logic [6:0] stage_cycle_cnt;
    logic [6:0] inner_cnt;
    logic [3:0] inc;
    logic [6:0] inner_period;
    logic       start_d;

    // Edge detection for start pulse
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) start_d <= 1'b0;
        else if (en) start_d <= start;
    end
    wire start_pulse = start & ~start_d;

    // Determine the twiddle increment schedule from the stage index.
    always_comb begin
        inc          = 1;
        inner_period = 1;
        if (stage == 0) begin
            inner_period = base_target;
            inc          = 1;
        end
        else if (stage >= 1 && stage <= L) begin
            inner_period = (base_target >> (stage-1));
            inc          = 1;
        end
        else if (stage > L && stage <= end_stage) begin
            inner_period = 1;
            inc          = 1 << (stage - L);
        end
    end

    // Main FSM for counting and stage transitions
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            tw_cnt          <= '0;
            tw_cnt_busy     <= 1'b0;
            tw_cnt_finish   <= 1'b0;
            stage           <= 0;
            stage_cycle_cnt <= 0;
            inner_cnt       <= 0;
        end
        else if(en) begin
            tw_cnt_finish <= 1'b0;

            if (!tw_cnt_busy) begin
                if (start_pulse) begin
                    tw_cnt_busy     <= 1'b1;
                    tw_cnt          <= tw_cnt_initial_value;
                    stage           <= start_stage;
                    stage_cycle_cnt <= 0;
                    inner_cnt       <= 0;
                end
            end
            else begin
                if (stage_cycle_cnt < base_target-1) begin
                    stage_cycle_cnt <= stage_cycle_cnt + 1;
                    if (inner_cnt < inner_period-1) begin
                        inner_cnt <= inner_cnt + 1;
                    end else begin
                        inner_cnt <= 0;
                        tw_cnt    <= tw_cnt + inc;
                    end
                end
                else begin
                    if (stage == end_stage) begin
                        tw_cnt_busy   <= 1'b0;
                        tw_cnt_finish <= 1'b1;
                    end else begin
                        stage           <= stage + 1;
                        stage_cycle_cnt <= 0;
                        inner_cnt       <= 0;
                        tw_cnt    <= tw_cnt + inc;
                    end
                end
            end
        end
    end

	assign tw_cnt_stage = stage;

endmodule

module invcounter_tw (
    input  logic        clk,
    input  logic        rstn,
    input  logic        en,
    input  logic        start,
    input  logic        security_level,
    input  logic        tw_intt_mode,
    output logic [10:0] tw_invcnt,
	output logic [ 3:0] tw_invcnt_stage,
    output logic        tw_invcnt_busy,
    output logic        tw_invcnt_finish
);

    localparam int MAX_STAGE_SEC0 = 8;
    localparam int MAX_STAGE_SEC1 = 9;

    logic [3:0]   stage;
    logic [15:0]  cycle_cnt;
    logic [10:0]  cnt_reg;
    logic [15:0]  period_target;
    logic [15:0]  interval;
    logic [10:0]  inc_val;
    logic [3:0]   start_stage;

    // Determine start_stage and period_target
    always_comb begin
        if (security_level) begin
            start_stage   = MAX_STAGE_SEC1;
            period_target = 16'd64;
        end else begin
            start_stage   = MAX_STAGE_SEC0;
            period_target = 16'd32;
        end
    end

    // Main FSM
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            stage            <= 4'd0;
            cycle_cnt        <= 16'd0;
            cnt_reg          <= 11'd0;
            tw_invcnt_busy   <= 1'b0;
            tw_invcnt_finish <= 1'b0;
        end else begin
            tw_invcnt_finish <= 1'b0;
            if (en) begin
                if (!tw_invcnt_busy) begin
                    if (start) begin
                        tw_invcnt_busy <= 1'b1;
                        stage          <= start_stage;
                        cycle_cnt      <= 16'd0;
                        // init counter value
                        if (start_stage == 0)
                            cnt_reg <= 11'd0;
                        else
                            cnt_reg <= (1 << (start_stage - 1));
                    end
                end else begin
                    // determine interval and inc_val based on stage
                    case (stage)
                        9: begin interval = 16'd1;                      inc_val = 11'd4; end
                        8: begin interval = 16'd1;                      inc_val = security_level ? 11'd2 : 11'd4; end
                        7: begin interval = 16'd1;                      inc_val = security_level ? 11'd1 : 11'd2; end
                        6: begin interval = security_level ? 16'd2 : 16'd1; inc_val = 11'd1; end
                        5: begin interval = security_level ? 16'd4 : 16'd2; inc_val = 11'd1; end
                        4: begin interval = security_level ? 16'd8 : 16'd4; inc_val = 11'd1; end
                        3: begin interval = security_level ? 16'd16: 16'd8; inc_val = 11'd1; end
                        2: begin interval = security_level ? 16'd32: 16'd16; inc_val = 11'd1; end
                        1: begin interval = security_level ? 16'd64: 16'd32; inc_val = 11'd1; end
                        0: begin interval = security_level ? 16'd64: 16'd32; inc_val = 11'd1; end
                        default: begin interval = 16'd1; inc_val = 11'd0; end
                    endcase

                    // increment counter when due
                    if ((cycle_cnt % interval) == (interval - 1)) begin
                        cnt_reg <= cnt_reg + inc_val;
                    end

                    cycle_cnt <= cycle_cnt + 1;

                    // stage transition
                    if (cycle_cnt == period_target - 1) begin
                        cycle_cnt <= 16'd0;
                        if (stage > 1) begin
                            stage <= stage - 1;
                            // reset cnt_reg for new stage
                            if ((stage - 1) == 0)
                                cnt_reg <= 11'd0;
                            else
                                cnt_reg <= (1 << ((stage - 1) - 1));
                        end else if ((stage == 1) && tw_intt_mode) begin
                            stage    <= 4'd0;
                            cnt_reg  <= 11'd0;
                        end else begin
                            tw_invcnt_busy   <= 1'b0;
                            tw_invcnt_finish <= 1'b1;
                        end
                    end
                end
            end
        end
    end

    assign tw_invcnt = cnt_reg;

	assign tw_invcnt_stage = stage;

endmodule
