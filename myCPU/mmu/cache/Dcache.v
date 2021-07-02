`include "cache.h"
module Dcache(
	input 			clk,
	input 			reset,
	////cpu_control
	input			data_req,
	input			data_op,
	input 	[ 6:0]	data_index,
	input 	[19:0]	data_tag,
	input 	[ 4:0]	data_offset,
	input 	[ 3:0]	data_wstrb,
	input 	[31:0]	data_wdata,
	output 			data_addr_ok,
	output 			data_ok,
	output	[31:0]	cpu_data_o,


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

parameter LR_IDLE = 3'b001;
parameter LR_LOOKUP = 3'b010;
parameter LR_MISS = 3'b011;
parameter LR_REPLACE = 3'b100;
parameter LR_RREQ = 3'b101;
parameter LR_REFILL = 3'b110;
parameter WB_IDLE = 2'b01;
parameter WB_WRITE = 2'b10;

//state machine:LR

reg [4:0] lr_state;
reg [4:0] lr_nextstate;
always @(posedge clk) begin
    if (reset) begin
        // reset
        lr_state <= LR_IDLE;
    end
    else
        lr_state <= lr_nextstate;
end
always @(*) begin
    case(lr_state)
    LR_IDLE:begin
        if(data_req&&data_addr_ok)
            lr_nextstate <= LR_LOOKUP;
        else begin
            lr_nextstate <= LR_IDLE;
        end
    end
    LR_LOOKUP:begin
        if(!cache_hit)
            lr_nextstate <= LR_MISS;
        else if(!data_req || bank_writing_conflict)
            lr_nextstate <= LR_IDLE;
        else 
            lr_nextstate <= LR_LOOKUP;
    end
    LR_MISS:begin
        
        if(!((LRU_pick)?way1_d[addr_reg[11:5]]:way0_d[addr_reg[11:5]]))
            lr_nextstate <= LR_RREQ;
        else if(awready)
            lr_nextstate <= LR_REPLACE;
        else begin
            lr_nextstate <= LR_MISS;
        end
    end
    LR_REPLACE:begin
        if(wvalid && wlast)
            lr_nextstate <= LR_RREQ;
        else begin
            lr_nextstate <= LR_REPLACE;
        end
    end
    LR_RREQ:begin
        if(arready)
            lr_nextstate <= LR_REFILL;
        else begin
            lr_nextstate <= LR_RREQ;
        end
    end
    LR_REFILL:begin
        if(refill_writing)
            lr_nextstate <= LR_IDLE;
        else begin
            lr_nextstate <= LR_REFILL;
        end
    end
    default:
        lr_nextstate <= LR_IDLE;
    endcase
end
//state machine:WB

(* max_fanout = "10" *)reg [1:0] wb_state;
reg [1:0] wb_nextstate;
always @(posedge clk) begin
    if (reset) begin
        // reset
        wb_state <= WB_IDLE;
    end
    else
        wb_state <= wb_nextstate;
end
always @(*) begin
    case(wb_state)
    WB_IDLE:begin
        if(hit_write)
            wb_nextstate <= WB_WRITE;
        else begin
            wb_nextstate <= WB_IDLE;
        end
    end
    WB_WRITE:begin
        if(hit_write)
            wb_nextstate <= WB_WRITE;
        else
            wb_nextstate <= WB_IDLE;
    end
    default:
        wb_nextstate <= WB_IDLE;
    endcase
end

//// request handle
(* max_fanout = "10" *)reg [31:0] addr_reg;
(* max_fanout = "10" *)reg [31:0] wdata_reg;
(* max_fanout = "10" *)reg [ 3:0] wstrb_reg;
reg        op_reg;
wire hit_write;
wire bank_writing_conflict;
wire [6:0] index_r = addr_reg[11:5];
wire bank_sel_r = addr_reg[4:2];
assign data_addr_ok = lr_state == LR_IDLE&&!bank_writing_conflict || lr_state == LR_LOOKUP&&!bank_writing_conflict&&cache_hit;
assign data_ok = cache_hit&&(lr_state == LR_LOOKUP) || refill_writing;
assign hit_write = cache_hit && (lr_state==LR_LOOKUP) && op_reg;
assign bank_writing_conflict = data_offset[4:2] == wb_addr_reg[4:2]&&wb_state==WB_WRITE || data_offset[4:2] == addr_reg[4:2] && hit_write;
assign cpu_data_o = (lr_state == LR_REFILL)? data_from_mem[addr_reg[4:2]]:(way0_hit)?way0_cache[addr_reg[4:2]]:way1_cache[addr_reg[4:2]];
always @(posedge clk) begin
    if (reset) begin
        // reset
        addr_reg <= 32'd0;
        wdata_reg <= 32'd0;
        wstrb_reg <= 4'd0;
        op_reg <= 1'd0;
    end
    else if (data_req && data_addr_ok) begin
        addr_reg <= {data_tag,data_index,data_offset};
        wdata_reg <= data_wdata;
        wstrb_reg <= data_wstrb;
        op_reg <= data_op;
    end
    else if (lr_state == LR_IDLE)begin
        addr_reg <= 32'd0;
        op_reg <= 1'd0;
    end
end

//// hit write 
(* max_fanout = "10" *)reg [31:0] wb_wdata_reg;
(* max_fanout = "10" *)reg [ 3:0] wb_wstrb_reg;
(* max_fanout = "10" *)reg [31:0] wb_addr_reg;
reg        wb_way_reg;
always @(posedge clk) begin
    if (reset) begin
        // reset
        wb_wdata_reg <= 32'd0;
        wb_wstrb_reg <= 4'd0;
        wb_addr_reg <= 32'd0;
        wb_way_reg <= 1'b0;
    end
    else if (hit_write) begin
        wb_wdata_reg <= wdata_reg;
        wb_wstrb_reg <= wstrb_reg;
        wb_addr_reg <= addr_reg;
        wb_way_reg <= way1_hit;
    end
end

//// TAG+V
wire tagv_en;
wire way0_tagv_we;
wire [20:0] way0_tagv_rdata;
wire way1_tagv_we;
wire [20:0] way1_tagv_rdata;
wire [20:0] tagv_wdata;
wire [ 6:0] tagv_addr;

assign tagv_en = data_req && data_addr_ok || way0_tagv_we || way1_tagv_we;
assign tagv_addr = (lr_state == LR_IDLE || lr_state == LR_LOOKUP)? data_index : addr_reg[11:5];
assign way0_tagv_we = rlast && rvalid && LRU_pick==0;
assign way1_tagv_we = rlast && rvalid && LRU_pick==1;
assign tagv_wdata = {addr_reg[31:12],1'b1};

tagv way0_tagv(.clka(clk),.ena(tagv_en),.wea(way0_tagv_we),.addra(tagv_addr),.dina(tagv_wdata), .douta(way0_tagv_rdata));
tagv way1_tagv(.clka(clk),.ena(tagv_en),.wea(way1_tagv_we),.addra(tagv_addr),.dina(tagv_wdata), .douta(way1_tagv_rdata));

//// hit or miss
wire cache_hit;
wire way0_hit,way1_hit;
reg  [19:0] replace_tag_reg;

always @(posedge clk) begin
    if (reset) begin
        // reset
        replace_tag_reg <= 20'd0;
    end
    else if (lr_state == LR_LOOKUP && !cache_hit) begin
        replace_tag_reg <= (LRU_pick==1'b0)? way0_tagv_rdata[20:1] : way1_tagv_rdata[20:1];
    end
end

assign way0_hit = way0_tagv_rdata[20:1] == addr_reg[31:12] && way0_tagv_rdata[0];
assign way1_hit = way1_tagv_rdata[20:1] == addr_reg[31:12] && way1_tagv_rdata[0];
assign cache_hit = way1_hit || way0_hit;

//LRU

/*
 * RU[index] == 1'b0 means way0's index'th data used recently
 * if way1 hit, RU[index] <= 1;
 * if way0 hit, RU[index] <= 0;
 */

integer j;
reg RU[127:0];

always @(posedge clk) begin
    if (reset) begin
        // reset
        for(j=0;j<128;j=j+1)    
        begin                   
            RU[j] <= 1'b0;
        end
    end
    else if (lr_state == LR_LOOKUP && cache_hit) begin
        RU[addr_reg[11:5]] <= way1_hit;
    end
    else if (refill_writing) begin
        RU[addr_reg[11:5]] <= LRU_pick;
    end
end

wire LRU_pick;
assign LRU_pick = !RU[addr_reg[11:5]];
//dirty
reg way0_d[127:0];
always @(posedge clk) begin
    if (reset) begin
        // reset                   
        for(j=0;j<128;j=j+1)    
        begin                   
            way0_d[j] <= 1'b0;
        end
    end
    else if (wb_state==WB_WRITE&&wb_way_reg==1'b0) begin
        way0_d[wb_addr_reg[11:5]] <= 1'b1;
    end
    else if (lr_state == LR_REFILL && LRU_pick==1'b0)begin
        way0_d[addr_reg[11:5]] <= op_reg ;
    end
end

reg way1_d[127:0];
integer i;
always @(posedge clk) begin
    if (reset) begin               
        for(i=0;i<128;i=i+1)    
        begin                   
            way1_d[i] <= 1'b0;
        end
    end
    else if (wb_state==WB_WRITE && wb_way_reg==1'b1) begin
        way1_d[wb_addr_reg[11:5]] <= 1'b1;
    end
    else if (lr_state == LR_REFILL && LRU_pick==1'b1)begin
        way1_d[addr_reg[11:5]] <= op_reg;
    end
end
//refill buffer;
reg [2:0] read_count;
always @(posedge clk) begin
    if (reset) begin
        // reset
        read_count <= 3'd0;
    end
    else if (rready&&rvalid) begin
        read_count <= read_count + 1;
    end
    else if (lr_state == LR_MISS)
        read_count <= 0;
end

reg [`DATABANK_WID-1:0] data_from_mem [`BlockNum-1:0];
always @(posedge clk) begin
    if (reset) begin
        // reset
        data_from_mem[0] <= 32'd0;
        data_from_mem[1] <= 32'd0; 
        data_from_mem[2] <= 32'd0; 
        data_from_mem[3] <= 32'd0; 
        data_from_mem[4] <= 32'd0; 
        data_from_mem[5] <= 32'd0; 
        data_from_mem[6] <= 32'd0; 
        data_from_mem[7] <= 32'd0; 

    end
    else if (rready&&rvalid) begin
        data_from_mem[read_count] <= rdata;
    end
end
/*
 * if a store missed, refill data should be packed by wdata(from CPU)
 * op == WRITE,wstrb[i] == 1,bank selected 
 */
wire [`DATABANK_WID-1:0] packed_refill_data [`BlockNum-1:0];
assign packed_refill_data[0] = {(wstrb_reg[3]&&op_reg&&addr_reg[4:2]==3'd0)?wdata_reg[31:24]:data_from_mem[0][31:24],
                                 (wstrb_reg[2]&&op_reg&&addr_reg[4:2]==3'd0)?wdata_reg[23:16]:data_from_mem[0][23:16],
                                 (wstrb_reg[1]&&op_reg&&addr_reg[4:2]==3'd0)?wdata_reg[15: 8]:data_from_mem[0][15: 8],
                                 (wstrb_reg[0]&&op_reg&&addr_reg[4:2]==3'd0)?wdata_reg[ 7: 0]:data_from_mem[0][ 7: 0]};

assign packed_refill_data[1] = {(wstrb_reg[3]&&op_reg&&addr_reg[4:2]==3'd1)?wdata_reg[31:24]:data_from_mem[1][31:24],
                                 (wstrb_reg[2]&&op_reg&&addr_reg[4:2]==3'd1)?wdata_reg[23:16]:data_from_mem[1][23:16],
                                 (wstrb_reg[1]&&op_reg&&addr_reg[4:2]==3'd1)?wdata_reg[15: 8]:data_from_mem[1][15: 8],
                                 (wstrb_reg[0]&&op_reg&&addr_reg[4:2]==3'd1)?wdata_reg[ 7: 0]:data_from_mem[1][ 7: 0]};

assign packed_refill_data[2] = {(wstrb_reg[3]&&op_reg&&addr_reg[4:2]==3'd2)?wdata_reg[31:24]:data_from_mem[2][31:24],
                                 (wstrb_reg[2]&&op_reg&&addr_reg[4:2]==3'd2)?wdata_reg[23:16]:data_from_mem[2][23:16],
                                 (wstrb_reg[1]&&op_reg&&addr_reg[4:2]==3'd2)?wdata_reg[15: 8]:data_from_mem[2][15: 8],
                                 (wstrb_reg[0]&&op_reg&&addr_reg[4:2]==3'd2)?wdata_reg[ 7: 0]:data_from_mem[2][ 7: 0]};

assign packed_refill_data[3] = {(wstrb_reg[3]&&op_reg&&addr_reg[4:2]==3'd3)?wdata_reg[31:24]:data_from_mem[3][31:24],
                                 (wstrb_reg[2]&&op_reg&&addr_reg[4:2]==3'd3)?wdata_reg[23:16]:data_from_mem[3][23:16],
                                 (wstrb_reg[1]&&op_reg&&addr_reg[4:2]==3'd3)?wdata_reg[15: 8]:data_from_mem[3][15: 8],
                                 (wstrb_reg[0]&&op_reg&&addr_reg[4:2]==3'd3)?wdata_reg[ 7: 0]:data_from_mem[3][ 7: 0]};

assign packed_refill_data[4] = {(wstrb_reg[3]&&op_reg&&addr_reg[4:2]==3'd4)?wdata_reg[31:24]:data_from_mem[4][31:24],
                                 (wstrb_reg[2]&&op_reg&&addr_reg[4:2]==3'd4)?wdata_reg[23:16]:data_from_mem[4][23:16],
                                 (wstrb_reg[1]&&op_reg&&addr_reg[4:2]==3'd4)?wdata_reg[15: 8]:data_from_mem[4][15: 8],
                                 (wstrb_reg[0]&&op_reg&&addr_reg[4:2]==3'd4)?wdata_reg[ 7: 0]:data_from_mem[4][ 7: 0]};

assign packed_refill_data[5] = {(wstrb_reg[3]&&op_reg&&addr_reg[4:2]==3'd5)?wdata_reg[31:24]:data_from_mem[5][31:24],
                                 (wstrb_reg[2]&&op_reg&&addr_reg[4:2]==3'd5)?wdata_reg[23:16]:data_from_mem[5][23:16],
                                 (wstrb_reg[1]&&op_reg&&addr_reg[4:2]==3'd5)?wdata_reg[15: 8]:data_from_mem[5][15: 8],
                                 (wstrb_reg[0]&&op_reg&&addr_reg[4:2]==3'd5)?wdata_reg[ 7: 0]:data_from_mem[5][ 7: 0]};

assign packed_refill_data[6] = {(wstrb_reg[3]&&op_reg&&addr_reg[4:2]==3'd6)?wdata_reg[31:24]:data_from_mem[6][31:24],
                                 (wstrb_reg[2]&&op_reg&&addr_reg[4:2]==3'd6)?wdata_reg[23:16]:data_from_mem[6][23:16],
                                 (wstrb_reg[1]&&op_reg&&addr_reg[4:2]==3'd6)?wdata_reg[15: 8]:data_from_mem[6][15: 8],
                                 (wstrb_reg[0]&&op_reg&&addr_reg[4:2]==3'd6)?wdata_reg[ 7: 0]:data_from_mem[6][ 7: 0]};

assign packed_refill_data[7] = {(wstrb_reg[3]&&op_reg&&addr_reg[4:2]==3'd7)?wdata_reg[31:24]:rdata[31:24],
                                 (wstrb_reg[2]&&op_reg&&addr_reg[4:2]==3'd7)?wdata_reg[23:16]:rdata[23:16],
                                 (wstrb_reg[1]&&op_reg&&addr_reg[4:2]==3'd7)?wdata_reg[15: 8]:rdata[15: 8],
                                 (wstrb_reg[0]&&op_reg&&addr_reg[4:2]==3'd7)?wdata_reg[ 7: 0]:rdata[ 7: 0]};
reg refill_writing;
always @(posedge clk) begin
    if (reset) begin
        // reset
        refill_writing <= 0;
    end
    else if (rlast && rvalid && rready) begin
        refill_writing <= 1;
    end
    else if (lr_state == LR_IDLE)
        refill_writing <= 0;
end

//data bank 
wire [`DATABANK_WID-1:0] way0_cache [`BlockNum-1:0];

wire way0_en_0;
wire way0_en_1;
wire way0_en_2;
wire way0_en_3;
wire way0_en_4;
wire way0_en_5;
wire way0_en_6;
wire way0_en_7;

wire [31:0] way0_wdata_0;
wire [31:0] way0_wdata_1;
wire [31:0] way0_wdata_2;
wire [31:0] way0_wdata_3;
wire [31:0] way0_wdata_4;
wire [31:0] way0_wdata_5;
wire [31:0] way0_wdata_6;
wire [31:0] way0_wdata_7;

wire [3:0] way0_we_0;
wire [3:0] way0_we_1;
wire [3:0] way0_we_2;
wire [3:0] way0_we_3;
wire [3:0] way0_we_4;
wire [3:0] way0_we_5;
wire [3:0] way0_we_6;
wire [3:0] way0_we_7;

wire [6:0] way0_index_0;
wire [6:0] way0_index_1;
wire [6:0] way0_index_2;
wire [6:0] way0_index_3;
wire [6:0] way0_index_4;
wire [6:0] way0_index_5;
wire [6:0] way0_index_6;
wire [6:0] way0_index_7;

/*
 * 
 * 1. READ :accept a request into this bank in both ways(LR_IDLE/LR_LOOKUP) 
 * 2. WRITE:hit write into this bank in this way(WB_WRITE)
 * 3. WRITE:refill a cache line, all banks in this way(LR_REFILL)
 * 4. READ :read a dirty cache line,all banks in this way(LR_RPLACE)
 */

assign way0_index_0 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b0)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd0 && wb_way_reg == 1'b0)? wb_addr_reg[11:5] : data_index;
assign way0_index_1 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b0)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd1 && wb_way_reg == 1'b0)? wb_addr_reg[11:5] : data_index;
assign way0_index_2 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b0)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd2 && wb_way_reg == 1'b0)? wb_addr_reg[11:5] : data_index;
assign way0_index_3 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b0)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd3 && wb_way_reg == 1'b0)? wb_addr_reg[11:5] : data_index;
assign way0_index_4 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b0)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd4 && wb_way_reg == 1'b0)? wb_addr_reg[11:5] : data_index;
assign way0_index_5 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b0)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd5 && wb_way_reg == 1'b0)? wb_addr_reg[11:5] : data_index;
assign way0_index_6 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b0)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd6 && wb_way_reg == 1'b0)? wb_addr_reg[11:5] : data_index;
assign way0_index_7 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b0)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd7 && wb_way_reg == 1'b0)? wb_addr_reg[11:5] : data_index;

assign way0_we_0 = (rlast && rvalid && LRU_pick == 1'b0)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd0 && wb_way_reg == 1'b0)? wb_wstrb_reg : 4'd0;
assign way0_we_1 = (rlast && rvalid && LRU_pick == 1'b0)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd1 && wb_way_reg == 1'b0)? wb_wstrb_reg : 4'd0;
assign way0_we_2 = (rlast && rvalid && LRU_pick == 1'b0)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd2 && wb_way_reg == 1'b0)? wb_wstrb_reg : 4'd0;
assign way0_we_3 = (rlast && rvalid && LRU_pick == 1'b0)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd3 && wb_way_reg == 1'b0)? wb_wstrb_reg : 4'd0;
assign way0_we_4 = (rlast && rvalid && LRU_pick == 1'b0)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd4 && wb_way_reg == 1'b0)? wb_wstrb_reg : 4'd0;
assign way0_we_5 = (rlast && rvalid && LRU_pick == 1'b0)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd5 && wb_way_reg == 1'b0)? wb_wstrb_reg : 4'd0;
assign way0_we_6 = (rlast && rvalid && LRU_pick == 1'b0)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd6 && wb_way_reg == 1'b0)? wb_wstrb_reg : 4'd0;
assign way0_we_7 = (rlast && rvalid && LRU_pick == 1'b0)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd7 && wb_way_reg == 1'b0)? wb_wstrb_reg : 4'd0;


assign way0_wdata_0 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[0];
assign way0_wdata_1 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[1];
assign way0_wdata_2 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[2];
assign way0_wdata_3 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[3];
assign way0_wdata_4 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[4];
assign way0_wdata_5 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[5];
assign way0_wdata_6 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[6];
assign way0_wdata_7 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[7];

assign way0_en_0 = data_req && data_addr_ok && data_offset[4:2]==3'd0 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd0 && wb_way_reg == 1'b0 || rlast && rvalid && LRU_pick == 1'b0 || lr_state == LR_MISS && LRU_pick == 1'b0;
assign way0_en_1 = data_req && data_addr_ok && data_offset[4:2]==3'd1 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd1 && wb_way_reg == 1'b0 || rlast && rvalid && LRU_pick == 1'b0 || lr_state == LR_MISS && LRU_pick == 1'b0;
assign way0_en_2 = data_req && data_addr_ok && data_offset[4:2]==3'd2 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd2 && wb_way_reg == 1'b0 || rlast && rvalid && LRU_pick == 1'b0 || lr_state == LR_MISS && LRU_pick == 1'b0;
assign way0_en_3 = data_req && data_addr_ok && data_offset[4:2]==3'd3 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd3 && wb_way_reg == 1'b0 || rlast && rvalid && LRU_pick == 1'b0 || lr_state == LR_MISS && LRU_pick == 1'b0;
assign way0_en_4 = data_req && data_addr_ok && data_offset[4:2]==3'd4 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd4 && wb_way_reg == 1'b0 || rlast && rvalid && LRU_pick == 1'b0 || lr_state == LR_MISS && LRU_pick == 1'b0;
assign way0_en_5 = data_req && data_addr_ok && data_offset[4:2]==3'd5 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd5 && wb_way_reg == 1'b0 || rlast && rvalid && LRU_pick == 1'b0 || lr_state == LR_MISS && LRU_pick == 1'b0;
assign way0_en_6 = data_req && data_addr_ok && data_offset[4:2]==3'd6 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd6 && wb_way_reg == 1'b0 || rlast && rvalid && LRU_pick == 1'b0 || lr_state == LR_MISS && LRU_pick == 1'b0;
assign way0_en_7 = data_req && data_addr_ok && data_offset[4:2]==3'd7 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd7 && wb_way_reg == 1'b0 || rlast && rvalid && LRU_pick == 1'b0 || lr_state == LR_MISS && LRU_pick == 1'b0;


data_bank way0_bank0(clk,way0_en_0,way0_we_0,way0_index_0,way0_wdata_0,way0_cache[0]);
data_bank way0_bank1(clk,way0_en_1,way0_we_1,way0_index_1,way0_wdata_1,way0_cache[1]);
data_bank way0_bank2(clk,way0_en_2,way0_we_2,way0_index_2,way0_wdata_2,way0_cache[2]);
data_bank way0_bank3(clk,way0_en_3,way0_we_3,way0_index_3,way0_wdata_3,way0_cache[3]);
data_bank way0_bank4(clk,way0_en_4,way0_we_4,way0_index_4,way0_wdata_4,way0_cache[4]);
data_bank way0_bank5(clk,way0_en_5,way0_we_5,way0_index_5,way0_wdata_5,way0_cache[5]);
data_bank way0_bank6(clk,way0_en_6,way0_we_6,way0_index_6,way0_wdata_6,way0_cache[6]);
data_bank way0_bank7(clk,way0_en_7,way0_we_7,way0_index_7,way0_wdata_7,way0_cache[7]);

wire [`DATABANK_WID-1:0] way1_cache [`BlockNum-1:0];

wire way1_en_0;
wire way1_en_1;
wire way1_en_2;
wire way1_en_3;
wire way1_en_4;
wire way1_en_5;
wire way1_en_6;
wire way1_en_7;

wire [31:0] way1_wdata_0;
wire [31:0] way1_wdata_1;
wire [31:0] way1_wdata_2;
wire [31:0] way1_wdata_3;
wire [31:0] way1_wdata_4;
wire [31:0] way1_wdata_5;
wire [31:0] way1_wdata_6;
wire [31:0] way1_wdata_7;

wire [3:0] way1_we_0;
wire [3:0] way1_we_1;
wire [3:0] way1_we_2;
wire [3:0] way1_we_3;
wire [3:0] way1_we_4;
wire [3:0] way1_we_5;
wire [3:0] way1_we_6;
wire [3:0] way1_we_7;

wire [6:0] way1_index_0;
wire [6:0] way1_index_1;
wire [6:0] way1_index_2;
wire [6:0] way1_index_3;
wire [6:0] way1_index_4;
wire [6:0] way1_index_5;
wire [6:0] way1_index_6;
wire [6:0] way1_index_7;

/*
 * 
 * 1. READ :accept a request into this bank in both ways(LR_IDLE/LR_LOOKUP) 
 * 2. WRITE:hit write into this bank in this way(WB_WRITE)
 * 3. WRITE:refill a cache line, all banks in this way(LR_REFILL)
 * 4. READ :read a dirty cache line,all banks in this way(LR_RPLACE)
 */

assign way1_index_0 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b1)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd0 && wb_way_reg == 1'b1)? wb_addr_reg[11:5] : data_index;
assign way1_index_1 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b1)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd1 && wb_way_reg == 1'b1)? wb_addr_reg[11:5] : data_index;
assign way1_index_2 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b1)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd2 && wb_way_reg == 1'b1)? wb_addr_reg[11:5] : data_index;
assign way1_index_3 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b1)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd3 && wb_way_reg == 1'b1)? wb_addr_reg[11:5] : data_index;
assign way1_index_4 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b1)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd4 && wb_way_reg == 1'b1)? wb_addr_reg[11:5] : data_index;
assign way1_index_5 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b1)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd5 && wb_way_reg == 1'b1)? wb_addr_reg[11:5] : data_index;
assign way1_index_6 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b1)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd6 && wb_way_reg == 1'b1)? wb_addr_reg[11:5] : data_index;
assign way1_index_7 = ((rlast && rvalid || lr_state == LR_MISS) && LRU_pick==1'b1)? addr_reg[11:5] : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd7 && wb_way_reg == 1'b1)? wb_addr_reg[11:5] : data_index;

assign way1_we_0 = (rlast && rvalid && LRU_pick==1'b1)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd0 && wb_way_reg == 1'b1)? wb_wstrb_reg : 4'd0;
assign way1_we_1 = (rlast && rvalid && LRU_pick==1'b1)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd1 && wb_way_reg == 1'b1)? wb_wstrb_reg : 4'd0;
assign way1_we_2 = (rlast && rvalid && LRU_pick==1'b1)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd2 && wb_way_reg == 1'b1)? wb_wstrb_reg : 4'd0;
assign way1_we_3 = (rlast && rvalid && LRU_pick==1'b1)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd3 && wb_way_reg == 1'b1)? wb_wstrb_reg : 4'd0;
assign way1_we_4 = (rlast && rvalid && LRU_pick==1'b1)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd4 && wb_way_reg == 1'b1)? wb_wstrb_reg : 4'd0;
assign way1_we_5 = (rlast && rvalid && LRU_pick==1'b1)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd5 && wb_way_reg == 1'b1)? wb_wstrb_reg : 4'd0;
assign way1_we_6 = (rlast && rvalid && LRU_pick==1'b1)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd6 && wb_way_reg == 1'b1)? wb_wstrb_reg : 4'd0;
assign way1_we_7 = (rlast && rvalid && LRU_pick==1'b1)? 4'b1111 : (wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd7 && wb_way_reg == 1'b1)? wb_wstrb_reg : 4'd0;

assign way1_wdata_0 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[0];
assign way1_wdata_1 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[1];
assign way1_wdata_2 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[2];
assign way1_wdata_3 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[3];
assign way1_wdata_4 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[4];
assign way1_wdata_5 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[5];
assign way1_wdata_6 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[6];
assign way1_wdata_7 = (wb_state == WB_WRITE)?wb_wdata_reg:packed_refill_data[7];

assign way1_en_0 = data_req && data_addr_ok && data_offset[4:2]==3'd0 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd0 && wb_way_reg == 1'b1 || rlast && rvalid && LRU_pick==1'b1 || lr_state == LR_MISS && LRU_pick==1'b1;
assign way1_en_1 = data_req && data_addr_ok && data_offset[4:2]==3'd1 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd1 && wb_way_reg == 1'b1 || rlast && rvalid && LRU_pick==1'b1 || lr_state == LR_MISS && LRU_pick==1'b1;
assign way1_en_2 = data_req && data_addr_ok && data_offset[4:2]==3'd2 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd2 && wb_way_reg == 1'b1 || rlast && rvalid && LRU_pick==1'b1 || lr_state == LR_MISS && LRU_pick==1'b1;
assign way1_en_3 = data_req && data_addr_ok && data_offset[4:2]==3'd3 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd3 && wb_way_reg == 1'b1 || rlast && rvalid && LRU_pick==1'b1 || lr_state == LR_MISS && LRU_pick==1'b1;
assign way1_en_4 = data_req && data_addr_ok && data_offset[4:2]==3'd4 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd4 && wb_way_reg == 1'b1 || rlast && rvalid && LRU_pick==1'b1 || lr_state == LR_MISS && LRU_pick==1'b1;
assign way1_en_5 = data_req && data_addr_ok && data_offset[4:2]==3'd5 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd5 && wb_way_reg == 1'b1 || rlast && rvalid && LRU_pick==1'b1 || lr_state == LR_MISS && LRU_pick==1'b1;
assign way1_en_6 = data_req && data_addr_ok && data_offset[4:2]==3'd6 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd6 && wb_way_reg == 1'b1 || rlast && rvalid && LRU_pick==1'b1 || lr_state == LR_MISS && LRU_pick==1'b1;
assign way1_en_7 = data_req && data_addr_ok && data_offset[4:2]==3'd7 || wb_state == WB_WRITE && wb_addr_reg[4:2]==3'd7 && wb_way_reg == 1'b1 || rlast && rvalid && LRU_pick==1'b1 || lr_state == LR_MISS && LRU_pick==1'b1;


data_bank way1_bank0(clk,way1_en_0,way1_we_0,way1_index_0,way1_wdata_0,way1_cache[0]);
data_bank way1_bank1(clk,way1_en_1,way1_we_1,way1_index_1,way1_wdata_1,way1_cache[1]);
data_bank way1_bank2(clk,way1_en_2,way1_we_2,way1_index_2,way1_wdata_2,way1_cache[2]);
data_bank way1_bank3(clk,way1_en_3,way1_we_3,way1_index_3,way1_wdata_3,way1_cache[3]);
data_bank way1_bank4(clk,way1_en_4,way1_we_4,way1_index_4,way1_wdata_4,way1_cache[4]);
data_bank way1_bank5(clk,way1_en_5,way1_we_5,way1_index_5,way1_wdata_5,way1_cache[5]);
data_bank way1_bank6(clk,way1_en_6,way1_we_6,way1_index_6,way1_wdata_6,way1_cache[6]);
data_bank way1_bank7(clk,way1_en_7,way1_we_7,way1_index_7,way1_wdata_7,way1_cache[7]);
////replace
reg  [`DATABANK_WID-1:0] replace_data [`BlockNum-1:0];
always @(posedge clk) begin
    if (reset) begin
        // reset
        replace_data[0] <= 32'd0;
        replace_data[1] <= 32'd0;
        replace_data[2] <= 32'd0;
        replace_data[3] <= 32'd0;
        replace_data[4] <= 32'd0;
        replace_data[5] <= 32'd0;
        replace_data[6] <= 32'd0;
        replace_data[7] <= 32'd0;

    end
    else if (lr_state == LR_MISS) begin
        replace_data[0] <= (LRU_pick)?way1_cache[0]:way0_cache[0];
        replace_data[1] <= (LRU_pick)?way1_cache[1]:way0_cache[1];
        replace_data[2] <= (LRU_pick)?way1_cache[2]:way0_cache[2];
        replace_data[3] <= (LRU_pick)?way1_cache[3]:way0_cache[3];
        replace_data[4] <= (LRU_pick)?way1_cache[4]:way0_cache[4];
        replace_data[5] <= (LRU_pick)?way1_cache[5]:way0_cache[5];
        replace_data[6] <= (LRU_pick)?way1_cache[6]:way0_cache[6];
        replace_data[7] <= (LRU_pick)?way1_cache[7]:way0_cache[7];
    end
end

reg [2:0] bank_write_count;
always @(posedge clk) begin
    if (reset) begin
        // reset
        bank_write_count <= 3'd0;
    end
    else if (wready && wvalid) begin
        bank_write_count <= bank_write_count+1;
    end
    else if (lr_state == LR_MISS) begin
        bank_write_count <= 3'd0;
    end
end
//// axi control
//read 
    //inst--0,data--1
assign arid     = 4'd11;
assign araddr   = {addr_reg[31:5],5'd0};
assign arlen    = 8'd7;
assign arsize   = 3'd2;
assign arburst  = 2'b10;
assign arlock   = 2'b0;
assign arcache  = 4'b0;
assign arprot   = 3'b0;
assign arvalid  = lr_state == LR_RREQ;

assign rready = lr_state == LR_REFILL;
//write
 //TODO: cache inst -- 0 data 2 
assign awid     = 4'd12;
assign awlen    = 8'd7;
assign awburst  = 2'b01;
assign awsize   = 3'd2;
assign awlock   = 2'b0;
assign awcache  = 4'b0;
assign awprot   = 3'b0;
assign awaddr   = {replace_tag_reg,addr_reg[11:5],5'd0};
assign awvalid  = lr_state == LR_MISS && ((LRU_pick)?way1_d[addr_reg[11:5]]:way0_d[addr_reg[11:5]]);

assign wdata    = replace_data[bank_write_count];
assign wvalid   = lr_state == LR_REPLACE && ((LRU_pick)?way1_d[addr_reg[11:5]]:way0_d[addr_reg[11:5]]);
assign wid      = 4'd12;//awid
assign wlast    = bank_write_count == 3'd7 && lr_state == LR_REPLACE;
assign wstrb    = 4'b1111;

assign bready   = 1'b1;



endmodule