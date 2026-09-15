module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16,
    parameter ALMOST_FULL_THRESH = DEPTH - 2,
    parameter ALMOST_EMPTY_THRESH = 2
)(
    input  logic                  clk,
    input  logic                  rstn, 
    input  logic                  en, 
    input  logic                  wr_en, 
    input  logic                  rd_en, 
    input  logic [DATA_WIDTH-1:0] din, 
    output logic [DATA_WIDTH-1:0] dout,         
    output logic                  full,
    output logic                  empty,
    output logic                  almost_full,
    output logic                  almost_empty,
    output logic [ADDR_WIDTH:0]   data_count     // valid data in fifo
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] rd_ptr, wr_ptr;
    logic [ADDR_WIDTH:0]   fifo_count;

    logic rst_sync1, rst_sync2;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rst_sync1 <= 1'b0;
            rst_sync2 <= 1'b0;
        end else begin
            rst_sync1 <= 1'b1;
            rst_sync2 <= rst_sync1;
        end
    end

    // write
    always_ff @(posedge clk) begin
        if (!rst_sync2) begin
            wr_ptr <= 0;
        end else if (en && wr_en && !full) begin
            mem[wr_ptr] <= din;
			if (wr_ptr==DEPTH-1) begin
				wr_ptr <= 'd0;
			end else begin
				wr_ptr <= wr_ptr + 1;
			end
        end
    end

    // read
    always_ff @(posedge clk) begin
        if (!rst_sync2) begin
            rd_ptr <= 0;
        end else if (en && rd_en && !empty) begin
			if (rd_ptr==DEPTH-1) begin
				rd_ptr <= 'd0;
			end else begin
				rd_ptr <= rd_ptr + 1;
			end
        end
    end

    // FIFO counter
    always_ff @(posedge clk) begin
        if (!rst_sync2) begin
            fifo_count <= 0;
        end else if (en) begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: fifo_count <= fifo_count + 1; // write
                2'b01: fifo_count <= fifo_count - 1; // read
                default: fifo_count <= fifo_count;
            endcase
        end
    end

    assign full         = (fifo_count == DEPTH);
    assign empty        = (fifo_count == 0);
    assign almost_full  = (fifo_count >= ALMOST_FULL_THRESH);
    assign almost_empty = (fifo_count <= ALMOST_EMPTY_THRESH);
    assign data_count = fifo_count;

	assign dout = mem[rd_ptr];	// asyn read

endmodule
