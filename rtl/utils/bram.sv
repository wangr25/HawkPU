// Simple Dual Port RAM (Simulation-Only Model)
// Synchronous clock, Write-First behavior
// Compatible with Xilinx BRAM IP port names

module sim_dpram #(
    parameter MEM_SIZE   = 1024,        // Number of memory locations
    parameter DATA_WIDTH = 32,          // Data width
    parameter ADDR_WIDTH = 10           // Address width: log2(MEM_SIZE)
)(
    // Shared clock for both ports
    input wire clka,

    // Port A - Write Port
    input wire ena,
    input wire wea,
    input wire [ADDR_WIDTH-1:0] addra,
    input wire [DATA_WIDTH-1:0] dina,

    // Port B - Read Port
    input wire enb,
    input wire [ADDR_WIDTH-1:0] addrb,
    output reg [DATA_WIDTH-1:0] doutb
);

    // Memory declaration
`ifdef FPGA_SYN
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1];
`else
    reg [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1];
`endif

    always @(posedge clka) begin
        // Write operation
        if (ena && wea) begin
            mem[addra] <= dina;
        end

        // Read operation with Write-First behavior
        if (enb) begin
            if ((ena && wea) && (addra == addrb)) begin
                doutb <= dina; // Write-First: return new data
            end else begin
                doutb <= mem[addrb]; // Normal read
            end
        end
    end

endmodule



// Simple Dual Port ROM (Simulation-Only Model)
// Synchronous clock
// Read-only memory with simulation-time initialization
module sim_dprom #(
    parameter MEM_SIZE   = 1024,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter INIT_FILE  = "" 
)(
    input wire clka,

    // Port A - Read Port
    input wire ena,
    input wire [ADDR_WIDTH-1:0] addra,
    output reg [DATA_WIDTH-1:0] douta,

    // Port B - Read Port
    input wire enb,
    input wire [ADDR_WIDTH-1:0] addrb,
    output reg [DATA_WIDTH-1:0] doutb
);

`ifdef FPGA_SYN
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] rom [0:MEM_SIZE-1];
`else
    reg [DATA_WIDTH-1:0] rom [0:MEM_SIZE-1];
`endif

    initial begin
        if (INIT_FILE != "") begin
            $display("Loading ROM contents from: %s", INIT_FILE);
            $readmemh(INIT_FILE, rom);
        end else begin
            $display("WARNING: No INIT_FILE specified, ROM contents undefined!");
        end
    end

    always @(posedge clka) begin
        if (ena) begin
            douta <= rom[addra];
        end
        if (enb) begin
            doutb <= rom[addrb];
        end
    end

endmodule


// Simple Single Port ROM (Simulation-Only Model)
// Synchronous clock
// Read-only memory with simulation-time initialization
module sim_sprom #(
    parameter MEM_SIZE   = 1024,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter INIT_FILE  = "" 
)(
    input  wire clka,

    // Port A - Read Port
    input  wire ena,
    input  wire [ADDR_WIDTH-1:0] addra,
    output reg  [DATA_WIDTH-1:0] douta
);

`ifdef FPGA_SYN
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] rom [0:MEM_SIZE-1];
`else
    reg [DATA_WIDTH-1:0] rom [0:MEM_SIZE-1];
`endif

    initial begin
        if (INIT_FILE != "") begin
            $display("Loading ROM contents from: %s", INIT_FILE);
            $readmemh(INIT_FILE, rom);
        end else begin
            $display("WARNING: No INIT_FILE specified, ROM contents undefined!");
        end
    end

    always @(posedge clka) begin
        if (ena) begin
            douta <= rom[addra];
        end
    end

endmodule

module sim_sprom_coreoutreg #(
    parameter MEM_SIZE   = 1024,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter INIT_FILE  = "" 
)(
    input  wire clka,

    // Port A - Read Port
    input  wire ena,
    input  wire [ADDR_WIDTH-1:0] addra,
    output reg  [DATA_WIDTH-1:0] douta
);

`ifdef FPGA_SYN
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] rom [0:MEM_SIZE-1];
`else
    reg [DATA_WIDTH-1:0] rom [0:MEM_SIZE-1];
`endif

    initial begin
        if (INIT_FILE != "") begin
            $display("Loading ROM contents from: %s", INIT_FILE);
            $readmemh(INIT_FILE, rom);
        end else begin
            $display("WARNING: No INIT_FILE specified, ROM contents undefined!");
        end
    end
    
    reg [DATA_WIDTH-1:0] d1;

    always @(posedge clka) begin
        if (ena) begin
            d1 <= rom[addra];
        end
    end
    always @(posedge clka) begin
        douta <= d1;
    end

endmodule
