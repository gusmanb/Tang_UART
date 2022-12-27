//Top module, echo server.
module uart_test(
        input clk,
        input rx,
        output tx,
        output rxempty,
        output txfull
    );


reg[7:0] tx_data;
reg push_tx;
wire tx_full;

wire[7:0] rx_data;
wire rx_empty;
reg pop_rx;

//Activity led's (show the FIFOs status)
assign rxempty = !rx_empty;
assign txfull = !tx_full;

SIMPLE_UART uart(
        .UART_SRC_CK(clk),
        //TX
        .TX_REG(tx_data),
        .PUSH_TX(push_tx),
        .TX_FULL(tx_full),
        .TX_LINE(tx),
        //RX
        .RX_REG(rx_data),
        .RX_EMPTY(rx_empty),
        .POP_RX(pop_rx),
        .RX_LINE(rx)
    );

//Configure UART timming parameters
defparam uart.UART_SRC_CK_FREQ = 27000000;
defparam uart.UART_BAUDS = 115200;

always @(posedge clk) begin

    //If there is data in the RX FIFO and the TX FIFO is not full
    //we transfer one byte between them.

    if(pop_rx)
    begin
        pop_rx <= 0;
        push_tx <= 0;
    end
    else if(!rx_empty && !tx_full && !pop_rx)
    begin
        tx_data <= rx_data;
        pop_rx <= 1;
        push_tx <= 1;
    end

end


endmodule