typedef struct packed {
    logic        is_write;
    logic [15:0] addr;
    logic [7:0]  write_data;
} bus_bridge_req_t;

typedef struct packed {
    logic        is_write;
    logic [7:0]  read_data;
} bus_bridge_resp_t;

module bus_bridge_target_if #(
    parameter logic [15:0] BRIDGE_BASE_ADDR = 16'h8000,
    parameter int unsigned TARGET0_SIZE = 16'd2048,
    parameter int unsigned TARGET1_SIZE = 16'd4096,
    parameter int unsigned TARGET2_SIZE = 16'd4096,
    parameter logic [15:0] BUSB_TARGET0_BASE = 16'h0000,
    parameter logic [15:0] BUSB_TARGET1_BASE = 16'h4000,
    parameter logic [15:0] BUSB_TARGET2_BASE = 16'h8000
)(
    input  logic clk,
    input  logic rst_n,
    input  logic split_grant,
    input  logic [15:0] target_addr_in,
    input  logic target_addr_in_valid,
    input  logic [7:0] target_data_in,
    input  logic target_data_in_valid,
    input  logic target_rw,
    output logic split_req,
    output logic [7:0] target_data_out,
    output logic target_data_out_valid,
    output logic target_ack,
    output logic target_split_ack,
    output logic target_ready,
    output logic [7:0] split_target_last_write,
    output logic req_valid,
    input  logic req_ready,
    output bus_bridge_req_t req_payload,
    input  logic resp_valid,
    output logic resp_ready,
    input  bus_bridge_resp_t resp_payload
);

    localparam int unsigned TOTAL_SPAN = TARGET0_SIZE + TARGET1_SIZE + TARGET2_SIZE;

    typedef enum logic [2:0] {
        TGT_IDLE,
        TGT_WAIT_WRITE_DATA,
        TGT_SEND_REQ,
        TGT_WAIT_RESPONSE,
        TGT_WAIT_READ_GRANT
    } target_state_t;

    target_state_t state;
    logic [15:0] current_addr_b;
    logic [7:0] current_write_data;
    logic current_is_write;
    logic [7:0] pending_read_data;
    logic [7:0] inflight_write_data;
    bus_bridge_req_t request_buffer;

    function automatic logic [15:0] map_to_bus_b(
        input logic [15:0] addr,
        output logic valid
    );
        int unsigned offset;
        logic [15:0] mapped;

        valid = 1'b0;
        mapped = 16'd0;
        if (addr < BRIDGE_BASE_ADDR)
            return mapped;

        offset = int'(addr) - int'(BRIDGE_BASE_ADDR);
        if (offset >= TOTAL_SPAN)
            return mapped;

        if (offset < TARGET0_SIZE) begin
            valid = 1'b1;
            mapped = BUSB_TARGET0_BASE + 16'(offset);
        end else if (offset < (TARGET0_SIZE + TARGET1_SIZE)) begin
            valid = 1'b1;
            mapped = BUSB_TARGET1_BASE + 16'(offset - TARGET0_SIZE);
        end else begin
            valid = 1'b1;
            mapped = BUSB_TARGET2_BASE + 16'(offset - TARGET0_SIZE - TARGET1_SIZE);
        end

        return mapped;
    endfunction

    assign target_ready = 1'b1;
    assign req_payload = request_buffer;
    assign resp_ready = (state == TGT_WAIT_RESPONSE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= TGT_IDLE;
            req_valid <= 1'b0;
            split_req <= 1'b0;
            target_data_out <= '0;
            target_data_out_valid <= 1'b0;
            target_ack <= 1'b0;
            target_split_ack <= 1'b0;
            split_target_last_write <= '0;
            current_addr_b <= '0;
            current_write_data <= '0;
            current_is_write <= 1'b0;
            pending_read_data <= '0;
            inflight_write_data <= '0;
            request_buffer <= '0;
        end else begin
            target_data_out_valid <= 1'b0;
            target_ack <= 1'b0;
            target_split_ack <= 1'b0;

            case (state)
                TGT_IDLE: begin
                    split_req <= 1'b0;
                    if (target_addr_in_valid) begin
                        logic mapped_valid;
                        logic [15:0] mapped_addr;

                        mapped_addr = map_to_bus_b(target_addr_in, mapped_valid);
                        current_addr_b <= mapped_addr;
                        current_is_write <= target_rw;
                        current_write_data <= target_data_in;
                        target_split_ack <= 1'b1;

                        if (!mapped_valid) begin
                            target_ack <= 1'b1;
                            target_data_out <= 8'h00;
                            target_data_out_valid <= (target_rw == 1'b0);
                            state <= TGT_IDLE;
                        end else if (target_rw && !target_data_in_valid) begin
                            state <= TGT_WAIT_WRITE_DATA;
                        end else begin
                            state <= TGT_SEND_REQ;
                        end
                    end
                end

                TGT_WAIT_WRITE_DATA: begin
                    if (target_data_in_valid) begin
                        current_write_data <= target_data_in;
                        state <= TGT_SEND_REQ;
                    end
                end

                TGT_SEND_REQ: begin
                    request_buffer.is_write <= current_is_write;
                    request_buffer.addr <= current_addr_b;
                    request_buffer.write_data <= current_write_data;
                    req_valid <= 1'b1;

                    if (req_ready) begin
                        req_valid <= 1'b0;
                        inflight_write_data <= current_write_data;
                        state <= TGT_WAIT_RESPONSE;
                    end
                end

                TGT_WAIT_RESPONSE: begin
                    split_req <= 1'b0;
                    if (resp_valid && resp_ready) begin
                        if (resp_payload.is_write) begin
                            target_ack <= 1'b1;
                            split_target_last_write <= inflight_write_data;
                            state <= TGT_IDLE;
                        end else begin
                            pending_read_data <= resp_payload.read_data;
                            split_req <= 1'b1;
                            state <= TGT_WAIT_READ_GRANT;
                        end
                    end
                end

                TGT_WAIT_READ_GRANT: begin
                    split_req <= 1'b1;
                    if (split_grant) begin
                        split_req <= 1'b0;
                        target_data_out <= pending_read_data;
                        target_data_out_valid <= 1'b1;
                        target_ack <= 1'b1;
                        state <= TGT_IDLE;
                    end
                end

                default: state <= TGT_IDLE;
            endcase

        end
    end
endmodule

module bus_bridge_initiator_if(
    input  logic clk,
    input  logic rst_n,
    input  logic req_valid,
    output logic req_ready,
    input  bus_bridge_req_t req_payload,
    output logic resp_valid,
    input  logic resp_ready,
    output bus_bridge_resp_t resp_payload,
    output logic init_req,
    output logic [15:0] init_addr_out,
    output logic init_addr_out_valid,
    output logic [7:0] init_data_out,
    output logic init_data_out_valid,
    output logic init_rw,
    output logic init_ready,
    input  logic init_grant,
    input  logic [7:0] init_data_in,
    input  logic init_data_in_valid,
    input  logic init_ack,
    input  logic init_split_ack
);

    typedef enum logic [1:0] {
        BI_IDLE,
        BI_SEND,
        BI_WAIT_ACK,
        BI_RESP_HOLD
    } initiator_state_t;

    initiator_state_t state;
    bus_bridge_req_t active_req;
    bus_bridge_resp_t response_buffer;
    logic init_req_reg;
    logic init_addr_valid_reg;
    logic init_data_valid_reg;
    logic init_rw_reg;
    logic addr_captured;
    logic data_captured;
    logic [7:0] read_data_buffer;
    logic read_data_valid;
    logic resp_valid_reg;

    assign req_ready = (state == BI_IDLE);
    assign init_addr_out = active_req.addr;
    assign init_addr_out_valid = init_addr_valid_reg;
    assign init_data_out = active_req.write_data;
    assign init_data_out_valid = init_data_valid_reg;
    assign init_req = init_req_reg;
    assign init_rw = init_rw_reg;
    assign init_ready = 1'b1;
    assign resp_valid = resp_valid_reg;
    assign resp_payload = response_buffer;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= BI_IDLE;
            active_req <= '0;
            response_buffer <= '0;
            init_req_reg <= 1'b0;
            init_addr_valid_reg <= 1'b0;
            init_data_valid_reg <= 1'b0;
            init_rw_reg <= 1'b1;
            addr_captured <= 1'b0;
            data_captured <= 1'b0;
            read_data_buffer <= '0;
            read_data_valid <= 1'b0;
            resp_valid_reg <= 1'b0;
        end else begin
            if (init_data_in_valid) begin
                read_data_buffer <= init_data_in;
                read_data_valid <= 1'b1;
            end

            case (state)
                BI_IDLE: begin
                    init_req_reg <= 1'b0;
                    init_addr_valid_reg <= 1'b0;
                    init_data_valid_reg <= 1'b0;
                    resp_valid_reg <= 1'b0;
                    read_data_valid <= 1'b0;
                    addr_captured <= 1'b0;
                    data_captured <= 1'b0;
                    if (req_valid) begin
                        active_req <= req_payload;
                        init_req_reg <= 1'b1;
                        init_rw_reg <= req_payload.is_write;
                        init_addr_valid_reg <= 1'b1;
                        init_data_valid_reg <= req_payload.is_write;
                        addr_captured <= 1'b0;
                        data_captured <= ~req_payload.is_write;
                        state <= BI_SEND;
                    end
                end

                BI_SEND: begin
                    if (!addr_captured && init_grant && init_addr_valid_reg) begin
                        addr_captured <= 1'b1;
                        init_addr_valid_reg <= 1'b0;
                    end

                    if (active_req.is_write && !data_captured && init_grant && init_data_valid_reg) begin
                        data_captured <= 1'b1;
                        init_data_valid_reg <= 1'b0;
                    end

                    if (addr_captured && data_captured) begin
                        state <= BI_WAIT_ACK;
                    end
                end

                BI_WAIT_ACK: begin
                    if (init_split_ack)
                        init_req_reg <= 1'b0;

                    if (init_ack) begin
                        init_req_reg <= 1'b0;
                        response_buffer.is_write <= active_req.is_write;
                        response_buffer.read_data <= read_data_valid ? read_data_buffer : 8'h00;
                        resp_valid_reg <= 1'b1;
                        state <= BI_RESP_HOLD;
                    end
                end

                BI_RESP_HOLD: begin
                    if (resp_ready) begin
                        resp_valid_reg <= 1'b0;
                        state <= BI_IDLE;
                    end
                end

                default: state <= BI_IDLE;
            endcase
        end
    end
endmodule

module bus_bridge #(
    parameter logic [15:0] BRIDGE_BASE_ADDR = 16'h8000,
    parameter int unsigned TARGET0_SIZE = 16'd2048,
    parameter int unsigned TARGET1_SIZE = 16'd4096,
    parameter int unsigned TARGET2_SIZE = 16'd4096,
    parameter logic [15:0] BUSB_TARGET0_BASE = 16'h0000,
    parameter logic [15:0] BUSB_TARGET1_BASE = 16'h4000,
    parameter logic [15:0] BUSB_TARGET2_BASE = 16'h8000
)(
    input  logic clk,
    input  logic rst_n,
    input  logic split_grant,
    input  logic [15:0] target_addr_in,
    input  logic target_addr_in_valid,
    input  logic [7:0] target_data_in,
    input  logic target_data_in_valid,
    input  logic target_rw,
    output logic split_req,
    output logic [7:0] target_data_out,
    output logic target_data_out_valid,
    output logic target_ack,
    output logic target_split_ack,
    output logic target_ready,
    output logic [7:0] split_target_last_write,
    output logic init_req,
    output logic [15:0] init_addr_out,
    output logic init_addr_out_valid,
    output logic [7:0] init_data_out,
    output logic init_data_out_valid,
    output logic init_rw,
    output logic init_ready,
    input  logic init_grant,
    input  logic [7:0] init_data_in,
    input  logic init_data_in_valid,
    input  logic init_ack,
    input  logic init_split_ack
);

    bus_bridge_req_t bridge_req_payload;
    bus_bridge_resp_t bridge_resp_payload;
    logic bridge_req_valid;
    logic bridge_req_ready;
    logic bridge_resp_valid;
    logic bridge_resp_ready;

    bus_bridge_target_if #(
        .BRIDGE_BASE_ADDR(BRIDGE_BASE_ADDR),
        .TARGET0_SIZE(TARGET0_SIZE),
        .TARGET1_SIZE(TARGET1_SIZE),
        .TARGET2_SIZE(TARGET2_SIZE),
        .BUSB_TARGET0_BASE(BUSB_TARGET0_BASE),
        .BUSB_TARGET1_BASE(BUSB_TARGET1_BASE),
        .BUSB_TARGET2_BASE(BUSB_TARGET2_BASE)
    ) u_bridge_target (
        .clk(clk),
        .rst_n(rst_n),
        .split_grant(split_grant),
        .target_addr_in(target_addr_in),
        .target_addr_in_valid(target_addr_in_valid),
        .target_data_in(target_data_in),
        .target_data_in_valid(target_data_in_valid),
        .target_rw(target_rw),
        .split_req(split_req),
        .target_data_out(target_data_out),
        .target_data_out_valid(target_data_out_valid),
        .target_ack(target_ack),
        .target_split_ack(target_split_ack),
        .target_ready(target_ready),
        .split_target_last_write(split_target_last_write),
        .req_valid(bridge_req_valid),
        .req_ready(bridge_req_ready),
        .req_payload(bridge_req_payload),
        .resp_valid(bridge_resp_valid),
        .resp_ready(bridge_resp_ready),
        .resp_payload(bridge_resp_payload)
    );

    bus_bridge_initiator_if u_bridge_initiator (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(bridge_req_valid),
        .req_ready(bridge_req_ready),
        .req_payload(bridge_req_payload),
        .resp_valid(bridge_resp_valid),
        .resp_ready(bridge_resp_ready),
        .resp_payload(bridge_resp_payload),
        .init_req(init_req),
        .init_addr_out(init_addr_out),
        .init_addr_out_valid(init_addr_out_valid),
        .init_data_out(init_data_out),
        .init_data_out_valid(init_data_out_valid),
        .init_rw(init_rw),
        .init_ready(init_ready),
        .init_grant(init_grant),
        .init_data_in(init_data_in),
        .init_data_in_valid(init_data_in_valid),
        .init_ack(init_ack),
        .init_split_ack(init_split_ack)
    );

endmodule
