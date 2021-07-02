`include "mycpu.h"

module mem2_stage(
    input                          clk            ,
    input                          reset          ,
    // Pipline shake
      // ms2-ws
    input                          ws_allowin_2   ,
    output                         ms2_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms2_to_ws_bus  ,
      // es1-ms1
    output                         ms2_allowin     ,
    input                          es2_to_ms2_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es2_to_ms2_bus  ,
    
    // Bypass network
      //to ds:forward
    output [41:0]                  ms2_reg    ,
    output                         ms2_loading,
      // ms1-ms2
    output  reg   ms2_wait,
    input         ms1_wait,

    // Dcache interface 
    input         dcache_data_ok,
    input  [31:0] dcache_rdata,
    // Exception related
    output        ms2_to_es_ex,

);

// Signal declaration
reg         ms_valid;
wire        ms_ready_go;
reg [`ES_TO_MS_BUS_WD -1:0] es2_to_ms2_bus_r;

wire        ms_is_load    ;
wire        ms_is_store   ;
wire        ms_es_ex      ;
wire        ms_es_bd      ;
wire [31:0] ms_final_result;
wire [ 3:0] load_we;
wire [ 3:0] ms_rf_we;
wire [31:0] ms_es_badvaddr;       
wire [ 4:0] ms_es_exccode ;
wire        ms_inst_eret    ;
wire        ms_inst_mfc0    ;
wire        ms_inst_mtc0    ;
wire [ 7:0] ms_c0_addr    ;
wire [ 6:0] ms_load_op;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire [31:0] mem_result;
wire [ 3:0] addr_align;
wire [31:0] lb_result;
wire [31:0] lh_result;
wire [31:0] lw_result;
wire [31:0] lwl_result;
wire [31:0] lwr_result;
wire [ 3:0] ms_index;
wire        ms_tlbwi;
wire        ms_tlbr;
wire        ms_tlbp;
wire        ms_tlbp_found;
wire        ms_tlbwir_cancel;
wire        ms_refill;

//====================================== HandShake for pipeline ===========================================
assign {ms_refill      ,  //139:139
        ms_tlbp_found  ,  //138:138
        es_to_ms_tlbwir_cancel, //137:137
        ms_index       ,  //136:133
        ms_tlbwi       ,  //132:132
        ms_tlbr        ,  //131:131
        ms_tlbp        ,  //130:130
        ms_es_ex       ,  //129:129
        ms_es_bd       ,  //128:128
        ms_es_badvaddr ,  //127:96      
        ms_es_exccode  ,  //95:91
        ms_inst_eret   ,  //90:90
        ms_inst_mfc0   ,  //89:89
        ms_inst_mtc0   ,  //88:88
        ms_c0_addr     ,  //87:80
		ms_is_load     ,  //79:79
        ms_is_store    ,  //78:78
        ms_load_op     ,  //77:71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es2_to_ms2_bus_r;
assign ms2_to_ws_bus = {ms_refill         ,  //132:132
                        ms_tlbp_found     ,  //131:131
                        ms_tlbwir_cancel  ,  //130:130
                        ms_index          ,  //129:126
                        ms_tlbwi          ,  //125:125
                        ms_tlbr           ,  //124:124
                        ms_tlbp           ,  //123:123
                        ms_es_ex          ,  //122:122
                        ms_es_bd          ,  //121:121
                        ms_es_badvaddr    ,  //120:89    
                        ms_es_exccode     ,  //88:84
                        ms_inst_eret      ,  //83:83
                        ms_inst_mfc0      ,  //82:82
                        ms_inst_mtc0      ,  //81:81
                        ms_c0_addr        ,  //80:73
                        ms_rf_we          ,  //72:69
                        ms_dest           ,  //68:64
                        ms_final_result   ,  //63:32
                        ms_pc                //31:0
                       };
assign ms_ready_go     = !ms1_wait && (handle_exc | handle_eret | pipe_flush) || !((ms_is_load | ms_is_store) && !dcache_data_ok);
assign ms2_allowin     = !ms_valid || ms_ready_go && ws_allowin_2;
assign ms2_to_ws_valid = ms_valid && ms_ready_go && !handle_exc && !handle_eret && !pipe_flush;
always @(posedge clk) begin
    if (reset) begin
        ms2_wait <= 1'b0;
    end
    else if (es2_to_ms2_valid && ms2_allowin) begin
        if ((ms_is_load | ms_is_store) && !dcache_data_ok) begin
            ms2_wait <= 1'b1;
        end else begin
            ms2_wait <= 1'b0;
        end
    end
    else if (ms2_wait && ((ms_is_load | ms_is_store) && dcache_data_ok)) begin
        ms2_wait <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms2_allowin) begin
        ms_valid <= es2_to_ms2_valid;
    end

    if (es2_to_ms2_valid && ms2_allowin) begin
        es2_to_ms2_bus_r  <= es2_to_ms2_bus;
    end
end

//====================================== Bypass Exception =================================================


//====================================== Load return data =================================================
assign load_we    = ({4{(ms_load_op[6] & (ms_alu_result[1:0] == 2'b00))}} & 4'b1111)|
					          ({4{(ms_load_op[6] & (ms_alu_result[1:0] == 2'b01))}} & 4'b0111)|
					          ({4{(ms_load_op[6] & (ms_alu_result[1:0] == 2'b10))}} & 4'b0011)|
					          ({4{(ms_load_op[6] & (ms_alu_result[1:0] == 2'b11))}} & 4'b0001)|
					          ({4{(ms_load_op[5] & (ms_alu_result[1:0] == 2'b00))}} & 4'b1000)|
					          ({4{(ms_load_op[5] & (ms_alu_result[1:0] == 2'b01))}} & 4'b1100)|
					          ({4{(ms_load_op[5] & (ms_alu_result[1:0] == 2'b10))}} & 4'b1110)|
					          ({4{(ms_load_op[5] & (ms_alu_result[1:0] == 2'b11))}} & 4'b1111)|
					          ({4{(ms_load_op[0] | ms_load_op[1] | ms_load_op[2] | ms_load_op[3] | ms_load_op[4])}} & {4{ms_gr_we}});
assign addr_align = {ms_alu_result[1:0] == 2'b11, ms_alu_result[1:0] == 2'b10,
                     ms_alu_result[1:0] == 2'b01, ms_alu_result[1:0] == 2'b00};
assign lb_result  = ({32{addr_align[0]}} & {{24{(ms_load_op[0]) ? dcache_rdata[ 7] : 1'b0}}, dcache_rdata[ 7: 0]}) |
                    ({32{addr_align[1]}} & {{24{(ms_load_op[0]) ? dcache_rdata[15] : 1'b0}}, dcache_rdata[15: 8]}) |
                    ({32{addr_align[2]}} & {{24{(ms_load_op[0]) ? dcache_rdata[23] : 1'b0}}, dcache_rdata[23:16]}) |
                    ({32{addr_align[3]}} & {{24{(ms_load_op[0]) ? dcache_rdata[31] : 1'b0}}, dcache_rdata[31:24]}) ;
assign lh_result  = ({32{~ms_alu_result[1]}} & {{16{(ms_load_op[2]) ? dcache_rdata[15] : 1'b0}}, dcache_rdata[15: 0]}) |
                    ({32{ ms_alu_result[1]}} & {{16{(ms_load_op[2]) ? dcache_rdata[31] : 1'b0}}, dcache_rdata[31:16]});
assign lw_result  = dcache_rdata;
assign lwl_result = ({32{addr_align[0]}} & {dcache_rdata[ 7: 0], 24'b0}) |
                    ({32{addr_align[1]}} & {dcache_rdata[15: 0], 16'b0}) |
                    ({32{addr_align[2]}} & {dcache_rdata[23: 0],  8'b0}) |
                    ({32{addr_align[3]}} &  dcache_rdata)                ;
assign lwr_result = ({32{addr_align[0]}} &  dcache_rdata)                |
                    ({32{addr_align[1]}} & { 8'b0, dcache_rdata[31: 8]}) |
                    ({32{addr_align[2]}} & {16'b0, dcache_rdata[31:16]}) |
                    ({32{addr_align[3]}} & {24'b0, dcache_rdata[31:24]}) ;
assign mem_result = ({32{ms_load_op[0] | ms_load_op[1]}} & lb_result ) |
                    ({32{ms_load_op[2] | ms_load_op[3]}} & lh_result ) |
                    ({32{ms_load_op[4]                }} & lw_result ) |
                    ({32{ms_load_op[5]                }} & lwl_result) |
                    ({32{ms_load_op[6]                }} & lwr_result) ;
					
assign ms_rf_we = ms_res_from_mem ? load_we : {4{ms_gr_we}};
assign ms_final_result = ms_res_from_mem ? mem_result : ms_alu_result;
assign ms2_loading = ms_is_load & ms_valid & !(|ms_rf_we && ms_to_ws_valid); 
assign ms2_reg = {ms_rf_we & {4{ms_to_ws_valid}},
                  ms_inst_mfc0 & ms_to_ws_valid,
							    ms_dest  & {5{ms_to_ws_valid}},
							    ms_final_result}; 
							  

endmodule