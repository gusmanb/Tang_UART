//Serializes a bit with 8N1 format
module SERIALIZE_SHIFTER(
        input ser_ck,
        input[7:0] shift_data,
        input shift,
        output reg serout,
        output reg busy);

initial serout = 1;
initial busy = 0;

parameter SRC_CLOCK = 0;
parameter BAUDS = 0;

localparam TICKS_PER_BAUD = (SRC_CLOCK / BAUDS) - 1;
localparam HALF_BAUD = (TICKS_PER_BAUD / 2) - 1;
localparam 
            SHIFT_IDLE = 0,
            SHIFT_SEND = 1,
            SHIFT_STOP = 2,
            SHIFT_DELAY = 3,
            SHIFT_HALF_DELAY = 4;

reg[2:0] shift_state = SHIFT_IDLE;
reg[2:0] shift_state_next = SHIFT_IDLE;

reg[3:0] shift_bit = 0;
reg[7:0] shift_buffer = 0;

reg[$clog2(TICKS_PER_BAUD + 1) + 1:0] baud_counter = 0;

always @(posedge ser_ck)begin

    case (shift_state)

        SHIFT_IDLE: 
        begin

            if(shift) //Something to send?
            begin

                shift_buffer <= shift_data; //copy data to buffer
                shift_bit <= 0; //we start sending bit 0 (lsb to msb)
                serout <= 0; //send start bit
                busy <= 1; //We're working!
                baud_counter <= 0; //Rested delay counter (just in case)
                shift_state <= SHIFT_DELAY; //After this bit we will wait a cycle
                shift_state_next <= SHIFT_SEND; //After the delay, we're going to send bits
            end

        end

        SHIFT_SEND:
        begin

            if(shift_bit > 7) //Is this the stop bit?
            begin
                serout <= 1; //Send it
                shift_state_next <= SHIFT_STOP; //We only wait half a cycle, this is to achieve maximum speeds
                shift_state <= SHIFT_HALF_DELAY;
            end
            else
            begin
                serout <= shift_buffer[shift_bit]; //Send a bit
                shift_bit <= shift_bit + 1; //Point to next bit
                shift_state_next <= SHIFT_SEND; //We will continue sending
                shift_state <= SHIFT_DELAY; //After a baud delay
            end

        end

        SHIFT_STOP:
        begin
            shift_state <= SHIFT_IDLE; //We're idle!
            busy <= 0; //Tell it everyone!
        end

        SHIFT_DELAY:
        begin

            baud_counter <= baud_counter + 1; //Increment counter (async)

            if(baud_counter == TICKS_PER_BAUD) //Remember, the increment is async, we will read the same value that was before increment
            begin
                baud_counter <= 0; //Reset counter
                shift_state <= shift_state_next; //Move state machine to selected state
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

end

endmodule