`timescale 1ns/1ps

module init_port_tb;
    // Clock and reset
    logic clk;
    logic rst_n;

    // Initiator-facing stimulus
    logic init_req;
    logic arbiter_grant;
    logic [7:0] init_data_out;
    logic init_data_out_valid;
    logic [15:0] init_addr_out;
    logic init_addr_out_valid;
    logic init_rw;
    logic init_ready;
    logic init_bus_mode;
    logic target_split;
    logic target_ack;
    logic bus_data_in_valid;

    // Testbench bus driver (targets the shared serial bus)
    logic tb_drive_en;
    logic tb_drive_value;

    // DUT outputs
    logic init_grant;
    logic [7:0] init_data_in;
    logic init_data_in_valid;
    logic bus_data_out_valid;
    logic arbiter_req;
    logic bus_mode;
    logic init_ack;
    logic bus_init_ready;
    logic bus_init_rw;
    logic init_split_ack;

    wire bus_data;

    // Tri-state hook up between TB and DUT
    assign bus_data = tb_drive_en ? tb_drive_value : 1'bz;

    init_port dut (
        .clk(clk),
        .rst_n(rst_n),
        .init_req(init_req),
        .arbiter_grant(arbiter_grant),
        .init_data_out(init_data_out),
        .init_data_out_valid(init_data_out_valid),
        .init_addr_out(init_addr_out),
        .init_addr_out_valid(init_addr_out_valid),
        .init_rw(init_rw),
        .init_ready(init_ready),
        .init_bus_mode(init_bus_mode),
        .target_split(target_split),
        .target_ack(target_ack),
        .bus_data_in_valid(bus_data_in_valid),
        .bus_data(bus_data),
        .init_grant(init_grant),
        .init_data_in(init_data_in),
        .init_data_in_valid(init_data_in_valid),
        .bus_data_out_valid(bus_data_out_valid),
        .arbiter_req(arbiter_req),
        .bus_mode(bus_mode),
        .init_ack(init_ack),
        .bus_init_ready(bus_init_ready),
        .bus_init_rw(bus_init_rw),
        .init_split_ack(init_split_ack)
    );

    localparam bit [15:0] TEST_ADDR = 16'hA55A;
    localparam bit [7:0] TEST_DATA_WR = 8'h3C;
    localparam bit [7:0] TEST_DATA_RD = 8'h96;

    // Clock generation (50 MHz)
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // Count how many read-valid pulses we observe
    int read_valid_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            read_valid_count <= 0;
        else if (init_data_in_valid)
            read_valid_count <= read_valid_count + 1;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
        end
    endtask

    task automatic drive_address(input bit [15:0] addr);
        bit [15:0] captured;
        int idx;

        captured = '0;
        idx = 0;

        init_bus_mode = 1'b0;
        init_addr_out = addr;
        init_addr_out_valid = 1'b1;
        init_req = 1'b1;
        arbiter_grant = 1'b1;
        init_rw = 1'b1;

        @(posedge clk);
        init_addr_out_valid = 1'b0;

        while (idx < 16) begin
            @(posedge clk);
            if (bus_data_out_valid) begin
                captured[idx] = bus_data;
                idx++;
            end
        end

        if (captured !== addr) begin
            $error("[%0t] Address serialisation mismatch. Expected %h, got %h", $time, addr, captured);
        end else begin
            $display("[%0t] Address serialisation OK (%h)", $time, captured);
        end

        repeat (2) @(posedge clk);
    endtask

    task automatic drive_write_data(input bit [7:0] data);
        bit [7:0] captured;
        int idx;

        captured = '0;
        idx = 0;

        init_bus_mode = 1'b1;
        init_data_out = data;
        init_data_out_valid = 1'b1;
        init_rw = 1'b1;

        @(posedge clk);
        init_data_out_valid = 1'b0;

        while (idx < 8) begin
            @(posedge clk);
            if (bus_data_out_valid) begin
                captured[idx] = bus_data;
                idx++;
            end
        end

        if (captured !== data) begin
            $error("[%0t] Write data serialisation mismatch. Expected %h, got %h", $time, data, captured);
        end else begin
            $display("[%0t] Write data serialisation OK (%h)", $time, captured);
        end

        repeat (2) @(posedge clk);
    endtask

    task automatic drive_read_data(input bit [7:0] data);
        init_req = 1'b0;
        arbiter_grant = 1'b0;
        init_bus_mode = 1'b1;
        init_rw = 1'b0;

        repeat (2) @(posedge clk);

        for (int i = 0; i < 8; i++) begin
            tb_drive_en = 1'b1;
            tb_drive_value = data[i];
            bus_data_in_valid = 1'b1;
            @(posedge clk);
        end

        tb_drive_en = 1'b0;
        tb_drive_value = 1'b0;
        bus_data_in_valid = 1'b0;

        wait (init_data_in_valid);

        if (init_data_in !== data) begin
            $error("[%0t] Read data mismatch. Expected %h, got %h", $time, data, init_data_in);
        end else begin
            $display("[%0t] Read data deserialisation OK (%h)", $time, init_data_in);
        end

        repeat (2) @(posedge clk);
    endtask

    // Main stimulus
    initial begin
        init_req = 1'b0;
        arbiter_grant = 1'b0;
        init_data_out = '0;
        init_data_out_valid = 1'b0;
        init_addr_out = '0;
        init_addr_out_valid = 1'b0;
        init_rw = 1'b0;
        init_ready = 1'b1;
        init_bus_mode = 1'b0;
        target_split = 1'b0;
        target_ack = 1'b0;
        bus_data_in_valid = 1'b0;
        tb_drive_en = 1'b0;
        tb_drive_value = 1'b0;
        rst_n = 1'b0;

        reset_dut();

        drive_address(TEST_ADDR);
        drive_write_data(TEST_DATA_WR);

        @(posedge clk);
        if (init_grant !== arbiter_grant || arbiter_req !== init_req || bus_mode !== init_bus_mode ||
            bus_init_ready !== init_ready || bus_init_rw !== init_rw) begin
            $error("[%0t] Control pass-through checks failed", $time);
        end

        target_ack = 1'b1;
        target_split = 1'b1;
        @(posedge clk);
        if (init_ack !== target_ack || init_split_ack !== target_split) begin
            $error("[%0t] Target handshake pass-through failed", $time);
        end
        target_ack = 1'b0;
        target_split = 1'b0;

        drive_read_data(TEST_DATA_RD);

        if (read_valid_count != 1) begin
            $error("[%0t] Expected exactly one read-valid pulse, observed %0d", $time, read_valid_count);
        end

        repeat (5) @(posedge clk);
        $display("[%0t] init_port testbench completed.", $time);
        $finish;
    end
endmodule
