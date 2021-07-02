module inst_buffer(
    input         clk,
    input         reset,
    input         ib_flush,
    // FETCH PORT
    input         ib_fetch_req,
    output [INST_BUF_LINE_WD-1:0] ib_rline1,
    output [INST_BUF_LINE_WD-1:0] ib_rline2,
    // WRITE PORT
    input         ib_write_req,
    input [31:0]  ib_pc,
    input [31:0]  ib_inst,
    input [2:0]   ib_exc,
    // CHECK PORT
    output        ib_empty,
    output        ib_full
);
reg [31:0] InstBuf_inst[INST_BUF_SIZE-1:0]; 
reg [31:0] InstBuf_pc  [INST_BUF_SIZE-1:0]; 
reg [2:0]  InstBuf_exc [INST_BUF_SIZE-1:0]; 
reg [INST_BUF_SIZE-1:0] InstBuf_valid;
reg [2:0]  head; // fifo read index
reg [2:0]  tail; // fifo write index

always @(posedge clk) begin
    if(rst || ib_flush)begin
        head <= 3'b0;
        tail <= 3'b0;
        InstBuf_valid <= 0;
    end
    else if (ib_fetch_req) begin
        head <= head + 2;
        InstBuf_valid[head  ] <= 0;
        InstBuf_valid[head+1] <= 0;
    end 
    else if (ib_write_req) begin
        tail <= tail + 1;
        InstBuf_valid[tail  ] <= 1;
    end
end

always @(posedge clk) begin
    if (ib_write_req) begin
        InstBuf_inst[tail] <= ib_inst;
        InstBuf_pc[tail  ] <= ib_pc;
        InstBuf_exc[tail ] <= ib_exc;
    end
end

assign ib_rline1 = {InstBuf_pc[head],InstBuf_inst[head],InstBuf_exc[head]};
assign ib_rline2 = {InstBuf_pc[head+1],InstBuf_inst[head+1],InstBuf_exc[head+1]};

assign ib_empty = (InstBuf_valid[head+1]==0);  // valid entry less than 2
assign ib_full = InstBuf_valid[tail];          // no empty entry

endmodule