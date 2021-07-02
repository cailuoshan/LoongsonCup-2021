`include "mycpu.h"

module preif_stage(
    input                          clk            ,
    input                          reset          ,
    // Pipline shake
    input                          fs_allowin     ,
    output                         prefs_to_fs_valid ,
    output [`TO_FS_BUS_WD -1:0]    prefs_to_fs_bus   ,
    
    // Branch Predictor
    output [31:0]  current_pc ,
    intput [31:0]  predict_pc ,
    // Icache interface
    output         icache_req,
    output [ 1:0]  icache_size,
    output [31:0]  icache_addr,
    input          icache_addr_ok,
	
	//TLB search port 0     
    output [18:0]  s0_vpn2,
    output         s0_odd_page,
    input          s0_found,     
    input  [ 3:0]  s0_index,     
    input  [19:0]  s0_pfn,     
    input  [ 2:0]  s0_c,     
    input          s0_d,     
    input          s0_v,
    //TLB refetch tag

    // Exception related
    
);

// Signal declaration
wire                     prefs_ready_go;

reg  [31:0]              fs_pc;
wire [31:0]              seq_pc;
wire [31:0]              virt_nextpc;
wire [31:0]              phys_nextpc;

wire                     prefs_tlb_miss;
wire                     prefs_tlb_invalid;
wire                     prefs_pc_adel;

// HandShake for pipeline
assign prefs_ready_go    = icache_req && icache_addr_ok; 
assign prefs_to_fs_valid = ~reset && prefs_ready_go;
assign prefs_to_fs_bus   = {prefs_tlb_miss,
                            prefs_tlb_invalid,
                            prefs_pc_adel,
                            virt_nextpc};

// Predict PC and Send request
assign seq_pc       = fs_pc + 3'h4;
assign virt_nextpc  = /*handle_exc && exception_tlb_refill ? 32'hbfc00200 :
                      handle_exc ? 32'hbfc00380 :
                      handle_eret ? cp0_epc :
                      pipe_flush ? pipe_flush_pc :
                      (br_bus_r_valid && br_taken && bd_done) ? br_target :
                      (fs_bd && !fs_valid) ? seq_pc :
                      br_taken ? br_target : */
                                 seq_pc;

assign icache_req = ~reset && fs_allowin;  
assign icache_addr = phys_nextpc;
assign icache_size = 2'b10;

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    /*end else if (handle_exc && exception_tlb_refill) begin
        fs_pc <= 32'hbfc001fc;
    end else if (handle_exc) begin
        fs_pc <= 32'hbfc0037c;
    end else if (handle_eret) begin
        fs_pc <= cp0_epc - 32'h4;
    end else if (pipe_flush) begin
        fs_pc <= pipe_flush_pc - 32'h4;*/
    end else if (prefs_to_fs_valid && fs_allowin) begin
        fs_pc <= virt_nextpc;
    end
end

// TLB Translation va->pa
assign s0_vpn2     = virt_nextpc[31:13];
assign s0_odd_page = virt_nextpc[12];
assign mapped  = ~virt_nextpc[31] | (virt_nextpc[31] & virt_nextpc[30]);  //kseg1 & kseg0 unmapped: 0x80000000-0xbfffffff
assign phys_nextpc = mapped ? {s0_pfn, {virt_nextpc[11:0]}} : virt_nextpc;

// IF-exc: AdEL;TLB-Refill(miss);TLB-Invalid
assign prefs_tlb_miss = mapped && !s0_found;
assign prefs_tlb_invalid = mapped && !s0_v;
assign prefs_pc_adel = fs_pc[1:0] != 2'b00;

endmodule