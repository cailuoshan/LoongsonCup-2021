 `include "mycpu.h"

module exe1_stage(
    input                          clk           ,
    input                          reset         ,
    // Pipline shake
      // es-ms
    input                          ms1_allowin     ,
    output                         es1_to_ms1_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es1_to_ms1_bus  ,
      // issue-es
    output                         es1_allowin    ,
    input                          ds_to_es1_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es1_bus  ,

    // Bypass network
      // to ds:forward
    output [42:0] es1_reg,
      // es1-es2
    output  reg   es1_wait,
    input         es2_wait,
      
    
    // HiLo reg port 1
    output        hilo_raddr,    // 1 for HI_reg, 0 for LO_reg
    input  [31:0] hilo_rdata,
    output        we_hi,       
    output [31:0] wdata_hi,
    output        we_lo,       
    output [31:0] wdata_lo,
      
    // Dcache interface 需要在cpu_top里进行仲裁，不允许出现两条指令同时请求
    output        dcache_req,
    output        dcache_wr,
    output [ 1:0] dcache_size,
    output [ 3:0] dcache_wstrb,
    output [31:0] dcache_addr,
    output [31:0] dcache_wdata,
    input         dcache_addr_ok,
    // TLB search port 1 需要再多一个search接口？？？
    output [18:0] s1_vpn2,     
    output        s1_odd_page,
    input         s1_found,     
    input  [ 3:0] s1_index,     
    input  [19:0] s1_pfn,     
    input  [ 2:0] s1_c,     
    input         s1_d,     
    input         s1_v,

    // Exception related
    input         ms1_to_es1_ex,
    input         ms2_to_es1_ex,
    input         ws_to_es1_ex,
    output        es1_to_es2_ex
); 

// Signal declaration
reg         es_valid      ;
wire        es_ready_go   ;
reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es1_bus_r;

wire        es_inst_eret;
wire        es_inst_mfc0;
wire        es_inst_mtc0;
wire        es_inst_mult;
wire        es_inst_multu;
wire        es_inst_div;
wire        es_inst_divu;
wire        es_inst_mthi;
wire        es_inst_mtlo;
wire        es_inst_mfhi;
wire        es_inst_mflo;
wire        es_tlbp;
wire        es_tlbr;
wire        es_tlbwi;

reg  [31:0] hi;
reg  [31:0] lo;
wire [63:0] mult_result;
wire [63:0] multu_result;
wire [63:0] div_result;
wire [63:0] divu_result;
reg  div_tvalid;
reg  divu_tvalid;
wire div_divisor_tready;
wire div_dividend_tready;
wire divu_divisor_tready;
wire divu_dividend_tready;
wire div_out_tvalid;
wire divu_out_tvalid;

wire        es_of_check      ;
wire        es_ds_ex      ;
wire        es_ds_bd      ;
wire [31:0] es_ds_badvaddr;       
wire [ 4:0] es_ds_exccode ;

wire [ 7:0] es_c0_addr    ;
wire [11:0] es_alu_op     ;
wire [ 4:0] es_store_op   ;
wire [ 6:0] es_load_op    ;

wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_zimm;
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;

wire [31:0] es_alu_src1;
wire [31:0] es_alu_src2;
wire [31:0] es_alu_result;

wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] data_sram_physical_addr   ;
wire [31:0] es_pc         ;

wire        has_ex;
wire        overflow;
wire        ades;
wire        adel;
wire        es_ex;
wire        es_bd;
wire [31:0] es_badvaddr;       
wire [ 4:0] es_exccode;

wire        es_res_from_mem;
wire        es_is_load;
wire        es_is_store;

wire [31:0] es_result;
wire [ 3:0] addr_align;
wire [31:0] es_sb_value;
wire [31:0] es_sh_value;
wire [31:0] es_sw_value;
wire [31:0] es_swl_value;
wire [31:0] es_swr_value;
wire [ 3:0] sb_strb;
wire [ 3:0] sh_strb;
wire [ 3:0] sw_strb;
wire [ 3:0] swl_strb;
wire [ 3:0] swr_strb;
wire [ 3:0] strb;

//====================================== HandShake for pipeline ===========================================
assign {ds_to_es_tlb_refill,    //211:211
        ds_to_es_tlbwir_cancel, //210:210
        es_tlbp        ,  //209:209
        es_tlbr        ,  //208:208 
        es_tlbwi       ,  //207:207
        es_of_check    ,  //206:206
        es_ds_badvaddr ,  //205:174    
        es_ds_exccode  ,  //173:169
        es_ds_ex       ,  //168:168
        es_ds_bd       ,  //167:167
        es_inst_eret   ,  //166:166
        es_inst_mfc0   ,  //165:165
        es_inst_mtc0   ,  //164:164
        es_c0_addr     ,  //163:156
        es_alu_op      ,  //155:144
        es_store_op    ,  //143:139
        es_load_op     ,  //138:132
        es_inst_mult   ,  //131:131
        es_inst_multu  ,  //130:130
        es_inst_div    ,  //129:129
        es_inst_divu   ,  //128:128
        es_inst_mthi   ,  //127:127
        es_inst_mtlo   ,  //126:126
        es_inst_mfhi   ,  //125:125
        es_inst_mflo   ,  //124:124
        es_src1_is_sa  ,  //123:123
        es_src1_is_pc  ,  //122:122
        es_src2_is_imm ,  //121:121
        es_src2_is_zimm,  //120:120
        es_src2_is_8   ,  //119:119
        es_gr_we       ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
        } = ds_to_es1_bus_r;

assign es_ready_go      = handle_exc || handle_eret || pipe_flush ? 1'b1 :
                          es2_wait     ? 1'b0 :
                          es_inst_div  ? div_out_tvalid   :
                          es_inst_divu ? divu_out_tvalid  :
                          es_is_load | es_is_store ? (dcache_req & dcache_addr_ok) :
                          1'b1;  //陪同阻塞
assign es1_allowin      = !es_valid || es_ready_go && ms1_allowin;
assign es1_to_ms1_valid = es_valid && es_ready_go && !handle_exc && !handle_eret && !pipe_flush;
always @(posedge clk) begin
    if (reset) begin
        es1_wait <= 1'b0;
    end
    else if (ds_to_es1_valid && es1_allowin) begin
        if ((es_inst_div && !div_out_tvalid) 
         || (es_inst_divu && !divu_out_tvalid)
         || ((es_is_load | es_is_store) && !(dcache_req & dcache_addr_ok))) begin
            es1_wait <= 1'b1;
        end else begin
            es1_wait <= 1'b0;
        end
    end
    else if (es1_wait && ((es_inst_div && div_out_tvalid) 
                       || (es_inst_divu && divu_out_tvalid)
                       || ((es_is_load | es_is_store) && (dcache_req & dcache_addr_ok)))) begin
        es1_wait <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es1_allowin) begin
        es_valid <= ds_to_es1_valid;
    end

    if (ds_to_es1_valid && es1_allowin) begin
        ds_to_es1_bus_r <= ds_to_es1_bus;
    end
end

assign es_is_store = |es_store_op;
assign es_is_load  = |es_load_op;
assign es_res_from_mem = es_is_load;
assign es_tlbp_found = es_tlbp && s1_found;
assign es_to_ms_bus = {es_tlb_miss | ds_to_es_tlb_refill    ,  //139:139
                       es_tlbp_found  ,  //138:138
                       es_tlbwir_cancel, //137:137
                       s1_index       ,  //136:133
                       es_tlbwi       ,  //132:132
                       es_tlbr        ,  //131:131
                       es_tlbp        ,  //130:130
                       es_ex          ,  //129:129
                       es_bd          ,  //128:128
                       es_badvaddr    ,  //127:96  
                       es_exccode     ,  //95:91
                       es_inst_eret   ,  //90:90
                       es_inst_mfc0   ,  //89:89
                       es_inst_mtc0   ,  //88:88
                       es_c0_addr     ,  //87:80
					   es_is_load     ,  //79:79
                       es_is_store    ,  //78:78
                       es_load_op     ,  //77:71
                       es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_result      ,  //63:32
                       es_pc             //31:0
                      };

//===================================== Execute calculate =============================================
assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     es_src2_is_zimm? {{16{1'b0}},es_imm[15:0]} :
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .overflow   (overflow     )
    );

assign mult_result = $signed(es_rs_value) * $signed(es_rt_value);
assign multu_result = es_rs_value * es_rt_value;
always @(posedge clk) begin
    if (reset) begin
        div_tvalid<=1'b0;
    end
    else if(ds_to_es_valid && es_allowin) begin
        div_tvalid<=ds_to_es_bus[129:129];
    end
    else if(div_tvalid && div_divisor_tready && div_dividend_tready)begin
        div_tvalid<=1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        divu_tvalid<=1'b0;
    end
    else if(ds_to_es_valid && es_allowin) begin
        divu_tvalid<=ds_to_es_bus[128:128];
    end
    else if(divu_tvalid && divu_divisor_tready && divu_dividend_tready)begin
        divu_tvalid<=1'b0;
    end
end

assign we_hi    = (es_inst_mult || es_inst_multu || es_inst_div || es_inst_divu || es_inst_mthi) && es_valid && !has_ex;
assign wdata_hi = es_inst_mult  ? mult_result[63:32] :
                  es_inst_multu ? multu_result[63:32]:
                  es_inst_div   ? div_result[31:0]   :
                  es_inst_divu  ? divu_result[31:0]  :
                                  es_rs_value;
assign we_lo    = (es_inst_mult || es_inst_multu || es_inst_div || es_inst_divu || es_inst_mthi) && es_valid && !has_ex;
assign wdata_lo = es_inst_mult  ? mult_result[31:0] :
                  es_inst_multu ? multu_result[31:0]:
                  es_inst_div   ? div_result[63:32] :
                  es_inst_divu  ? divu_result[63:32]:
                                  es_rs_value; 

mydiv mydiv(
    .aclk                   (clk),
    .s_axis_divisor_tvalid  (div_tvalid),
    .s_axis_divisor_tready  (div_divisor_tready),
    .s_axis_divisor_tdata   (es_rt_value),
    .s_axis_dividend_tvalid (div_tvalid),
    .s_axis_dividend_tready (div_dividend_tready),
    .s_axis_dividend_tdata  (es_rs_value),
    .m_axis_dout_tvalid     (div_out_tvalid),
    .m_axis_dout_tdata      (div_result)
);

mydiv_u mydiv_u(
    .aclk                   (clk),
    .s_axis_divisor_tvalid  (divu_tvalid),
    .s_axis_divisor_tready  (divu_divisor_tready),
    .s_axis_divisor_tdata   (es_rt_value),
    .s_axis_dividend_tvalid (divu_tvalid),
    .s_axis_dividend_tready (divu_dividend_tready),
    .s_axis_dividend_tdata  (es_rs_value),
    .m_axis_dout_tvalid     (divu_out_tvalid),
    .m_axis_dout_tdata      (divu_result)
);

assign es1_reg = {{4{es_gr_we & es_valid}},
                    es_is_load && es_valid,
							      es_inst_mfc0 && es_valid,
							      es_dest & {5{es_valid}},
							      es_result};

assign hilo_raddr = es_inst_mfhi;
assign es_result = (es_inst_mfhi || es_inst_mflo) ? hilo_rdata : es_inst_mtc0 ? es_rt_value : es_alu_result;

//==================================== Load/Store req =================================================
assign addr_align = {es_alu_result[1:0] == 2'b11, es_alu_result[1:0] == 2'b10,
                     es_alu_result[1:0] == 2'b01, es_alu_result[1:0] == 2'b00};
assign es_sw_value   = es_rt_value;
assign es_sb_value   = ({32{addr_align[0]}} & {24'b0, es_rt_value[7:0]       }) |
                       ({32{addr_align[1]}} & {16'b0, es_rt_value[7:0],  8'b0}) |
                       ({32{addr_align[2]}} & { 8'b0, es_rt_value[7:0], 16'b0}) |
                       ({32{addr_align[3]}} & {       es_rt_value[7:0], 24'b0}) ;
assign es_sh_value   = ({32{~es_alu_result[1]}} & {16'b0, es_rt_value[15:0]       }) |
                       ({32{ es_alu_result[1]}} & {       es_rt_value[15:0], 16'b0}) ;
assign es_swl_value  = ({32{addr_align[0]}} & {24'b0, es_rt_value[31:24]}) |
                       ({32{addr_align[1]}} & {16'b0, es_rt_value[31:16]}) |
                       ({32{addr_align[2]}} & { 8'b0, es_rt_value[31: 8]}) |
                       ({32{addr_align[3]}} &  es_rt_value)                 ;
assign es_swr_value  = ({32{addr_align[0]}} &  es_rt_value              ) |
                       ({32{addr_align[1]}} & {es_rt_value[23:0], 8'b0}) |
                       ({32{addr_align[2]}} & {es_rt_value[15:0],16'b0}) |
                       ({32{addr_align[3]}} & {es_rt_value[ 7:0],24'b0}) ;
assign sw_strb  = 4'b1111;
assign sb_strb  = {addr_align[3], addr_align[2],  addr_align[1],  addr_align[0]};
assign sh_strb  = {es_alu_result[1], es_alu_result[1], ~es_alu_result[1], ~es_alu_result[1]};
assign swl_strb = {es_alu_result[1] & es_alu_result[0], es_alu_result[1], es_alu_result[1] | es_alu_result[0], 1'b1};
assign swr_strb = {1'b1, ~(es_alu_result[1] & es_alu_result[0]), ~es_alu_result[1], ~(es_alu_result[1] | es_alu_result[0])};
assign strb     = ({4{es_store_op[0]}} & sb_strb ) |
                  ({4{es_store_op[1]}} & sh_strb ) |
                  ({4{es_store_op[2]}} & sw_strb ) |
                  ({4{es_store_op[3]}} & swl_strb) |
                  ({4{es_store_op[4]}} & swr_strb) ;
				  
assign ades = (es_store_op[2] & (es_alu_result[1:0]!=2'b00)) | (es_store_op[1] & (es_alu_result[0]!=1'b0));
assign adel = (es_load_op[4]  & (es_alu_result[1:0]!=2'b00)) | ((es_load_op[2] | es_load_op[3]) & (es_alu_result[0]!=1'b0));
// TLB
assign mapped      = ~es_alu_result[31] | (es_alu_result[31] & es_alu_result[30]);
assign s1_vpn2     = es_tlbp ? cp0_entryhi[31:13] : es_alu_result[31:13];
assign s1_odd_page = es_tlbp ? 0 : es_alu_result[12];
assign dcache_phys_addr = {s1_pfn, {es_alu_result[11:0]}} &
                          ((es_store_op[3] | es_load_op[5]) ? 32'hfffffffc : 32'hffffffff);
// Dcache 
assign dcache_req = es_valid & ms_allowin & (es_is_load | es_is_store);
assign dcache_wr  = es_is_store;
assign data_size_2 = es_store_op[2] | es_load_op[4] |
                    ((es_store_op[3] | es_load_op[5]) && (es_alu_result[1:0] == 2'b10 || es_alu_result[1:0] == 2'b11)) | 
                    ((es_store_op[4] | es_load_op[6]) && (es_alu_result[1:0] == 2'b00 || es_alu_result[1:0] == 2'b01)) ; 
assign data_size_1 = es_store_op[1] | es_load_op[2] | es_load_op[3] |
                    ((es_store_op[3] | es_load_op[5]) && (es_alu_result[1:0] == 2'b01)) | 
                    ((es_store_op[4] | es_load_op[6]) && (es_alu_result[1:0] == 2'b10)) ; 
assign dcache_size = data_size_2 ? 2'b10 : data_size_1 ? 2'b01 : 2'b0; 
assign dcache_wstrb = es_mem_we && es_valid && (!has_ex) ? strb : 4'h0;
assign dcache_addr = mapped ? dcache_phys_addr :
                    (es_alu_result & ((es_store_op[3] | es_load_op[5]) ? 32'hfffffffc : 32'hffffffff)) & 32'h1fffffff;
assign dcache_wdata = ({32{es_store_op[0]}} & es_sb_value ) |
                      ({32{es_store_op[1]}} & es_sh_value ) |
                      ({32{es_store_op[2]}} & es_sw_value ) |
                      ({32{es_store_op[3]}} & es_swl_value) |
                      ({32{es_store_op[4]}} & es_swr_value) ;

//============================== EXE-exc: TLB-MOD;TLB-L;TLB-S;OV;ADES;ADEL ===================================
assign es_tlb_miss    = mapped && !s1_found && (es_is_load || es_is_store);
assign es_tlb_invalid = mapped && s1_found && !s1_v && (es_is_load || es_is_store);
assign es_tlb_mod     = mapped && s1_found && s1_v && !s1_d && es_is_store;
assign es_tlb_ex      = es_tlb_miss | es_tlb_invalid | es_tlb_mod;    
assign es_overflow = es_of_check && overflow;
assign es_ex = es_ds_ex    | es_overflow    | ades      | adel 
             | es_tlb_miss | es_tlb_invalid | es_tlb_mod;
assign es_bd = es_ds_bd;
assign es_badvaddr = es_ds_ex ? es_ds_badvaddr :
                     es_tlb_ex ? es_alu_result :
                     ades || adel ? es_result : 32'b0 ;                
assign es_exccode =  es_ds_ex ? es_ds_exccode :
                     es_tlb_mod ? `EX_MOD :
                     (es_tlb_miss || es_tlb_invalid) && es_is_load  ? `EX_TLBL :
                     (es_tlb_miss || es_tlb_invalid) && es_is_store ? `EX_TLBS :
                     es_overflow ? `EX_OV :
                     ades ? `EX_ADES :
                     adel ? `EX_ADEL : 5'b0;
// 不需要考虑path2的exe级例外                     
assign has_ex = es_ex || ms1_to_es1_ex || ms2_to_es1_ex || ws_to_es1_ex || es_tlbwir_cancel;
assign es1_to_es2_ex = es_ex;

endmodule