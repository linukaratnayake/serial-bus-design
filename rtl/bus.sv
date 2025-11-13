module bus (
    input  logic clk,
    input  logic rst_n,

    // Initiator 0 interface
    input  logic init0_req,
    input  logic [7:0] init0_data_out,
    input  logic init0_data_out_valid,
    input  logic [15:0] init0_addr_out,
    input  logic init0_addr_out_valid,
    input  logic init0_rw,
    input  logic init0_ready,
    output logic init0_grant,
    output logic [7:0] init0_data_in,
    output logic init0_data_in_valid,
    output logic init0_ack,
    output logic init0_split_ack,

    // Initiator 1 interface
    input  logic init1_req,
    input  logic [7:0] init1_data_out,
    input  logic init1_data_out_valid,
    input  logic [15:0] init1_addr_out,
    input  logic init1_addr_out_valid,
    input  logic init1_rw,
    input  logic init1_ready,
    output logic init1_grant,
    output logic [7:0] init1_data_in,
    output logic init1_data_in_valid,
    output logic init1_ack,
    output logic init1_split_ack,

    // Target 1 interface
    input  logic [7:0] target1_data_out,
    input  logic target1_data_out_valid,
    input  logic target1_ack,
    input  logic target1_ready,
    output logic [7:0] target1_data_in,
    output logic target1_data_in_valid,
    output logic [15:0] target1_addr_in,
    output logic target1_addr_in_valid,
    output logic target1_rw,

    // Target 2 interface
    input  logic [7:0] target2_data_out,
    input  logic target2_data_out_valid,
    input  logic target2_ack,
    input  logic target2_ready,
    output logic [7:0] target2_data_in,
    output logic target2_data_in_valid,
    output logic [15:0] target2_addr_in,
    output logic target2_addr_in_valid,
    output logic target2_rw,

    // Split target (target 3) interface
    input  logic split_target_req,
    input  logic [7:0] split_target_data_out,
    input  logic split_target_data_out_valid,
    input  logic split_target_ack,
    input  logic split_target_split_ack,
    input  logic split_target_ready,
    output logic split_target_grant,
    output logic [7:0] split_target_data_in,
    output logic split_target_data_in_valid,
    output logic [15:0] split_target_addr_in,
    output logic split_target_addr_in_valid,
    output logic split_target_rw
);

    // Arbitration and decoding signals
    logic arbiter_grant_i1;
    logic arbiter_grant_i2;
    logic arbiter_grant_split;
    logic [1:0] arbiter_sel;

    logic target_1_valid;
    logic target_2_valid;
    logic target_3_valid;
    logic [1:0] decoder_sel;

    // Shared bus signals
    logic forward_data_bit;
    logic forward_data_valid;
    logic forward_bus_mode;
    logic forward_bus_rw;

    logic [1:0] backward_sel;
    logic backward_data_bit;
    logic backward_data_valid;
    logic backward_target_ack;
    logic backward_split_ack;

    // Initiator port side wiring
    logic init0_bus_data_out;
    logic init0_bus_data_out_valid;
    logic init0_bus_mode;
    logic init0_bus_init_rw;
    logic init0_arbiter_req;
    logic init0_bus_data_in;
    logic init0_bus_data_in_valid;
    logic init0_target_ack_in;
    logic init0_target_split_in;

    logic init1_bus_data_out;
    logic init1_bus_data_out_valid;
    logic init1_bus_mode;
    logic init1_bus_init_rw;
    logic init1_arbiter_req;
    logic init1_bus_data_in;
    logic init1_bus_data_in_valid;
    logic init1_target_ack_in;
    logic init1_target_split_in;

    init_port u_init_port_0 (
        .clk(clk),
        .rst_n(rst_n),
        .init_req(init0_req),
        .arbiter_grant(arbiter_grant_i1),
        .init_data_out(init0_data_out),
        .init_data_out_valid(init0_data_out_valid),
        .init_addr_out(init0_addr_out),
        .init_addr_out_valid(init0_addr_out_valid),
        .init_rw(init0_rw),
        .init_ready(init0_ready),
        .target_split(init0_target_split_in),
        .target_ack(init0_target_ack_in),
        .bus_data_in_valid(init0_bus_data_in_valid),
        .bus_data_in(init0_bus_data_in),
        .bus_data_out(init0_bus_data_out),
        .init_grant(init0_grant),
        .init_data_in(init0_data_in),
        .init_data_in_valid(init0_data_in_valid),
        .bus_data_out_valid(init0_bus_data_out_valid),
        .arbiter_req(init0_arbiter_req),
        .bus_mode(init0_bus_mode),
        .init_ack(init0_ack),
        .bus_init_ready(),
        .bus_init_rw(init0_bus_init_rw),
        .init_split_ack(init0_split_ack)
    );

    init_port u_init_port_1 (
        .clk(clk),
        .rst_n(rst_n),
        .init_req(init1_req),
        .arbiter_grant(arbiter_grant_i2),
        .init_data_out(init1_data_out),
        .init_data_out_valid(init1_data_out_valid),
        .init_addr_out(init1_addr_out),
        .init_addr_out_valid(init1_addr_out_valid),
        .init_rw(init1_rw),
        .init_ready(init1_ready),
        .target_split(init1_target_split_in),
        .target_ack(init1_target_ack_in),
        .bus_data_in_valid(init1_bus_data_in_valid),
        .bus_data_in(init1_bus_data_in),
        .bus_data_out(init1_bus_data_out),
        .init_grant(init1_grant),
        .init_data_in(init1_data_in),
        .init_data_in_valid(init1_data_in_valid),
        .bus_data_out_valid(init1_bus_data_out_valid),
        .arbiter_req(init1_arbiter_req),
        .bus_mode(init1_bus_mode),
        .init_ack(init1_ack),
        .bus_init_ready(),
        .bus_init_rw(init1_bus_init_rw),
        .init_split_ack(init1_split_ack)
    );

    // Target port wiring
    logic [7:0] target1_data_in_int;
    logic target1_data_in_valid_int;
    logic [15:0] target1_addr_in_int;
    logic target1_addr_in_valid_int;
    logic target1_bus_data_out;
    logic target1_bus_data_out_valid;
    logic target1_bus_target_ack;
    logic target1_rw_int;

    target_port u_target_port_1 (
        .clk(clk),
        .rst_n(rst_n),
        .target_data_out(target1_data_out),
        .target_data_out_valid(target1_data_out_valid),
        .target_rw(target1_rw_int),
        .target_ready(target1_ready),
        .target_ack(target1_ack),
        .decoder_valid(target_1_valid),
        .bus_data_in_valid(forward_data_valid),
        .bus_data_in(forward_data_bit),
        .bus_mode(forward_bus_mode),
        .bus_data_out(target1_bus_data_out),
        .target_data_in(target1_data_in_int),
        .target_data_in_valid(target1_data_in_valid_int),
        .target_addr_in(target1_addr_in_int),
        .target_addr_in_valid(target1_addr_in_valid_int),
        .bus_data_out_valid(target1_bus_data_out_valid),
        .bus_target_ready(),
        .bus_target_rw(),
        .bus_target_ack(target1_bus_target_ack)
    );

    assign target1_data_in = target1_data_in_int;
    assign target1_data_in_valid = target1_data_in_valid_int;
    assign target1_addr_in = target1_addr_in_int;
    assign target1_addr_in_valid = target1_addr_in_valid_int;

    logic [7:0] target2_data_in_int;
    logic target2_data_in_valid_int;
    logic [15:0] target2_addr_in_int;
    logic target2_addr_in_valid_int;
    logic target2_bus_data_out;
    logic target2_bus_data_out_valid;
    logic target2_bus_target_ack;
    logic target2_rw_int;

    target_port u_target_port_2 (
        .clk(clk),
        .rst_n(rst_n),
        .target_data_out(target2_data_out),
        .target_data_out_valid(target2_data_out_valid),
        .target_rw(target2_rw_int),
        .target_ready(target2_ready),
        .target_ack(target2_ack),
        .decoder_valid(target_2_valid),
        .bus_data_in_valid(forward_data_valid),
        .bus_data_in(forward_data_bit),
        .bus_mode(forward_bus_mode),
        .bus_data_out(target2_bus_data_out),
        .target_data_in(target2_data_in_int),
        .target_data_in_valid(target2_data_in_valid_int),
        .target_addr_in(target2_addr_in_int),
        .target_addr_in_valid(target2_addr_in_valid_int),
        .bus_data_out_valid(target2_bus_data_out_valid),
        .bus_target_ready(),
        .bus_target_rw(),
        .bus_target_ack(target2_bus_target_ack)
    );

    assign target2_data_in = target2_data_in_int;
    assign target2_data_in_valid = target2_data_in_valid_int;
    assign target2_addr_in = target2_addr_in_int;
    assign target2_addr_in_valid = target2_addr_in_valid_int;

    // Split target port wiring
    logic [7:0] target3_data_in_int;
    logic target3_data_in_valid_int;
    logic [15:0] target3_addr_in_int;
    logic target3_addr_in_valid_int;
    logic target3_bus_data_out;
    logic target3_bus_data_out_valid;
    logic target3_bus_target_ack;
    logic target3_bus_split_ack;
    logic split_unused_ack;
    logic split_target_rw_int;
    logic split_arbiter_req;

    split_target_port u_split_target_port (
        .clk(clk),
        .rst_n(rst_n),
        .split_req(split_target_req),
        .arbiter_grant(arbiter_grant_split),
        .target_data_out(split_target_data_out),
        .target_data_out_valid(split_target_data_out_valid),
        .target_rw(split_target_rw_int),
        .target_ready(split_target_ready),
        .target_split_ack(split_target_split_ack),
        .target_ack(split_target_ack),
        .decoder_valid(target_3_valid),
        .bus_data_in_valid(forward_data_valid),
        .bus_data_in(forward_data_bit),
        .bus_mode(forward_bus_mode),
        .bus_data_out(target3_bus_data_out),
        .split_grant(split_target_grant),
        .target_data_in(target3_data_in_int),
        .target_data_in_valid(target3_data_in_valid_int),
        .target_addr_in(target3_addr_in_int),
        .target_addr_in_valid(target3_addr_in_valid_int),
        .bus_data_out_valid(target3_bus_data_out_valid),
        .arbiter_split_req(split_arbiter_req),
        .split_ack(split_unused_ack),
        .bus_target_ready(),
        .bus_target_rw(),
        .bus_split_ack(target3_bus_split_ack),
        .bus_target_ack(target3_bus_target_ack)
    );

    assign split_target_data_in = target3_data_in_int;
    assign split_target_data_in_valid = target3_data_in_valid_int;
    assign split_target_addr_in = target3_addr_in_int;
    assign split_target_addr_in_valid = target3_addr_in_valid_int;

    arbiter u_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req_i_1(init0_arbiter_req),
        .req_i_2(init1_arbiter_req),
        .req_split(split_arbiter_req),
        .grant_i_1(arbiter_grant_i1),
        .grant_i_2(arbiter_grant_i2),
        .grant_split(arbiter_grant_split),
        .sel(arbiter_sel)
    );

    addr_decoder u_addr_decoder (
        .clk(clk),
        .rst_n(rst_n),
        .bus_data_in(forward_data_bit),
        .bus_data_in_valid(forward_data_valid),
        .bus_mode(forward_bus_mode),
        .target_1_valid(target_1_valid),
        .target_2_valid(target_2_valid),
        .target_3_valid(target_3_valid),
        .sel(decoder_sel)
    );

    always_comb begin
        forward_data_bit = 1'b0;
        forward_data_valid = 1'b0;
        forward_bus_mode = 1'b0;
        forward_bus_rw = 1'b0;

        unique case (arbiter_sel)
            2'b01: begin
                forward_data_bit = init0_bus_data_out;
                forward_data_valid = init0_bus_data_out_valid;
                forward_bus_mode = init0_bus_mode;
                forward_bus_rw = init0_bus_init_rw;
            end
            2'b10: begin
                forward_data_bit = init1_bus_data_out;
                forward_data_valid = init1_bus_data_out_valid;
                forward_bus_mode = init1_bus_mode;
                forward_bus_rw = init1_bus_init_rw;
            end
            default: ;
        endcase
    end

    assign target1_rw_int = forward_bus_rw;
    assign target2_rw_int = forward_bus_rw;
    assign split_target_rw_int = forward_bus_rw;
    assign target1_rw = target1_rw_int;
    assign target2_rw = target2_rw_int;
    assign split_target_rw = split_target_rw_int;

    always_comb begin
        backward_sel = decoder_sel;
        if (arbiter_grant_split)
            backward_sel = 2'b10;

        backward_data_bit = 1'b0;
        backward_data_valid = 1'b0;
        backward_target_ack = 1'b0;
        backward_split_ack = 1'b0;

        unique case (backward_sel)
            2'b00: begin
                backward_data_bit = target1_bus_data_out;
                backward_data_valid = target1_bus_data_out_valid;
                backward_target_ack = target1_bus_target_ack;
            end
            2'b01: begin
                backward_data_bit = target2_bus_data_out;
                backward_data_valid = target2_bus_data_out_valid;
                backward_target_ack = target2_bus_target_ack;
            end
            2'b10: begin
                backward_data_bit = target3_bus_data_out;
                backward_data_valid = target3_bus_data_out_valid;
                backward_target_ack = target3_bus_target_ack;
                backward_split_ack = target3_bus_split_ack;
            end
            default: ;
        endcase
    end

    // Remember which initiator issued the outstanding split transaction so the return path can be steered correctly.
    logic split_owner;
    logic split_owner_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            split_owner <= 1'b0;
            split_owner_valid <= 1'b0;
        end else begin
            if (backward_split_ack && (arbiter_grant_i1 || arbiter_grant_i2)) begin
                split_owner <= arbiter_grant_i2;
                split_owner_valid <= 1'b1;
            end else if (arbiter_grant_split && backward_target_ack) begin
                split_owner_valid <= 1'b0;
            end
        end
    end

    // Decide which initiator receives the return bus each cycle
    logic init0_receive_back;
    logic init1_receive_back;

    always_comb begin
        init0_receive_back = 1'b0;
        init1_receive_back = 1'b0;

        if (arbiter_grant_split) begin
            if (split_owner_valid) begin
                init0_receive_back = (split_owner == 1'b0);
                init1_receive_back = (split_owner == 1'b1);
            end
        end else begin
            init0_receive_back = arbiter_grant_i1;
            init1_receive_back = arbiter_grant_i2;
        end
    end

    assign init0_bus_data_in = init0_receive_back ? backward_data_bit : 1'b0;
    assign init0_bus_data_in_valid = init0_receive_back ? backward_data_valid : 1'b0;
    assign init0_target_ack_in = init0_receive_back ? backward_target_ack : 1'b0;
    assign init0_target_split_in = init0_receive_back ? backward_split_ack : 1'b0;

    assign init1_bus_data_in = init1_receive_back ? backward_data_bit : 1'b0;
    assign init1_bus_data_in_valid = init1_receive_back ? backward_data_valid : 1'b0;
    assign init1_target_ack_in = init1_receive_back ? backward_target_ack : 1'b0;
    assign init1_target_split_in = init1_receive_back ? backward_split_ack : 1'b0;

endmodule
