`timescale 1ns/1ps

module bus_tb;
    logic clk;
    logic rst_n;

    localparam logic [15:0] INIT0_ADDR = 16'h800A;
    localparam logic [7:0]  INIT0_DATA = 8'h5C;
    localparam logic [15:0] INIT1_ADDR = 16'h4102;
    localparam logic [7:0]  INIT1_DATA = 8'hD7;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            repeat (6) @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
        end
    endtask

    // Initiator 0 signals
    logic init0_trigger;
    logic init0_req;
    logic [15:0] init0_addr_out;
    logic init0_addr_out_valid;
    logic [7:0] init0_data_out;
    logic init0_data_out_valid;
    logic init0_rw;
    logic init0_ready;
    logic init0_grant;
    logic [7:0] init0_data_in;
    logic init0_data_in_valid;
    logic init0_ack;
    logic init0_split_ack;
    logic init0_done;
    logic [7:0] init0_read_data;

    // Initiator 1 signals
    logic init1_trigger;
    logic init1_req;
    logic [15:0] init1_addr_out;
    logic init1_addr_out_valid;
    logic [7:0] init1_data_out;
    logic init1_data_out_valid;
    logic init1_rw;
    logic init1_ready;
    logic init1_grant;
    logic [7:0] init1_data_in;
    logic init1_data_in_valid;
    logic init1_ack;
    logic init1_split_ack;
    logic init1_done;
    logic [7:0] init1_read_data;

    // Target 1 signals (unused target, kept to exercise decoder routing)
    logic [7:0] target1_data_out;
    logic target1_data_out_valid;
    logic target1_ack;
    logic target1_ready;
    logic [7:0] target1_data_in;
    logic target1_data_in_valid;
    logic [15:0] target1_addr_in;
    logic target1_addr_in_valid;
    logic target1_rw;

    // Target 2 signals
    logic [7:0] target2_data_out;
    logic target2_data_out_valid;
    logic target2_ack;
    logic target2_ready;
    logic [7:0] target2_data_in;
    logic target2_data_in_valid;
    logic [15:0] target2_addr_in;
    logic target2_addr_in_valid;
    logic target2_rw;

    // Split target (target 3) signals
    logic split_target_req;
    logic [7:0] split_target_data_out;
    logic split_target_data_out_valid;
    logic split_target_ack;
    logic split_target_split_ack;
    logic split_target_ready;
    logic split_target_grant;
    logic [7:0] split_target_data_in;
    logic split_target_data_in_valid;
    logic [15:0] split_target_addr_in;
    logic split_target_addr_in_valid;
    logic split_target_rw;

    initiator #(
        .WRITE_ADDR(INIT0_ADDR),
        .READ_ADDR(INIT0_ADDR),
        .MEM_INIT_DATA(INIT0_DATA)
    ) u_initiator_0 (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(init0_trigger),
        .init_grant(init0_grant),
        .init_ack(init0_ack),
        .init_split_ack(init0_split_ack),
        .init_data_in(init0_data_in),
        .init_data_in_valid(init0_data_in_valid),
        .init_req(init0_req),
        .init_addr_out(init0_addr_out),
        .init_addr_out_valid(init0_addr_out_valid),
        .init_data_out(init0_data_out),
        .init_data_out_valid(init0_data_out_valid),
        .init_rw(init0_rw),
        .init_ready(init0_ready),
        .done(init0_done),
        .read_data_value(init0_read_data)
    );

    initiator #(
        .WRITE_ADDR(INIT1_ADDR),
        .READ_ADDR(INIT1_ADDR),
        .MEM_INIT_DATA(INIT1_DATA)
    ) u_initiator_1 (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(init1_trigger),
        .init_grant(init1_grant),
        .init_ack(init1_ack),
        .init_split_ack(init1_split_ack),
        .init_data_in(init1_data_in),
        .init_data_in_valid(init1_data_in_valid),
        .init_req(init1_req),
        .init_addr_out(init1_addr_out),
        .init_addr_out_valid(init1_addr_out_valid),
        .init_data_out(init1_data_out),
        .init_data_out_valid(init1_data_out_valid),
        .init_rw(init1_rw),
        .init_ready(init1_ready),
        .done(init1_done),
        .read_data_value(init1_read_data)
    );

    bus u_bus (
        .clk(clk),
        .rst_n(rst_n),
        // Initiator 0
        .init0_req(init0_req),
        .init0_data_out(init0_data_out),
        .init0_data_out_valid(init0_data_out_valid),
        .init0_addr_out(init0_addr_out),
        .init0_addr_out_valid(init0_addr_out_valid),
        .init0_rw(init0_rw),
        .init0_ready(init0_ready),
        .init0_grant(init0_grant),
        .init0_data_in(init0_data_in),
        .init0_data_in_valid(init0_data_in_valid),
        .init0_ack(init0_ack),
        .init0_split_ack(init0_split_ack),
        // Initiator 1
        .init1_req(init1_req),
        .init1_data_out(init1_data_out),
        .init1_data_out_valid(init1_data_out_valid),
        .init1_addr_out(init1_addr_out),
        .init1_addr_out_valid(init1_addr_out_valid),
        .init1_rw(init1_rw),
        .init1_ready(init1_ready),
        .init1_grant(init1_grant),
        .init1_data_in(init1_data_in),
        .init1_data_in_valid(init1_data_in_valid),
        .init1_ack(init1_ack),
        .init1_split_ack(init1_split_ack),
        // Target 1
        .target1_data_out(target1_data_out),
        .target1_data_out_valid(target1_data_out_valid),
        .target1_ack(target1_ack),
        .target1_ready(target1_ready),
        .target1_data_in(target1_data_in),
        .target1_data_in_valid(target1_data_in_valid),
        .target1_addr_in(target1_addr_in),
        .target1_addr_in_valid(target1_addr_in_valid),
        .target1_rw(target1_rw),
        // Target 2
        .target2_data_out(target2_data_out),
        .target2_data_out_valid(target2_data_out_valid),
        .target2_ack(target2_ack),
        .target2_ready(target2_ready),
        .target2_data_in(target2_data_in),
        .target2_data_in_valid(target2_data_in_valid),
        .target2_addr_in(target2_addr_in),
        .target2_addr_in_valid(target2_addr_in_valid),
        .target2_rw(target2_rw),
        // Split target (target 3)
        .split_target_req(split_target_req),
        .split_target_data_out(split_target_data_out),
        .split_target_data_out_valid(split_target_data_out_valid),
        .split_target_ack(split_target_ack),
        .split_target_split_ack(split_target_split_ack),
        .split_target_ready(split_target_ready),
        .split_target_grant(split_target_grant),
        .split_target_data_in(split_target_data_in),
        .split_target_data_in_valid(split_target_data_in_valid),
        .split_target_addr_in(split_target_addr_in),
        .split_target_addr_in_valid(split_target_addr_in_valid),
        .split_target_rw(split_target_rw)
    );

    target #(
        .INTERNAL_ADDR_BITS(8)
    ) u_target_1 (
        .clk(clk),
        .rst_n(rst_n),
        .target_addr_in(target1_addr_in),
        .target_addr_in_valid(target1_addr_in_valid),
        .target_data_in(target1_data_in),
        .target_data_in_valid(target1_data_in_valid),
        .target_rw(target1_rw),
        .target_data_out(target1_data_out),
        .target_data_out_valid(target1_data_out_valid),
        .target_ack(target1_ack),
        .target_ready(target1_ready)
    );

    target #(
        .INTERNAL_ADDR_BITS(8)
    ) u_target_2 (
        .clk(clk),
        .rst_n(rst_n),
        .target_addr_in(target2_addr_in),
        .target_addr_in_valid(target2_addr_in_valid),
        .target_data_in(target2_data_in),
        .target_data_in_valid(target2_data_in_valid),
        .target_rw(target2_rw),
        .target_data_out(target2_data_out),
        .target_data_out_valid(target2_data_out_valid),
        .target_ack(target2_ack),
        .target_ready(target2_ready)
    );

    split_target #(
        .INTERNAL_ADDR_BITS(12),
        .READ_LATENCY(4)
    ) u_split_target (
        .clk(clk),
        .rst_n(rst_n),
        .split_grant(split_target_grant),
        .target_addr_in(split_target_addr_in),
        .target_addr_in_valid(split_target_addr_in_valid),
        .target_data_in(split_target_data_in),
        .target_data_in_valid(split_target_data_in_valid),
        .target_rw(split_target_rw),
        .split_req(split_target_req),
        .target_data_out(split_target_data_out),
        .target_data_out_valid(split_target_data_out_valid),
        .target_ack(split_target_ack),
        .target_split_ack(split_target_split_ack),
        .target_ready(split_target_ready)
    );

    int t3_write_ack_count;
    int t3_read_ack_count;
    int t3_split_ack_count;
    int t2_write_ack_count;
    int t2_read_ack_count;
    bit t1_ack_seen;
    bit init0_split_seen;
    bit init1_split_seen;

    always @(posedge clk) begin
        if (split_target_addr_in_valid)
            $display("[%0t] split_target_addr_in_valid addr=%h rw=%0b", $time, split_target_addr_in, split_target_rw);
        if (split_target_split_ack)
            $display("[%0t] split_target_split_ack asserted", $time);
        if (split_target_ack)
            $display("[%0t] split_target_ack (rw=%0b)", $time, split_target_rw);
        if (split_target_data_out_valid)
            $display("[%0t] split_target_data_out_valid data=%02h", $time, split_target_data_out);
        if (split_target_req)
            $display("[%0t] split_target_req active", $time);
        if (split_target_grant)
            $display("[%0t] split_target_grant active", $time);
        if (init0_ack)
            $display("[%0t] init0_ack", $time);
        if (init0_split_ack)
            $display("[%0t] init0_split_ack", $time);
        if (init0_addr_out_valid)
            $display("[%0t] init0_addr_out_valid", $time);
        if (init0_grant)
            $display("[%0t] init0_grant", $time);
        if (init0_data_in_valid)
            $display("[%0t] init0_data_in_valid data=%02h", $time, init0_data_in);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t3_write_ack_count <= 0;
            t3_read_ack_count <= 0;
            t3_split_ack_count <= 0;
            t2_write_ack_count <= 0;
            t2_read_ack_count <= 0;
            t1_ack_seen <= 1'b0;
            init0_split_seen <= 1'b0;
            init1_split_seen <= 1'b0;
        end else begin
            if (split_target_ack && split_target_rw)
                t3_write_ack_count <= t3_write_ack_count + 1;
            else if (split_target_ack && !split_target_rw)
                t3_read_ack_count <= t3_read_ack_count + 1;

            if (split_target_split_ack)
                t3_split_ack_count <= t3_split_ack_count + 1;

            if (target2_ack && target2_rw)
                t2_write_ack_count <= t2_write_ack_count + 1;
            else if (target2_ack && !target2_rw)
                t2_read_ack_count <= t2_read_ack_count + 1;

            if (target1_ack)
                t1_ack_seen <= 1'b1;

            if (init0_split_ack)
                init0_split_seen <= 1'b1;

            if (init1_split_ack)
                init1_split_seen <= 1'b1;
        end
    end

    initial begin
        int cycle_guard;
        init0_trigger = 1'b0;
        init1_trigger = 1'b0;

        reset_dut();

        if (init1_done === 1'b1)
            $error("Initiator 1 should be idle after reset");

        @(posedge clk);
        init0_trigger <= 1'b1;
        @(posedge clk);
        init0_trigger <= 1'b0;

        cycle_guard = 0;
        while (init0_done !== 1'b1) begin
            @(posedge clk);
            cycle_guard++;
            if (cycle_guard > 200) begin
                $error("Initiator 0 did not assert done within timeout");
                break;
            end
        end
        @(posedge clk);

        if (init0_read_data !== INIT0_DATA)
            $error("Initiator 0 read data mismatch: expected %h, got %h", INIT0_DATA, init0_read_data);
        if (t3_write_ack_count != 1)
            $error("Target 3 write ACK count mismatch: %0d", t3_write_ack_count);
        if (t3_read_ack_count != 1)
            $error("Target 3 read ACK count mismatch: %0d", t3_read_ack_count);
        if (t3_split_ack_count != 1)
            $error("Target 3 split ACK count mismatch: %0d", t3_split_ack_count);
        if (!init0_split_seen)
            $error("Initiator 0 never observed a split acknowledgement");
        if (t2_write_ack_count != 0 || t2_read_ack_count != 0)
            $error("Target 2 should be idle during Initiator 0 transaction");
        if (t1_ack_seen)
            $error("Target 1 unexpectedly acknowledged a transfer");

        repeat (6) @(posedge clk);

        init1_trigger <= 1'b1;
        @(posedge clk);
        init1_trigger <= 1'b0;

        cycle_guard = 0;
        while (init1_done !== 1'b1) begin
            @(posedge clk);
            cycle_guard++;
            if (cycle_guard > 2000) begin
                $error("Initiator 1 did not assert done within timeout");
                break;
            end
        end
        @(posedge clk);

        if (init1_read_data !== INIT1_DATA)
            $error("Initiator 1 read data mismatch: expected %h, got %h", INIT1_DATA, init1_read_data);
        if (t2_write_ack_count != 1)
            $error("Target 2 write ACK count mismatch: %0d", t2_write_ack_count);
        if (t2_read_ack_count != 1)
            $error("Target 2 read ACK count mismatch: %0d", t2_read_ack_count);
        if (t3_write_ack_count != 1 || t3_read_ack_count != 1 || t3_split_ack_count != 1)
            $error("Target 3 ACK counters changed during Initiator 1 transaction");
        if (init1_split_seen)
            $error("Initiator 1 should not receive split acknowledgements");
        if (t1_ack_seen)
            $error("Target 1 unexpectedly acknowledged a transfer");

        repeat (10) @(posedge clk);
        $display("[%0t] bus testbench completed successfully", $time);
        $finish;
    end
endmodule
