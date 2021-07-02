`include "mycpu.h"

module mem_req_stage(
    input                          clk           ,
    input                          reset         ,
	
    //allowin
    input                          ms_allowin    ,
    output                         rs_allowin    ,
	
    //from ds
    input                          es_to_rs_valid,
    input  [`ES_TO_RS_BUS_WD -1:0] es_to_rs_bus  ,
	
    //to ms
    output                         rs_to_ms_valid,
    output [`RS_TO_MS_BUS_WD -1:0] rs_to_ms_bus  ,
    output                         rs_loading,
    output                         data_cache,
	
    //data sram interface 
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
	
    //exception related
    output         exception_tlb_refill,
    output         handle_exc,
    output         handle_eret,
	output         rs_ex_tlb,
    output         pipe_flush,
	output [42:0]  rs_reg,
	output         rs_bd,
	output [ 4:0]  rs_exccode,
	output [31:0]  rs_badvaddr,
	output [31:0]  rs_pc,
    output         fs_pc_error
	
);
reg  [31:0] hi;
reg  [31:0] lo;
wire rs_inst_eret;
(* max_fanout = 10 *)reg         rs_valid;
wire        rs_ready_go   ;
(* max_fanout = 10 *)reg handle_exc_r;
always @(posedge clk) begin
    if (reset)
        handle_exc_r <= 0;
    else if (rs_ex)
        handle_exc_r <= 1;
    else if (ms_allowin && rs_ready_go)
        handle_exc_r <= 0;
end

(* max_fanout = 10 *)reg handle_eret_r;
always @(posedge clk) begin
    if (reset)
        handle_eret_r <= 0;
    else if (rs_inst_eret)
        handle_eret_r <= 1;
    else if (ms_allowin && rs_ready_go)
        handle_eret_r <= 0;
end

(* max_fanout = 20 *)reg  [`ES_TO_RS_BUS_WD -1:0] es_to_rs_bus_r;

assign pipe_flush  = rs_tlbwir_cancel && rs_valid;
assign handle_eret = rs_inst_eret && !handle_eret_r && rs_valid;
assign handle_exc  = rs_ex && !handle_exc_r && rs_valid;

wire [ 4:0] rs_dest;
wire [31:0] rs_result;
wire [31:0] es_result;
wire [ 6:0] rs_load_op;
wire [31:0] rs_c0_rdata;

wire inst_mfhi;
wire inst_mflo;
wire inst_mthi;
wire inst_mtlo;
wire inst_mult;
wire inst_multu;
wire inst_div;
wire inst_divu;
wire [31:0] rs_rs_value;
wire [63:0] mult_result;
wire [63:0] multu_result;
wire [63:0] div_result;
wire [63:0] divu_result;

assign {data_cache,
        inst_mfhi,
        inst_mflo,
        inst_mthi,
        inst_mtlo,
        inst_mult,
        inst_multu,
        inst_div,
        inst_divu,
        rs_rs_value,
        div_result,
        divu_result,
        mult_result,
        multu_result,
        fs_pc_error,
        rs_inst_eret,
        rs_tlbwir_cancel,
        exception_tlb_refill,
		data_sram_addr,
		data_sram_wr,
		data_sram_wdata,
		data_sram_size,
		data_sram_wstrb,
		has_ex,
		rs_ex,
		rs_bd,
		rs_badvaddr,
		rs_exccode,
		rs_inst_mfc0,
		rs_c0_rdata,
		rs_is_load,
		rs_is_store,
		rs_load_op,
		rs_res_from_mem,
		rs_gr_we,
		rs_dest,
		es_result,
		rs_pc
       } = es_to_rs_bus_r;

assign rs_ex_tlb = (rs_exccode == `EX_TLBL || rs_exccode == `EX_TLBS || 
                    rs_exccode == `EX_MOD) && rs_valid;

assign rs_loading = rs_is_load | rs_is_store;
assign rs_result  = inst_mfhi ? hi : inst_mflo ? lo : es_result;
assign rs_to_ms_bus = {rs_inst_mfc0   ,  //112:112
					   rs_c0_rdata    ,  //111:80
					   rs_is_load     ,  //79:79
                       rs_is_store    ,  //78:78
                       rs_load_op     ,  //77:71
                       rs_res_from_mem,  //70:70
                       rs_gr_we       ,  //69:69
                       rs_dest        ,  //68:64
                       rs_result      ,  //63:32
                       rs_pc             //31:0
                      };

assign rs_ready_go    = rs_ex || rs_inst_eret || rs_tlbwir_cancel ? 1'b1 :
                        rs_is_load | rs_is_store ? (data_sram_req && data_sram_addr_ok) :
                        1'b1;
assign rs_allowin     = !rs_valid || rs_ready_go && ms_allowin;
assign rs_to_ms_valid = rs_valid && rs_ready_go && !rs_ex && !rs_inst_eret && !rs_tlbwir_cancel;

always @(posedge clk) begin
    if (reset) begin
        rs_valid <= 1'b0;
    end
    else if (rs_allowin) begin
        rs_valid <= es_to_rs_valid;
    end

    if (es_to_rs_valid && rs_allowin) begin
        es_to_rs_bus_r <= es_to_rs_bus;
    end
end

always @(posedge clk) begin
    if (reset) begin
        hi <= 32'b0;
    end
    else if(inst_mult && rs_valid && !has_ex) begin
        hi <= mult_result[63:32];
    end
    else if(inst_multu && rs_valid && !has_ex) begin
        hi <= multu_result[63:32];
    end
    else if(inst_div && rs_valid && !has_ex) begin
        hi <= div_result[31:0];
    end
    else if(inst_divu && rs_valid && !has_ex) begin
        hi <= divu_result[31:0];
    end
    else if(inst_mthi && rs_valid && !has_ex) begin
        hi <= rs_rs_value;
    end
end

always @(posedge clk) begin
    if (reset) begin
        lo<=32'b0;
    end
    else if(inst_mult && rs_valid && !has_ex) begin
        lo<=mult_result[31:0];
    end
    else if(inst_multu && rs_valid && !has_ex) begin
        lo <= multu_result[31:0];
    end
    else if(inst_div && rs_valid && !has_ex) begin
        lo <= div_result[63:32];
    end
    else if(inst_divu && rs_valid && !has_ex) begin
        lo <= divu_result[63:32];
    end
    else if(inst_mtlo && rs_valid && !has_ex) begin
        lo <= rs_rs_value;
    end
end

assign rs_reg = {{4{rs_gr_we & rs_valid}},
                    rs_is_load && rs_valid,
					rs_inst_mfc0 && rs_valid,
					rs_dest & {5{rs_valid}},
					rs_result};

assign data_sram_req = rs_valid && ms_allowin && (rs_is_load | rs_is_store) && !(rs_ex || rs_inst_eret);

endmodule
