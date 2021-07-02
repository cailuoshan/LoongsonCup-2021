module hilo_reg(
    input         clk,
    // READ PORT
    input         raddr,    //1 for HI_reg, 0 for LO_reg
    output [31:0] rdata,
    // WRITE PORT for HI
    input         we_hi,       
    input  [31:0] wdata_hi,
    // WRITE PORT for LO
    input         we_lo,       
    input  [31:0] wdata_lo
);
reg [31:0] HI;
reg [31:0] LO;

//WRITE HI
always @(posedge clk) begin
    if (we_hi) HI<= wdata_hi;
end

//WRITE LO
always @(posedge clk) begin
    if (we_lo) LO<= wdata_lo;
end

//READ OUT
assign rdata = (raddr==1'b1) ? HI : LO;

endmodule