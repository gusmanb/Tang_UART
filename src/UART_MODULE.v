//Buffered UART module
module SIMPLE_UART(
        input UART_SRC_CK,
        //TX
        input[7:0] TX_REG,
        input PUSH_TX,
        output wire TX_FULL,
        output wire TX_LINE,

        //RX
        output wire[7:0] RX_REG,
        output wire RX_EMPTY,
        input POP_RX,
        input RX_LINE
    );

//The module itself is basically glue logic between the shifters and the fifos.

//We receive the timming information at compilation time, this can be easily extended to
//use registers and then we will be able to change its speed at run time
parameter UART_SRC_CK_FREQ = 0;
parameter UART_BAUDS = 0;

wire[7:0] fifo_tx_output = 0;

reg tx_start = 0;
wire tx_fifo_empty;
wire tx_ser_busy;

//TX FIFO
//You can replace it with a smaller one based on your needs and it will use less resources.
//The FIFO must be FWT.
fifo_sc_hs_64_reg_top tx_fifo(
    .Data(TX_REG), //input [7:0] Data
    .Clk(UART_SRC_CK), //input Clk
    .WrEn(PUSH_TX), //input WrEn
    .RdEn(tx_start), //input RdEn
    .Reset(1'b0), //input Reset
    .Q(fifo_tx_output), //output [7:0] Q
    .Empty(tx_fifo_empty), //output Empty
    .Full(TX_FULL) //output Full
);

//Output shifter
SERIALIZE_SHIFTER serout_module(
        .ser_ck(UART_SRC_CK),
        .shift_data(fifo_tx_output),
        .shift(tx_start),
        .serout(TX_LINE),
        .busy(tx_ser_busy)
    );

//Configure shifter timming
defparam serout_module.SRC_CLOCK = UART_SRC_CK_FREQ;
defparam serout_module.BAUDS = UART_BAUDS;

always @(posedge UART_SRC_CK)
begin

    //If there is data in the FIFO and the shifter is idle, signal a start.
    //We don't need to transfer the data from the fifo to the shifter as these are interconnected
    //via a wire.
    //Start signal is only one cycle long,

    if(tx_start)
    begin
        tx_start <= 0;
    end
    else if(!tx_fifo_empty && !tx_ser_busy)
    begin
        tx_start <= 1;
    end

end

wire[7:0] rx_data;
wire rx_available;
reg rx_start = 0;
wire rx_full;

//RX FIFO
//You can replace it with a smaller one based on your needs and it will use less resources.
//The FIFO must be FWT.
fifo_sc_hs_64_reg_top rx_fifo(
    .Data(rx_data), //input [7:0] Data
    .Clk(UART_SRC_CK), //input Clk
    .WrEn(rx_start), //input WrEn
    .RdEn(POP_RX), //input RdEn
    .Reset(1'b0), //input Reset
    .Q(RX_REG), //output [7:0] Q
    .Empty(RX_EMPTY), //output Empty
    .Full(rx_full) //output Full
);

//Input shifter
DESERIALIZE_SHIFTER serin_module(
        .ser_ck(UART_SRC_CK),
        .serin(RX_LINE),
        .rd_data(rx_start),
        .shifted_data(rx_data),
        .available(rx_available)
    );

//Configure shifter timming
defparam serin_module.SRC_CLOCK = UART_SRC_CK_FREQ;
defparam serin_module.BAUDS = UART_BAUDS;

always @(posedge UART_SRC_CK)
begin

    //If the shifter has received the data and there is room for it
    //in the fifo store it.
    //Storage signal is only one cycle long.

    if(rx_start)
    begin
        rx_start <= 0;
    end
    else
    if(rx_available && !rx_full)
    begin
        rx_start <= 1;
    end

end

endmodule