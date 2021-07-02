`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,

    // IF-ID Bus
    input                          ds_allowin     ,
    output                         fs_allowin     ,

    input                          ps_to_fs_valid ,
    input  [`PS_TO_FS_BUS_WD -1:0] ps_to_fs_bus   ,
    
	output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,

    // IF-WB Bus Exception related
    input         handle_exc,
    input         handle_eret,
    input         pipe_flush,
    input         has_int,

    // Inst-sram interface
    input         inst_sram_data_ok,
	input  [31:0] inst_sram_rdata,
    
    //TLB refetch tag
    input ds_tlbwir_cancel,
    input refresh_tlb_cache,
    input fs_pc_error
);

// IF
(* max_fanout = "10" *)reg         fs_valid;
(* max_fanout = "10" *)reg [`PS_TO_FS_BUS_WD - 1:0] ps_to_fs_bus_r;
wire        fs_ready_go;
wire        fs_allowin;

wire [31:0] fs_inst;
wire [31:0] fs_pc;
reg  [31:0] fs_inst_sram_rdata_r;
reg         fs_inst_sram_rdata_r_vaild;

// Exception
wire        fs_ex;
wire [31:0] fs_badvaddr;       
wire [ 4:0] fs_exccode;
wire        fs_pc_adel;

assign {fs_pc_adel,
		fs_tlb_miss,
		fs_tlb_invalid,
	    fs_pc} = ps_to_fs_bus_r;

reg fs_cancel;
always @(posedge clk)begin
    if(reset) begin
        fs_cancel <= 1'b0;
    end else if((handle_exc || handle_eret || pipe_flush) && !fs_pc_error && (ps_to_fs_valid || (!fs_allowin && !fs_ready_go))) begin
        fs_cancel <= 1'b1;
    end else if(inst_sram_data_ok) begin
        fs_cancel <= 1'b0;
    end
end

// IF stage
assign fs_to_ds_bus = {fs_tlb_miss,
                       fs_tlbwir_cancel,
                       fs_ex,
                       fs_badvaddr,      
                       fs_exccode,
                       fs_inst ,
                       fs_pc};
					   
assign fs_ready_go    = !fs_cancel && (inst_sram_data_ok || fs_inst_sram_rdata_r_vaild) || fs_pc_adel || fs_tlb_miss || fs_tlb_invalid;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid = fs_valid && fs_ready_go && !handle_exc && !handle_eret && !pipe_flush;

assign fs_tlbwir_cancel = ds_tlbwir_cancel;

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end else if (handle_exc || handle_eret || pipe_flush) begin
        fs_valid <= 1'b0;
    end else if (fs_allowin) begin
        fs_valid <= ps_to_fs_valid;
    end

    if (ps_to_fs_valid && fs_allowin) begin
        ps_to_fs_bus_r <= ps_to_fs_bus;
    end
end

always @(posedge clk) begin
    if(reset) begin
        fs_inst_sram_rdata_r <= 32'b0;
    end else if(inst_sram_data_ok && !ds_allowin) begin
        fs_inst_sram_rdata_r <= inst_sram_rdata;
    end
end

always @(posedge clk) begin
    if(reset) begin
        fs_inst_sram_rdata_r_vaild <= 1'b0;
    end else if(handle_exc || handle_eret || pipe_flush) begin
        fs_inst_sram_rdata_r_vaild <= 1'b0;
    end else if(inst_sram_data_ok && !ds_allowin) begin
        fs_inst_sram_rdata_r_vaild <= 1'b1;
    end else if(fs_ready_go && ds_allowin) begin
        fs_inst_sram_rdata_r_vaild <= 1'b0;
    end
end

assign fs_inst = fs_ex ? 32'b0 : fs_inst_sram_rdata_r_vaild ? fs_inst_sram_rdata_r : inst_sram_rdata;
assign fs_ex = has_int | fs_pc_adel | fs_tlb_miss | fs_tlb_invalid;                 
assign fs_badvaddr = fs_pc;
assign fs_exccode =  has_int                           ? `EX_INT  :
                    (fs_tlb_miss | fs_tlb_invalid) ? `EX_TLBL :
                     fs_pc_adel                        ? `EX_ADEL : 5'b0 ; 
endmodule

