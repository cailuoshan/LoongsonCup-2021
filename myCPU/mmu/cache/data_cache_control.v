`include "cache.h"
module data_cache_control(
	input 			clk,
	input 			reset,
	////cpu_control
	input           data_req,
    input   [ 1:0]  data_size,
    input           data_op,
    input   [ 6:0]  data_index,
    input   [19:0]  data_tag,
    input   [ 4:0]  data_offset,
    input   [ 3:0]  data_wstrb,
    input   [31:0]  data_wdata,
    output          data_addr_ok,
    output          data_data_ok,
    output  [31:0]  data_rdata,
    input           data_cache,

    //// dcache interface

    output           dcache_req,
    input            dcache_addr_ok,
    input            dcache_data_ok,
    input    [31:0]  dcache_rdata,
    
    //// uncache inst axi control
    output  [3 :0] arid   ,
    output  [31:0] araddr,
    output  [7 :0] arlen  ,
    output  [2 :0] arsize ,
    output  [1 :0] arburst,
    output  [1 :0] arlock ,
    output  [3 :0] arcache,
    output  [2 :0] arprot ,
    output         arvalid,
    input          arready,
    //r
    input [3 :0] rid    ,
    input [31:0] rdata  ,
    input [1 :0] rresp ,
    input        rlast ,
    input        rvalid ,
    output       rready ,
    //aw
    output  [3 :0] awid   ,
    output  [31:0] awaddr ,
    output  [7 :0] awlen  ,
    output  [2 :0] awsize ,
    output  [1 :0] awburst,
    output  [1 :0] awlock ,
    output  [3 :0] awcache,
    output  [2 :0] awprot ,
    output         awvalid,
    input          awready,
    //w
    output  [3 :0] wid    ,
    output  [31:0] wdata  ,
    output  [3 :0] wstrb  ,
    output         wlast  ,
    output         wvalid ,
    input          wready ,
    //b
    input [3 :0] bid    ,
    input [1 :0] bresp  ,
    input        bvalid ,
    output       bready 


	);

wire [31:0] dcache_addr;
wire        is_cached;
(* max_fanout = "10" *)reg  [31:0] addr_reg;
(* max_fanout = "10" *)reg  [31:0] wdata_reg;
(* max_fanout = "10" *)reg  [ 3:0] wstrb_reg;
(* max_fanout = "10" *)reg  [ 1:0] size_reg;
wire        addr_ok;
wire        data_ok;
(* max_fanout = "10" *)reg         dcache_working;
(* max_fanout = "10" *)reg [2:0]   state;
reg [2:0]   nextstate;
parameter   IDLE = 3'd1;
parameter   AR   = 3'd2;
parameter   READ = 3'd3;
parameter   AW   = 3'd4;
parameter   WRITE= 3'd5;


assign dcache_addr = {data_tag,data_index,data_offset};
assign dcache_req = data_req && is_cached;

assign is_cached = data_cache;

assign addr_ok = state == IDLE && !is_cached;
assign data_ok = rlast && rready && rvalid || wlast;
assign data_addr_ok = (is_cached)? dcache_addr_ok : addr_ok;
assign data_data_ok = (dcache_working)? dcache_data_ok : data_ok;
assign data_rdata = (dcache_working)? dcache_rdata : rdata;

always @(posedge clk) begin
    if (reset) begin
        // reset
        dcache_working <= 1'b0;
    end
    else if (data_req && is_cached) begin
        dcache_working <= 1'b1;
    end
    else if (dcache_data_ok)
        dcache_working <= 1'b0;
end

always @(posedge clk) begin
    if (reset) begin
        // reset
        state <= IDLE;
    end
    else
        state <= nextstate;
end
always @(*) begin
    case(state)
    IDLE:begin
        if(data_req && !is_cached && data_op==`OP_READ )
            nextstate <= AR;
        else if (data_req && !is_cached && data_op==`OP_WRIET) begin
            nextstate <= AW;
        end else begin
            nextstate <= IDLE;
        end
    end
    AR:begin
        if(arready)
            nextstate <= READ;
        else
            nextstate <= AR;
    end
    READ:begin
        if(data_ok)
            nextstate <= IDLE;
        else
            nextstate <= READ;
    end
    AW:begin
        if(awready)
            nextstate <= WRITE;
        else
            nextstate <= AW;
    end
    WRITE:begin
        if(data_ok)
            nextstate <= IDLE;
        else
            nextstate <= WRITE;
    end
    default:
        nextstate <= IDLE;
    endcase
end
always @(posedge clk) begin
    if (reset) begin
        // reset
        addr_reg <= 32'd0;
        wdata_reg <= 32'd0;
        wstrb_reg <= 4'd0;
        size_reg <= 2'd0;
    end
    else if (data_req && !is_cached && addr_ok) begin
        addr_reg <= dcache_addr;
        wdata_reg <= data_wdata;
        wstrb_reg <= data_wstrb;
        size_reg <= data_size;
    end
end

assign arid     = 4'd11;
assign araddr   = addr_reg;
assign arlen    = 8'd0;
assign arsize   = size_reg;
assign arburst  = 2'b00;
assign arlock   = 2'b0;
assign arcache  = 4'b0;
assign arprot   = 3'b0;
assign arvalid  = state == AR;

assign rready = state == READ;

assign awid     = 4'd7;
assign awlen    = 8'd0;
assign awburst  = 2'b00;
assign awsize   = size_reg;
assign awlock   = 2'b0;
assign awcache  = 4'b0;
assign awprot   = 3'b0;
assign awaddr   = addr_reg;
assign awvalid  = state == AW;


assign wdata    = wdata_reg;
assign wvalid   = state == WRITE;
assign wid      = 4'd7;//awid
assign wlast    = wvalid && wready;
assign wstrb    = wstrb_reg;

assign bready   = 1'b1;



endmodule