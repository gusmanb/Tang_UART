//Deserializes a bit with 8N1 format
module DESERIALIZE_SHIFTER(
        input ser_ck,
        input serin,
        input rd_data,
        output reg[7:0] shifted_data,
        output reg available);

initial shifted_data = 0;
initial available = 0;

//State machine
localparam  
            SHIFT_IDLE = 0,
            SHIFT_START = 1,
            SHIFT_RCV = 2,
            SHIFT_STOP = 3,
            SHIFT_DELAY = 4,
            SHIFT_HALF_DELAY = 5;

reg[2:0] shift_state = SHIFT_IDLE;
reg[2:0] shift_state_next = SHIFT_IDLE;
reg[3:0] shift_bit = 0;
reg[7:0] shift_buffer = 0;

//Timming parameters, left to 0 so it is forced to be assigned from the declaring module
parameter SRC_CLOCK = 0;
parameter BAUDS = 0;

//Cycles per baud en half baud
localparam TICKS_PER_BAUD = (SRC_CLOCK / BAUDS) - 1;
localparam HALF_BAUD = (TICKS_PER_BAUD / 2) - 1;

reg[$clog2(TICKS_PER_BAUD + 1) + 1:0] baud_counter = 0;

reg rd_metastable = 1;
reg rd_stable = 1;

//Stabilization of the input, to avoid problems with cross-domain clocks.
always @(posedge ser_ck)begin
    rd_metastable <= serin;
    rd_stable <= rd_metastable;
end

always @(posedge ser_ck)begin

    case (shift_state)

        SHIFT_IDLE: 
        begin

            if(!rd_stable) //wait for start bit
            begin

                shift_buffer <= 0; //clear shifted data
                shift_bit <= 0; //we start receiving bit 0 (lsb to msb)
                baud_counter <= 0; //Reset everything
                shift_state <= SHIFT_HALF_DELAY; //We are going to wait half a cycle, as we go many times faster than the serial 
                                                 //data speed we will catch the signal at the beginning of the cycle, so we wait
                                                 //until half a cycle passes to sample in the middle of it, to correct dicrepances of speed with the other end.
                shift_state_next <= SHIFT_START;
            end

        end

        SHIFT_START:
        begin
            shift_state <= SHIFT_DELAY; //Ok, we're in the middle of the start bit transfer, now we start sampling at the specified rate
            shift_state_next <= SHIFT_RCV;
        end

        SHIFT_RCV:
        begin

            shift_buffer[shift_bit] <= rd_stable; //Shift bit in
            shift_bit <= shift_bit + 1; //Next bit
            if(shift_bit == 7) //If this is the last bit, let's go for the start bit
            begin
                shift_state <= SHIFT_STOP;
            end
            else
            begin
                shift_state_next <= SHIFT_RCV; //Else let's wait for another bit
                shift_state <= SHIFT_DELAY;
            end
            

        end

        SHIFT_STOP:
        begin
            if(rd_stable) //We're waiting for the stop bit, a 1, it could happen that the last 
                          //bit was a 1 and this exits earlier, but that's not a problem as the other 
                          //side should send another one, what will not cause the start bit to be detected incorrectly.
            begin
                shifted_data <= shift_buffer; //Push the data to the output register
                available <= 1; //Tell it everone that there is available data
                shift_state <= SHIFT_IDLE; //Ok, now we're free, let's wait for another start
            end
        end

        SHIFT_DELAY:
        begin

            baud_counter <= baud_counter + 1;

            if(baud_counter == TICKS_PER_BAUD)
            begin
                baud_counter <= 0;
                shift_state <= shift_state_next;
            end

        end

        SHIFT_HALF_DELAY:
        begin

            baud_counter <= baud_counter + 1;

            if(baud_counter == HALF_BAUD)
            begin
                baud_counter <= 0;
                shift_state <= shift_state_next;
            end

        end

    endcase

    //Someone has read the available data (or does not care about it), so we drop the available flag
    if(rd_data)
    begin
        available <= 0;
    end
end

endmodule