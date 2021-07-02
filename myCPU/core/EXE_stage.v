`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
	
    //allowin
    input                          rs_allowin    ,
    output                         es_allowin    ,
	
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
	
    //to ms
    output                         es_to_rs_valid,
    output [`ES_TO_RS_BUS_WD -1:0] es_to_rs_bus  ,
	
    //to ds:forward
    output [44:0] es_reg,
	input refresh_tlb_cache,
    //TLB search port 1
    output [18:0] s1_vpn2,     
    output        s1_odd_page,
    input         s1_found,     
    input  [ 3:0] s1_index,     
    input  [19:0] s1_pfn,     
    input  [ 2:0] s1_c,     
    input         s1_d,     
    input         s1_v,

	output        es_tlbp,
	output        es_tlbr,

    input  [31:0] cp0_entryhi,
	output        es_tlbwi,
    input         handle_exc,      
    input         handle_eret,
    input         pipe_flush,
	
	output [ 7:0]  es_c0_addr,
	output [31:0]  mtc0_data,
	output [31:0] pipe_flush_pc,
	output         mtc0_we,
	input  [31:0]  mfc0_rdata,
    output         es_tlbwir_cancel
);

assign es_tlbwir_cancel = (es_tlbwi | es_tlbr) && es_valid;

reg div_finish;
reg divu_finish;

always @(posedge clk) begin
    if (reset)
        div_finish <= 1'b0;
    else if (handle_exc || handle_eret || pipe_flush)
        div_finish <= 1'b0;
    else if (es_inst_div && div_out_tvalid)
        div_finish <= 1'b1;
    else if (rs_allowin && es_ready_go)
        div_finish <= 1'b0;
end

always @(posedge clk) begin
    if (reset)
        divu_finish <= 1'b0;
    else if (handle_exc || handle_eret || pipe_flush)
        divu_finish <= 1'b0;
    else if (es_inst_div && divu_out_tvalid)
        divu_finish <= 1'b1;
    else if (rs_allowin && es_ready_go)
        divu_finish <= 1'b0;
end

assign pipe_flush_pc = es_pc;
wire [31:0] es_result;
wire [31:0] es_pc;
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
wire        es_inst_mul;


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

wire        has_ex;
wire        overflow;
wire        ades;
wire        adel;
wire        es_ex;

(* max_fanout = 10 *)reg         es_valid      ;
wire        es_ready_go   ;

`ifdef USE_TLB
// TLB query: 0 for get, 1 for querying
(* max_fanout = 10 *)reg [1:0] tlb_query_state;
(* max_fanout = 10 *)reg [1:0] next_state;
wire tlb_hit;
`endif

wire        data_sram_wr;
wire [ 1:0] data_sram_size;
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire         es_bd;
wire [ 4:0]  es_exccode;
wire [31:0]  es_badvaddr;
wire         fs_pc_error;

`ifdef USE_TLB
assign exception_tlb_refill = (es_tlb_miss || ds_to_es_tlb_refill) && es_valid;
`else
assign exception_tlb_refill = 0;
`endif 
`ifdef USE_TLB
(* max_fanout = 10 *)reg [   18:0] tlb_history_vpn2;
(* max_fanout = 10 *)reg [   19:0] tlb_history_pfn ;
(* max_fanout = 10 *)reg           tlb_history_odd ;
(* max_fanout = 10 *)reg           tlb_history_found;
(* max_fanout = 10 *)reg           tlb_history_v   ;
(* max_fanout = 10 *)reg           tlb_history_d   ;
(* max_fanout = 10 *)reg           tlb_history_vv  ;
always @(posedge clk) begin
    if (reset)
        tlb_query_state <= 2'b0;
    else 
        tlb_query_state <= next_state; 
end

assign tlb_hit = es_alu_result[12] == tlb_history_odd && es_alu_result[31:13] == tlb_history_vpn2 && tlb_history_v;

always @(*) begin
    case (tlb_query_state)
        0:
            if ((tlb_hit || !mapped) && (es_is_load || es_is_store))
                next_state = 0;
            else if (es_is_load || es_is_store)
                next_state = 1;
            else
                next_state = 0;
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
        tlb_history_d    <=  1'b0;
        tlb_history_vv   <=  1'b0;
        tlb_history_found<=  1'b0;
    end else if (handle_exc || es_inst_mtc0) begin
        tlb_history_v    <=  1'b0;
    end else if (tlb_query_state == 0 && !tlb_hit && (es_is_load || es_is_store)) begin
        tlb_history_vpn2 <= es_alu_result[31:13]; 
        tlb_history_odd  <= es_alu_result[12];
    end else if (tlb_query_state == 1) begin
        tlb_history_pfn  <= s1_pfn;    
        tlb_history_v <= 1;    
        tlb_history_found<= s1_found;
        tlb_history_vv   <= s1_v;
        tlb_history_d    <= s1_d;
    end
end
`endif

(* max_fanout = 20 *)reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

assign {fs_pc_error,
        ds_to_es_tlb_refill,  //211:211
        ds_to_es_tlbwir_cancel, //210:210
        es_tlbp        ,  //209:209
        es_tlbr        ,  //208:208 
        es_tlbwi       ,  //207:207
        es_of_check    ,  //206:206
        es_ds_badvaddr ,  //205:174    
        es_ds_exccode  ,  //173:169
        es_ds_ex       ,  //168:168
        es_ds_bd       ,  //167:167
        es_inst_mul    ,
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
       } = ds_to_es_bus_r;

assign es_bd = es_ds_bd;
wire        es_res_from_mem;
wire        es_is_load;
wire        es_is_store;

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
assign mtc0_data = es_rt_value;
assign es_result = es_inst_mul ? mult_result[31:0] : es_inst_mfc0 ? mfc0_rdata : es_alu_result;

`ifdef USE_TLB
assign es_ex_tlb = (es_exccode == `EX_TLBL || es_exccode == `EX_TLBS || 
                    es_exccode == `EX_MOD) && es_valid;
//exception
assign es_tlb_miss    = mapped && !tlb_history_found && (es_is_load || es_is_store);
assign es_tlb_invalid = mapped && tlb_history_found && !tlb_history_vv && (es_is_load || es_is_store);
assign es_tlb_mod     = mapped && tlb_history_found && tlb_history_vv && !tlb_history_d && es_is_store;
assign es_tlb_ex      = es_tlb_miss | es_tlb_invalid | es_tlb_mod;    
`else
assign es_ex_tlb = 0;
assign es_tlb_miss    = 0;
assign es_tlb_invalid = 0;
assign es_tlb_mod     = 0;
assign es_tlb_ex      = 0;  
`endif

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
assign mtc0_we = es_valid && es_inst_mtc0 && !es_ex;

`ifdef USE_TLB
assign has_ex = es_ex || ds_to_es_tlbwir_cancel && es_valid;
`else
assign has_ex = es_ex && es_valid;
`endif 

assign es_is_store = |es_store_op;
assign es_is_load  = |es_load_op;
assign es_res_from_mem = es_is_load;
assign es_c0_rdata = mfc0_rdata;

`ifdef USE_TLB
wire kseg1 = mapped ? data_sram_physical_addr[31:29] == 3'b101 : es_alu_result[31:29] == 3'b101;
`else
wire kseg1 = es_alu_result[31:29] == 3'b101;
`endif 

wire data_cache = !kseg1 && `USE_DCACHE;
assign es_to_rs_bus = {data_cache,
                       es_inst_mfhi,
                       es_inst_mflo,
                       es_inst_mthi,
                       es_inst_mtlo,
                       es_inst_mult,
                       es_inst_multu,
                       es_inst_div,
                       es_inst_divu,
                       es_rs_value,
                       div_result,
                       divu_result,
                       mult_result,
                       multu_result,
                       fs_pc_error,
                       es_inst_eret,          //226:226
                       ds_to_es_tlbwir_cancel,//225:225
                       exception_tlb_refill, //224:224
					   data_sram_addr ,      //223:192
					   data_sram_wr   ,      //191:191
					   data_sram_wdata,      //190:159
					   data_sram_size ,      //158:157
					   data_sram_wstrb,      //156:153
					   has_ex         ,      //152:152
					   es_ex          ,      //151:151
					   es_bd          ,      //150:150
					   es_badvaddr    ,      //149:118
					   es_exccode     ,      //117:113
					   es_inst_mfc0   ,      //112:112
					   mfc0_rdata     ,      //111:80
					   es_is_load     ,      //79:79
                       es_is_store    ,      //78:78
                       es_load_op     ,      //77:71
                       es_res_from_mem,      //70:70
                       (es_gr_we && !es_ex),   //69:69
                       es_dest        ,      //68:64
                       es_result      ,      //63:32
                       es_pc                 //31:0
                      };
`ifdef USE_TLB
assign es_ready_go    = es_is_load | es_is_store ? !wait_translation :
						es_inst_div  ? div_out_tvalid  || div_finish  :
                        es_inst_divu ? divu_out_tvalid || divu_finish :
                        1'b1;
`else
assign es_ready_go    = es_inst_div  ? div_out_tvalid  || div_finish  :
                        es_inst_divu ? divu_out_tvalid || divu_finish :
                        1'b1;
`endif

assign es_allowin     = !es_valid || es_ready_go && rs_allowin;
assign es_to_rs_valid = es_valid && es_ready_go && !handle_exc && !handle_eret && !pipe_flush;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
	else if (handle_exc || handle_eret || pipe_flush) begin
		es_valid <= 1'b0;
	end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

//execute
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

assign es_reg = {{4{es_gr_we & es_valid}},
                   es_is_load && es_valid,
        		   es_inst_mfc0 && es_valid,
                   es_inst_mfhi && es_valid,
                   es_inst_mflo && es_valid,
				   es_dest & {5{es_valid}},
				   es_result};

//unalign store							   
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
assign adel = ( es_load_op[4] & (es_alu_result[1:0]!=2'b00)) | ((es_load_op[2] | es_load_op[3]) & (es_alu_result[0]!=1'b0));

// SRAM interface
`ifdef USE_TLB
wire wait_translation = mapped && !(tlb_query_state == 0 && tlb_hit);
`endif

assign data_sram_wr  = es_is_store & !ades & !adel;

assign data_size_2 = es_store_op[2] | es_load_op[4] |
                    ((es_store_op[3] | es_load_op[5]) && (es_alu_result[1:0] == 2'b10 || es_alu_result[1:0] == 2'b11)) | 
                    ((es_store_op[4] | es_load_op[6]) && (es_alu_result[1:0] == 2'b00 || es_alu_result[1:0] == 2'b01)) ; 
assign data_size_1 = es_store_op[1] | es_load_op[2] | es_load_op[3] |
                    ((es_store_op[3] | es_load_op[5]) && (es_alu_result[1:0] == 2'b01)) | 
                    ((es_store_op[4] | es_load_op[6]) && (es_alu_result[1:0] == 2'b10)) ; 
assign data_sram_size = data_size_2 ? 2'b10 : data_size_1 ? 2'b01 : 2'b0; 
assign data_sram_wstrb = es_mem_we && es_valid && (!has_ex) ? strb : 4'h0;

wire [31:0] _real_address;

assign _real_address = es_alu_result & (es_alu_result[31:30] == 2'b10 ? 32'h1fffffff : 32'hffffffff);

`ifdef USE_TLB
assign data_sram_addr = mapped ? data_sram_physical_addr : _real_address;
`else 
assign data_sram_addr = _real_address;
`endif

assign data_sram_wdata = ({32{es_store_op[0]}} & es_sb_value ) |
                         ({32{es_store_op[1]}} & es_sh_value ) |
                         ({32{es_store_op[2]}} & es_sw_value ) |
                         ({32{es_store_op[3]}} & es_swl_value) |
                         ({32{es_store_op[4]}} & es_swr_value) ;
// TLB related
`ifdef USE_TLB
assign mapped      = ~es_alu_result[31] | (es_alu_result[31] & es_alu_result[30]);
assign s1_vpn2     =  es_tlbp ? cp0_entryhi[31:13] : tlb_history_vpn2;
assign s1_odd_page =  es_tlbp ? 0 : tlb_history_odd;
assign data_sram_physical_addr = {tlb_history_pfn, {es_alu_result[11:0]}} 
                   & ((es_store_op[3] | es_load_op[5]) ? 32'hfffffffc : 32'hffffffff);
`endif
endmodule
