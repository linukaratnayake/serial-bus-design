import bus_bridge_pkg::*;

module bus_bridge_uart_req_tx #(
    parameter int unsigned CLOCK_DIV = 868
)(
    input  logic clk,
    input  logic rst_n,
    input  logic req_valid,
    output logic req_ready,
    input  bus_bridge_req_t req_payload,
    output logic uart_tx
);

    typedef enum logic [1:0] {
        TX_IDLE,
        TX_SEND
    } tx_state_t;

    tx_state_t state;
    logic [7:0] frame_bytes [0:5];
    logic [2:0] frame_len;
    logic [2:0] byte_index;
    logic tx_start;
    logic [7:0] tx_data;
    logic tx_ready;

    uart_simple_tx #(
        .CLOCK_DIV(CLOCK_DIV)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .start(tx_start),
        .data(tx_data),
        .ready(tx_ready),
        .tx(uart_tx)
    );

    assign req_ready = (state == TX_IDLE) && tx_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= TX_IDLE;
            frame_len <= '0;
            byte_index <= '0;
            tx_start <= 1'b0;
            tx_data <= 8'hFF;
        end else begin
            tx_start <= 1'b0;
            case (state)
                TX_IDLE: begin
                    if (req_valid && req_ready) begin
                        frame_bytes[0] <= 8'h55;
                        frame_bytes[1] <= req_payload.is_write ? 8'h01 : 8'h00;
                        frame_bytes[2] <= req_payload.addr[15:8];
                        frame_bytes[3] <= req_payload.addr[7:0];
                        if (req_payload.is_write) begin
                            frame_bytes[4] <= req_payload.write_data;
                            frame_bytes[5] <= 8'hAA;
                            frame_len <= 3'd6;
                        end else begin
                            frame_bytes[4] <= 8'hAA;
                            frame_len <= 3'd5;
                        end
                        byte_index <= '0;
                        state <= TX_SEND;
                    end
                end

                TX_SEND: begin
                    if (tx_ready) begin
                        tx_data <= frame_bytes[byte_index];
                        tx_start <= 1'b1;
                        byte_index <= byte_index + 1'b1;
                        if (byte_index + 1'b1 == frame_len) begin
                            state <= TX_IDLE;
                        end
                    end
                end

                default: state <= TX_IDLE;
            endcase
        end
    end
endmodule

module bus_bridge_uart_resp_tx #(
    parameter int unsigned CLOCK_DIV = 868
)(
    input  logic clk,
    input  logic rst_n,
    input  logic resp_valid,
    output logic resp_ready,
    input  bus_bridge_resp_t resp_payload,
    output logic uart_tx
);

    typedef enum logic [1:0] {
        TXR_IDLE,
        TXR_SEND
    } txr_state_t;

    txr_state_t state;
    logic [7:0] frame_bytes [0:4];
    logic [2:0] frame_len;
    logic [2:0] byte_index;
    logic tx_start;
    logic [7:0] tx_data;
    logic tx_ready;

    uart_simple_tx #(
        .CLOCK_DIV(CLOCK_DIV)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .start(tx_start),
        .data(tx_data),
        .ready(tx_ready),
        .tx(uart_tx)
    );

    assign resp_ready = (state == TXR_IDLE) && tx_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= TXR_IDLE;
            frame_len <= '0;
            byte_index <= '0;
            tx_start <= 1'b0;
            tx_data <= 8'hFF;
        end else begin
            tx_start <= 1'b0;
            case (state)
                TXR_IDLE: begin
                    if (resp_valid && resp_ready) begin
                        frame_bytes[0] <= 8'h55;
                        frame_bytes[1] <= resp_payload.is_write ? 8'h81 : 8'h80;
                        if (resp_payload.is_write) begin
                            frame_bytes[2] <= 8'hAA;
                            frame_len <= 3'd3;
                        end else begin
                            frame_bytes[2] <= resp_payload.read_data;
                            frame_bytes[3] <= 8'hAA;
                            frame_len <= 3'd4;
                        end
                        byte_index <= '0;
                        state <= TXR_SEND;
                    end
                end

                TXR_SEND: begin
                    if (tx_ready) begin
                        tx_data <= frame_bytes[byte_index];
                        tx_start <= 1'b1;
                        byte_index <= byte_index + 1'b1;
                        if (byte_index + 1'b1 == frame_len) begin
                            state <= TXR_IDLE;
                        end
                    end
                end

                default: state <= TXR_IDLE;
            endcase
        end
    end
endmodule

module bus_bridge_uart_req_rx #(
    parameter int unsigned CLOCK_DIV = 868
)(
    input  logic clk,
    input  logic rst_n,
    input  logic uart_rx,
    output logic req_valid,
    input  logic req_ready,
    output bus_bridge_req_t req_payload
);

    typedef enum logic [2:0] {
        RX_WAIT_START,
        RX_TYPE,
        RX_ADDR_HI,
        RX_ADDR_LO,
        RX_WRITE_DATA,
        RX_WAIT_END,
        RX_HOLD
    } rx_req_state_t;

    rx_req_state_t state;
    logic [7:0] rx_byte;
    logic rx_valid;
    logic rx_ready_internal;
    logic expected_write;
    logic [15:0] addr_buffer;
    logic [7:0] data_buffer;

    uart_simple_rx #(
        .CLOCK_DIV(CLOCK_DIV)
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .data(rx_byte),
        .valid(rx_valid),
        .ready(rx_ready_internal)
    );

    assign rx_ready_internal = (state != RX_HOLD);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= RX_WAIT_START;
            expected_write <= 1'b0;
            addr_buffer <= '0;
            data_buffer <= '0;
            req_valid <= 1'b0;
            req_payload <= '0;
        end else begin
            case (state)
                RX_WAIT_START: begin
                    expected_write <= 1'b0;
                    data_buffer <= 8'h00;
                    if (rx_valid && rx_byte == 8'h55 && rx_ready_internal) begin
                        state <= RX_TYPE;
                    end
                end

                RX_TYPE: begin
                    if (rx_valid && rx_ready_internal) begin
                        expected_write <= (rx_byte == 8'h01);
                        state <= (rx_byte == 8'h00 || rx_byte == 8'h01) ? RX_ADDR_HI : RX_WAIT_START;
                    end
                end

                RX_ADDR_HI: begin
                    if (rx_valid && rx_ready_internal) begin
                        addr_buffer[15:8] <= rx_byte;
                        state <= RX_ADDR_LO;
                    end
                end

                RX_ADDR_LO: begin
                    if (rx_valid && rx_ready_internal) begin
                        addr_buffer[7:0] <= rx_byte;
                        state <= expected_write ? RX_WRITE_DATA : RX_WAIT_END;
                    end
                end

                RX_WRITE_DATA: begin
                    if (rx_valid && rx_ready_internal) begin
                        data_buffer <= rx_byte;
                        state <= RX_WAIT_END;
                    end
                end

                RX_WAIT_END: begin
                    if (rx_valid && rx_ready_internal) begin
                        if (rx_byte == 8'hAA) begin
                            req_payload.is_write <= expected_write;
                            req_payload.addr <= addr_buffer;
                            req_payload.write_data <= expected_write ? data_buffer : 8'h00;
                            req_valid <= 1'b1;
                            state <= RX_HOLD;
                        end else begin
                            state <= RX_WAIT_START;
                        end
                    end
                end

                RX_HOLD: begin
                    if (req_valid && req_ready) begin
                        req_valid <= 1'b0;
                        state <= RX_WAIT_START;
                    end
                end

                default: state <= RX_WAIT_START;
            endcase
        end
    end
endmodule

module bus_bridge_uart_resp_rx #(
    parameter int unsigned CLOCK_DIV = 868
)(
    input  logic clk,
    input  logic rst_n,
    input  logic uart_rx,
    output logic resp_valid,
    input  logic resp_ready,
    output bus_bridge_resp_t resp_payload
);

    typedef enum logic [2:0] {
        RXR_WAIT_START,
        RXR_TYPE,
        RXR_DATA,
        RXR_WAIT_END,
        RXR_HOLD
    } rxr_state_t;

    rxr_state_t state;
    logic [7:0] rx_byte;
    logic rx_valid;
    logic rx_ready_internal;
    logic expected_write_ack;
    logic [7:0] data_buffer;

    uart_simple_rx #(
        .CLOCK_DIV(CLOCK_DIV)
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .data(rx_byte),
        .valid(rx_valid),
        .ready(rx_ready_internal)
    );

    assign rx_ready_internal = (state != RXR_HOLD);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= RXR_WAIT_START;
            expected_write_ack <= 1'b0;
            data_buffer <= '0;
            resp_valid <= 1'b0;
            resp_payload <= '0;
        end else begin
            case (state)
                RXR_WAIT_START: begin
                    expected_write_ack <= 1'b0;
                    data_buffer <= 8'h00;
                    if (rx_valid && rx_byte == 8'h55 && rx_ready_internal) begin
                        state <= RXR_TYPE;
                    end
                end

                RXR_TYPE: begin
                    if (rx_valid && rx_ready_internal) begin
                        if (rx_byte == 8'h81) begin
                            expected_write_ack <= 1'b1;
                            state <= RXR_WAIT_END;
                        end else if (rx_byte == 8'h80) begin
                            expected_write_ack <= 1'b0;
                            state <= RXR_DATA;
                        end else begin
                            state <= RXR_WAIT_START;
                        end
                    end
                end

                RXR_DATA: begin
                    if (rx_valid && rx_ready_internal) begin
                        data_buffer <= rx_byte;
                        state <= RXR_WAIT_END;
                    end
                end

                RXR_WAIT_END: begin
                    if (rx_valid && rx_ready_internal) begin
                        if (rx_byte == 8'hAA) begin
                            resp_payload.is_write <= expected_write_ack;
                            resp_payload.read_data <= expected_write_ack ? 8'h00 : data_buffer;
                            resp_valid <= 1'b1;
                            state <= RXR_HOLD;
                        end else begin
                            state <= RXR_WAIT_START;
                        end
                    end
                end

                RXR_HOLD: begin
                    if (resp_valid && resp_ready) begin
                        resp_valid <= 1'b0;
                        state <= RXR_WAIT_START;
                    end
                end

                default: state <= RXR_WAIT_START;
            endcase
        end
    end
endmodule

module bus_bridge_target_uart #(
    parameter int unsigned CLOCK_DIV = 868,
    parameter logic [15:0] BRIDGE_BASE_ADDR = 16'h8000,
    parameter int unsigned TARGET0_SIZE = 16'd2048,
    parameter int unsigned TARGET1_SIZE = 16'd4096,
    parameter int unsigned TARGET2_SIZE = 16'd4096,
    parameter logic [15:0] BUSB_TARGET0_BASE = 16'h0000,
    parameter logic [15:0] BUSB_TARGET1_BASE = 16'h4000,
    parameter logic [15:0] BUSB_TARGET2_BASE = 16'h8000
)(
    input  logic clk,
    input  logic rst_n,
    input  logic split_grant,
    input  logic [15:0] target_addr_in,
    input  logic target_addr_in_valid,
    input  logic [7:0] target_data_in,
    input  logic target_data_in_valid,
    input  logic target_rw,
    output logic split_req,
    output logic [7:0] target_data_out,
    output logic target_data_out_valid,
    output logic target_ack,
    output logic target_split_ack,
    output logic target_ready,
    output logic [7:0] split_target_last_write,
    output logic uart_tx,
    input  logic uart_rx
);

    logic req_valid;
    logic req_ready;
    bus_bridge_req_t req_payload;
    logic resp_valid;
    logic resp_ready;
    bus_bridge_resp_t resp_payload;

    bus_bridge_target_if #(
        .BRIDGE_BASE_ADDR(BRIDGE_BASE_ADDR),
        .TARGET0_SIZE(TARGET0_SIZE),
        .TARGET1_SIZE(TARGET1_SIZE),
        .TARGET2_SIZE(TARGET2_SIZE),
        .BUSB_TARGET0_BASE(BUSB_TARGET0_BASE),
        .BUSB_TARGET1_BASE(BUSB_TARGET1_BASE),
        .BUSB_TARGET2_BASE(BUSB_TARGET2_BASE)
    ) u_target_if (
        .clk(clk),
        .rst_n(rst_n),
        .split_grant(split_grant),
        .target_addr_in(target_addr_in),
        .target_addr_in_valid(target_addr_in_valid),
        .target_data_in(target_data_in),
        .target_data_in_valid(target_data_in_valid),
        .target_rw(target_rw),
        .split_req(split_req),
        .target_data_out(target_data_out),
        .target_data_out_valid(target_data_out_valid),
        .target_ack(target_ack),
        .target_split_ack(target_split_ack),
        .target_ready(target_ready),
        .split_target_last_write(split_target_last_write),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_payload(req_payload),
        .resp_valid(resp_valid),
        .resp_ready(resp_ready),
        .resp_payload(resp_payload)
    );

    bus_bridge_uart_req_tx #(
        .CLOCK_DIV(CLOCK_DIV)
    ) u_req_tx (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_payload(req_payload),
        .uart_tx(uart_tx)
    );

    bus_bridge_uart_resp_rx #(
        .CLOCK_DIV(CLOCK_DIV)
    ) u_resp_rx (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .resp_valid(resp_valid),
        .resp_ready(resp_ready),
        .resp_payload(resp_payload)
    );
endmodule

module bus_bridge_initiator_uart #(
    parameter int unsigned CLOCK_DIV = 868
)(
    input  logic clk,
    input  logic rst_n,
    output logic init_req,
    output logic [15:0] init_addr_out,
    output logic init_addr_out_valid,
    output logic [7:0] init_data_out,
    output logic init_data_out_valid,
    output logic init_rw,
    output logic init_ready,
    input  logic init_grant,
    input  logic [7:0] init_data_in,
    input  logic init_data_in_valid,
    input  logic init_ack,
    input  logic init_split_ack,
    input  logic uart_rx,
    output logic uart_tx
);

    logic req_valid;
    logic req_ready;
    bus_bridge_req_t req_payload;
    logic resp_valid;
    logic resp_ready;
    bus_bridge_resp_t resp_payload;

    bus_bridge_initiator_if u_initiator_if (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_payload(req_payload),
        .resp_valid(resp_valid),
        .resp_ready(resp_ready),
        .resp_payload(resp_payload),
        .init_req(init_req),
        .init_addr_out(init_addr_out),
        .init_addr_out_valid(init_addr_out_valid),
        .init_data_out(init_data_out),
        .init_data_out_valid(init_data_out_valid),
        .init_rw(init_rw),
        .init_ready(init_ready),
        .init_grant(init_grant),
        .init_data_in(init_data_in),
        .init_data_in_valid(init_data_in_valid),
        .init_ack(init_ack),
        .init_split_ack(init_split_ack)
    );

    bus_bridge_uart_req_rx #(
        .CLOCK_DIV(CLOCK_DIV)
    ) u_req_rx (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_payload(req_payload)
    );

    bus_bridge_uart_resp_tx #(
        .CLOCK_DIV(CLOCK_DIV)
    ) u_resp_tx (
        .clk(clk),
        .rst_n(rst_n),
        .resp_valid(resp_valid),
        .resp_ready(resp_ready),
        .resp_payload(resp_payload),
        .uart_tx(uart_tx)
    );
endmodule
