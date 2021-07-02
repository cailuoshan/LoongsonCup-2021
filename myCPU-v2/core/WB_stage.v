 `include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    // Pipline shake
    output                          ws_allowin_1   ,
    input                           ms1_to_ws_valid,
    input [`MS_TO_WS_BUS_WD -1:0]   ms1_to_ws_bus  ,
    output                          ws_allowin_2   ,
    input                           ms2_to_ws_valid,
    input [`MS_TO_WS_BUS_WD -1:0]   ms2_to_ws_bus  ,

    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    // forward_bus
    output [40:0]                   ws1_reg,    // 例外在MEM级报出的话不需要WS的前递
    output [40:0]                   ws2_reg,
    
    //TLB Write Port
    output         tlb_we, 
    output  [ 3:0] w_index,
    output  [18:0] w_vpn2,
    output  [ 7:0] w_asid,
    output         w_g,
    output  [19:0] w_pfn0,
    output  [ 2:0] w_c0,
    output         w_d0,
    output         w_v0,
    output  [19:0] w_pfn1,
    output  [ 2:0] w_c1,
    output         w_d1,
    output         w_v1,
    //TLB Read Port
    output  [ 3:0] r_index,
    input   [18:0] r_vpn2,
    input   [ 7:0] r_asid,
    input          r_g,
    input   [19:0] r_pfn0,
    input   [ 2:0] r_c0,
    input          r_d0,
    input          r_v0,
    input   [19:0] r_pfn1,
    input   [ 2:0] r_c1,
    input          r_d1,
    input          r_v1,

    //trace debug interface
    output [31:0] debug_wb_pc_1     ,
    output [ 3:0] debug_wb_rf_wen_1 ,
    output [ 4:0] debug_wb_rf_wnum_1,
    output [31:0] debug_wb_rf_wdata_1,
    output [31:0] debug_wb_pc_2     ,
    output [ 3:0] debug_wb_rf_wen_2 ,
    output [ 4:0] debug_wb_rf_wnum_2,
    output [31:0] debug_wb_rf_wdata_2
);

// Signal declaration
reg         ws_valid_1;
reg         ws_valid_2;
wire        ws_ready_go;
reg  [`MS_TO_WS_BUS_WD -1:0] ws_inst1_bus_r;
reg  [`MS_TO_WS_BUS_WD -1:0] ws_inst2_bus_r;


//====================================== HandShake for pipeline ===========================================
//提交状态机....................................
localparam COMMIT_START  = 5'b00001;  //两条指令都没到
localparam COMMIT_WAIT_1 = 5'b00010;   //inst2到了，inst1没到
localparam COMMIT_WAIT_2 = 5'b00100;   //inst1到了，inst2没到
localparam COMMIT_DUAL   = 5'b01000;   //两条都到了，提交写回 ???会浪费一拍？        
localparam COMMIT_SINGLE = 5'b10000; //有例外，只提交一条，不需要等另一条了？？
reg [3:0] commit_state;
reg [3:0] commit_next_state;
always @ (posedge aclk) begin
    if(reset) begin
        commit_state <= COMMIT_START;
    end else begin
        commit_state <= commit_next_state;
    end
end
always @ (*) begin
    case (commit_state)
    COMMIT_START:begin
        if (ms2_to_ws_valid && ws_allowin_2) begin         
            commit_next_state = COMMIT_WAIT_1;
        end else if (ms1_to_ws_valid && ws_allowin_1) begin
            commit_next_state = COMMIT_WAIT_2;
        end else if (ms2_to_ws_valid && ws_allowin_2 && ms1_to_ws_valid && ws_allowin_1) begin
            commit_next_state = COMMIT_DUAL;
        end else begin
            commit_next_state = COMMIT_START;
        end
    end
    COMMIT_WAIT_1:begin
        if (ms1_to_ws_valid && ws_allowin_1) begin   
            commit_next_state = COMMIT_DUAL;
        end else begin
            commit_next_state = COMMIT_WAIT_1;
        end
    end
    COMMIT_WAIT_2:begin
        if ((ms1_to_ws_valid && ws_allowin_1) || (ms2_to_ws_valid && ws_allowin_2)) begin   
            commit_next_state = COMMIT_DUAL;
        end else begin
            commit_next_state = COMMIT_WAIT_2;
        end
    end
    COMMIT_DUAL:begin
        commit_next_state = COMMIT_START;
    end
    COMMIT_SINGLE:begin
        ???
    end
        default: commit_next_state = COMMIT_START;
    endcase
end
assign ws_ready_go = (commit_state==COMMIT_DUAL) || (commit_state==COMMIT_SINGLE);    
assign ws_allowin_1 = (commit_state==COMMIT_START) || (commit_state==COMMIT_WAIT_1) || (commit_state==COMMIT_WAIT_2);
assign ws_allowin_2 = (commit_state==COMMIT_START) || (commit_state==COMMIT_WAIT_2);
always @(posedge clk) begin
    if (reset) begin
        ws_valid_1 <= 1'b0;
    end else if (ws_allowin_1) begin
        ws_valid_1 <= ms1_to_ws_valid;  
    end
    if (reset) begin
        ws_valid_2 <= 1'b0;
    end else if (ws_allowin_2) begin
        ws_valid_2 <= ms2_to_ws_valid;  
    end

    if ((commit_state==COMMIT_START || commit_state==COMMIT_WAIT_1) && ms1_to_ws_valid && ws_allowin_1) begin
        ws_inst1_bus_r <= ms1_to_ws_bus;
    end
    if ((commit_state==COMMIT_START || commit_state==COMMIT_WAIT_2) && ms2_to_ws_valid && ws_allowin_2) begin
        ws_inst2_bus_r <= ms2_to_ws_bus;
    end else if ((commit_state==COMMIT_WAIT_2) && ms1_to_ws_valid && ws_allowin_1) begin
        ws_inst2_bus_r <= ms1_to_ws_bus;
    end
end

assign {ws1_refill       ,  //132:132
        ws1_tlbp_found   ,  //131:131
        ws1_tlbwir_cancel,  //130:130
        ws1_index        ,  //129:126
        ws1_tlbwi        ,  //125:125
        ws1_tlbr         ,  //124:124
        ws1_tlbp         ,  //123:123
        ws1_ex           ,  //122:122
        ws1_bd           ,  //121:121
        ws1_badvaddr     ,  //120:89     
        ws1_exccode      ,  //88:84
        ws1_inst_eret    ,  //83:83
        ws1_inst_mfc0    ,  //82:82
        ws1_inst_mtc0    ,  //81:81
        ws1_c0_addr      ,  //80:73
        ws1_gr_we        ,  //72:69
        ws1_dest         ,  //68:64
        ws1_final_result ,  //63:32
        ws1_pc              //31:0
       } = ws_inst1_bus_r;
assign {ws2_refill       ,  //132:132
        ws2_tlbp_found   ,  //131:131
        ws2_tlbwir_cancel,  //130:130
        ws2_index        ,  //129:126
        ws2_tlbwi        ,  //125:125
        ws2_tlbr         ,  //124:124
        ws2_tlbp         ,  //123:123
        ws2_ex           ,  //122:122
        ws2_bd           ,  //121:121
        ws2_badvaddr     ,  //120:89     
        ws2_exccode      ,  //88:84
        ws2_inst_eret    ,  //83:83
        ws2_inst_mfc0    ,  //82:82
        ws2_inst_mtc0    ,  //81:81
        ws2_c0_addr      ,  //80:73
        ws2_gr_we        ,  //72:69
        ws2_dest         ,  //68:64
        ws2_final_result ,  //63:32
        ws2_pc              //31:0
       } = ws_inst2_bus_r;

wire [ 3:0] rf_we_1   ;
wire [ 4:0] rf_waddr_1;
wire [31:0] rf_wdata_1;
wire [ 3:0] rf_we_2   ;
wire [ 4:0] rf_waddr_2;
wire [31:0] rf_wdata_2;
assign rf_we_1    = ws1_gr_we&{4{ws_valid_1}} & {4{~ws1_ex}};
assign rf_waddr_1 = ws1_dest;
assign rf_wdata_1 = ws1_inst_mfc0 ? mfc0_rdata : ws1_final_result;   //???
assign rf_we_2    = ws2_gr_we&{4{ws_valid_2}} & {4{~ws2_ex}};
assign rf_waddr_2 = ws2_dest;
assign rf_wdata_2 = ws2_inst_mfc0 ? mfc0_rdata : ws2_final_result;   //???
assign ws_to_rf_bus = {rf_we_2   ,  
                       rf_waddr_2,  
                       rf_wdata_2,   
                       rf_we_1   ,  //40:37
                       rf_waddr_1,  //36:32
                       rf_wdata_1   //31:0
                      };

// ==========================都需要考虑两条指令按顺序提交的问题===============================================
// debug info generate
assign debug_wb_pc_1       = ws_pc_1;
assign debug_wb_rf_wen_1   = rf_we_1;
assign debug_wb_rf_wnum_1  = ws_dest_1;
assign debug_wb_rf_wdata_1 = rf_wdata_1;
assign debug_wb_pc_2       = ws_pc_2;
assign debug_wb_rf_wen_2   = rf_we_2;
assign debug_wb_rf_wnum_2  = ws_dest_2;
assign debug_wb_rf_wdata_2 = rf_wdata_2;

// TLB
assign r_index=c0_index_index;
assign w_index=c0_index_index;

assign we       =ws_tlbwi_op && ws_valid; 
assign w_vpn2   =c0_entryhi_vpn2;
assign w_asid   =c0_entryhi_asid;
assign w_g      =c0_entrylo0_g0&c0_entrylo1_g1;
assign w_pfn0   =c0_entrylo0_pfn0;
assign w_c0     =c0_entrylo0_c0;
assign w_d0     =c0_entrylo0_d0;
assign w_v0     =c0_entrylo0_v0;
assign w_pfn1   =c0_entrylo1_pfn1;
assign w_c1     =c0_entrylo1_c1;
assign w_d1     =c0_entrylo1_d1;
assign w_v1     =c0_entrylo1_v1;

endmodule