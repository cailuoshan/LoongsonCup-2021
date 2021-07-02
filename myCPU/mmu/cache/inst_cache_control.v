`include "cache.h"
module inst_cache_control(
	input 			clk,
	input 			reset,
	////cpu_control
	input           inst_req,
    input   [ 1:0]  inst_size,
    input           inst_op,
    input   [ 6:0]  inst_index,
    input   [19:0]  inst_tag,
    input   [ 4:0]  inst_offset,
    input   [ 3:0]  inst_wstrb,
    input   [31:0]  inst_wdata,
    output          inst_addr_ok,
    output          inst_data_ok,
    output  [31:0]  inst_rdata,
    input           inst_cache,

    //// dcache interface

    output           icache_req,
    input            icache_addr_ok,
    input            icache_data_ok,
    input    [31:0]  icache_rdata,
    
    //// uncache inst axi control
    output  [3 :0]  arid   ,
    output  [31:0]  araddr,
    output  [7 :0]  arlen  ,
    output  [2 :0]  arsize ,
    output  [1 :0]  arburst,
    output  [1 :0]  arlock ,
    output  [3 :0]  arcache,
    output  [2 :0]  arprot ,
    output          arvalid,
    input           arready,
    //r
    input [3 :0]  rid    ,
    input [31:0]  rdata  ,
    input [1 :0]  rresp ,
    input         rlast ,
    input         rvalid ,
    output        rready ,
    //aw
    output  [3 :0]  awid   ,
    output  [31:0]  awaddr ,
    output  [7 :0]  awlen  ,
    output  [2 :0]  awsize ,
    output  [1 :0]  awburst,
    output  [1 :0]  awlock ,
    output  [3 :0]  awcache,
    output  [2 :0]  awprot ,
    output          awvalid,
    input           awready,
    //w
    output  [3 :0]  wid    ,
    output  [31:0]  wdata  ,
    output  [3 :0]  wstrb  ,
    output          wlast  ,
    output          wvalid ,
    input           wready ,
    //b
    input [3 :0]  bid    ,
    input [1 :0]  bresp  ,
    input         bvalid ,
    output        bready 

	);

wire [31:0] icache_addr;
wire        is_cached;
(* max_fanout = "10" *)reg  [31:0]  addr_reg;
wire         addr_ok;
wire         data_ok;
(* max_fanout = "10" *)reg         icache_working;
(* max_fanout = "10" *)reg [2:0]   state;
reg [2:0]   nextstate;
parameter   IDLE = 3'd1;
parameter   AR   = 3'd2;
parameter   READ = 3'd3;

assign icache_addr = {inst_tag,inst_index,inst_offset};
assign icache_req = inst_req && is_cached;

assign is_cached = inst_cache;

assign addr_ok =  state == IDLE && !is_cached;
assign data_ok =  rlast &&  rready &&  rvalid;
assign inst_addr_ok = (is_cached)? icache_addr_ok : addr_ok;
assign inst_data_ok = (icache_working)? icache_data_ok : data_ok;
assign inst_rdata = (icache_working)? icache_rdata : rdata;

always @(posedge clk) begin
    if (reset) begin
        // reset
        icache_working <= 1'b0;
    end
    else if (inst_req && is_cached) begin
        icache_working <= 1'b1;
    end
    else if (icache_data_ok)
        icache_working <= 1'b0;
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
    case( state)
    IDLE:begin
        if(inst_req && !is_cached && addr_ok  )begin
             nextstate <= AR;
        end
        else begin
             nextstate <= IDLE;
        end
    end
    AR:begin
        if(arready&&arvalid)
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
    default:
         nextstate <= IDLE;
    endcase
end
always @(posedge clk) begin
    if (reset) begin
        // reset
         addr_reg <= 32'd0;
    end
    else if (inst_req && !is_cached && addr_ok) begin
        addr_reg <= icache_addr;
    end
end

// not use
assign awid     = 4'd0;
assign awlen    = 8'b0;
assign awburst  = 2'b0;
assign awlock   = 2'b0;
assign awcache  = 4'b0;
assign awprot   = 3'b0;
assign awaddr   = 32'b0;
assign awvalid  = 1'b0;
assign awsize   = 3'd2;

assign wdata    = 32'b0;
assign wvalid   = 1'b0;
assign wid      = 4'd2;
assign wlast    = 1'b0;

assign bresp    = 2'b0;
assign bready   = 1'b0;

// axi read
assign arid     = 4'd3;
assign araddr   = {addr_reg[31:2],2'd0};
assign arlen    = 8'd0;
assign arsize   = 3'd2; 
assign arburst  = 2'b00;
assign arlock   = 2'b0;
assign arcache  = 4'b0;
assign arprot   = 3'b0;
assign arvalid  = state == AR;

assign rready   = state == READ;

endmodule