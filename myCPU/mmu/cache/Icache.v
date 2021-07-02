`include "cache.h"
module Icache(
	input 			clk,
	input 			resetn,
	////cpu_control
	input			inst_valid,
	input			inst_op,
	input 	[ 6:0]	inst_index,
	input 	[19:0]	inst_tag,
	input 	[ 4:0]	inst_offset,
	input 	[ 3:0]	inst_wstrb,
	input 	[31:0]	inst_wdata,
	output 			inst_addr_ok,
	output 			inst_data_ok,
	output	[31:0]	inst_rdata,


	////axi_control
    //ar
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
/*
 * 2-way, 32byte/line, 128 entries
 */
wire rst;
assign rst = !resetn;

// not use
assign awid     = 4'd2;
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
assign araddr   = {inst_addr_reg[31:5],5'b0};
assign arlen    = 8'd7;
assign arsize   = 3'd2; 
assign arburst  = 2'b01;
assign arlock   = 2'b0;
assign arcache  = 4'b0;
assign arprot   = 3'b0;
assign arvalid  = lr_state == LR_MISS;

assign rready   = lr_state == LR_REFILL;
    //read count
// state machine
parameter LR_IDLE = 3'b001;
parameter LR_LOOKUP = 3'b010;
parameter LR_MISS = 3'b011;
parameter LR_REFILL = 3'b100;

reg [2:0] lr_state;
reg [2:0] lr_nextstate;

always @(posedge clk) begin
    if (!resetn) begin
        // reset
        lr_state <= LR_IDLE;
    end
    else
        lr_state <= lr_nextstate;
end
always @(*) begin
    case(lr_state)
    LR_IDLE:begin
        if(inst_valid&&inst_addr_ok)
            lr_nextstate <= LR_LOOKUP;
        else begin
            lr_nextstate <= LR_IDLE;
        end
    end
    LR_LOOKUP:begin
        if(!cache_hit)
            lr_nextstate <= LR_MISS;
        else if(!inst_valid)
            lr_nextstate <= LR_IDLE;
        else 
            lr_nextstate <= LR_LOOKUP;
    end
    LR_MISS:begin
        if(arready)
            lr_nextstate <= LR_REFILL;
        else
            lr_nextstate <= LR_MISS;
    end
    LR_REFILL:begin
        if(write_wait)
            lr_nextstate <= LR_IDLE;
        else
            lr_nextstate <= LR_REFILL;
    end
    default:
        lr_nextstate <= LR_IDLE;
    endcase
end

//request buffer
assign inst_addr_ok = lr_state == LR_IDLE || lr_state == LR_LOOKUP&&cache_hit;
assign inst_data_ok = cache_hit&&lr_state == LR_LOOKUP || rlast&&rvalid;
assign inst_rdata = (lr_state == LR_REFILL)?
                    (inst_addr_reg[4:2] == 3'd7)?rdata:mem_data[inst_addr_reg[4:2]]
                    :(way0_hit)? way0_cache[inst_addr_reg[4:2]]
                    :way1_cache[inst_addr_reg[4:2]];
wire [`INST_REQUEST_BUFFER_WID-1:0] inst_request_buffer;
reg [`INST_REQUEST_BUFFER_WID-1 :0] inst_addr_reg;
assign inst_request_buffer = {
    inst_tag,//31:12
    inst_index,//11:5
    inst_offset//4:0
};
always @(posedge clk) begin
    if (rst) begin
        // reset
        inst_addr_reg <= 32'd0;
    end
    else if (inst_valid && inst_addr_ok) begin
        inst_addr_reg <= inst_request_buffer;
    end
end
//tagv
wire tagv_en;
wire tagv_we_0,tagv_we_1;
wire [20:0] tagv_rdata_0,tagv_rdata_1;
wire [20:0] tagv_wdata_0,tagv_wdata_1;
wire [6:0]  tagv_index;
assign tagv_index = (lr_state == LR_IDLE || lr_state == LR_LOOKUP)? inst_index : inst_addr_reg[11:5] ;

assign tagv_en = inst_valid && inst_addr_ok || tagv_we_0 || tagv_we_1;
assign tagv_we_0 = rlast && rvalid && LRU_pick==0;
assign tagv_we_1 = rlast && rvalid && LRU_pick==1;
assign tagv_wdata_0 = {inst_addr_reg[31:12],1'b1};
assign tagv_wdata_1 = {inst_addr_reg[31:12],1'b1};

tagv way0_tagv(clk,tagv_en,tagv_we_0,tagv_index,tagv_wdata_0,tagv_rdata_0);
tagv way1_tagv(clk,tagv_en,tagv_we_1,tagv_index,tagv_wdata_1,tagv_rdata_1);

//hit or miss
wire way1_hit,way0_hit;
wire cache_hit;
assign way0_hit = tagv_rdata_0[20:1] == inst_addr_reg[31:12] && tagv_rdata_0[0];
assign way1_hit = tagv_rdata_1[20:1] == inst_addr_reg[31:12] && tagv_rdata_1[0];
assign cache_hit = way1_hit || way0_hit;
//LRU
integer j;
reg RU[127:0];
/*
 * RU[index] == 1'b0 means way0's index'th data used recently
 * if way1 hit, RU[index] <= 1;
 * if way0 hit, RU[index] <= 0;
 */
integer j;
always @(posedge clk) begin
    if (rst) begin
        // reset
        for(j=0;j<128;j=j+1)    
            begin                   
                RU[j] <= 1'b0;
            end
    end
    else if (lr_state == LR_LOOKUP && cache_hit) begin
        RU[inst_addr_reg[11:5]] <= way1_hit;
    end
    else if (write_wait) begin
        RU[inst_addr_reg[11:5]] <= LRU_pick;
    end
end
wire LRU_pick;
assign LRU_pick = !RU[inst_addr_reg[11:5]];
//refill buffer
reg [2:0] read_count;
always @(posedge clk) begin
    if (rst) begin
        // reset
        read_count <= 3'd0;
    end
    else if (rready&&rvalid && rid == 4'd3) begin
        read_count <= read_count + 1;
    end
    else if (lr_state == LR_MISS)
        read_count <= 0;
end
reg [`DATABANK_WID-1:0] mem_data [`BlockNum-1:0];

always @(posedge clk) begin
    if (rst) begin
        // reset
        mem_data[0] <= 32'd0;
        mem_data[1] <= 32'd0; 
        mem_data[2] <= 32'd0; 
        mem_data[3] <= 32'd0; 
        mem_data[4] <= 32'd0; 
        mem_data[5] <= 32'd0; 
        mem_data[6] <= 32'd0; 
        mem_data[7] <= 32'd0; 

    end
    else if (rready&&rvalid) begin
        mem_data[read_count] <= rdata;
    end
end
reg write_wait;
always @(posedge clk) begin
    if (rst) begin
        // reset
        write_wait <= 0;
    end
    else if (rlast && rvalid && rready) begin
        write_wait <= 1;
    end
    else if (lr_state == LR_IDLE)
        write_wait <= 0;
end
//data bank
wire [`INDEX_WID-1:0] bank_index = (lr_state == LR_REFILL)? inst_addr_reg[11:5]:inst_index; 

wire [`DATABANK_WID-1:0] way0_cache [`BlockNum-1:0];
wire way0_en;
wire [3:0] way0_we;
assign way0_en = inst_valid && inst_addr_ok || way0_we[0];
assign way0_we = (rlast&& rvalid && LRU_pick == 0)? 4'b1111 : 4'd0;
data_bank way0_bank0(clk,way0_en,way0_we,bank_index,mem_data[0],way0_cache[0]);
data_bank way0_bank1(clk,way0_en,way0_we,bank_index,mem_data[1],way0_cache[1]);
data_bank way0_bank2(clk,way0_en,way0_we,bank_index,mem_data[2],way0_cache[2]);
data_bank way0_bank3(clk,way0_en,way0_we,bank_index,mem_data[3],way0_cache[3]);
data_bank way0_bank4(clk,way0_en,way0_we,bank_index,mem_data[4],way0_cache[4]);
data_bank way0_bank5(clk,way0_en,way0_we,bank_index,mem_data[5],way0_cache[5]);
data_bank way0_bank6(clk,way0_en,way0_we,bank_index,mem_data[6],way0_cache[6]);
data_bank way0_bank7(clk,way0_en,way0_we,bank_index,rdata,way0_cache[7]);


wire [`DATABANK_WID-1:0] way1_cache [`BlockNum-1:0];
wire way1_en;
wire [3:0] way1_we;
assign way1_en = inst_valid && inst_addr_ok || way1_we[0];
assign way1_we = (rlast && rvalid && LRU_pick == 1)? 4'b1111 : 4'd0;

data_bank way1_bank0(clk,way1_en,way1_we,bank_index,mem_data[0],way1_cache[0]);
data_bank way1_bank1(clk,way1_en,way1_we,bank_index,mem_data[1],way1_cache[1]);
data_bank way1_bank2(clk,way1_en,way1_we,bank_index,mem_data[2],way1_cache[2]);
data_bank way1_bank3(clk,way1_en,way1_we,bank_index,mem_data[3],way1_cache[3]);
data_bank way1_bank4(clk,way1_en,way1_we,bank_index,mem_data[4],way1_cache[4]);
data_bank way1_bank5(clk,way1_en,way1_we,bank_index,mem_data[5],way1_cache[5]);
data_bank way1_bank6(clk,way1_en,way1_we,bank_index,mem_data[6],way1_cache[6]);
data_bank way1_bank7(clk,way1_en,way1_we,bank_index,rdata,way1_cache[7]);

endmodule

