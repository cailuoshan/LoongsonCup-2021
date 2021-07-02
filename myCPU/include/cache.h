`ifndef CACHE_H
	`define CACHE_H
	`define DATABANK_WID 32
	`define INDEX_ENTRIES 128
	`define OFFSET_WID 5
	`define INDEX_WID 7
	`define TAG_WID 20
	`define INST_REQUEST_BUFFER_WID 32
	`define BlockNum 8
	
	`define ICACHE_RID 4'd1
	`define I_UNCACHE_RID 4'd2
	`define ICACHE_WID 4'd3
	`define I_UNCACHE_WID 4'd4
	`define DCACHE_RID 4'd5
	`define D_UNCACHE_RID 4'd6
	`define DCACHE_WID 4'd7
	`define D_UNCACHE_WID 4'd8
	`define OP_WRIET 1'b1
	`define OP_READ 1'b0
`endif

