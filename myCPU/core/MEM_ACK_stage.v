`include "mycpu.h"

module mem_ack_stage(
    input                          clk           ,
    input                          reset         ,
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es 
    input                          rs_to_ms_valid,
    input  [`RS_TO_MS_BUS_WD -1:0] rs_to_ms_bus  ,
    input                          rs_loading    ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //to ds:forward
    output [42:0]                  ms_reg,
    output                         ms_loading,
    //data sram interface
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata
);

reg         ms_valid;
wire        ms_ready_go;

(* max_fanout = 30 *)reg [`RS_TO_MS_BUS_WD -1:0] rs_to_ms_bus_r;

wire        ms_is_load    ;
wire        ms_is_store   ;
wire [31:0] ms_final_result;
wire [ 3:0] load_we;
wire [ 3:0] ms_rf_we;
wire        ms_inst_mfc0    ;
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
wire [31:0] ms_c0_rdata;

assign {ms_inst_mfc0   ,  //112:112
		ms_c0_rdata    ,  //111:80
		ms_is_load     ,  //79:79
        ms_is_store    ,  //78:78
        ms_load_op     ,  //77:71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = rs_to_ms_bus_r;

//exception
assign ms_to_ws_bus = {ms_c0_rdata       ,  //105:74
                       ms_inst_mfc0      ,  //73:73
                       ms_rf_we          ,  //72:69
                       ms_dest           ,  //68:64
                       ms_final_result   ,  //63:32
                       ms_pc                //31:0
                      };

assign ms_ready_go    = !((ms_is_load || ms_is_store) && !data_sram_data_ok);
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid =  ms_valid && ms_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= rs_to_ms_valid;
    end

    if (rs_to_ms_valid && ms_allowin) begin
        rs_to_ms_bus_r  <= rs_to_ms_bus;
    end
end

//unalign load
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
assign lb_result  = ({32{addr_align[0]}} & {{24{(ms_load_op[0]) ? data_sram_rdata[ 7] : 1'b0}}, data_sram_rdata[ 7: 0]}) |
                    ({32{addr_align[1]}} & {{24{(ms_load_op[0]) ? data_sram_rdata[15] : 1'b0}}, data_sram_rdata[15: 8]}) |
                    ({32{addr_align[2]}} & {{24{(ms_load_op[0]) ? data_sram_rdata[23] : 1'b0}}, data_sram_rdata[23:16]}) |
                    ({32{addr_align[3]}} & {{24{(ms_load_op[0]) ? data_sram_rdata[31] : 1'b0}}, data_sram_rdata[31:24]}) ;
assign lh_result  = ({32{~ms_alu_result[1]}} & {{16{(ms_load_op[2]) ? data_sram_rdata[15] : 1'b0}}, data_sram_rdata[15: 0]}) |
                    ({32{ ms_alu_result[1]}} & {{16{(ms_load_op[2]) ? data_sram_rdata[31] : 1'b0}}, data_sram_rdata[31:16]});
assign lw_result  = data_sram_rdata;
assign lwl_result = ({32{addr_align[0]}} & {data_sram_rdata[ 7: 0], 24'b0}) |
                    ({32{addr_align[1]}} & {data_sram_rdata[15: 0], 16'b0}) |
                    ({32{addr_align[2]}} & {data_sram_rdata[23: 0],  8'b0}) |
                    ({32{addr_align[3]}} &  data_sram_rdata)                ;
assign lwr_result = ({32{addr_align[0]}} &  data_sram_rdata)                |
                    ({32{addr_align[1]}} & { 8'b0, data_sram_rdata[31: 8]}) |
                    ({32{addr_align[2]}} & {16'b0, data_sram_rdata[31:16]}) |
                    ({32{addr_align[3]}} & {24'b0, data_sram_rdata[31:24]}) ;
assign mem_result = ({32{ms_load_op[0] | ms_load_op[1]}} & lb_result ) |
                    ({32{ms_load_op[2] | ms_load_op[3]}} & lh_result ) |
                    ({32{ms_load_op[4]                }} & lw_result ) |
                    ({32{ms_load_op[5]                }} & lwl_result) |
                    ({32{ms_load_op[6]                }} & lwr_result) ;
					
assign ms_rf_we = ms_res_from_mem ? load_we : {4{ms_gr_we}};
assign ms_final_result = ms_res_from_mem ? mem_result : ms_alu_result;
assign ms_loading = ms_is_load & ms_valid; 
assign ms_reg = {ms_is_load ,
                 ms_rf_we    & {4{ms_valid}},
                 ms_inst_mfc0 & ms_valid,
				 ms_dest      & {5{ms_valid}},
	             ms_alu_result/*ms_final_result*/}; 
							  
endmodule
