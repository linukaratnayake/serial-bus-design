`timescale 1ns/1ps

module split_target_port_tb;
    // Clock and reset
    logic clk;
    logic rst_n;

    // Target-facing stimulus
    logic split_req;
    logic arbiter_grant;
    logic [7:0] target_data_out;
    logic target_data_out_valid;
    logic target_rw;
    logic target_ready;
    logic target_split_ack;
    logic target_ack;
    logic bus_data_in_valid;
    logic bus_data_in;

    // DUT outputs
    logic bus_data_out;
    logic split_grant;
    logic [7:0] target_data_in;
    logic target_data_in_valid;
    logic bus_data_out_valid;
    logic arbiter_split_req;
    logic split_ack;
    logic bus_target_ready;
    logic bus_target_rw;
    logic bus_split_ack;
    logic bus_target_ack;

    localparam bit [7:0] TEST_WRITE_DATA = 8'hC5;
    localparam bit [7:0] TEST_READ_DATA  = 8'h2F;

    split_target_port dut (
        .clk(clk),
        .rst_n(rst_n),
        .split_req(split_req),
        .arbiter_grant(arbiter_grant),
        .target_data_out(target_data_out),
        .target_data_out_valid(target_data_out_valid),
        .target_rw(target_rw),
        .target_ready(target_ready),
        .target_split_ack(target_split_ack),
        .target_ack(target_ack),
        .bus_data_in_valid(bus_data_in_valid),
        .bus_data_in(bus_data_in),
        .bus_data_out(bus_data_out),
        .split_grant(split_grant),
        .target_data_in(target_data_in),
        .target_data_in_valid(target_data_in_valid),
        .bus_data_out_valid(bus_data_out_valid),
        .arbiter_split_req(arbiter_split_req),
        .split_ack(split_ack),
        .bus_target_ready(bus_target_ready),
        .bus_target_rw(bus_target_rw),
        .bus_split_ack(bus_split_ack),
        .bus_target_ack(bus_target_ack)
    );

    // Clock generation (50 MHz)
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
        end
    endtask

    task automatic send_write_byte(input bit [7:0] data);
        bit [7:0] captured;
        int idx;

        captured = '0;
        idx = 0;

        target_rw = 1'b1;
        target_data_out = data;
        target_data_out_valid = 1'b1;
        @(posedge clk);
        target_data_out_valid = 1'b0;

        while (idx < 8) begin
            @(posedge clk);
            if (bus_data_out_valid) begin
                captured[idx] = bus_data_out;
                idx++;
            end
        end

        if (captured !== data) begin
            $error("[%0t] Target write serialisation mismatch. Expected %h, got %h", $time, data, captured);
        end else begin
            $display("[%0t] Target write serialisation OK (%h)", $time, captured);
        end

        repeat (2) @(posedge clk);
    endtask

    task automatic drive_bus_read(input bit [7:0] data);
        target_rw = 1'b0;
        bus_data_in_valid = 1'b0;
        bus_data_in = 1'b0;

        repeat (2) @(posedge clk);

        for (int i = 0; i < 8; i++) begin
            bus_data_in = data[i];
            bus_data_in_valid = 1'b1;
            @(posedge clk);
        end

        bus_data_in_valid = 1'b0;
        bus_data_in = 1'b0;

        wait (target_data_in_valid);

        if (target_data_in !== data) begin
            $error("[%0t] Target read deserialisation mismatch. Expected %h, got %h", $time, data, target_data_in);
        end else begin
            $display("[%0t] Target read deserialisation OK (%h)", $time, target_data_in);
        end

        repeat (2) @(posedge clk);
    endtask

    // Count read-valid pulses for sanity
    int read_valid_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            read_valid_count <= 0;
        else if (target_data_in_valid)
            read_valid_count <= read_valid_count + 1;
    end

    initial begin
        split_req = 1'b0;
        arbiter_grant = 1'b0;
        target_data_out = '0;
        target_data_out_valid = 1'b0;
        target_rw = 1'b0;
        target_ready = 1'b0;
        target_split_ack = 1'b0;
        target_ack = 1'b0;
        bus_data_in_valid = 1'b0;
        bus_data_in = 1'b0;
        rst_n = 1'b0;

        reset_dut();

        split_req = 1'b1;
        arbiter_grant = 1'b1;
        target_ready = 1'b1;
        target_split_ack = 1'b1;
        target_ack = 1'b1;
        @(posedge clk);
        if (split_grant !== arbiter_grant || arbiter_split_req !== split_req ||
            bus_target_ready !== target_ready || bus_target_rw !== target_rw ||
            bus_split_ack !== target_split_ack || bus_target_ack !== target_ack) begin
            $error("[%0t] Control pass-through checks failed", $time);
        end
        target_split_ack = 1'b0;
        target_ack = 1'b0;

        send_write_byte(TEST_WRITE_DATA);
        drive_bus_read(TEST_READ_DATA);

        if (read_valid_count != 1) begin
            $error("[%0t] Expected exactly one read-valid pulse, observed %0d", $time, read_valid_count);
        end

        repeat (5) @(posedge clk);
        $display("[%0t] split_target_port testbench completed.", $time);
        $finish;
    end
endmodule
