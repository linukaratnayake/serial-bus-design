`timescale 1ns/1ps

module system_integration_tb;
    // Clock and reset
    logic clk;
    logic rst_n;

    // Initiator stimulus
    logic init_req;
    logic [7:0] init_data_out;
    logic init_data_out_valid;
    logic [15:0] init_addr_out;
    logic init_addr_out_valid;
    logic init_rw;
    logic init_ready;
    logic target_split;
    logic target_ack;

    // Initiator outputs / bus lines
    logic bus_serial;
    logic bus_serial_valid;
    logic bus_mode;
    logic init_grant;
    logic [7:0] init_data_in;
    logic init_data_in_valid;
    logic arbiter_req;
    logic init_ack;
    logic bus_init_ready;
    logic bus_init_rw;
    logic init_split_ack;

    // Connections to arbiter
    logic arbiter_grant;

    // Target port facing signals
    logic bus_data_out_from_target;
    logic bus_data_out_valid_from_target;
    logic [7:0] target_data_in;
    logic target_data_in_valid;
    logic [15:0] target_addr_in;
    logic target_addr_in_valid;
    logic bus_target_ready;
    logic bus_target_rw;
    logic bus_split_ack;
    logic bus_target_ack;

    // Arbiter split-channel wires
    logic arbiter_split_grant;
    logic arbiter_split_req_sig;

    // Stimulus driving the target core side
    logic [7:0] target_data_out_tb;
    logic target_data_out_valid_tb;
    logic target_split_ack_tb;
    logic target_ack_tb;
    logic split_req_tb;

    // Arbiter monitoring
    logic [1:0] arbiter_sel;

    // Address decoder outputs
    logic target_1_valid;
    logic target_2_valid;
    logic target_3_valid;
    logic [1:0] sel;

    // Constants for the scenario (choose address in Slave 3 range 1000 xxxx xxxx xxxx)
    localparam bit [15:0] TARGET3_ADDR = 16'h800A;
    localparam bit [7:0] TARGET_WRITE_DATA = 8'h5C;
    localparam bit [15:0] TARGET3_READ_ADDR = TARGET3_ADDR;
    localparam bit [7:0] TARGET_READ_RESPONSE = TARGET_WRITE_DATA;

    // Instantiate initiator port
    init_port u_init_port (
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
        .bus_data_in_valid(bus_data_out_valid_from_target),
        .bus_data_in(bus_data_out_from_target),
        .bus_data_out(bus_serial),
        .init_grant(init_grant),
        .init_data_in(init_data_in),
        .init_data_in_valid(init_data_in_valid),
        .bus_data_out_valid(bus_serial_valid),
        .arbiter_req(arbiter_req),
        .bus_mode(bus_mode),
        .init_ack(init_ack),
        .bus_init_ready(bus_init_ready),
        .bus_init_rw(bus_init_rw),
        .init_split_ack(init_split_ack)
    );

    // Instantiate split target port (receives serial stream)
    split_target_port u_split_target_port (
        .clk(clk),
        .rst_n(rst_n),
        .split_req(split_req_tb),
        .arbiter_grant(arbiter_split_grant),
        .target_data_out(target_data_out_tb),
        .target_data_out_valid(target_data_out_valid_tb),
        .target_rw(bus_init_rw),
        .target_ready(bus_init_ready),
        .target_split_ack(target_split_ack_tb),
        .target_ack(target_ack_tb),
        .bus_data_in_valid(bus_serial_valid),
        .bus_data_in(bus_serial),
        .bus_mode(bus_mode),
        .bus_data_out(bus_data_out_from_target),
        .split_grant(),
        .target_data_in(target_data_in),
        .target_data_in_valid(target_data_in_valid),
        .target_addr_in(target_addr_in),
        .target_addr_in_valid(target_addr_in_valid),
        .bus_data_out_valid(bus_data_out_valid_from_target),
        .arbiter_split_req(arbiter_split_req_sig),
        .split_ack(),
        .bus_target_ready(bus_target_ready),
        .bus_target_rw(bus_target_rw),
        .bus_split_ack(bus_split_ack),
        .bus_target_ack(bus_target_ack)
    );

    // Instantiate address decoder observing the same bus
    addr_decoder u_addr_decoder (
        .clk(clk),
        .rst_n(rst_n),
        .bus_data_in(bus_serial),
        .bus_data_in_valid(bus_serial_valid),
        .bus_mode(bus_mode),
        .split(1'b0),
        .target_1_valid(target_1_valid),
        .target_2_valid(target_2_valid),
        .target_3_valid(target_3_valid),
        .sel(sel)
    );

    // Instantiate arbiter, only request/grant 1 used
    arbiter u_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req_i_1(arbiter_req),
        .req_i_2(1'b0),
        .req_split(arbiter_split_req_sig),
        .grant_i_1(arbiter_grant),
        .grant_i_2(),
        .grant_split(arbiter_split_grant),
        .sel(arbiter_sel)
    );

    // Clock generation (100 MHz)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            repeat (5) @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
        end
    endtask

    bit decoder_target3_seen_write;
    bit decoder_target3_seen_read;
    bit decoder_wrong_target_seen;
    bit in_read_phase;
    int init_data_in_valid_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decoder_target3_seen_write <= 1'b0;
            decoder_target3_seen_read <= 1'b0;
            decoder_wrong_target_seen <= 1'b0;
            in_read_phase <= 1'b0;
            init_data_in_valid_count <= 0;
        end else begin
            if (target_3_valid && sel == 2'b10) begin
                if (in_read_phase)
                    decoder_target3_seen_read <= 1'b1;
                else
                    decoder_target3_seen_write <= 1'b1;
            end
            if (target_1_valid || target_2_valid || (target_3_valid && sel != 2'b10))
                decoder_wrong_target_seen <= 1'b1;
            if (init_data_in_valid)
                init_data_in_valid_count <= init_data_in_valid_count + 1;
        end
    end

    // Display target activity once both address and data arrive together
    always @(posedge clk) begin
        if (target_addr_in_valid && target_data_in_valid) begin
            $display("[%0t] Target observed %s to addr %h with data %h", $time,
                     bus_target_rw ? "WRITE" : "READ",
                     target_addr_in,
                     target_data_in);
        end
    end

    always @(posedge clk) begin
        if (init_data_in_valid) begin
            $display("[%0t] Initiator received data %h", $time, init_data_in);
        end
    end

    initial begin
        // Default stimulus values
        init_req = 1'b0;
        init_data_out = '0;
        init_data_out_valid = 1'b0;
        init_addr_out = '0;
        init_addr_out_valid = 1'b0;
        init_rw = 1'b1; // Drive a WRITE transaction
        init_ready = 1'b1;
        target_split = 1'b0;
        target_ack = 1'b0;
        target_data_out_tb = '0;
        target_data_out_valid_tb = 1'b0;
    target_split_ack_tb = 1'b0;
    target_ack_tb = 1'b0;
    split_req_tb = 1'b0;

        reset_dut();

        // Start a transaction targeting slave 3
        @(posedge clk);
        init_addr_out <= TARGET3_ADDR;
        init_data_out <= TARGET_WRITE_DATA;
        init_addr_out_valid <= 1'b1;
        init_data_out_valid <= 1'b1;
        init_req <= 1'b1;

        // Wait for arbiter to grant the bus
        wait (arbiter_grant === 1'b1);

        @(posedge clk);
        init_addr_out_valid <= 1'b0;
        init_data_out_valid <= 1'b0;

        // Wait for the target to latch both address and data
        wait (target_addr_in_valid && target_data_in_valid);

        // Hold request for one more cycle then release
        @(posedge clk);
        init_req <= 1'b0;

        repeat (2) @(posedge clk);

        // Checks for write transaction
        if (target_addr_in !== TARGET3_ADDR)
            $error("Target captured wrong address. Expected %h, got %h", TARGET3_ADDR, target_addr_in);

        if (target_data_in !== TARGET_WRITE_DATA)
            $error("Target captured wrong data. Expected %h, got %h", TARGET_WRITE_DATA, target_data_in);

        if (!decoder_target3_seen_write)
            $error("Address decoder never asserted target 3 valid with correct selection");

        if (decoder_wrong_target_seen)
            $error("Address decoder asserted an unexpected target selection");

        if (bus_target_rw !== init_rw)
            $error("Target observed RW=%b but initiator drove %b", bus_target_rw, init_rw);

        // Begin read phase
        in_read_phase = 1'b1;
        init_data_in_valid_count = 0;
        init_rw = 1'b0; // read transaction

        @(posedge clk);
        init_addr_out <= TARGET3_READ_ADDR;
        init_addr_out_valid <= 1'b1;
        init_data_out_valid <= 1'b0;
        init_req <= 1'b1;

        wait (arbiter_grant === 1'b1);

        @(posedge clk);
        init_addr_out_valid <= 1'b0;

        wait (target_addr_in_valid && (bus_target_rw == 1'b0));
        if (target_addr_in !== TARGET3_READ_ADDR)
            $error("Target captured wrong read address. Expected %h, got %h", TARGET3_READ_ADDR, target_addr_in);
        if (target_data_in_valid)
            $error("Target reported data valid during read command");

        @(posedge clk);
        target_split_ack_tb <= 1'b1;
        @(posedge clk);
        target_split_ack_tb <= 1'b0;

        wait (bus_split_ack);

        repeat (2) @(posedge clk);
        split_req_tb <= 1'b1;
        wait (arbiter_split_req_sig);

        wait (arbiter_split_grant);
        @(posedge clk);
        split_req_tb <= 1'b0;

        target_data_out_tb <= TARGET_READ_RESPONSE;
        target_data_out_valid_tb <= 1'b1;
        @(posedge clk);
        target_data_out_valid_tb <= 1'b0;
        target_data_out_tb <= '0;

        target_ack_tb <= 1'b1;
        @(posedge clk);
        target_ack_tb <= 1'b0;

        wait (init_data_in_valid);
        if (init_data_in !== TARGET_READ_RESPONSE)
            $error("Initiator captured wrong read data. Expected %h, got %h", TARGET_READ_RESPONSE, init_data_in);

        @(posedge clk);
        init_req <= 1'b0;

        // Give modules time to settle after read
        repeat (5) @(posedge clk);

        if (!decoder_target3_seen_read)
            $error("Address decoder did not indicate target 3 during read phase");

        if (decoder_wrong_target_seen)
            $error("Address decoder asserted an unexpected target selection");

        if (bus_target_rw !== init_rw)
            $error("Target observed RW=%b but initiator drove %b", bus_target_rw, init_rw);

        if (init_data_in_valid_count != 1)
            $error("Initiator should have seen exactly one data-valid pulse during read, observed %0d", init_data_in_valid_count);

        in_read_phase = 1'b0;

        $display("[%0t] System integration test completed.", $time);
        $finish;
    end

endmodule
