module addr_decoder(
    input logic clk,
    input logic rst_n,
    input logic bus_data_in,
    input logic bus_data_in_valid,
    input logic bus_mode, // 1 for data, 0 for address
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
    logic hold_active;
    logic [2:0] held_valids;
    logic [1:0] held_sel;
    logic data_phase_active;
    logic [3:0] data_bit_count;
    logic [2:0] pending_valids;
    logic [1:0] pending_sel;
    logic pending_load;
    logic clear_pending;

    assign sel = held_sel;
    assign target_1_valid = held_valids[0];
    assign target_2_valid = held_valids[1];
    assign target_3_valid = held_valids[2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_shift <= '0;
            addr_bit_count <= '0;
            hold_active <= 1'b0;
            held_valids <= 3'b000;
            held_sel <= 2'b00;
            data_phase_active <= 1'b0;
            data_bit_count <= 4'd0;
            pending_valids <= 3'b000;
            pending_sel <= 2'b00;
            pending_load <= 1'b0;
            clear_pending <= 1'b0;
        end else begin
            if (pending_load) begin
                held_valids <= pending_valids;
                held_sel <= pending_sel;
                hold_active <= |pending_valids;
                pending_load <= 1'b0;
                clear_pending <= 1'b0;
            end else if (clear_pending) begin
                held_valids <= 3'b000;
                held_sel <= 2'b00;
                hold_active <= 1'b0;
                clear_pending <= 1'b0;
                pending_load <= 1'b0;
            end

            if (bus_mode && hold_active && bus_data_in_valid) begin
                logic [3:0] next_count;
                next_count = data_phase_active ? (data_bit_count + 4'd1) : 4'd1;

                if (next_count == 4'd8) begin
                    clear_pending <= 1'b1;
                    data_phase_active <= 1'b0;
                    data_bit_count <= 4'd0;
                end else begin
                    data_phase_active <= 1'b1;
                    data_bit_count <= next_count;
                end
            end else if (!bus_mode) begin
                data_phase_active <= 1'b0;
                data_bit_count <= 4'd0;
            end

            // Allow a fresh address to be captured even if a prior selection is held.
            if (!bus_mode && bus_data_in_valid) begin
                logic [15:0] addr_next;
                addr_next = {bus_data_in, addr_shift[15:1]};
                addr_shift <= addr_next;

                if (addr_bit_count == 5'd15) begin
                    logic [2:0] decoded_valids;
                    logic [1:0] decoded_sel;

                    decoded_valids = decode_target(addr_next);
                    decoded_sel = encode_sel(decoded_valids);

                    pending_valids <= decoded_valids;
                    pending_sel <= decoded_sel;
                    pending_load <= 1'b1;
                    data_phase_active <= 1'b0;
                    data_bit_count <= 4'd0;
                    addr_bit_count <= 5'd0;
                end else begin
                    addr_bit_count <= addr_bit_count + 5'd1;
                end
            end

            if (!hold_active && !bus_mode && !bus_data_in_valid) begin
                data_phase_active <= 1'b0;
                data_bit_count <= 4'd0;
            end
        end
    end

endmodule
