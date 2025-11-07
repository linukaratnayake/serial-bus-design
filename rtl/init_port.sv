module init_port(
    input logic clk,
    input logic rst_n,
    input logic init_req,
    input logic arbiter_grant,
    input logic [7:0] init_data_out,
    input logic init_data_out_valid,
    input logic [15:0] init_addr_out,
    input logic init_addr_out_valid,
    input logic init_rw, // 1 for write, 0 for read
    input logic init_ready,
    input logic init_bus_mode,
    input logic target_split,
    input logic target_ack,
    input logic bus_data_in_valid,
    input logic bus_data_in,
    output logic bus_data_out,
    output logic init_grant,
    output logic [7:0] init_data_in,
    output logic init_data_in_valid,
    output logic bus_data_out_valid,
    output logic arbiter_req,
    output logic bus_mode, // 1 for data, 0 for address
    output logic init_ack,
    output logic bus_init_ready,
    output logic bus_init_rw,
    output logic init_split_ack
);

assign init_grant = arbiter_grant;
assign arbiter_req = init_req;
assign bus_mode = init_bus_mode;
assign bus_init_rw = init_rw;
assign bus_init_ready = init_ready;
assign init_ack = target_ack;
assign init_split_ack = target_split;

logic [15:0] tx_shift;
logic [4:0] tx_bits_remaining;
logic tx_active;
logic [7:0] rx_shift;
logic [2:0] rx_bit_count;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_shift <= '0;
        tx_bits_remaining <= '0;
        tx_active <= 1'b0;
        bus_data_out <= 1'b0;
        bus_data_out_valid <= 1'b0;
    end else begin
        bus_data_out_valid <= 1'b0;

        if (tx_active) begin
            bus_data_out <= tx_shift[0];
            bus_data_out_valid <= 1'b1;
            tx_shift <= {1'b0, tx_shift[15:1]};

            if (tx_bits_remaining == 5'd1) begin
                tx_active <= 1'b0;
                tx_bits_remaining <= '0;
            end else begin
                tx_bits_remaining <= tx_bits_remaining - 5'd1;
            end
        end else if (arbiter_grant && init_req) begin
            if (!init_bus_mode && init_addr_out_valid) begin
                tx_shift <= init_addr_out;
                tx_bits_remaining <= 5'd16;
                tx_active <= 1'b1;
            end else if (init_bus_mode && init_data_out_valid) begin
                tx_shift <= {8'd0, init_data_out};
                tx_bits_remaining <= 5'd8;
                tx_active <= 1'b1;
            end
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_shift <= '0;
        rx_bit_count <= '0;
        init_data_in <= '0;
        init_data_in_valid <= 1'b0;
    end else begin
        init_data_in_valid <= 1'b0;

        if (bus_data_in_valid && !tx_active) begin
            rx_shift[rx_bit_count] = bus_data_in;

            if (rx_bit_count == 3'd7) begin
                init_data_in <= rx_shift;
                init_data_in_valid <= 1'b1;
                rx_bit_count <= 3'd0;
                rx_shift <= '0;
            end else begin
                rx_bit_count <= rx_bit_count + 3'd1;
            end
        end
    end
end

endmodule
