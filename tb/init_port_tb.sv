`timescale 1ns/1ps

module init_port_tb;
    logic clk;
    logic rst_n;

    logic init_req;
    logic arbiter_grant;
    logic [7:0] init_data_out;
    logic init_data_out_valid;
    logic [15:0] init_addr_out;
    logic init_addr_out_valid;
    logic init_rw;
    logic init_ready;
    logic target_split;
    logic target_ack;
    logic bus_data_in_valid;
    logic bus_data_in;

    logic bus_data_out;
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

    localparam bit [15:0] TEST_ADDR = 16'hA55A;
    localparam bit [7:0] TEST_DATA_WR = 8'h3C;
    localparam bit [7:0] TEST_DATA_RD = 8'h96;

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
        .target_split(target_split),
        .target_ack(target_ack),
        .bus_data_in_valid(bus_data_in_valid),
        .bus_data_in(bus_data_in),
        .bus_data_out(bus_data_out),
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

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

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

    task automatic issue_addr_data(input bit [15:0] addr, input bit [7:0] data);
        bit [23:0] captured;
        bit [15:0] addr_rx;
        bit [7:0] data_rx;
        int bit_idx;

        captured = '0;
        addr_rx = '0;
        data_rx = '0;
        bit_idx = 0;

        init_req = 1'b1;
        arbiter_grant = 1'b1;
        init_rw = 1'b1;
        init_addr_out = addr;
        init_addr_out_valid = 1'b1;
        init_data_out = data;
        init_data_out_valid = 1'b1;

        @(posedge clk);
        init_addr_out_valid = 1'b0;
        init_data_out_valid = 1'b0;

        while (bit_idx < 24) begin
            @(posedge clk);
            if (bus_data_out_valid) begin
                captured[bit_idx] = bus_data_out;
                if (bit_idx < 16) begin
                    if (bus_mode !== 1'b0)
                        $error("[%0t] bus_mode should be 0 during address bits", $time);
                end else begin
                    if (bus_mode !== 1'b1)
                        $error("[%0t] bus_mode should be 1 during data bits", $time);
                end
                bit_idx++;
            end
        end

        addr_rx = captured[15:0];
        data_rx = captured[23:16];

        if (addr_rx !== addr)
            $error("[%0t] Address serialisation mismatch. Expected %h, got %h", $time, addr, addr_rx);
        else
            $display("[%0t] Address serialisation OK (%h)", $time, addr_rx);

        if (data_rx !== data)
            $error("[%0t] Data serialisation mismatch. Expected %h, got %h", $time, data, data_rx);
        else
            $display("[%0t] Data serialisation OK (%h)", $time, data_rx);

        init_req = 1'b0;
        arbiter_grant = 1'b0;
        init_rw = 1'b0;

        repeat (2) @(posedge clk);

        if (bus_mode !== 1'b0)
            $error("[%0t] bus_mode should return to 0 when idle", $time);
    endtask

    task automatic drive_read_data(input bit [7:0] data);
        init_req = 1'b0;
        arbiter_grant = 1'b0;
        init_rw = 1'b0;

        repeat (2) @(posedge clk);

        for (int i = 0; i < 8; i++) begin
            bus_data_in = data[i];
            bus_data_in_valid = 1'b1;
            @(posedge clk);
        end

        bus_data_in_valid = 1'b0;
        bus_data_in = 1'b0;

        wait (init_data_in_valid);

        if (init_data_in !== data)
            $error("[%0t] Read data mismatch. Expected %h, got %h", $time, data, init_data_in);
        else
            $display("[%0t] Read data deserialisation OK (%h)", $time, init_data_in);

        repeat (2) @(posedge clk);
    endtask

    initial begin
        init_req = 1'b0;
        arbiter_grant = 1'b0;
        init_data_out = '0;
        init_data_out_valid = 1'b0;
        init_addr_out = '0;
        init_addr_out_valid = 1'b0;
        init_rw = 1'b0;
        init_ready = 1'b1;
        target_split = 1'b0;
        target_ack = 1'b0;
        bus_data_in_valid = 1'b0;
        bus_data_in = 1'b0;
        rst_n = 1'b0;

        reset_dut();

        issue_addr_data(TEST_ADDR, TEST_DATA_WR);

        @(posedge clk);
        if (init_grant !== arbiter_grant || arbiter_req !== init_req ||
            bus_init_ready !== init_ready || bus_init_rw !== init_rw)
            $error("[%0t] Control pass-through checks failed", $time);

        target_ack = 1'b1;
        target_split = 1'b1;
        @(posedge clk);
        if (init_ack !== target_ack || init_split_ack !== target_split)
            $error("[%0t] Target handshake pass-through failed", $time);
        target_ack = 1'b0;
        target_split = 1'b0;

        drive_read_data(TEST_DATA_RD);

        if (read_valid_count != 1)
            $error("[%0t] Expected exactly one read-valid pulse, observed %0d", $time, read_valid_count);

        repeat (5) @(posedge clk);
        $display("[%0t] init_port testbench completed.", $time);
        $finish;
    end
endmodule
