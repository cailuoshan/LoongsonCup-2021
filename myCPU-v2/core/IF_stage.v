`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    // Pipline shake
    input                          prefs_to_fs_valid ,
    input  [`TO_FS_BUS_WD -1:0]    prefs_to_fs_bus   ,                        
    output                         fs_allowin     ,
    
    // Branch Predictor Update
    output [31:0]  bp_pc ,
    output         is_br ,
    output         br_taken ,
    output [31:0]  br_target,

    // Icache interface
    input          icache_data_ok,
    input  [31:0]  icache_rdata  ,
    // Inst Buffer
    input          ib_full,
    output         ib_write_req,
    output [31:0]  ib_pc,
    output [31:0]  ib_inst,
    output [2:0]   ib_exc,
	
    //TLB refetch tag

    // Exception related
    
);

// Signal declaration
wire               fs_ready_go;
reg                fs_valid;

wire [31:0]        fs_inst;
wire [31:0]        fs_pc;
reg  [31:0]        icache_rdata_r;
reg                icache_rdata_r_vaild;

wire               fs_tlb_miss;
wire               fs_tlb_invalid;
wire               fs_pc_adel;

// HandShake for pipeline
assign {fs_tlb_miss,
        fs_tlb_invalid,
        fs_pc_adel,
        fs_pc      } = prefs_to_fs_bus;
assign fs_ready_go   = (icache_data_ok || icache_rdata_r_vaild) && !ib_full;
assign fs_allowin    = !fs_valid || fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    /*end else if (handle_exc || handle_eret || pipe_flush) begin
        fs_valid <= 1'b0;*/
    end else if (fs_allowin) begin
        fs_valid <= prefs_to_fs_valid;
    end
end

// Wait for Inst fetch
always @(posedge clk) begin
    if(reset) begin
        icache_rdata_r <= 32'b0;
    end else if(icache_data_ok) begin
        icache_rdata_r <= icache_rdata;
    end
end

always @(posedge clk) begin
    if(reset) begin
        icache_rdata_r_vaild <= 1'b0;
    /*end else if(handle_exc || handle_eret || pipe_flush) begin
        fs_inst_sram_rdata_r_vaild <= 1'b0;*/
    end else if(icache_data_ok) begin
        icache_rdata_r_vaild <= 1'b1;
    end else if(fs_ready_go) begin
        icache_rdata_r_vaild <= 1'b0;
    end
end

assign fs_inst = icache_rdata_r_vaild ? icache_rdata_r : icache_rdata;

// Update Predictor
???


// Write into InstBuffer
assign ib_write_req = fs_ready_go;
assign ib_pc        = fs_pc;
assign ib_inst      = fs_inst;
assign ib_exc       = {fs_tlb_miss,fs_tlb_invalid,fs_pc_adel};

endmodule