module uart_simple_tx #(
    parameter int unsigned CLOCK_DIV = 868
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [7:0] data,
    output logic ready,
    output logic tx
);

    logic [3:0] bit_count;
    logic [15:0] baud_cnt;
    logic [9:0] shift_reg;
    logic busy;

    assign ready = ~busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= '0;
            baud_cnt <= '0;
            shift_reg <= 10'h3FF;
            busy <= 1'b0;
            tx <= 1'b1;
        end else begin
            if (!busy) begin
                tx <= 1'b1;
                if (start) begin
                    shift_reg <= {1'b1, data, 1'b0};
                    bit_count <= 4'd10;
                    baud_cnt <= CLOCK_DIV - 1;
                    busy <= 1'b1;
                    tx <= 1'b0;
                end
            end else begin
                if (baud_cnt == 0) begin
                    baud_cnt <= CLOCK_DIV - 1;
                    if (bit_count > 4'd1) begin
                        tx <= shift_reg[1];
                    end else begin
                        tx <= 1'b1;
                    end
                    shift_reg <= {1'b1, shift_reg[9:1]};
                    bit_count <= bit_count - 1'b1;
                    if (bit_count == 4'd1) begin
                        busy <= 1'b0;
                    end
                end else begin
                    baud_cnt <= baud_cnt - 1'b1;
                end
            end
        end
    end
endmodule

module uart_simple_rx #(
    parameter int unsigned CLOCK_DIV = 868
)(
    input  logic clk,
    input  logic rst_n,
    input  logic rx,
    output logic [7:0] data,
    output logic valid,
    input  logic ready
);

    typedef enum logic [2:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP,
        RX_HOLD
    } rx_state_t;

    rx_state_t state;
    logic [15:0] baud_cnt;
    logic [3:0] bit_index;
    logic [7:0] shift_reg;
    logic rx_sync0;
    logic rx_sync1;

    wire rx_sample = rx_sync1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= RX_IDLE;
            baud_cnt <= '0;
            bit_index <= '0;
            shift_reg <= '0;
            data <= '0;
            valid <= 1'b0;
        end else begin
            case (state)
                RX_IDLE: begin
                    valid <= 1'b0;
                    if (rx_sample == 1'b0) begin
                        baud_cnt <= (CLOCK_DIV >> 1);
                        state <= RX_START;
                    end
                end

                RX_START: begin
                    if (baud_cnt == 0) begin
                        if (rx_sample == 1'b0) begin
                            baud_cnt <= CLOCK_DIV - 1;
                            bit_index <= '0;
                            state <= RX_DATA;
                        end else begin
                            state <= RX_IDLE;
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 1'b1;
                    end
                end

                RX_DATA: begin
                    if (baud_cnt == 0) begin
                        shift_reg[bit_index] <= rx_sample;
                        baud_cnt <= CLOCK_DIV - 1;
                        if (bit_index == 4'd7) begin
                            state <= RX_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 1'b1;
                    end
                end

                RX_STOP: begin
                    if (baud_cnt == 0) begin
                        baud_cnt <= CLOCK_DIV - 1;
                        if (rx_sample == 1'b1) begin
                            data <= shift_reg;
                            valid <= 1'b1;
                            state <= RX_HOLD;
                        end else begin
                            state <= RX_IDLE;
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 1'b1;
                    end
                end

                RX_HOLD: begin
                    if (ready) begin
                        valid <= 1'b0;
                        state <= RX_IDLE;
                    end
                end

                default: state <= RX_IDLE;
            endcase
        end
    end
endmodule
