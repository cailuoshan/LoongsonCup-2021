`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    output                         br_leaving    ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,
    // forward_bus
    input  [44:0] es_reg,
    input  [42:0] rs_reg,
    input  [42:0] ms_reg,
    input  [40:0] ws_reg,
    input         ms_loading,
    
    input         handle_exc,      
    input         handle_eret,
    output ds_tlbwir_cancel,
    input  es_tlbwir_cancel,
    input  pipe_flush
);

// branch counter

wire        br_cancel;
(* max_fanout = "10" *)reg  [31:0] br_cnt;
(* max_fanout = "10" *)reg  [31:0] br_target_r;
wire [31:0] next_br_target;

assign next_br_target = br_taken ? br_target : ds_pc + 8;
assign br_cancel      = br_cnt != 0 && br_cnt != 1 && !(ds_pc == br_target_r);
assign br_bd          = br_cnt == 1;

always @(posedge clk) begin
	if (reset)
		br_cnt <= 3'b0;
	else if (handle_exc || handle_eret || pipe_flush)
		br_cnt <= 3'b0;
	else if (is_branch && ds_valid && !br_cancel && es_allowin && ds_ready_go)
		br_cnt <= 3'b1;
	else if (ds_pc == br_target_r)
		br_cnt <= 3'b0;
	else if (br_cnt != 3'b0 && ds_valid && es_allowin && ds_ready_go)
		br_cnt <= br_cnt + 1'b1; 
end

always @(posedge clk) begin
	if (reset) begin
		br_target_r <= 32'b0;
	end else if (handle_exc || handle_eret || pipe_flush) begin
		br_target_r <= 32'b0;
	end else if (is_branch && es_allowin && ds_ready_go && !br_cancel) begin
		br_target_r <= next_br_target;
	end else if (ds_pc == br_target_r) begin
		br_target_r <= 32'b0;
	end
end

(* max_fanout = "10" *)reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
assign fs_pc = fs_to_ds_bus[31:0];

(* max_fanout = 20 *)reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
wire        ds_fs_ex;
wire        ds_fs_bd;
wire [31:0] ds_fs_badvaddr;       
wire [ 4:0] ds_fs_exccode;
wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_tlb_refill,
        fs_tlbwir_cancel,
        ds_fs_ex,
        ds_fs_badvaddr,       
        ds_fs_exccode,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;
wire [ 3:0] rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //40:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_stall;
wire        is_branch;
wire        br_taken;
wire [31:0] br_target;
assign br_bus = {br_taken && ds_ready_go && es_allowin && !br_cancel,
                 br_target};

wire        of_check;  
wire        ds_ex;
wire        ds_bd;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_zimm;
wire        src2_is_8;
wire        gr_we;
wire        mem_we;
wire [31:0] ds_badvaddr;       
wire [ 4:0] ds_exccode;
wire [ 7:0] ds_c0_addr;
wire [11:0] alu_op;
wire [ 4:0] store_op;
wire [ 6:0] load_op;
wire        src1_is_sa;

wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;
wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;
wire        inst_add;
wire        inst_addi;
wire        inst_sub;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sllv;
wire        inst_srav;
wire        inst_srlv;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j;
wire        inst_jalr;
wire        inst_bgezal;
wire        inst_bltzal;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwr;
wire        inst_lwl;
wire        inst_sb;
wire        inst_sh;
wire        inst_swr;
wire        inst_swl;

wire        inst_sysc;
wire        inst_mfc0;
wire        inst_eret;
wire        inst_mtc0;
wire        inst_break;
wire        inst_remain;

wire        inst_tlbwi;
wire        inst_tlbp;
wire        inst_tlbr;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
wire        rs_gez;
wire        rs_gtz;

//Forward
wire        es_is_mfhi;
wire        es_is_mflo;
wire [ 3:0] es_we;
wire [ 4:0] es_dest;
wire [31:0] es_result;
wire es_load;
wire es_is_mfc0;
assign {es_we,
        es_load,
		es_is_mfc0,
        es_is_mfhi,
        es_is_mflo,
		es_dest,
		es_result} = es_reg;

//Forward
wire [ 3:0] rs_we;
wire [ 4:0] rs_dest;
wire [31:0] rs_result;
wire rs_load;
wire rs_is_mfc0;
assign {rs_we,
        rs_load,
		rs_is_mfc0,
		rs_dest,
		rs_result} = rs_reg;
wire        ms_load;
wire [ 3:0] ms_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_result;
wire ms_is_mfc0;
assign {ms_load,
        ms_we,
		ms_is_mfc0,
		ms_dest,
		ms_result} = ms_reg;
wire [ 3:0] ws_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_result;		
	
assign {ws_we,
		ws_dest,
		ws_result} = ws_reg;

assign ds_to_es_bus = {213{!br_cancel}} &
					  {ds_fs_ex && ds_exccode != `EX_INT,
                       ds_tlb_refill ,  //211:211
                       ds_tlbwir_cancel | fs_tlbwir_cancel | es_tlbwir_cancel, //210:210
                       inst_tlbp   ,  //209:209
                       inst_tlbr   ,  //208:208
                       inst_tlbwi  ,  //207:207
                       of_check    ,  //206:206    
                       ds_badvaddr ,  //205:174    
                       ds_exccode  ,  //173:169
                       ds_ex       ,  //168:168
                       ds_bd       ,  //167:167 
                       inst_mul    ,
                       inst_eret   ,  //166:166
                       inst_mfc0   ,  //165:165
                       inst_mtc0   ,  //164:164
                       ds_c0_addr  ,  //163:156
                       alu_op      ,  //155:144
                       store_op    ,  //143:139
                       load_op     ,  //138:132
                       inst_mult   ,  //131:131
                       inst_multu  ,  //130:130
                       inst_div    ,  //129:129
                       inst_divu   ,  //128:128
                       inst_mthi   ,  //127:127
                       inst_mtlo   ,  //126:126
                       inst_mfhi   ,  //125:125
                       inst_mflo   ,  //124:124
                       src1_is_sa  ,  //123:123
                       src1_is_pc  ,  //122:122
                       src2_is_imm ,  //121:121
                       src2_is_zimm,  //120:120
                       src2_is_8   ,  //119:119
                       gr_we       ,  //118:118
                       mem_we      ,  //117:117
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };

assign rt_re      = !(dst_is_rt | inst_jal     | inst_jr   | inst_mthi | inst_mtlo   | inst_j | inst_jalr |
                      inst_bgez | inst_bgtz    | inst_blez | inst_bltz | inst_bgezal | inst_bltzal | 
                      inst_eret | inst_sysc    | inst_tlbp | inst_tlbr | inst_tlbwi  );

assign rs_re      = !(inst_lui  | inst_sll     | inst_srl  | inst_sra  | mem_we     | inst_jal  | inst_j | 
                      inst_eret | inst_sysc    | inst_tlbp | inst_tlbr | inst_tlbwi | inst_mtc0 | inst_mfc0);
assign wait_ms = !ms_we && ms_loading;
assign es_hit_load = ((es_dest == rf_raddr1 && rf_raddr1 != 0) || (es_dest == rf_raddr2 && rf_raddr2 != 0)) && es_load;
assign ms_hit_load = ((ms_dest == rf_raddr1 && rf_raddr1 != 0) || (ms_dest == rf_raddr2 && rf_raddr2 != 0)) && ms_load;
assign es_hit_mfhi = ((es_dest == rf_raddr1 && rf_raddr1 != 0) || (es_dest == rf_raddr2 && rf_raddr2 != 0)) && es_is_mfhi;
assign es_hit_mflo = ((es_dest == rf_raddr1 && rf_raddr1 != 0) || (es_dest == rf_raddr2 && rf_raddr2 != 0)) && es_is_mflo;
assign rs_hit_load = ((rs_dest == rf_raddr1 && rf_raddr1 != 0) || (rs_dest == rf_raddr2 && rf_raddr2 != 0)) && rs_load;
assign ds_ready_go = (handle_exc || handle_eret || pipe_flush) || !(wait_ms || es_hit_load || ms_hit_load || rs_hit_load || es_hit_mfhi || es_hit_mflo);				
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go && !handle_exc && !handle_eret && !pipe_flush;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (handle_exc || handle_eret || pipe_flush) begin
    	ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

//Decode
assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & sa_d[5'h00] & rd_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & sa_d[5'h00] & rd_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00] & rd_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & sa_d[5'h00] & rd_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_j      = op_d[6'h02];
assign inst_jalr   = op_d[6'h00] & rt_d[5'h00] & sa_d[5'h00] & func_d[6'h09];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];

assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00] & (ds_inst[10:3] == 8'h00);
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04] & (ds_inst[10:3] == 8'h00);
assign inst_sysc   = op_d[6'h00] & func_d[6'h0c];
assign inst_eret   = op_d[6'h10] & func_d[6'h18] & (ds_inst[25:6] == 20'h80000);
assign inst_break  = op_d[6'h00] & func_d[6'h0d];

assign inst_tlbwi  = op_d[6'h10] & ds_inst[25] & (ds_inst[24:6] == 0) & func_d[6'h02];
assign inst_tlbp   = op_d[6'h10] & ds_inst[25] & (ds_inst[24:6] == 0) & func_d[6'h08];
assign inst_tlbr   = op_d[6'h10] & ds_inst[25] & (ds_inst[24:6] == 0) & func_d[6'h01];

assign inst_mul    = op_d[6'h1c] & func_d[6'h02];

assign inst_remain = !( inst_addu | inst_subu   | inst_slt    | inst_sltu   | inst_and    | inst_or   | inst_xor  
                    | inst_nor  | inst_sll    | inst_srl    | inst_sra    | inst_addiu  | inst_lui  | inst_lw   
                    | inst_sw   | inst_beq    | inst_bne    | inst_jal    | inst_jr     | inst_add  | inst_addi   
                    | inst_sub  | inst_slti   | inst_sltiu  | inst_andi   | inst_ori    | inst_xori | inst_sllv   
                    | inst_srlv | inst_srav   | inst_mult   | inst_multu  | inst_div    | inst_divu | inst_mfhi 
                    | inst_mflo | inst_mthi   | inst_mtlo   | inst_bgez   | inst_bgtz   | inst_blez | inst_bltz 
                    | inst_j    | inst_bltzal | inst_bgezal | inst_jalr   | inst_lb     | inst_lbu  | inst_lh   
                    | inst_lhu  | inst_lwl    | inst_lwr    | inst_sb     | inst_sh     | inst_swl  | inst_swr 
                    | inst_sysc | inst_eret   | inst_mfc0   | inst_mtc0   | inst_break  | inst_tlbp | inst_tlbwi
                    | inst_tlbr | inst_mul    );
				
assign ds_c0_addr = {rd,ds_inst[2:0]};
assign ds_ex = ds_fs_ex || inst_remain || inst_sysc || inst_break;         
assign ds_bd = br_bd;
assign ds_badvaddr = ds_fs_badvaddr;
assign ds_exccode = ds_fs_ex ? ds_fs_exccode :
                   inst_remain  ? `EX_RI :
                   inst_sysc  ? `EX_SYS :
                   inst_break ? `EX_BP : 5'b0;     

assign of_check = inst_add | inst_addi | inst_sub;

assign alu_op[ 0] = inst_add  | inst_addu | inst_addi   | inst_addiu  | inst_lw | inst_sw | 
                    inst_jal  | inst_jalr | inst_bltzal | inst_bgezal | inst_lb | inst_lh |
                    inst_lbu  | inst_lhu  | inst_lwl    | inst_lwr    | inst_sb | inst_sh |
                    inst_swr  | inst_swl  ;
assign alu_op[ 1] = inst_sub  | inst_subu;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or   | inst_ori;
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_sll  | inst_sllv;
assign alu_op[ 9] = inst_srl  | inst_srlv;
assign alu_op[10] = inst_sra  | inst_srav;
assign alu_op[11] = inst_lui;

assign store_op = {inst_swr,inst_swl,inst_sw,inst_sh,inst_sb};
assign load_op  = {inst_lwr,inst_lwl,inst_lw,inst_lhu,inst_lh,inst_lbu,inst_lb};

assign src1_is_sa   = inst_sll  | inst_srl    | inst_sra;
assign src1_is_pc   = inst_jal  | inst_bgezal | inst_bltzal | inst_jalr;
assign src2_is_imm  = inst_slti | inst_sltiu  | inst_addi   | inst_addiu | inst_lui  | inst_lw  | inst_sw   |
                      inst_lb   | inst_lbu    | inst_lh     | inst_lhu   | inst_lwl  | inst_lwr | inst_swl  |
                      inst_swr  | inst_sb     | inst_sh     ;
assign src2_is_zimm = inst_andi | inst_ori    | inst_xori   ;
assign src2_is_8    = inst_jal  | inst_bgezal | inst_bltzal | inst_jalr;
assign dst_is_r31   = inst_jal  | inst_bgezal | inst_bltzal;
assign dst_is_rt    = inst_addi | inst_addiu  | inst_lui    | inst_sltiu | inst_slti | inst_lw  | inst_andi |
                      inst_ori  | inst_xori   | inst_lb     | inst_lbu   | inst_lh   | inst_lhu | inst_lwl  |
                      inst_lwr  | inst_mfc0;
assign gr_we        = ~inst_bgtz & ~inst_blez & ~inst_bgez & ~inst_bltz  & ~inst_j   & ~inst_sw   & ~inst_beq 
                    & ~inst_bne  & ~inst_jr   & ~inst_mult & ~inst_multu & ~inst_div & ~inst_divu & ~inst_mthi 
                    & ~inst_mtlo & ~inst_swr  & ~inst_swl  & ~inst_sh    & ~inst_sb  & ~inst_mtc0 & ~inst_sysc
                    & ~inst_eret & ~inst_break& ~inst_tlbwi& ~inst_tlbp  & ~inst_tlbr;
assign mem_we       = inst_sw | inst_sb | inst_sh | inst_swl | inst_swr;
assign ds_tlbwir_cancel = (inst_tlbwi | inst_tlbr | fs_tlbwir_cancel) && ds_valid;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    :
                      (gr_we == 1'b0) ? 5'b0 :
                                   rd;
                                   
assign rs_value[ 7: 0] = (es_we[0] && es_dest == rf_raddr1 && rf_raddr1!=0)? es_result[ 7: 0] :
                         (rs_we[0] && rs_dest == rf_raddr1 && rf_raddr1!=0)? rs_result[ 7: 0] :
                         (ms_we[0] && ms_dest == rf_raddr1 && rf_raddr1!=0)? ms_result[ 7: 0] :
                         (ws_we[0] && ws_dest == rf_raddr1 && rf_raddr1!=0)? ws_result[ 7: 0] :
                         rf_rdata1[ 7: 0];

assign rt_value[ 7: 0] = (es_we[0] && es_dest == rf_raddr2 && rf_raddr2!=0)? es_result[ 7: 0] :
                         (rs_we[0] && rs_dest == rf_raddr2 && rf_raddr2!=0)? rs_result[ 7: 0] :
                         (ms_we[0] && ms_dest == rf_raddr2 && rf_raddr2!=0)? ms_result[ 7: 0] :
                         (ws_we[0] && ws_dest == rf_raddr2 && rf_raddr2!=0)? ws_result[ 7: 0] :
                         rf_rdata2[ 7: 0];

assign rs_value[15: 8] = (es_we[1] && es_dest == rf_raddr1 && rf_raddr1!=0)? es_result[15: 8] :
                         (rs_we[1] && rs_dest == rf_raddr1 && rf_raddr1!=0)? rs_result[15: 8] :
                         (ms_we[1] && ms_dest == rf_raddr1 && rf_raddr1!=0)? ms_result[15: 8] :
                         (ws_we[1] && ws_dest == rf_raddr1 && rf_raddr1!=0)? ws_result[15: 8] :
                         rf_rdata1[15: 8];


assign rt_value[15: 8] = (es_we[1] && es_dest == rf_raddr2 && rf_raddr2!=0)? es_result[15: 8] :
                         (rs_we[1] && rs_dest == rf_raddr2 && rf_raddr2!=0)? rs_result[15: 8] :
                         (ms_we[1] && ms_dest == rf_raddr2 && rf_raddr2!=0)? ms_result[15: 8] :
                         (ws_we[1] && ws_dest == rf_raddr2 && rf_raddr2!=0)? ws_result[15: 8] :
                         rf_rdata2[15: 8];
assign rs_value[23:16] = (es_we[2] && es_dest == rf_raddr1 && rf_raddr1!=0)? es_result[23:16] :
                         (rs_we[2] && rs_dest == rf_raddr1 && rf_raddr1!=0)? rs_result[23:16] :
                         (ms_we[2] && ms_dest == rf_raddr1 && rf_raddr1!=0)? ms_result[23:16] :
                         (ws_we[2] && ws_dest == rf_raddr1 && rf_raddr1!=0)? ws_result[23:16] :
                         rf_rdata1[23:16];
assign rt_value[23:16] = (es_we[2] && es_dest == rf_raddr2 && rf_raddr2!=0)? es_result[23:16] :
                         (rs_we[2] && rs_dest == rf_raddr2 && rf_raddr2!=0)? rs_result[23:16] :
                         (ms_we[2] && ms_dest == rf_raddr2 && rf_raddr2!=0)? ms_result[23:16] :
                         (ws_we[2] && ws_dest == rf_raddr2 && rf_raddr2!=0)? ws_result[23:16] :
                         rf_rdata2[23:16];
assign rs_value[31:24] = (es_we[3] && es_dest == rf_raddr1 && rf_raddr1!=0)? es_result[31:24] :
                         (rs_we[3] && rs_dest == rf_raddr1 && rf_raddr1!=0)? rs_result[31:24] :
                         (ms_we[3] && ms_dest == rf_raddr1 && rf_raddr1!=0)? ms_result[31:24] :
                         (ws_we[3] && ws_dest == rf_raddr1 && rf_raddr1!=0)? ws_result[31:24]:
                         rf_rdata1[31:24];
assign rt_value[31:24] = (es_we[3] && es_dest == rf_raddr2 && rf_raddr2!=0)? es_result[31:24] :
                         (rs_we[3] && rs_dest == rf_raddr2 && rf_raddr2!=0)? rs_result[31:24] :
                         (ms_we[3] && ms_dest == rf_raddr2 && rf_raddr2!=0)? ms_result[31:24] :
                         (ws_we[3] && ws_dest == rf_raddr2 && rf_raddr2!=0)? ws_result[31:24] :
                         rf_rdata2[31:24];

assign rs_eq_rt = (rs_value == rt_value);
assign rs_gez = !rs_value[31];
assign rs_gtz = !rs_value[31] && rs_value!=0;
assign is_branch = ds_valid && (inst_beq | inst_bne | inst_bgez | inst_bgtz | inst_blez | inst_bltz | inst_bgezal | inst_bltzal | inst_jal | inst_j | inst_jr | inst_jalr);
assign br_leaving = is_branch && ds_ready_go && es_allowin && !br_cancel;
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
                                            {fs_pc[31:28], jidx[25:0], 2'b0};

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );
endmodule
