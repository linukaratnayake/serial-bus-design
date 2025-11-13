module addr_decoder(
    input logic clk,
    input logic rst_n,
    input logic bus_data_in,
    input logic bus_data_in_valid,
    input logic bus_mode, // 1 for data, 0 for address
    input logic bus_rw,   // 1 for write transactions, 0 for reads
    output logic target_1_valid,
    output logic target_2_valid,
    output logic target_3_valid,
    output logic [1:0] sel
);

    function automatic logic [2:0] decode_target(logic [15:0] addr);
        logic [2:0] result;
        result = 3'b000;

        if (addr[15:11] == 5'b00000)
            result[0] = 1'b1; // Slave 1: 0000 0xxx xxxx xxxx
        else if (addr[15:14] == 2'b01)
            result[1] = 1'b1; // Slave 2: 01xx xxxx xxxx xxxx
        else if (addr[15:12] == 4'b1000)
            result[2] = 1'b1; // Slave 3: 1000 xxxx xxxx xxxx

        return result;
    endfunction

    function automatic logic [1:0] encode_sel(logic [2:0] valid_vec);
        if (valid_vec[2])
            return 2'b10;
        else if (valid_vec[1])
            return 2'b01;
        else
            return 2'b00;
    endfunction

    logic [15:0] addr_shift;
    logic [4:0] addr_bit_count;
    logic [2:0] pulse_valids;
    logic [1:0] pulse_sel;
    logic [2:0] hold_valids;
    logic [1:0] hold_sel;
    logic hold_active;
    logic [3:0] data_bit_count;
    logic wait_for_data_phase;

    assign target_1_valid = hold_active ? hold_valids[0] : pulse_valids[0];
    assign target_2_valid = hold_active ? hold_valids[1] : pulse_valids[1];
    assign target_3_valid = hold_active ? hold_valids[2] : pulse_valids[2];
    assign sel = hold_active ? hold_sel : pulse_sel;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_shift <= '0;
            addr_bit_count <= '0;
            pulse_valids <= 3'b000;
            pulse_sel <= 2'b00;
            hold_valids <= 3'b000;
            hold_sel <= 2'b00;
            hold_active <= 1'b0;
            data_bit_count <= 4'd0;
            wait_for_data_phase <= 1'b0;
        end else begin
            pulse_valids <= 3'b000;
            pulse_sel <= 2'b00;

            if (!bus_mode && bus_data_in_valid) begin
                logic [15:0] addr_next;
                addr_next = addr_shift;
                addr_next[addr_bit_count] = bus_data_in;
                addr_shift <= addr_next;

                if (addr_bit_count == 5'd15) begin
                    logic [2:0] decoded_valids;
                    logic [1:0] decoded_sel;

                    decoded_valids = decode_target(addr_next);
                    decoded_sel = encode_sel(decoded_valids);

                    pulse_valids <= decoded_valids;
                    pulse_sel <= decoded_sel;

                    if (bus_rw && |decoded_valids) begin
                        hold_valids <= decoded_valids;
                        hold_sel <= decoded_sel;
                        hold_active <= 1'b1;
                        wait_for_data_phase <= 1'b1;
                        data_bit_count <= 4'd0;
                    end else begin
                        hold_valids <= 3'b000;
                        hold_sel <= 2'b00;
                        hold_active <= 1'b0;
                        wait_for_data_phase <= 1'b0;
                    end

                    addr_bit_count <= 5'd0;
                    addr_shift <= '0;
                end else begin
                    addr_bit_count <= addr_bit_count + 5'd1;
                end
            end else if (!bus_mode && !bus_data_in_valid) begin
                addr_bit_count <= 5'd0;
                addr_shift <= '0;
            end

            if (hold_active) begin
                if (bus_mode && bus_data_in_valid) begin
                    wait_for_data_phase <= 1'b0;
                    data_bit_count <= data_bit_count + 4'd1;
                    if (data_bit_count == 4'd7) begin
                        hold_active <= 1'b0;
                        hold_valids <= 3'b000;
                        hold_sel <= 2'b00;
                        data_bit_count <= 4'd0;
                    end
                end else if (!bus_mode && !bus_data_in_valid && !wait_for_data_phase) begin
                    // Data phase completed cleanly, release the hold.
                    hold_active <= 1'b0;
                    hold_valids <= 3'b000;
                    hold_sel <= 2'b00;
                    data_bit_count <= 4'd0;
                end else if (!bus_mode && !bus_data_in_valid && wait_for_data_phase) begin
                    // No data ever arrived; release the hold so reads can progress.
                    hold_active <= 1'b0;
                    hold_valids <= 3'b000;
                    hold_sel <= 2'b00;
                    wait_for_data_phase <= 1'b0;
                end
            end else begin
                data_bit_count <= 4'd0;
                wait_for_data_phase <= 1'b0;
            end
        end
    end

endmodule
