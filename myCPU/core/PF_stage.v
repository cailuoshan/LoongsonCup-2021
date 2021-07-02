`include "mycpu.h"

module pf_stage(
    input                          clk            ,
    input                          reset          ,

    // IF-ID Bus
    input                          fs_allowin     ,
    output                         ps_to_fs_valid ,
    output [`PS_TO_FS_BUS_WD -1:0] ps_to_fs_bus   ,
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    input                          br_leaving     ,

    // IF-WB Bus Exception related
    input         handle_exc,
    input         handle_eret,
    input         exception_tlb_refill,
    input [31:0]  cp0_epc,
    input [31:0]  pipe_flush_pc,
    input         pipe_flush,

    // Inst-sram interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [31:0] inst_sram_addr,
    input         inst_sram_addr_ok,
    output        inst_cache,
    	
	//TLB search port 0     
    output [18:0] s0_vpn2,
    output        s0_odd_page,
    input         s0_found,     
    input  [ 3:0] s0_index,     
    input  [19:0] s0_pfn,     
    input  [ 2:0] s0_c,     
    input         s0_d,     
    input         s0_v,
    
    //TLB refetch tag
    input ds_tlbwir_cancel,
    input refresh_tlb_cache,
    output fs_error
);

// Pre IF
wire                     to_ps_valid;
wire                     ps_ready_go;
wire                     mapped;
wire [31:0]              seq_pc;
wire [31:0]              nextpc;
wire [31:0]              real_pc;
wire [31:0]             _real_pc;
(* max_fanout = "10" *)reg  [`BR_BUS_WD - 1:0]  br_bus_r;
reg                      br_bus_r_valid;
wire                     br_taken;
wire [ 31:0]             br_target;

assign fs_error = ps_ex;
always @(posedge clk) begin
	if (reset)
		br_bus_r <= 33'b0;
	else if (br_leaving)
		br_bus_r <= br_bus;
end

always @(posedge clk) begin
	if (reset)
		br_bus_r_valid <= 1'b0;
    else if (handle_exc || handle_eret || pipe_flush)
        br_bus_r_valid <= 1'b0;
	else if (br_leaving)
		br_bus_r_valid <= 1'b1;
	else if (ps_pc == br_target)
		br_bus_r_valid <= 1'b0;
end

assign br_taken  = br_bus_r_valid && !(ps_pc == br_target) && br_bus_r[32]; 
assign br_target = br_bus_r[31:0]; 

// IF
(* max_fanout = "10" *)reg  [31:0] ps_pc;
(* max_fanout = "10" *)reg         ps_valid;

`ifdef USE_TLB
// TLB query: 0 for get, 1 for querying, 2 for result
(* max_fanout = "10" *)reg  [ 1:0] tlb_query_state;
(* max_fanout = "10" *)reg  [ 1:0] next_state;
wire tlb_hit;

(* max_fanout = "10" *)reg [   18:0] tlb_history_vpn2;
(* max_fanout = "10" *)reg [   19:0] tlb_history_pfn ;
(* max_fanout = "10" *)reg           tlb_history_odd ;
(* max_fanout = "10" *)reg           tlb_history_v   ;
(* max_fanout = "10" *)reg           tlb_history_vv  ;
(* max_fanout = "10" *)reg           tlb_history_found   ;
always @(posedge clk) begin
    if (reset)
        tlb_query_state <= 2'b0;
    else 
        tlb_query_state <= next_state; 
end

assign tlb_hit = ps_pc[12] == tlb_history_odd && ps_pc[31:13] == tlb_history_vpn2 && tlb_history_v;

always @(*) begin
    case (tlb_query_state)
        0:
            if (tlb_hit || !mapped || ps_pc_adel)
                next_state = 0;
            else
                next_state = 1;
        1:
            next_state = 2;
        2:
            next_state = 0;
        default: next_state = 0;
    endcase 
end

always @(posedge clk) begin
    if (reset) begin
        tlb_history_vpn2 <= 32'b0;
        tlb_history_pfn  <= 32'b0;
        tlb_history_odd  <= 32'b0;
        tlb_history_v    <=  1'b0;
        tlb_history_vv   <=  1'b0;
        tlb_history_found<=  1'b0;
    end else if (refresh_tlb_cache) begin
        tlb_history_v    <= 1'b0;
    end else if (tlb_query_state == 0 && !tlb_hit) begin
        tlb_history_vpn2 <= ps_pc[31:13]; 
        tlb_history_odd  <= ps_pc[12];
    end else if (tlb_query_state == 1) begin
        tlb_history_pfn  <= s0_pfn;    
        tlb_history_v    <= 1;
        tlb_history_vv   <= s0_v;    
        tlb_history_found<= s0_found;
    end
end
`endif

wire kseg1 = real_pc[31:29] == 3'b101;
assign inst_cache = !kseg1;

assign ps_to_fs_bus = {ps_pc_adel,
		               ps_tlb_miss,
	                   ps_tlb_invalid,
	                   ps_pc};

// pre-IF stage
assign ps_ready_go = !wait_translation && (inst_sram_req && inst_sram_addr_ok || ps_ex);
assign to_ps_valid = ~reset && ps_ready_go;
assign ps_to_fs_valid = to_ps_valid && ps_ready_go; //&& !handle_exc && !handle_eret && !pipe_flush;

assign nextpc       = br_taken ? br_target: seq_pc;
assign seq_pc       = ps_pc + 3'h4;

`ifdef USE_TLB
wire wait_translation = mapped && !(tlb_query_state == 0 && tlb_hit) && !ps_pc_adel;
`else
wire wait_translation = 0;
`endif

assign inst_sram_req   = ~reset && !wait_translation && fs_allowin && !ps_ex;
assign inst_sram_addr  = ps_ex ? 32'b0 : real_pc; 
assign inst_sram_size  = 2'b10;
assign inst_sram_wdata = 32'b0;
assign inst_sram_wr    = 0;

always @(posedge clk) begin
    if (reset) begin
        ps_valid <= 1'b0;
    end else if (handle_exc || handle_eret || pipe_flush) begin
        ps_valid <= 1'b0;
    end else begin
        ps_valid <= to_ps_valid;
    end
end

always @(posedge clk) begin
    if (reset) begin
        ps_pc <= 32'hbfc00000;
    end else if (handle_exc && exception_tlb_refill) begin
        ps_pc <= 32'hbfc00200;
    end else if (handle_exc) begin
        ps_pc <= 32'hbfc00380;
    end else if (handle_eret) begin
        ps_pc <= cp0_epc;
    end else if (pipe_flush) begin
        ps_pc <= pipe_flush_pc;
    end else if (to_ps_valid && fs_allowin) begin
        ps_pc <= nextpc;
    end
end

// TLB va->pa
`ifdef USE_TLB
assign s0_vpn2        = tlb_history_vpn2;
assign s0_odd_page    = tlb_history_odd;
assign mapped         = ~ps_pc[31] | (ps_pc[31] & ps_pc[30]);
assign _real_pc       = mapped ? {tlb_history_pfn, {ps_pc[11:0]}} : ps_pc;
assign ps_tlb_miss    = mapped && !tlb_history_found;
assign ps_tlb_invalid = mapped && !tlb_history_vv;
`else
assign _real_pc       = ps_pc;
assign ps_tlb_miss    = 0;
assign ps_tlb_invalid = 0;
`endif

assign real_pc        = _real_pc & (_real_pc[31:30] == 2'b10 ? 32'h1fffffff : 32'hffffffff);
assign ps_pc_adel     = ps_pc[1:0] != 2'b00;
assign ps_ex          = ps_pc_adel | ps_tlb_miss | ps_tlb_invalid;

endmodule
