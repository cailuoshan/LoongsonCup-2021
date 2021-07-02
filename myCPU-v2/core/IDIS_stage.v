 `include "mycpu.h"

module idis_stage(
    input                          clk           ,
    input                          reset         ,
    // Pipline shake
      // ds-es
    input                          es1_allowin    ,
    input                          es2_allowin    ,
    output                         ds_to_es1_valid,
    output                         ds_to_es2_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es1_bus  ,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es2_bus  ,
    
    // Forward bypass
    input  [42:0] es1_reg,
    input  [41:0] ms1_reg,
    input  [40:0] ws1_reg,
    input  [42:0] es2_reg,
    input  [41:0] ms2_reg,
    input  [40:0] ws2_reg,
    input         ms1_loading,
    input         ms2_loading,

    // Inst Buffer
    input                          ib_empty,
    output                         ib_fetch_req;
    input  [INST_BUF_LINE_WD-1:0]  ib_rline1;
    input  [INST_BUF_LINE_WD-1:0]  ib_rline2;

    // ws-rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,
    
    // Exception related
    
);

//================================================ Signal declaration ================================================
reg         ds_valid_1 ;
reg         ds_valid_2 ;     //指inst2有效，非path2有效, 目前没用到？？？
wire        ds_ready_go_1;
wire        ds_ready_go_2;   //指inst2可以发射

wire [31:0] ds_pc_1;
wire [31:0] ds_pc_2;
wire [31:0] ds_inst_1;
wire [31:0] ds_inst_2;

wire [ 5:0] op_1;
wire [ 4:0] rs_1;
wire [ 4:0] rt_1;
wire [ 4:0] rd_1;
wire [ 4:0] sa_1;
wire [ 5:0] func_1;
wire [15:0] imm_1;
wire [25:0] jidx_1;
wire [63:0] op_d_1;
wire [31:0] rs_d_1;
wire [31:0] rt_d_1;
wire [31:0] rd_d_1;
wire [31:0] sa_d_1;
wire [63:0] func_d_1;
wire        inst_addu_1;
wire        inst_subu_1;
wire        inst_slt_1;
wire        inst_sltu_1;
wire        inst_and_1;
wire        inst_or_1;
wire        inst_xor_1;
wire        inst_nor_1;
wire        inst_sll_1;
wire        inst_srl_1;
wire        inst_sra_1;
wire        inst_addiu_1;
wire        inst_lui_1;
wire        inst_lw_1;
wire        inst_sw_1;
wire        inst_beq_1;
wire        inst_bne_1;
wire        inst_jal_1;
wire        inst_jr_1;
wire        inst_add_1;
wire        inst_addi_1;
wire        inst_sub_1;
wire        inst_slti_1;
wire        inst_sltiu_1;
wire        inst_andi_1;
wire        inst_ori_1;
wire        inst_xori_1;
wire        inst_sllv_1;
wire        inst_srav_1;
wire        inst_srlv_1;
wire        inst_mult_1;
wire        inst_multu_1;
wire        inst_div_1;
wire        inst_divu_1;
wire        inst_mfhi_1;
wire        inst_mflo_1;
wire        inst_mthi_1;
wire        inst_mtlo_1;
wire        inst_bgez_1;
wire        inst_bgtz_1;
wire        inst_blez_1;
wire        inst_bltz_1;
wire        inst_j_1;
wire        inst_jalr_1;
wire        inst_bgezal_1;
wire        inst_bltzal_1;
wire        inst_lb_1;
wire        inst_lbu_1;
wire        inst_lh_1;
wire        inst_lhu_1;
wire        inst_lwr_1;
wire        inst_lwl_1;
wire        inst_sb_1;
wire        inst_sh_1;
wire        inst_swr_1;
wire        inst_swl_1;
wire        inst_sysc_1;
wire        inst_mfc0_1;
wire        inst_eret_1;
wire        inst_mtc0_1;
wire        inst_break_1;
wire        inst_remain_1;
wire        inst_tlbwi_1;
wire        inst_tlbp_1;
wire        inst_tlbr_1;

wire [ 4:0] dest_1;
wire [31:0] rs_value_1;
wire [31:0] rt_value_1;
wire [11:0] alu_op_1;
wire [ 4:0] store_op_1;
wire [ 6:0] load_op_1;
wire        src1_is_sa_1;
wire        src1_is_pc_1;
wire        src2_is_imm_1;
wire        src2_is_zimm_1;
wire        src2_is_8_1;
wire        dst_is_r31_1;  
wire        dst_is_rt_1;  
wire        gr_we_1;
wire        mem_we_1; 
wire        rs_eq_rt_1;
wire        rs_gez_1;
wire        rs_gtz_1;

wire [ 4:0] rf_raddr1_1;
wire [31:0] rf_rdata1_1;
wire [ 4:0] rf_raddr2_1;
wire [31:0] rf_rdata2_1;

wire [ 5:0] op_2;
wire [ 4:0] rs_2;
wire [ 4:0] rt_2;
wire [ 4:0] rd_2;
wire [ 4:0] sa_2;
wire [ 5:0] func_2;
wire [15:0] imm_2;
wire [25:0] jidx_2;
wire [63:0] op_d_2;
wire [31:0] rs_d_2;
wire [31:0] rt_d_2;
wire [31:0] rd_d_2;
wire [31:0] sa_d_2;
wire [63:0] func_d_2;
wire        inst_addu_2;
wire        inst_subu_2;
wire        inst_slt_2;
wire        inst_sltu_2;
wire        inst_and_2;
wire        inst_or_2;
wire        inst_xor_2;
wire        inst_nor_2;
wire        inst_sll_2;
wire        inst_srl_2;
wire        inst_sra_2;
wire        inst_addiu_2;
wire        inst_lui_2;
wire        inst_lw_2;
wire        inst_sw_2;
wire        inst_beq_2;
wire        inst_bne_2;
wire        inst_jal_2;
wire        inst_jr_2;
wire        inst_add_2;
wire        inst_addi_2;
wire        inst_sub_2;
wire        inst_slti_2;
wire        inst_sltiu_2;
wire        inst_andi_2;
wire        inst_ori_2;
wire        inst_xori_2;
wire        inst_sllv_2;
wire        inst_srav_2;
wire        inst_srlv_2;
wire        inst_mult_2;
wire        inst_multu_2;
wire        inst_div_2;
wire        inst_divu_2;
wire        inst_mfhi_2;
wire        inst_mflo_2;
wire        inst_mthi_2;
wire        inst_mtlo_2;
wire        inst_bgez_2;
wire        inst_bgtz_2;
wire        inst_blez_2;
wire        inst_bltz_2;
wire        inst_j_2;
wire        inst_jalr_2;
wire        inst_bgezal_2;
wire        inst_bltzal_2;
wire        inst_lb_2;
wire        inst_lbu_2;
wire        inst_lh_2;
wire        inst_lhu_2;
wire        inst_lwr_2;
wire        inst_lwl_2;
wire        inst_sb_2;
wire        inst_sh_2;
wire        inst_swr_2;
wire        inst_swl_2;
wire        inst_sysc_2;
wire        inst_mfc0_2;
wire        inst_eret_2;
wire        inst_mtc0_2;
wire        inst_break_2;
wire        inst_remain_2;
wire        inst_tlbwi_2;
wire        inst_tlbp_2;
wire        inst_tlbr_2;

wire [ 4:0] dest_2;
wire [31:0] rs_value_2;
wire [31:0] rt_value_2;
wire [11:0] alu_op_2;
wire [ 4:0] store_op_2;
wire [ 6:0] load_op_2;
wire        src1_is_sa_2;
wire        src1_is_pc_2;
wire        src2_is_imm_2;
wire        src2_is_zimm_2;
wire        src2_is_8_2;
wire        dst_is_r31_2;  
wire        dst_is_rt_2;  
wire        gr_we_2;
wire        mem_we_2; 
wire        rs_eq_rt_2;
wire        rs_gez_2;
wire        rs_gtz_2;

wire [ 4:0] rf_raddr1_2;
wire [31:0] rf_rdata1_2;
wire [ 4:0] rf_raddr2_2;
wire [31:0] rf_rdata2_2;

wire        ds_related;     // 待发射的两条指令存在RAW/WAW相关
wire        ds_both_ldst;
wire        ds_both_divmul;
wire        wait_load_1;    // inst1需要等待访存得到的结果
wire        wait_load_2;


wire        ds_ex_1;
wire        ds_badvaddr_1;
wire        ds_adel_1;
wire        ds_tlb_miss_1;
wire        ds_tlb_invalid_1;
wire [ 4:0] ds_exccode_1;
wire        ds_ex_2;
wire        ds_badvaddr_2;
wire        ds_adel_2;
wire        ds_tlb_miss_2;
wire        ds_tlb_invalid_2;
wire [ 4:0] ds_exccode_2;

// ======================================= HandShake for pipeline =================================================
wire [ 3:0] rf_we_1   ;
wire [ 4:0] rf_waddr_1;
wire [31:0] rf_wdata_1;
wire [ 3:0] rf_we_2   ;
wire [ 4:0] rf_waddr_2;
wire [31:0] rf_wdata_2;
assign {rf_we_2   ,  
        rf_waddr_2,  
        rf_wdata_2,   
        rf_we_1   ,  //40:37
        rf_waddr_1,  //36:32
        rf_wdata_1   //31:0
       } = ws_to_rf_bus;  
/*wire        br_stall;
wire        is_branch;
wire        br_taken;
wire [31:0] br_target;
assign br_bus = {br_stall,
                 is_branch,
                 br_taken,
                 br_target}; in IF-stage??? or still need here?*/
wire [ 3:0] es_we_1;
wire [ 4:0] es_dest_1;
wire [31:0] es_result_1;
wire        es_load_1;
wire        es_is_mfc0_1;
assign {es_we_1,
        es_load_1,
		es_is_mfc0_1,
		es_dest_1,
		es_result_1} = es1_reg;
wire [ 3:0] ms_we_1;
wire [ 4:0] ms_dest_1;
wire [31:0] ms_result_1;
wire        ms_is_mfc0_1;
assign {ms_we_1,
		ms_is_mfc0_1,
		ms_dest_1,
		ms_result_1} = ms1_reg;
wire [ 3:0] ws_we_1;
wire [ 4:0] ws_dest_1;
wire [31:0] ws_result_1;		
assign {ws_we_1,
		ws_dest_1,
		ws_result_1} = ws1_reg;

wire [ 3:0] es_we_2;
wire [ 4:0] es_dest_2;
wire [31:0] es_result_2;
wire        es_load_2;
wire        es_is_mfc0_2;
assign {es_we_2,
        es_load_2,
		es_is_mfc0_2,
		es_dest_2,
		es_result_2} = es2_reg;
wire [ 3:0] ms_we_2;
wire [ 4:0] ms_dest_2;
wire [31:0] ms_result_2;
wire        ms_is_mfc0_2;
assign {ms_we_2,
		ms_is_mfc0_2,
		ms_dest_2,
		ms_result_2} = ms2_reg;
wire [ 3:0] ws_we_2;
wire [ 4:0] ws_dest_2;
wire [31:0] ws_result_2;		
assign {ws_we_2,
		ws_dest_2,
		ws_result_2} = ws2_reg;                  

// Issue according to relations	
wire   rt_re_1;   // inst1 should read reg[rt]
wire   rs_re_1;
wire   rt_re_2;   // inst2 should read reg[rt]
wire   rs_re_2;
assign rt_re_1      = !(dst_is_rt_1 | inst_jal_1     | inst_jr_1   | inst_mthi_1 | inst_mtlo_1   | inst_j_1 | inst_jalr_1 |
                        inst_bgez_1 | inst_bgtz_1    | inst_blez_1 | inst_bltz_1 | inst_bgezal_1 | inst_bltzal_1 | 
                        inst_eret_1 | inst_syscall_1 | inst_tlbp_1 | inst_tlbr_1 | inst_tlbwi_1  );
assign rs_re_1      = !(inst_lui_1  | inst_sll_1     | inst_srl_1  | inst_sra_1  | mem_we_1     | inst_jal_1  | inst_j_1 | 
                        inst_eret_1 | inst_syscall_1 | inst_tlbp_1 | inst_tlbr_1 | inst_tlbwi_1 | inst_mtc0_1 | inst_mfc0_1);
assign rt_re_2      = !(dst_is_rt_2 | inst_jal_2     | inst_jr_2   | inst_mthi_2 | inst_mtlo_2   | inst_j_2 | inst_jalr_2 |
                        inst_bgez_2 | inst_bgtz_2    | inst_blez_2 | inst_bltz_2 | inst_bgezal_2 | inst_bltzal_2 | 
                        inst_eret_2 | inst_syscall_2 | inst_tlbp_2 | inst_tlbr_2 | inst_tlbwi_2  );
assign rs_re_2      = !(inst_lui_2  | inst_sll_2     | inst_srl_2  | inst_sra_2  | mem_we_2     | inst_jal_2  | inst_j_2 | 
                        inst_eret_2 | inst_syscall_2 | inst_tlbp_2 | inst_tlbr_2 | inst_tlbwi_2 | inst_mtc0_2 | inst_mfc0_2);
assign ds_related   = (gr_we_1 && rt_re_2 && dest1==rt_2) ||
                      (gr_we_1 && rs_re_2 && dest1==rs_2) ||
                      (gr_we_1 && gr_we_2 && dest1==dest2);                            //待发射的两条指令间存在RAW/WAW相关
assign ds_both_ldst = (|load_op_1 || |store_op_1) && (|load_op_2 || |store_op_2);
assign ds_both_divmul = (inst_mult_1 || inst_multu_1 || inst_div_1 || inst_divu_1) &&
                        (inst_mult_2 || inst_multu_2 || inst_div_2 || inst_divu_2) ;
assign wait_load_1  = (es_load_1 && rt_re_1 && (es_dest_1 == rt_1 && rt_1 != 0)) ||
                      (es_load_1 && rs_re_1 && (es_dest_1 == rs_1 && rs_1 != 0)) ||
                      (es_load_2 && rt_re_1 && (es_dest_2 == rt_1 && rt_1 != 0)) ||
                      (es_load_2 && rs_re_1 && (es_dest_2 == rs_1 && rs_1 != 0)) ||
                      (ms1_loading && rt_re_1 && (ms_dest_1 == rt_1 && rt_1 != 0)) ||
                      (ms1_loading && rs_re_1 && (ms_dest_1 == rs_1 && rs_1 != 0)) ||
                      (ms2_loading && rt_re_1 && (ms_dest_2 == rt_1 && rt_1 != 0)) ||
                      (ms2_loading && rs_re_1 && (ms_dest_2 == rs_1 && rs_1 != 0));    // inst1需要等待访存得到的结果
assign wait_load_2  = (es_load_1 && rt_re_2 && (es_dest_1 == rt_2 && rt_2 != 0)) ||
                      (es_load_1 && rs_re_2 && (es_dest_1 == rs_2 && rs_2 != 0)) ||
                      (es_load_2 && rt_re_2 && (es_dest_2 == rt_2 && rt_2 != 0)) ||
                      (es_load_2 && rs_re_2 && (es_dest_2 == rs_2 && rs_2 != 0)) ||
                      (ms1_loading && rt_re_2 && (ms_dest_1 == rt_2 && rt_2 != 0)) ||
                      (ms1_loading && rs_re_2 && (ms_dest_1 == rs_2 && rs_2 != 0)) ||
                      (ms2_loading && rt_re_2 && (ms_dest_2 == rt_2 && rt_2 != 0)) ||
                      (ms2_loading && rs_re_2 && (ms_dest_2 == rs_2 && rs_2 != 0));                                                 
assign ds_ready_go_1   = (handle_exc || handle_eret || pipe_flush) || 
                        !(wait_load_1|| ...);	                                                //指Inst1可以发射
assign ds_ready_go_2   = (handle_exc || handle_eret || pipe_flush) || 
                        !(wait_load_2|| ds_related  || ds_both_ldst|| ds_both_divmul || ...);   //指Inst2可以发射
// 发射的状态机...........................................
localparam FETCH_INSTS = 4'b0001;
localparam ISSUE_SINGLE_1 = 4'b0010; 
localparam ISSUE_SINGLE_2 = 4'b0100;           
localparam ISSUE_DUAL = 4'b1000;               

reg [3:0] issue_state;
reg [3:0] issue_next_state;
always @ (posedge aclk) begin
    if(reset) begin
        issue_state <= FETCH_INSTS;
    end else begin
        issue_state <= issue_next_state;
    end
end
always @ (*) begin
    case (issue_state)
    FETCH_INSTS:begin
        if (!ib_empty && (ds_related || ds_both_ldst || ds_both_divmul)) begin         
            issue_next_state = ISSUE_SINGLE_1;
        end else if (!ib_empty && !(ds_related || ds_both_ldst || ds_both_divmul)) begin
            issue_next_state = ISSUE_DUAL;
        end else begin
            issue_next_state = FETCH_INSTS;
        end
    end
    ISSUE_SINGLE_1:begin
        if (ds_ready_go_1 && es1_allowin) begin   //???ds_to_es1_valid?
            issue_next_state = ISSUE_SINGLE_2;
        end else begin
            issue_next_state = ISSUE_SINGLE_1;
        end
    end
    ISSUE_SINGLE_2:begin
        if (ds_ready_go_2 && es1_allowin) begin         
            issue_next_state = FETCH_INSTS;
        end else begin
            issue_next_state = ISSUE_SINGLE_2;
        end
    end
    ISSUE_DUAL:begin
        if (ds_ready_go_1 && ds_ready_go_2 && es1_allowin && es2_allowin) begin
            issue_next_state = FETCH_INSTS;
        end else begin
            issue_next_state = ISSUE_DUAL;
        end
    end
        default: issue_next_state = FETCH_INSTS;
    endcase
end
// 路径1发射有效
assign ds_to_es1_valid = ~reset && !handle_exc && !handle_eret && !pipe_flush &&
                        ((issue_state==ISSUE_SINGLE_1 && ds_ready_go_1) ||
                         (issue_state==ISSUE_SINGLE_2 && ds_ready_go_2) ||
                         (issue_state==ISSUE_DUAL && ds_ready_go_1 && ds_ready_go_2 && es1_allowin && es2_allowin)
                        ); 
// 路径2发射有效
assign ds_to_es2_valid = ~reset && !handle_exc && !handle_eret && !pipe_flush &&
                        (issue_state==ISSUE_DUAL && ds_ready_go_1 && ds_ready_go_2 && es1_allowin && es2_allowin);	
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_1;  //inst_1的流水Bus
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_2;
assign ds_to_es_bus_1 = {ds_tlb_refill ,  //211:211  ??
                        fs_tlbwir_cancel, //210:210  
                        inst_tlbp_1   ,  //209:209
                        inst_tlbr_1   ,  //208:208
                        inst_tlbwi_1  ,  //207:207
                        of_check_1    ,  //206:206    
                        ds_badvaddr_1 ,  //205:174    
                        ds_exccode_1  ,  //173:169
                        ds_ex_1       ,  //168:168
                        ds_bd_1       ,  //167:167 
                        inst_eret_1   ,  //166:166
                        inst_mfc0_1   ,  //165:165
                        inst_mtc0_1   ,  //164:164
                        ds_c0_addr_1  ,  //163:156    ??
                        alu_op_1      ,  //155:144
                        store_op_1    ,  //143:139
                        load_op_1     ,  //138:132
                        inst_mult_1   ,  //131:131
                        inst_multu_1  ,  //130:130
                        inst_div_1    ,  //129:129
                        inst_divu_1   ,  //128:128
                        inst_mthi_1   ,  //127:127
                        inst_mtlo_1   ,  //126:126
                        inst_mfhi_1   ,  //125:125
                        inst_mflo_1   ,  //124:124
                        src1_is_sa_1  ,  //123:123
                        src1_is_pc_1  ,  //122:122
                        src2_is_imm_1 ,  //121:121
                        src2_is_zimm_1,  //120:120
                        src2_is_8_1   ,  //119:119
                        gr_we_1       ,  //118:118
                        mem_we_1      ,  //117:117
                        dest_1        ,  //116:112
                        imm_1         ,  //111:96
                        rs_value_1    ,  //95 :64
                        rt_value_1    ,  //63 :32
                        ds_pc_1          //31 :0
                       };
assign ds_to_es_bus_2 = {ds_tlb_refill ,  //211:211  ??
                        fs_tlbwir_cancel, //210:210  
                        inst_tlbp_2   ,  //209:209
                        inst_tlbr_2   ,  //208:208
                        inst_tlbwi_2  ,  //207:207
                        of_check_2    ,  //206:206    
                        ds_badvaddr_2 ,  //205:174    
                        ds_exccode_2  ,  //173:169
                        ds_ex_2       ,  //168:168
                        ds_bd_2       ,  //167:167 
                        inst_eret_2   ,  //166:166
                        inst_mfc0_2   ,  //165:165
                        inst_mtc0_2   ,  //164:164
                        ds_c0_addr_2  ,  //163:156    ??
                        alu_op_2      ,  //155:144
                        store_op_2    ,  //143:139
                        load_op_2     ,  //138:132
                        inst_mult_2   ,  //131:131
                        inst_multu_2  ,  //130:130
                        inst_div_2    ,  //129:129
                        inst_divu_2   ,  //128:128
                        inst_mthi_2   ,  //127:127
                        inst_mtlo_2   ,  //126:126
                        inst_mfhi_2   ,  //125:125
                        inst_mflo_2   ,  //124:124
                        src1_is_sa_2  ,  //123:123
                        src1_is_pc_2  ,  //122:122
                        src2_is_imm_2 ,  //121:121
                        src2_is_zimm_2,  //120:120
                        src2_is_8_2   ,  //119:119
                        gr_we_2       ,  //118:118
                        mem_we_2      ,  //117:117
                        dest_2        ,  //116:112
                        imm_2         ,  //111:96
                        rs_value_2    ,  //95 :64
                        rt_value_2    ,  //63 :32
                        ds_pc_2          //31 :0
                       };      
assign ds_to_es1_bus = (issue_state==ISSUE_SINGLE_2) ? ds_to_es_bus_2 : ds_to_es_bus_1;
assign ds_to_es2_bus = ds_to_es_bus_2;
// Fetch 2 insts from inst_buffer
assign ib_fetch_req = !ib_empty && (issue_state==FETCH_INSTS);
assign {ds_pc_1,
        ds_inst_1,
        ds_tlb_miss_1,
        ds_tlb_invalid_1,
        ds_adel_1} = ib_rline1;
assign {ds_pc_2,
        ds_inst_2,
        ds_tlb_miss_2,
        ds_tlb_invalid_2,
        ds_adel_2} = ib_rline2;

//============================== Decode (double)============================================================
assign op_1   = ds_inst_1[31:26];
assign rs_1   = ds_inst_1[25:21];
assign rt_1   = ds_inst_1[20:16];
assign rd_1   = ds_inst_1[15:11];
assign sa_1   = ds_inst_1[10: 6];
assign func_1 = ds_inst_1[ 5: 0];
assign imm_1  = ds_inst_1[15: 0];
assign jidx_1 = ds_inst_1[25: 0];

decoder_6_64 u_dec0_1(.in(op_1  ), .out(op_d_1  ));
decoder_6_64 u_dec1_1(.in(func_1), .out(func_d_1));
decoder_5_32 u_dec2_1(.in(rs_1  ), .out(rs_d_1  ));
decoder_5_32 u_dec3_1(.in(rt_1  ), .out(rt_d_1  ));
decoder_5_32 u_dec4_1(.in(rd_1  ), .out(rd_d_1  ));
decoder_5_32 u_dec5_1(.in(sa_1  ), .out(sa_d_1  ));

assign inst_addu_1   = op_d_1[6'h00] & func_d_1[6'h21] & sa_d_1[5'h00];
assign inst_subu_1   = op_d_1[6'h00] & func_d_1[6'h23] & sa_d_1[5'h00];
assign inst_slt_1    = op_d_1[6'h00] & func_d_1[6'h2a] & sa_d_1[5'h00];
assign inst_sltu_1   = op_d_1[6'h00] & func_d_1[6'h2b] & sa_d_1[5'h00];
assign inst_and_1    = op_d_1[6'h00] & func_d_1[6'h24] & sa_d_1[5'h00];
assign inst_or_1     = op_d_1[6'h00] & func_d_1[6'h25] & sa_d_1[5'h00];
assign inst_xor_1    = op_d_1[6'h00] & func_d_1[6'h26] & sa_d_1[5'h00];
assign inst_nor_1    = op_d_1[6'h00] & func_d_1[6'h27] & sa_d_1[5'h00];
assign inst_sll_1    = op_d_1[6'h00] & func_d_1[6'h00] & rs_d_1[5'h00];
assign inst_srl_1    = op_d_1[6'h00] & func_d_1[6'h02] & rs_d_1[5'h00];
assign inst_sra_1    = op_d_1[6'h00] & func_d_1[6'h03] & rs_d_1[5'h00];
assign inst_addiu_1  = op_d_1[6'h09];
assign inst_lui_1    = op_d_1[6'h0f] & rs_d_1[5'h00];
assign inst_lw_1     = op_d_1[6'h23];
assign inst_sw_1     = op_d_1[6'h2b];
assign inst_beq_1    = op_d_1[6'h04];
assign inst_bne_1    = op_d_1[6'h05];
assign inst_jal_1    = op_d_1[6'h03];
assign inst_jr_1     = op_d_1[6'h00] & func_d_1[6'h08] & rt_d_1[5'h00] & rd_d_1[5'h00] & sa_d_1[5'h00];
assign inst_add_1    = op_d_1[6'h00] & func_d_1[6'h20] & sa_d_1[5'h00];
assign inst_addi_1   = op_d_1[6'h08];
assign inst_sub_1    = op_d_1[6'h00] & func_d_1[6'h22] & sa_d_1[5'h00];
assign inst_slti_1   = op_d_1[6'h0a];
assign inst_sltiu_1  = op_d_1[6'h0b];
assign inst_andi_1   = op_d_1[6'h0c];
assign inst_ori_1    = op_d_1[6'h0d];
assign inst_xori_1   = op_d_1[6'h0e];
assign inst_sllv_1   = op_d_1[6'h00] & func_d_1[6'h04] & sa_d_1[5'h00];
assign inst_srav_1   = op_d_1[6'h00] & func_d_1[6'h07] & sa_d_1[5'h00];
assign inst_srlv_1   = op_d_1[6'h00] & func_d_1[6'h06] & sa_d_1[5'h00];
assign inst_div_1    = op_d_1[6'h00] & func_d_1[6'h1a] & sa_d_1[5'h00] & rd_d_1[5'h00];
assign inst_divu_1   = op_d_1[6'h00] & func_d_1[6'h1b] & sa_d_1[5'h00] & rd_d_1[5'h00];
assign inst_mult_1   = op_d_1[6'h00] & func_d_1[6'h18] & sa_d_1[5'h00] & rd_d_1[5'h00];
assign inst_multu_1  = op_d_1[6'h00] & func_d_1[6'h19] & sa_d_1[5'h00] & rd_d_1[5'h00];
assign inst_mfhi_1   = op_d_1[6'h00] & func_d_1[6'h10] & rs_d_1[5'h00] & rt_d_1[5'h00] & sa_d_1[5'h00];
assign inst_mflo_1   = op_d_1[6'h00] & func_d_1[6'h12] & rs_d_1[5'h00] & rt_d_1[5'h00] & sa_d_1[5'h00];
assign inst_mthi_1   = op_d_1[6'h00] & func_d_1[6'h11] & rd_d_1[5'h00] & rt_d_1[5'h00] & sa_d_1[5'h00];
assign inst_mtlo_1   = op_d_1[6'h00] & func_d_1[6'h13] & rd_d_1[5'h00] & rt_d_1[5'h00] & sa_d_1[5'h00];
assign inst_bgez_1   = op_d_1[6'h01] & rt_d_1[5'h01];
assign inst_bgtz_1   = op_d_1[6'h07] & rt_d_1[5'h00];
assign inst_blez_1   = op_d_1[6'h06] & rt_d_1[5'h00];
assign inst_bltz_1   = op_d_1[6'h01] & rt_d_1[5'h00];
assign inst_j_1      = op_d_1[6'h02];
assign inst_jalr_1   = op_d_1[6'h00] & rt_d_1[5'h00] & sa_d_1[5'h00] & func_d_1[6'h09];
assign inst_bgezal_1 = op_d_1[6'h01] & rt_d_1[5'h11];
assign inst_bltzal_1 = op_d_1[6'h01] & rt_d_1[5'h10];
assign inst_lb_1     = op_d_1[6'h20];
assign inst_lbu_1    = op_d_1[6'h24];
assign inst_lh_1     = op_d_1[6'h21];
assign inst_lhu_1    = op_d_1[6'h25];
assign inst_lwl_1    = op_d_1[6'h22];
assign inst_lwr_1    = op_d_1[6'h26];
assign inst_sb_1     = op_d_1[6'h28];
assign inst_sh_1     = op_d_1[6'h29];
assign inst_swl_1    = op_d_1[6'h2a];
assign inst_swr_1    = op_d_1[6'h2e];

assign inst_mfc0_1   = op_d_1[6'h10] & rs_d_1[5'h00] & (ds_inst_1[10:3] == 8'h00);
assign inst_mtc0_1   = op_d_1[6'h10] & rs_d_1[5'h04] & (ds_inst_1[10:3] == 8'h00);
assign inst_sysc_1   = op_d_1[6'h00] & func_d_1[6'h0c];
assign inst_eret_1   = op_d_1[6'h10] & func_d_1[6'h18] & (ds_inst_1[25:6] == 20'h80000);
assign inst_break_1  = op_d_1[6'h00] & func_d_1[6'h0d];

assign inst_tlbwi_1  = op_d_1[6'h10] & ds_inst_1[25] & (ds_inst_1[24:6] == 0) & func_d_1[6'h02];
assign inst_tlbp_1   = op_d_1[6'h10] & ds_inst_1[25] & (ds_inst_1[24:6] == 0) & func_d_1[6'h08];
assign inst_tlbr_1   = op_d_1[6'h10] & ds_inst_1[25] & (ds_inst_1[24:6] == 0) & func_d_1[6'h01];

assign inst_remain_1 = !( inst_addu_1 | inst_subu_1   | inst_slt_1    | inst_sltu_1   | inst_and_1    | inst_or_1   | inst_xor_1  
                        | inst_nor_1  | inst_sll_1    | inst_srl_1    | inst_sra_1    | inst_addiu_1  | inst_lui_1  | inst_lw_1   
                        | inst_sw_1   | inst_beq_1    | inst_bne_1    | inst_jal_1    | inst_jr_1     | inst_add_1  | inst_addi_1   
                        | inst_sub_1  | inst_slti_1   | inst_sltiu_1  | inst_andi_1   | inst_ori_1    | inst_xori_1 | inst_sllv_1   
                        | inst_srlv_1 | inst_srav_1   | inst_mult_1   | inst_multu_1  | inst_div_1    | inst_divu_1 | inst_mfhi_1 
                        | inst_mflo_1 | inst_mthi_1   | inst_mtlo_1   | inst_bgez_1   | inst_bgtz_1   | inst_blez_1 | inst_bltz_1 
                        | inst_j_1    | inst_bltzal_1 | inst_bgezal_1 | inst_jalr_1   | inst_lb_1     | inst_lbu_1  | inst_lh_1   
                        | inst_lhu_1  | inst_lwl_1    | inst_lwr_1    | inst_sb_1     | inst_sh_1     | inst_swl_1  | inst_swr_1 
                        | inst_sysc_1 | inst_eret_1   | inst_mfc0_1   | inst_mtc0_1   | inst_break_1  | inst_tlbp_1 | inst_tlbwi_1
                        | inst_tlbr_1);

assign alu_op_1[ 0] = inst_add_1  | inst_addu_1 | inst_addi_1   | inst_addiu_1  | inst_lw_1 | inst_sw_1 | 
                      inst_jal_1  | inst_jalr_1 | inst_bltzal_1 | inst_bgezal_1 | inst_lb_1 | inst_lh_1 |
                      inst_lbu_1  | inst_lhu_1  | inst_lwl_1    | inst_lwr_1    | inst_sb_1 | inst_sh_1 |
                      inst_swr_1  | inst_swl_1  ;
assign alu_op_1[ 1] = inst_sub_1  | inst_subu_1;
assign alu_op_1[ 2] = inst_slt_1  | inst_slti_1;
assign alu_op_1[ 3] = inst_sltu_1 | inst_sltiu_1;
assign alu_op_1[ 4] = inst_and_1  | inst_andi_1;
assign alu_op_1[ 5] = inst_nor_1;
assign alu_op_1[ 6] = inst_or_1   | inst_ori_1;
assign alu_op_1[ 7] = inst_xor_1  | inst_xori_1;
assign alu_op_1[ 8] = inst_sll_1  | inst_sllv_1;
assign alu_op_1[ 9] = inst_srl_1  | inst_srlv_1;
assign alu_op_1[10] = inst_sra_1  | inst_srav_1;
assign alu_op_1[11] = inst_lui_1;

assign store_op_1 = {inst_swr_1,inst_swl_1,inst_sw_1,inst_sh_1,inst_sb_1};
assign load_op_1  = {inst_lwr_1,inst_lwl_1,inst_lw_1,inst_lhu_1,inst_lh_1,inst_lbu_1,inst_lb_1};
assign src1_is_sa_1   = inst_sll_1  | inst_srl_1    | inst_sra_1;
assign src1_is_pc_1   = inst_jal_1  | inst_bgezal_1 | inst_bltzal_1 | inst_jalr_1;
assign src2_is_imm_1  = inst_slti_1 | inst_sltiu_1  | inst_addi_1   | inst_addiu_1 | inst_lui_1  | inst_lw_1  | inst_sw_1   |
                        inst_lb_1   | inst_lbu_1    | inst_lh_1     | inst_lhu_1   | inst_lwl_1  | inst_lwr_1 | inst_swl_1  |
                        inst_swr_1  | inst_sb_1     | inst_sh_1     ;
assign src2_is_zimm_1 = inst_andi_1 | inst_ori_1    | inst_xori_1   ;
assign src2_is_8_1    = inst_jal_1  | inst_bgezal_1 | inst_bltzal_1 | inst_jalr_1;
assign dst_is_r31_1   = inst_jal_1  | inst_bgezal_1 | inst_bltzal_1;
assign dst_is_rt_1    = inst_addi_1 | inst_addiu_1  | inst_lui_1    | inst_sltiu_1 | inst_slti_1 | inst_lw_1  | inst_andi_1 |
                        inst_ori_1  | inst_xori_1   | inst_lb_1     | inst_lbu_1   | inst_lh_1   | inst_lhu_1 | inst_lwl_1  |
                        inst_lwr_1  | inst_mfc0_1;
assign gr_we_1        = ~inst_bgtz_1 & ~inst_blez_1 & ~inst_bgez_1 & ~inst_bltz_1  & ~inst_j_1   & ~inst_sw_1   & ~inst_beq_1 
                      & ~inst_bne_1  & ~inst_jr_1   & ~inst_mult_1 & ~inst_multu_1 & ~inst_div_1 & ~inst_divu_1 & ~inst_mthi_1 
                      & ~inst_mtlo_1 & ~inst_swr_1  & ~inst_swl_1  & ~inst_sh_1    & ~inst_sb_1  & ~inst_mtc0_1 & ~inst_sysc_1
                      & ~inst_eret_1 & ~inst_break_1& ~inst_tlbwi_1& ~inst_tlbp_1  & ~inst_tlbr_1;
assign mem_we_1       = inst_sw_1 | inst_sb_1 | inst_sh_1 | inst_swl_1 | inst_swr_1;
//assign ds_tlbwir_cancel_1 = inst_tlbwi_1 | inst_tlbr_1;

assign dest_1         = dst_is_r31_1 ? 5'd31 :
                        dst_is_rt_1  ? rt_1  :
                        (gr_we_1 == 1'b0) ? 5'b0 :
                                       rd_1;
// 在路径1一定比路径2的指令在前的设计中，写后读相关顺序如下
assign rs_value_1[ 7: 0] = (es_we_2[0] && es_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? es_result_2[ 7: 0] :
                           (es_we_1[0] && es_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? es_result_1[ 7: 0] :
                           (ms_we_2[0] && ms_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? ms_result_2[ 7: 0] :
                           (ms_we_1[0] && ms_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? ms_result_1[ 7: 0] :
                           (ws_we_2[0] && ws_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? ws_result_2[ 7: 0] :
                           (ws_we_1[0] && ws_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? ws_result_1[ 7: 0] :
                           rf_rdata1_1[ 7: 0];
assign rt_value_1[ 7: 0] = (es_we_2[0] && es_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? es_result_2[ 7: 0] :
                           (es_we_1[0] && es_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? es_result_1[ 7: 0] :
                           (ms_we_2[0] && ms_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? ms_result_2[ 7: 0] :
                           (ms_we_1[0] && ms_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? ms_result_1[ 7: 0] :
                           (ws_we_2[0] && ws_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? ws_result_2[ 7: 0] :
                           (ws_we_1[0] && ws_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? ws_result_1[ 7: 0] :
                           rf_rdata2_1[ 7: 0];
assign rs_value_1[15: 8] = (es_we_2[1] && es_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? es_result_2[15: 8] :
                           (es_we_1[1] && es_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? es_result_1[15: 8] :
                           (ms_we_2[1] && ms_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? ms_result_2[15: 8] :
                           (ms_we_1[1] && ms_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? ms_result_1[15: 8] :
                           (ws_we_2[1] && ws_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? ws_result_2[15: 8] :
                           (ws_we_1[1] && ws_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? ws_result_1[15: 8] :
                           rf_rdata1_1[15: 8];
assign rt_value_1[15: 8] = (es_we_2[1] && es_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? es_result_2[15: 8] :
                           (es_we_1[1] && es_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? es_result_1[15: 8] :
                           (ms_we_2[1] && ms_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? ms_result_2[15: 8] :
                           (ms_we_1[1] && ms_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? ms_result_1[15: 8] :
                           (ws_we_2[1] && ws_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? ws_result_2[15: 8] :
                           (ws_we_1[1] && ws_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? ws_result_1[15: 8] :
                           rf_rdata2_1[15: 8];
assign rs_value_1[23:16] = (es_we_2[2] && es_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? es_result_2[23:16] :
                           (es_we_1[2] && es_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? es_result_1[23:16] :
                           (ms_we_2[2] && ms_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? ms_result_2[23:16] :
                           (ms_we_1[2] && ms_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? ms_result_1[23:16] :
                           (ws_we_2[2] && ws_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? ws_result_2[23:16] :
                           (ws_we_1[2] && ws_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? ws_result_1[23:16] :
                           rf_rdata1_1[23:16];
assign rt_value_1[23:16] = (es_we_2[2] && es_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? es_result_2[23:16] :
                           (es_we_1[2] && es_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? es_result_1[23:16] :
                           (ms_we_2[2] && ms_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? ms_result_2[23:16] :
                           (ms_we_1[2] && ms_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? ms_result_1[23:16] :
                           (ws_we_2[2] && ws_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? ws_result_2[23:16] :
                           (ws_we_1[2] && ws_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? ws_result_1[23:16] :
                           rf_rdata2_1[23:16];
assign rs_value_1[31:24] = (es_we_2[3] && es_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? es_result_2[31:24] :
                           (es_we_1[3] && es_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? es_result_1[31:24] :
                           (ms_we_2[3] && ms_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? ms_result_2[31:24] :
                           (ms_we_1[3] && ms_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? ms_result_1[31:24] :
                           (ws_we_2[3] && ws_dest_2 == rf_raddr1_1 && rf_raddr1_1!=0)? ws_result_2[31:24] :
                           (ws_we_1[3] && ws_dest_1 == rf_raddr1_1 && rf_raddr1_1!=0)? ws_result_1[31:24] :
                           rf_rdata1_1[31:24];
assign rt_value_1[31:24] = (es_we_2[3] && es_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? es_result_2[31:24] :
                           (es_we_1[3] && es_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? es_result_1[31:24] :
                           (ms_we_2[3] && ms_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? ms_result_2[31:24] :
                           (ms_we_1[3] && ms_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? ms_result_1[31:24] :
                           (ws_we_2[3] && ws_dest_2 == rf_raddr2_1 && rf_raddr2_1!=0)? ws_result_2[31:24] :
                           (ws_we_1[3] && ws_dest_1 == rf_raddr2_1 && rf_raddr2_1!=0)? ws_result_1[31:24] :
                           rf_rdata2_1[31:24];

/*assign rs_eq_rt_1 = (rs_value_1 == rt_value_1);
assign rs_gez_1 = !rs_value_1[31];
assign rs_gtz_1 = !rs_value_1[31] && rs_value_1!=0;
assign is_branch_1 = ds_valid && (inst_beq | inst_bne | inst_bgez | inst_bgtz | inst_blez | inst_bltz | inst_bgezal | inst_bltzal | inst_jal | inst_j | inst_jr | inst_jalr);
assign br_leaving_1 = is_branch && ds_ready_go && es_allowin;
assign br_stall = is_branch && !(ds_ready_go && es_allowin);
assign br_taken = (   inst_beq    &&  rs_eq_rt
                   || inst_bne    && !rs_eq_rt
                   || inst_bgez   &&  rs_gez
                   || inst_bgtz   &&  rs_gtz
                   || inst_blez   && !rs_gtz
                   || inst_bltz   && !rs_gez
                   || inst_bgezal && rs_gez
                   || inst_bltzal && !rs_gez
                   || inst_jal
                   || inst_j
                   || inst_jr
                   || inst_jalr
                  ) && ds_valid ;
assign br_target = !br_taken ? ds_pc + 32'h8 :
                   (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_bgezal || inst_bltzal)
                             ? (ds_pc + 4'h4 + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr) ? rs_value :
                                            {fs_pc[31:28], jidx[25:0], 2'b0};*/


assign op_2   = ds_inst_2[31:26];
assign rs_2   = ds_inst_2[25:21];
assign rt_2   = ds_inst_2[20:16];
assign rd_2   = ds_inst_2[15:11];
assign sa_2   = ds_inst_2[10: 6];
assign func_2 = ds_inst_2[ 5: 0];
assign imm_2  = ds_inst_2[15: 0];
assign jidx_2 = ds_inst_2[25: 0];

decoder_6_64 u_dec0_2(.in(op_2  ), .out(op_d_2  ));
decoder_6_64 u_dec1_2(.in(func_2), .out(func_d_2));
decoder_5_32 u_dec2_2(.in(rs_2  ), .out(rs_d_2  ));
decoder_5_32 u_dec3_2(.in(rt_2  ), .out(rt_d_2  ));
decoder_5_32 u_dec4_2(.in(rd_2  ), .out(rd_d_2  ));
decoder_5_32 u_dec5_2(.in(sa_2  ), .out(sa_d_2  ));

assign inst_addu_2   = op_d_2[6'h00] & func_d_2[6'h21] & sa_d_2[5'h00];
assign inst_subu_2   = op_d_2[6'h00] & func_d_2[6'h23] & sa_d_2[5'h00];
assign inst_slt_2    = op_d_2[6'h00] & func_d_2[6'h2a] & sa_d_2[5'h00];
assign inst_sltu_2   = op_d_2[6'h00] & func_d_2[6'h2b] & sa_d_2[5'h00];
assign inst_and_2    = op_d_2[6'h00] & func_d_2[6'h24] & sa_d_2[5'h00];
assign inst_or_2     = op_d_2[6'h00] & func_d_2[6'h25] & sa_d_2[5'h00];
assign inst_xor_2    = op_d_2[6'h00] & func_d_2[6'h26] & sa_d_2[5'h00];
assign inst_nor_2    = op_d_2[6'h00] & func_d_2[6'h27] & sa_d_2[5'h00];
assign inst_sll_2    = op_d_2[6'h00] & func_d_2[6'h00] & rs_d_2[5'h00];
assign inst_srl_2    = op_d_2[6'h00] & func_d_2[6'h02] & rs_d_2[5'h00];
assign inst_sra_2    = op_d_2[6'h00] & func_d_2[6'h03] & rs_d_2[5'h00];
assign inst_addiu_2  = op_d_2[6'h09];
assign inst_lui_2    = op_d_2[6'h0f] & rs_d_2[5'h00];
assign inst_lw_2     = op_d_2[6'h23];
assign inst_sw_2     = op_d_2[6'h2b];
assign inst_beq_2    = op_d_2[6'h04];
assign inst_bne_2    = op_d_2[6'h05];
assign inst_jal_2    = op_d_2[6'h03];
assign inst_jr_2     = op_d_2[6'h00] & func_d_2[6'h08] & rt_d_2[5'h00] & rd_d_2[5'h00] & sa_d_2[5'h00];
assign inst_add_2    = op_d_2[6'h00] & func_d_2[6'h20] & sa_d_2[5'h00];
assign inst_addi_2   = op_d_2[6'h08];
assign inst_sub_2    = op_d_2[6'h00] & func_d_2[6'h22] & sa_d_2[5'h00];
assign inst_slti_2   = op_d_2[6'h0a];
assign inst_sltiu_2  = op_d_2[6'h0b];
assign inst_andi_2   = op_d_2[6'h0c];
assign inst_ori_2    = op_d_2[6'h0d];
assign inst_xori_2   = op_d_2[6'h0e];
assign inst_sllv_2   = op_d_2[6'h00] & func_d_2[6'h04] & sa_d_2[5'h00];
assign inst_srav_2   = op_d_2[6'h00] & func_d_2[6'h07] & sa_d_2[5'h00];
assign inst_srlv_2   = op_d_2[6'h00] & func_d_2[6'h06] & sa_d_2[5'h00];
assign inst_div_2    = op_d_2[6'h00] & func_d_2[6'h1a] & sa_d_2[5'h00] & rd_d_2[5'h00];
assign inst_divu_2   = op_d_2[6'h00] & func_d_2[6'h1b] & sa_d_2[5'h00] & rd_d_2[5'h00];
assign inst_mult_2   = op_d_2[6'h00] & func_d_2[6'h18] & sa_d_2[5'h00] & rd_d_2[5'h00];
assign inst_multu_2  = op_d_2[6'h00] & func_d_2[6'h19] & sa_d_2[5'h00] & rd_d_2[5'h00];
assign inst_mfhi_2   = op_d_2[6'h00] & func_d_2[6'h10] & rs_d_2[5'h00] & rt_d_2[5'h00] & sa_d_2[5'h00];
assign inst_mflo_2   = op_d_2[6'h00] & func_d_2[6'h12] & rs_d_2[5'h00] & rt_d_2[5'h00] & sa_d_2[5'h00];
assign inst_mthi_2   = op_d_2[6'h00] & func_d_2[6'h11] & rd_d_2[5'h00] & rt_d_2[5'h00] & sa_d_2[5'h00];
assign inst_mtlo_2   = op_d_2[6'h00] & func_d_2[6'h13] & rd_d_2[5'h00] & rt_d_2[5'h00] & sa_d_2[5'h00];
assign inst_bgez_2   = op_d_2[6'h01] & rt_d_2[5'h01];
assign inst_bgtz_2   = op_d_2[6'h07] & rt_d_2[5'h00];
assign inst_blez_2   = op_d_2[6'h06] & rt_d_2[5'h00];
assign inst_bltz_2   = op_d_2[6'h01] & rt_d_2[5'h00];
assign inst_j_2      = op_d_2[6'h02];
assign inst_jalr_2   = op_d_2[6'h00] & rt_d_2[5'h00] & sa_d_2[5'h00] & func_d_2[6'h09];
assign inst_bgezal_2 = op_d_2[6'h01] & rt_d_2[5'h11];
assign inst_bltzal_2 = op_d_2[6'h01] & rt_d_2[5'h10];
assign inst_lb_2     = op_d_2[6'h20];
assign inst_lbu_2    = op_d_2[6'h24];
assign inst_lh_2     = op_d_2[6'h21];
assign inst_lhu_2    = op_d_2[6'h25];
assign inst_lwl_2    = op_d_2[6'h22];
assign inst_lwr_2    = op_d_2[6'h26];
assign inst_sb_2     = op_d_2[6'h28];
assign inst_sh_2     = op_d_2[6'h29];
assign inst_swl_2    = op_d_2[6'h2a];
assign inst_swr_2    = op_d_2[6'h2e];

assign inst_mfc0_2   = op_d_2[6'h10] & rs_d_2[5'h00] & (ds_inst_2[10:3] == 8'h00);
assign inst_mtc0_2   = op_d_2[6'h10] & rs_d_2[5'h04] & (ds_inst_2[10:3] == 8'h00);
assign inst_sysc_2   = op_d_2[6'h00] & func_d_2[6'h0c];
assign inst_eret_2   = op_d_2[6'h10] & func_d_2[6'h18] & (ds_inst_2[25:6] == 20'h80000);
assign inst_break_2  = op_d_2[6'h00] & func_d_2[6'h0d];

assign inst_tlbwi_2  = op_d_2[6'h10] & ds_inst_2[25] & (ds_inst_2[24:6] == 0) & func_d_2[6'h02];
assign inst_tlbp_2   = op_d_2[6'h10] & ds_inst_2[25] & (ds_inst_2[24:6] == 0) & func_d_2[6'h08];
assign inst_tlbr_2   = op_d_2[6'h10] & ds_inst_2[25] & (ds_inst_2[24:6] == 0) & func_d_2[6'h01];

assign inst_remain_2 = !( inst_addu_2 | inst_subu_2   | inst_slt_2    | inst_sltu_2   | inst_and_2    | inst_or_2   | inst_xor_2  
                        | inst_nor_2  | inst_sll_2    | inst_srl_2    | inst_sra_2    | inst_addiu_2  | inst_lui_2  | inst_lw_2   
                        | inst_sw_2   | inst_beq_2    | inst_bne_2    | inst_jal_2    | inst_jr_2     | inst_add_2  | inst_addi_2   
                        | inst_sub_2  | inst_slti_2   | inst_sltiu_2  | inst_andi_2   | inst_ori_2    | inst_xori_2 | inst_sllv_2   
                        | inst_srlv_2 | inst_srav_2   | inst_mult_2   | inst_multu_2  | inst_div_2    | inst_divu_2 | inst_mfhi_2 
                        | inst_mflo_2 | inst_mthi_2   | inst_mtlo_2   | inst_bgez_2   | inst_bgtz_2   | inst_blez_2 | inst_bltz_2 
                        | inst_j_2    | inst_bltzal_2 | inst_bgezal_2 | inst_jalr_2   | inst_lb_2     | inst_lbu_2  | inst_lh_2   
                        | inst_lhu_2  | inst_lwl_2    | inst_lwr_2    | inst_sb_2     | inst_sh_2     | inst_swl_2  | inst_swr_2 
                        | inst_sysc_2 | inst_eret_2   | inst_mfc0_2   | inst_mtc0_2   | inst_break_2  | inst_tlbp_2 | inst_tlbwi_2
                        | inst_tlbr_2);

assign alu_op_2[ 0] = inst_add_2  | inst_addu_2 | inst_addi_2   | inst_addiu_2  | inst_lw_2 | inst_sw_2 | 
                      inst_jal_2  | inst_jalr_2 | inst_bltzal_2 | inst_bgezal_2 | inst_lb_2 | inst_lh_2 |
                      inst_lbu_2  | inst_lhu_2  | inst_lwl_2    | inst_lwr_2    | inst_sb_2 | inst_sh_2 |
                      inst_swr_2  | inst_swl_2  ;
assign alu_op_2[ 1] = inst_sub_2  | inst_subu_2;
assign alu_op_2[ 2] = inst_slt_2  | inst_slti_2;
assign alu_op_2[ 3] = inst_sltu_2 | inst_sltiu_2;
assign alu_op_2[ 4] = inst_and_2  | inst_andi_2;
assign alu_op_2[ 5] = inst_nor_2;
assign alu_op_2[ 6] = inst_or_2   | inst_ori_2;
assign alu_op_2[ 7] = inst_xor_2  | inst_xori_2;
assign alu_op_2[ 8] = inst_sll_2  | inst_sllv_2;
assign alu_op_2[ 9] = inst_srl_2  | inst_srlv_2;
assign alu_op_2[10] = inst_sra_2  | inst_srav_2;
assign alu_op_2[11] = inst_lui_2;

assign store_op_2 = {inst_swr_2,inst_swl_2,inst_sw_2,inst_sh_2,inst_sb_2};
assign load_op_2  = {inst_lwr_2,inst_lwl_2,inst_lw_2,inst_lhu_2,inst_lh_2,inst_lbu_2,inst_lb_2};
assign src1_is_sa_2   = inst_sll_2  | inst_srl_2    | inst_sra_2;
assign src1_is_pc_2   = inst_jal_2  | inst_bgezal_2 | inst_bltzal_2 | inst_jalr_2;
assign src2_is_imm_2  = inst_slti_2 | inst_sltiu_2  | inst_addi_2   | inst_addiu_2 | inst_lui_2  | inst_lw_2  | inst_sw_2   |
                        inst_lb_2   | inst_lbu_2    | inst_lh_2     | inst_lhu_2   | inst_lwl_2  | inst_lwr_2 | inst_swl_2  |
                        inst_swr_2  | inst_sb_2     | inst_sh_2     ;
assign src2_is_zimm_2 = inst_andi_2 | inst_ori_2    | inst_xori_2   ;
assign src2_is_8_2    = inst_jal_2  | inst_bgezal_2 | inst_bltzal_2 | inst_jalr_2;
assign dst_is_r31_2   = inst_jal_2  | inst_bgezal_2 | inst_bltzal_2;
assign dst_is_rt_2    = inst_addi_2 | inst_addiu_2  | inst_lui_2    | inst_sltiu_2 | inst_slti_2 | inst_lw_2  | inst_andi_2 |
                        inst_ori_2  | inst_xori_2   | inst_lb_2     | inst_lbu_2   | inst_lh_2   | inst_lhu_2 | inst_lwl_2  |
                        inst_lwr_2  | inst_mfc0_2;
assign gr_we_2        = ~inst_bgtz_2 & ~inst_blez_2 & ~inst_bgez_2 & ~inst_bltz_2  & ~inst_j_2   & ~inst_sw_2   & ~inst_beq_2 
                      & ~inst_bne_2  & ~inst_jr_2   & ~inst_mult_2 & ~inst_multu_2 & ~inst_div_2 & ~inst_divu_2 & ~inst_mthi_2 
                      & ~inst_mtlo_2 & ~inst_swr_2  & ~inst_swl_2  & ~inst_sh_2    & ~inst_sb_2  & ~inst_mtc0_2 & ~inst_sysc_2
                      & ~inst_eret_2 & ~inst_break_2& ~inst_tlbwi_2& ~inst_tlbp_2  & ~inst_tlbr_2;
assign mem_we_2       = inst_sw_2 | inst_sb_2 | inst_sh_2 | inst_swl_2 | inst_swr_2;
//assign ds_tlbwir_cancel_1 = inst_tlbwi_1 | inst_tlbr_1;

assign dest_2         = dst_is_r31_2 ? 5'd31 :
                        dst_is_rt_2  ? rt_2  :
                        (gr_we_2 == 1'b0) ? 5'b0 :
                                       rd_2;
assign rs_value_2[ 7: 0] = (es_we_2[0] && es_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? es_result_2[ 7: 0] :
                           (es_we_1[0] && es_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? es_result_1[ 7: 0] :
                           (ms_we_2[0] && ms_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? ms_result_2[ 7: 0] :
                           (ms_we_1[0] && ms_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? ms_result_1[ 7: 0] :
                           (ws_we_2[0] && ws_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? ws_result_2[ 7: 0] :
                           (ws_we_1[0] && ws_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? ws_result_1[ 7: 0] :
                           rf_rdata1_2[ 7: 0];
assign rt_value_2[ 7: 0] = (es_we_2[0] && es_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? es_result_2[ 7: 0] :
                           (es_we_1[0] && es_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? es_result_1[ 7: 0] :
                           (ms_we_2[0] && ms_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? ms_result_2[ 7: 0] :
                           (ms_we_1[0] && ms_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? ms_result_1[ 7: 0] :
                           (ws_we_2[0] && ws_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? ws_result_2[ 7: 0] :
                           (ws_we_1[0] && ws_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? ws_result_1[ 7: 0] :
                           rf_rdata2_2[ 7: 0];
assign rs_value_2[15: 8] = (es_we_2[1] && es_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? es_result_2[15: 8] :
                           (es_we_1[1] && es_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? es_result_1[15: 8] :
                           (ms_we_2[1] && ms_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? ms_result_2[15: 8] :
                           (ms_we_1[1] && ms_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? ms_result_1[15: 8] :
                           (ws_we_2[1] && ws_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? ws_result_2[15: 8] :
                           (ws_we_1[1] && ws_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? ws_result_1[15: 8] :
                           rf_rdata1_2[15: 8];
assign rt_value_2[15: 8] = (es_we_2[1] && es_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? es_result_2[15: 8] :
                           (es_we_1[1] && es_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? es_result_1[15: 8] :
                           (ms_we_2[1] && ms_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? ms_result_2[15: 8] :
                           (ms_we_1[1] && ms_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? ms_result_1[15: 8] :
                           (ws_we_2[1] && ws_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? ws_result_2[15: 8] :
                           (ws_we_1[1] && ws_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? ws_result_1[15: 8] :
                           rf_rdata2_2[15: 8];
assign rs_value_2[23:16] = (es_we_2[2] && es_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? es_result_2[23:16] :
                           (es_we_1[2] && es_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? es_result_1[23:16] :
                           (ms_we_2[2] && ms_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? ms_result_2[23:16] :
                           (ms_we_1[2] && ms_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? ms_result_1[23:16] :
                           (ws_we_2[2] && ws_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? ws_result_2[23:16] :
                           (ws_we_1[2] && ws_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? ws_result_1[23:16] :
                           rf_rdata1_2[23:16];
assign rt_value_2[23:16] = (es_we_2[2] && es_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? es_result_2[23:16] :
                           (es_we_1[2] && es_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? es_result_1[23:16] :
                           (ms_we_2[2] && ms_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? ms_result_2[23:16] :
                           (ms_we_1[2] && ms_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? ms_result_1[23:16] :
                           (ws_we_2[2] && ws_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? ws_result_2[23:16] :
                           (ws_we_1[2] && ws_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? ws_result_1[23:16] :
                           rf_rdata2_2[23:16];
assign rs_value_2[31:24] = (es_we_2[3] && es_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? es_result_2[31:24] :
                           (es_we_1[3] && es_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? es_result_1[31:24] :
                           (ms_we_2[3] && ms_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? ms_result_2[31:24] :
                           (ms_we_1[3] && ms_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? ms_result_1[31:24] :
                           (ws_we_2[3] && ws_dest_2 == rf_raddr1_2 && rf_raddr1_2!=0)? ws_result_2[31:24] :
                           (ws_we_1[3] && ws_dest_1 == rf_raddr1_2 && rf_raddr1_2!=0)? ws_result_1[31:24] :
                           rf_rdata1_2[31:24];
assign rt_value_2[31:24] = (es_we_2[3] && es_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? es_result_2[31:24] :
                           (es_we_1[3] && es_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? es_result_1[31:24] :
                           (ms_we_2[3] && ms_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? ms_result_2[31:24] :
                           (ms_we_1[3] && ms_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? ms_result_1[31:24] :
                           (ws_we_2[3] && ws_dest_2 == rf_raddr2_2 && rf_raddr2_2!=0)? ws_result_2[31:24] :
                           (ws_we_1[3] && ws_dest_1 == rf_raddr2_2 && rf_raddr2_2!=0)? ws_result_1[31:24] :
                           rf_rdata2_2[31:24];

//============================ ID-exc: SYS;Remain-Inst;BP =====================================================================
assign ds_ex_1 = ds_adel_1 || ds_tlb_miss_1 || ds_tlb_invalid_1 || inst_remain_1 || inst_sysc_1 || inst_break_1;
assign ds_badvaddr_1 = ds_pc_1;
assign ds_exccode_1 = (ds_tlb_miss_1 | ds_tlb_invalid_1) ? `EX_TLBL : 
                      ds_adel_1      ? `EX_ADEL :
                      inst_remain_1  ? `EX_RI :
                      inst_sysc_1    ? `EX_SYS :
                      inst_break_1   ? `EX_BP : 5'b0;   

assign ds_ex_2 = ds_adel_2 || ds_tlb_miss_2 || ds_tlb_invalid_2 || inst_remain_2 || inst_sysc_2 || inst_break_2;
assign ds_badvaddr_2 = ds_pc_2;
assign ds_exccode_2 = (ds_tlb_miss_2 | ds_tlb_invalid_2) ? `EX_TLBL : 
                      ds_adel_2      ? `EX_ADEL :
                      inst_remain_2  ? `EX_RI :
                      inst_sysc_2    ? `EX_SYS :
                      inst_break_2   ? `EX_BP : 5'b0; 

//=============================================== Read Operation_data =========================================================
assign rf_raddr1_1 = rs_1;
assign rf_raddr2_1 = rt_1;
assign rf_raddr1_2 = rs_2;
assign rf_raddr2_2 = rt_2;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1_1 (rf_raddr1_1),
    .rdata1_1 (rf_rdata1_1),
    .raddr2_1 (rf_raddr2_1),
    .rdata2_1 (rf_rdata2_1),
    .raddr1_2 (rf_raddr1_2),
    .rdata1_2 (rf_rdata1_2),
    .raddr2_2 (rf_raddr2_2),
    .rdata2_2 (rf_rdata2_2),
    .we_1     (rf_we_1    ),
    .waddr_1  (rf_waddr_1 ),
    .wdata_1  (rf_wdata_1 ),
    .we_2     (rf_we_2    ),
    .waddr_2  (rf_waddr_2 ),
    .wdata_2  (rf_wdata_2 )
);

// Update Predictor


endmodule