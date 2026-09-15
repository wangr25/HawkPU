// use one-hot coded select
module mux31_onehot #(
    parameter DATA_WIDTH = 32
)(

    input wire [2:0] select,

    input wire [DATA_WIDTH-1:0] data1,
    input wire [DATA_WIDTH-1:0] data2,
    input wire [DATA_WIDTH-1:0] data3,

    output wire [DATA_WIDTH-1:0] data_out

);

assign data_out = ({DATA_WIDTH{select[0]}} & data1)
				| ({DATA_WIDTH{select[1]}} & data2)
				| ({DATA_WIDTH{select[2]}} & data3);

endmodule

module mux41 #(
    parameter DATA_WIDTH = 32
)(

    input wire [1:0] select,

    input wire [DATA_WIDTH-1:0] data00,
    input wire [DATA_WIDTH-1:0] data01,
    input wire [DATA_WIDTH-1:0] data10,
    input wire [DATA_WIDTH-1:0] data11,

    output wire [DATA_WIDTH-1:0] data_out

);

wire select00;
wire select01;
wire select10;
wire select11;

assign select00 = (~select[1]) & (~select[0]);
assign select01 = (~select[1]) & select[0];
assign select10 = select[1] & (~select[0]);
assign select11 = select[1] & select[0];

assign data_out = ({DATA_WIDTH{select00}} & data00)
				| ({DATA_WIDTH{select01}} & data01)
				| ({DATA_WIDTH{select10}} & data10)
				| ({DATA_WIDTH{select11}} & data11);

endmodule

// use one-hot coded select
module mux41_onehot #(
    parameter DATA_WIDTH = 32
)(

    input wire [3:0] select,

    input wire [DATA_WIDTH-1:0] data1,
    input wire [DATA_WIDTH-1:0] data2,
    input wire [DATA_WIDTH-1:0] data3,
    input wire [DATA_WIDTH-1:0] data4,

    output wire [DATA_WIDTH-1:0] data_out

);

assign data_out = ({DATA_WIDTH{select[0]}} & data1)
				| ({DATA_WIDTH{select[1]}} & data2)
				| ({DATA_WIDTH{select[2]}} & data3)
				| ({DATA_WIDTH{select[3]}} & data4);

endmodule
