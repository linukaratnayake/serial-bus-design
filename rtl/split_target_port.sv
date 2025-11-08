module split_target_port(
    input logic clk,
    input logic rst_n,
    input logic split_req,
    input logic arbiter_grant,
    input logic [7:0] target_data_out,
    input logic target_data_out_valid,
    input logic target_rw, // 1 for write, 0 for read
    input logic target_ready,
    input logic target_split_ack,
    input logic target_ack,
    input logic bus_data_in_valid,
    input logic bus_data_in,
    input logic bus_mode, // 1 for data, 0 for address
    output logic bus_data_out,
    output logic split_grant,
    output logic [7:0] target_data_in,
    output logic target_data_in_valid,
    output logic [15:0] target_addr_in,
    output logic target_addr_in_valid,
    output logic bus_data_out_valid,
    output logic arbiter_split_req,
    output logic split_ack,
    output logic bus_target_ready,
    output logic bus_target_rw,
    output logic bus_split_ack,
    output logic bus_target_ack
);

assign split_grant = arbiter_grant;
assign arbiter_split_req = split_req;
assign bus_target_ready = target_ready;
assign bus_target_rw = target_rw;
assign bus_split_ack = target_split_ack;
assign bus_target_ack = target_ack;
assign split_ack = target_split_ack;

logic [7:0] tx_shift;
logic [3:0] tx_bits_remaining;
logic tx_active;
logic [7:0] pending_tx_data;
logic pending_tx_valid;

logic [15:0] addr_shift;
logic [4:0] addr_bit_count;
logic [15:0] addr_buffer;
logic addr_pending;
logic expect_data;
logic [7:0] data_shift;
logic [2:0] data_bit_count;
logic [7:0] data_buffer;
logic data_pending;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_shift <= '0;
        tx_bits_remaining <= '0;
        tx_active <= 1'b0;
        pending_tx_data <= '0;
        pending_tx_valid <= 1'b0;
        bus_data_out <= 1'b0;
        bus_data_out_valid <= 1'b0;
    end else begin
        bus_data_out_valid <= 1'b0;

        if (target_data_out_valid) begin
            pending_tx_data <= target_data_out;
            pending_tx_valid <= 1'b1;
        end

        if (tx_active) begin
            bus_data_out <= tx_shift[0];
            bus_data_out_valid <= 1'b1;
            tx_shift <= {1'b0, tx_shift[7:1]};

            if (tx_bits_remaining == 4'd1) begin
                tx_active <= 1'b0;
                tx_bits_remaining <= '0;
            end else begin
                tx_bits_remaining <= tx_bits_remaining - 4'd1;
            end
        end else if (pending_tx_valid && arbiter_grant) begin
            tx_shift <= pending_tx_data;
            tx_bits_remaining <= 4'd8;
            tx_active <= 1'b1;
            pending_tx_valid <= 1'b0;
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        addr_shift <= '0;
        addr_bit_count <= '0;
        addr_buffer <= '0;
        addr_pending <= 1'b0;
        expect_data <= 1'b0;
        data_shift <= '0;
        data_bit_count <= '0;
        data_buffer <= '0;
        data_pending <= 1'b0;
        target_addr_in <= '0;
        target_addr_in_valid <= 1'b0;
        target_data_in <= '0;
        target_data_in_valid <= 1'b0;
    end else begin
        target_addr_in_valid <= 1'b0;
        target_data_in_valid <= 1'b0;

        if (addr_pending) begin
            target_addr_in <= addr_buffer;
            target_addr_in_valid <= 1'b1;
            addr_pending <= 1'b0;
        end

        if (data_pending) begin
            target_data_in <= data_buffer;
            target_data_in_valid <= 1'b1;
            data_pending <= 1'b0;
        end

        if (bus_data_in_valid) begin
            if (!bus_mode) begin
                logic [15:0] next_addr;
                next_addr = addr_shift;
                next_addr[addr_bit_count] = bus_data_in;

                if (addr_bit_count == 5'd15) begin
                    addr_buffer <= next_addr;
                    addr_pending <= 1'b1;
                    addr_shift <= '0;
                    addr_bit_count <= 5'd0;
                    expect_data <= target_rw;
                end else begin
                    addr_shift <= next_addr;
                    addr_bit_count <= addr_bit_count + 5'd1;
                end
            end else if (bus_mode && expect_data && !data_pending) begin
                logic [7:0] next_data;
                next_data = data_shift;
                next_data[data_bit_count] = bus_data_in;

                if (data_bit_count == 3'd7) begin
                    data_buffer <= next_data;
                    data_pending <= 1'b1;
                    data_shift <= '0;
                    data_bit_count <= 3'd0;
                    expect_data <= 1'b0;
                end else begin
                    data_shift <= next_data;
                    data_bit_count <= data_bit_count + 3'd1;
                end
            end
        end
    end
end

endmodule
