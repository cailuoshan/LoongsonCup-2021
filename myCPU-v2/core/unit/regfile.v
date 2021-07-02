 module regfile(
    input         clk,
    // READ-1 PORT 1
    input  [ 4:0] raddr1_1,
    output [31:0] rdata1_1,
    // READ-1 PORT 2
    input  [ 4:0] raddr2_1,
    output [31:0] rdata2_1,
    // READ-2 PORT 1
    input  [ 4:0] raddr1_2,
    output [31:0] rdata1_2,
    // READ-2 PORT 2
    input  [ 4:0] raddr2_2,
    output [31:0] rdata2_2,
    // WRITE PORT-1
    input  [ 3:0]    we_1,       
    input  [ 4:0] waddr_1,
    input  [31:0] wdata_1,
    // WRITE PORT-2
    input  [ 3:0]    we_2,       
    input  [ 4:0] waddr_2,
    input  [31:0] wdata_2
);
reg [31:0] rf[31:0];

//WRITE
wire waddr_same;
assign waddr_same = (waddr_1==waddr_2);
always @(posedge clk) begin
    if(|we_1 && |we_2 && waddr_same)begin
        rf[waddr_2][ 7: 0] <= we_2[0] ? wdata_2[ 7: 0] :
                              we_1[0] ? wdata_1[ 7: 0] : rf[waddr_2][ 7: 0];
        rf[waddr_2][15: 8] <= we_2[1] ? wdata_2[15: 8] :
                              we_1[1] ? wdata_1[15: 8] : rf[waddr_2][15: 8];
        rf[waddr_2][23:16] <= we_2[2] ? wdata_2[23:16] :
                              we_1[2] ? wdata_1[23:16] : rf[waddr_2][23:16];
        rf[waddr_2][31:24] <= we_2[3] ? wdata_2[31:24] :
                              we_1[3] ? wdata_1[31:24] : rf[waddr_2][31:24];
    end else if (!(|we_1) && |we_2)) begin
        rf[waddr_2][ 7: 0] <= we_2[0] ? wdata_2[ 7: 0] : rf[waddr_2][ 7: 0];
        rf[waddr_2][15: 8] <= we_2[1] ? wdata_2[15: 8] : rf[waddr_2][15: 8];
        rf[waddr_2][23:16] <= we_2[2] ? wdata_2[23:16] : rf[waddr_2][23:16];
        rf[waddr_2][31:24] <= we_2[3] ? wdata_2[31:24] : rf[waddr_2][31:24];
    end else if (!(|we_2) && |we_1) begin
        rf[waddr_1][ 7: 0] <= we_1[0] ? wdata_1[ 7: 0] : rf[waddr_1][ 7: 0];
        rf[waddr_1][15: 8] <= we_1[1] ? wdata_1[15: 8] : rf[waddr_1][15: 8];
        rf[waddr_1][23:16] <= we_1[2] ? wdata_1[23:16] : rf[waddr_1][23:16];
        rf[waddr_1][31:24] <= we_1[3] ? wdata_1[31:24] : rf[waddr_1][31:24];
    end else if (|we_1 && |we_2 && !waddr_same) begin
        rf[waddr_1][ 7: 0] <= we_1[0] ? wdata_1[ 7: 0] : rf[waddr_1][ 7: 0];
        rf[waddr_1][15: 8] <= we_1[1] ? wdata_1[15: 8] : rf[waddr_1][15: 8];
        rf[waddr_1][23:16] <= we_1[2] ? wdata_1[23:16] : rf[waddr_1][23:16];
        rf[waddr_1][31:24] <= we_1[3] ? wdata_1[31:24] : rf[waddr_1][31:24];
        rf[waddr_2][ 7: 0] <= we_2[0] ? wdata_2[ 7: 0] : rf[waddr_2][ 7: 0];
        rf[waddr_2][15: 8] <= we_2[1] ? wdata_2[15: 8] : rf[waddr_2][15: 8];
        rf[waddr_2][23:16] <= we_2[2] ? wdata_2[23:16] : rf[waddr_2][23:16];
        rf[waddr_2][31:24] <= we_2[3] ? wdata_2[31:24] : rf[waddr_2][31:24];
    end
end

//READ OUT 1
assign rdata1_1 = (raddr1_1==5'b0) ? 32'b0 : rf[raddr1_1];
assign rdata2_1 = (raddr2_1==5'b0) ? 32'b0 : rf[raddr2_1];
//READ OUT 2
assign rdata1_2 = (raddr1_2==5'b0) ? 32'b0 : rf[raddr1_2];
assign rdata2_2 = (raddr2_2==5'b0) ? 32'b0 : rf[raddr2_2];

endmodule