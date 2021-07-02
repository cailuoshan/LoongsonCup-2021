`include "include/mycpu.h"
module mycpu_top(
    input  [ 5:0]  ext_int,
    input          aclk,
    input          aresetn,
    
    output [ 3:0]  arid,
    output [31:0]  araddr,
    output [ 7:0]  arlen,
    output [ 2:0]  arsize,
    output [ 1:0]  arburst,
    output [ 1:0]  arlock,
    output [ 3:0]  arcache,
    output [ 2:0]  arprot,
    output         arvalid,
    input          arready,

    input  [ 3:0]  rid,
    input  [31:0]  rdata,
    input  [ 1:0]  rresp,
    input          rlast,
    input          rvalid,
    output         rready,

    output [ 3:0]  awid,
    output [31:0]  awaddr,
    output [ 7:0]  awlen,
    output [ 2:0]  awsize,
    output [ 1:0]  awburst,
    output [ 1:0]  awlock,
    output [ 3:0]  awcache,
    output [ 2:0]  awprot,
    output         awvalid,
    input          awready,

    output [ 3:0]  wid,
    output [31:0]  wdata,
    output [ 3:0]  wstrb,
    output         wlast,
    output         wvalid,
    input          wready,

    input  [ 3:0]  bid,
    input  [ 1:0]  bresp,
    input          bvalid,
    output         bready,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
wire        data_sram_req;
wire        data_sram_wr;
wire [ 1:0] data_sram_size;
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;
wire [31:0] data_sram_rdata;
wire [31:0] inst_sram_wdata;
wire        inst_sram_addr_ok;
wire        inst_sram_data_ok;
wire [31:0] inst_sram_rdata;
wire        inst_sram_req;
wire        inst_sram_wr;
wire [ 1:0] inst_sram_size;
wire [ 3:0] inst_sram_wstrb;
wire [31:0] inst_sram_addr;
reg         reset;
wire        clk = aclk;

always @(posedge clk) reset <= ~aresetn;

wire         fs_allowin;
wire         ds_allowin;
wire         es_allowin;
wire         rs_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         ps_to_fs_valid;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_rs_valid;
wire         rs_to_ms_valid;
wire         ms_to_ws_valid;
wire [`PS_TO_FS_BUS_WD -1:0] ps_to_fs_bus;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_RS_BUS_WD -1:0] es_to_rs_bus;
wire [`RS_TO_MS_BUS_WD -1:0] rs_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [44:0] es_reg; 
wire [42:0] rs_reg; 
wire [42:0] ms_reg;
wire [40:0] ws_reg;

wire          handle_exc;
wire          handle_eret;
wire [31:0]   cp0_epc;
wire          has_int;
wire          br_leaving;
wire          es_loading;
wire          rs_loading;
wire          ms_loading;

wire [18:0]   s0_vpn2;
wire          s0_odd_page;
wire          s0_found;
wire [ 3:0]   s0_index;
wire [19:0]   s0_pfn;
wire [ 2:0]   s0_c;
wire          s0_d;
wire          s0_v;
wire [18:0]   s1_vpn2;
wire          s1_odd_page;
wire          s1_found;
wire [ 3:0]   s1_index;
wire [19:0]   s1_pfn;
wire [ 2:0]   s1_c;
wire          s1_d;
wire          s1_v;
wire          ds_tlbwir_cancel;
wire [31:0]   cp0_entryhi;
wire [31:0]   pipe_flush_pc;
wire          pipe_flush;
wire          exception_tlb_refill;


wire [18:0] s0_vpn2;
wire        s0_odd_page;
wire        s0_found;     
wire [ 3:0] s0_index;     
wire [19:0] s0_pfn;     
wire [ 2:0] s0_c;     
wire        s0_d;     
wire        s0_v;

wire [18:0] s1_vpn2;
wire        s1_odd_page;
wire        s1_found;     
wire [ 3:0] s1_index;     
wire [19:0] s1_pfn;     
wire [ 2:0] s1_c;   
wire        s1_d;     
wire        s1_v;

wire [18:0] r_vpn2;
wire [ 7:0] r_asid;
wire        r_g;
wire [19:0] r_pfn0;
wire [ 2:0] r_c0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_pfn1;
wire [ 2:0] r_c1;
wire        r_d1;
wire        r_v1;

wire rs_bd;
wire [ 4:0] rs_exccode;
wire [31:0] rs_badvaddr;
wire mtc0_we;
wire [ 7:0] es_c0_addr;
wire [31:0] es_pc;
wire [31:0] rs_pc;
wire [31:0] mtc0_data;
wire [31:0] mfc0_rdata;

wire [31:0] cp0_entrylo0;
wire [31:0] cp0_entrylo1;
wire [31:0] cp0_index;

wire inst_cache;
wire es_tlbp;
wire es_tlbr;
wire es_tlbwi;
assign refresh_tlb_cache = handle_exc | handle_eret | pipe_flush;
wire fs_error;
// PF stage
pf_stage pf_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //IF-ID Bus
    .fs_allowin     (fs_allowin     ),
    .ps_to_fs_valid (ps_to_fs_valid ),
    .ps_to_fs_bus   (ps_to_fs_bus   ),
    .br_bus         (br_bus         ),
    .br_leaving     (br_leaving     ),
    // IF-WB Bus
    .handle_exc     (handle_exc     ),
    .exception_tlb_refill(exception_tlb_refill),
    .handle_eret    (handle_eret    ),
    .cp0_epc        (cp0_epc        ),
    .pipe_flush_pc  (pipe_flush_pc  ),
    .pipe_flush     (pipe_flush     ),
    // Inst-sram interface
    .inst_sram_req    (inst_sram_req    ),
    .inst_sram_wr     (inst_sram_wr     ),
    .inst_sram_size   (inst_sram_size   ),
    .inst_sram_addr   (inst_sram_addr   ),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_cache       (inst_cache),
    
    .s0_vpn2        (s0_vpn2),
    .s0_odd_page    (s0_odd_page),
    .s0_found       (s0_found),
    .s0_index       (s0_index),
    .s0_pfn         (s0_pfn),
    .s0_c           (s0_c),
    .s0_d           (s0_d),
    .s0_v           (s0_v),

    .refresh_tlb_cache (refresh_tlb_cache),
    .ds_tlbwir_cancel(ds_tlbwir_cancel),
    .fs_error (fs_error)
);

// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //IF-ID Bus
    .ds_allowin     (ds_allowin     ),
    .fs_allowin     (fs_allowin     ),
    .ps_to_fs_valid (ps_to_fs_valid ),
    .ps_to_fs_bus   (ps_to_fs_bus   ),
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),

    // IF-WB Bus
    .handle_exc     (handle_exc     ),
    .handle_eret    (handle_eret    ),
    .pipe_flush     (pipe_flush     ),
    .has_int        (has_int        ),
    // Inst-sram interface
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata  (inst_sram_rdata  ),
    
    .refresh_tlb_cache (refresh_tlb_cache),
    .ds_tlbwir_cancel(ds_tlbwir_cancel),
    .fs_pc_error(fs_pc_error | fs_error)
);

// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    .br_leaving     (br_leaving     ),
    //forward_bus
    .es_reg         (es_reg         ),
    .rs_reg         (rs_reg         ),
    .ms_reg         (ms_reg         ),
    .ws_reg         (ws_reg         ),
    .ms_loading     (ms_loading     ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    
    .handle_exc     (handle_exc     ),
    .handle_eret    (handle_eret    ),
    .ds_tlbwir_cancel(ds_tlbwir_cancel),
    .pipe_flush     (pipe_flush     ),
    .es_tlbwir_cancel(es_tlbwir_cancel)
);

// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .rs_allowin     (rs_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to rs
    .es_to_rs_valid (es_to_rs_valid ),
    .es_to_rs_bus   (es_to_rs_bus   ),

    //forward_bus
    .es_reg         (es_reg         ),

    .s1_vpn2          (s1_vpn2),
    .s1_odd_page      (s1_odd_page),
    .s1_found         (s1_found),
    .s1_index         (s1_index),
    .s1_pfn           (s1_pfn),
    .s1_c             (s1_c),
    .s1_d             (s1_d),
    .s1_v             (s1_v),

	.handle_eret      (handle_eret         ),
	.handle_exc       (handle_exc          ),
	.pipe_flush       (pipe_flush          ),
	
	.cp0_entryhi    (cp0_entryhi    ),
	.mtc0_we         (mtc0_we    ),
	.es_c0_addr      (es_c0_addr ),
	.pipe_flush_pc           (pipe_flush_pc      ),
	.mtc0_data       (mtc0_data  ),
	.mfc0_rdata      (mfc0_rdata ),
	.refresh_tlb_cache (refresh_tlb_cache),
	.es_tlbp         (es_tlbp    ),
	.es_tlbr         (es_tlbr    ),
	.es_tlbwi        (es_tlbwi   ),
    .es_tlbwir_cancel(es_tlbwir_cancel)
);

// MEM_REQ stage
mem_req_stage mem_req_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .rs_allowin     (rs_allowin     ),
    //from ds
    .rs_to_ms_valid (rs_to_ms_valid ),
    .rs_to_ms_bus   (rs_to_ms_bus   ),
    //to rs
    .es_to_rs_valid (es_to_rs_valid ),
    .es_to_rs_bus   (es_to_rs_bus   ),

    //forward_bus
    .rs_reg         (rs_reg         ),
    .rs_loading     (rs_loading     ),
    //data sram interface 
    .data_sram_req    (data_sram_req    ),
    .data_sram_wr     (data_sram_wr     ),
    .data_sram_size   (data_sram_size   ),
    .data_sram_wstrb  (data_sram_wstrb  ),
    .data_sram_addr   (data_sram_addr   ),
    .data_sram_wdata  (data_sram_wdata  ),
    .data_sram_addr_ok(data_sram_addr_ok),

	.exception_tlb_refill (exception_tlb_refill),
	.handle_eret          (handle_eret         ),
	.handle_exc           (handle_exc          ),
	.rs_ex_tlb            (rs_ex_tlb           ),
	.pipe_flush           (pipe_flush          ),
    .data_cache       (data_cache       ),
	
	.rs_bd           (rs_bd      ),
	.rs_exccode      (rs_exccode ),
	.rs_badvaddr     (rs_badvaddr),
	.rs_pc           (rs_pc      ),
    .fs_pc_error(fs_pc_error)
);
// MEM_ACK stage
mem_ack_stage mem_ack_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .rs_to_ms_valid (rs_to_ms_valid ),
    .rs_to_ms_bus   (rs_to_ms_bus   ),
    .rs_loading     (rs_loading     ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //forward_bus
    .ms_reg         (ms_reg         ),
    .ms_loading     (ms_loading     ),
    //from data-sram
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata  (data_sram_rdata  )
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    .ws_reg         (ws_reg         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),

    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

cp0 cp0 (
    .clk            (clk            ),
    .rst            (reset          ),
    .es_ex          (handle_exc     ),
    .es_ex_tlb      (rs_ex_tlb      ),
	.eret_flush     (handle_eret    ),
    .ext_int_in     (ext_int        ),
    .es_bd          (rs_bd          ),
	.es_exccode     (rs_exccode     ),
	.es_badvaddr    (rs_badvaddr    ),
	.mtc0_we        (mtc0_we        ),
	.dst            (es_c0_addr[7:3]),
	.sel            (es_c0_addr[2:0]),
    .es_pc          (rs_pc          ),
	.data           (mtc0_data      ),
	.rdata          (mfc0_rdata     ),
    .cp0_epc        (cp0_epc        ),
    .has_int        (has_int        ),
    .tlbp           (es_tlbp        ),
    .tlbp_found     (es_tlbp && s1_found),
    .index          (s1_index       ),
    .tlbr           (es_tlbr        ),
    .r_vpn2         (r_vpn2         ),
    .r_asid         (r_asid         ),
    .r_g            (r_g            ),
    .r_pfn0         (r_pfn0         ),
    .r_c0           (r_c0           ),
    .r_d0           (r_d0           ),
    .r_v0           (r_v0           ),
    .r_pfn1         (r_pfn1         ),
    .r_c1           (r_c1           ),
    .r_d1           (r_d1           ),
    .r_v1           (r_v1           ),
    .cp0_entryhi    (cp0_entryhi    ),
    .cp0_entrylo0   (cp0_entrylo0   ),
    .cp0_entrylo1   (cp0_entrylo1   ),
    .cp0_index      (cp0_index      )
);

`ifdef USE_TLB
tlb #(.TLBNUM(`TLBNUM)) tlb
(
    .clk        (clk),
    .reset      (reset),
    .s0_vpn2    (s0_vpn2),
    .s0_odd_page(s0_odd_page),
    .s0_asid    (cp0_entryhi[7:0]),
    .s0_found   (s0_found),
    .s0_index   (s0_index),
    .s0_pfn     (s0_pfn),
    .s0_c       (s0_c),
    .s0_d       (s0_d),
    .s0_v       (s0_v),

    .s1_vpn2    (s1_vpn2),
    .s1_odd_page(s1_odd_page),
    .s1_asid    (cp0_entryhi[7:0]),
    .s1_found   (s1_found),
    .s1_index   (s1_index),
    .s1_pfn     (s1_pfn),
    .s1_c       (s1_c),
    .s1_d       (s1_d),
    .s1_v       (s1_v),
    
    .we         (es_tlbwi),
    .w_index    (cp0_index[3:0]),
    .w_vpn2     (cp0_entryhi[31:13]),
    .w_asid     (cp0_entryhi[7:0]),
    .w_g        (cp0_entrylo0[0] & cp0_entrylo1[0]),
    .w_pfn0     (cp0_entrylo0[25:6]),
    .w_c0       (cp0_entrylo0[5:3]),     
    .w_d0       (cp0_entrylo0[2]), 
    .w_v0       (cp0_entrylo0[1]),     
    .w_pfn1     (cp0_entrylo1[25:6]),     
    .w_c1       (cp0_entrylo1[5:3]),     
    .w_d1       (cp0_entrylo1[2]),     
    .w_v1       (cp0_entrylo1[1]), 

    .r_index    (cp0_index[3:0]),   
    .r_vpn2     (r_vpn2),     
    .r_asid     (r_asid),     
    .r_g        (r_g),     
    .r_pfn0     (r_pfn0),     
    .r_c0       (r_c0),     
    .r_d0       (r_d0),     
    .r_v0       (r_v0),     
    .r_pfn1     (r_pfn1),     
    .r_c1       (r_c1),     
    .r_d1       (r_d1),     
    .r_v1       (r_v1) 
);
`endif

wire  [3 :0]icache_arid   ;
wire  [31:0]icache_araddr ;
wire  [7 :0]icache_arlen  ;
wire  [2 :0]icache_arsize ;
wire  [1 :0]icache_arburst;
wire  [1 :0]icache_arlock ;
wire  [3 :0]icache_arcache;
wire  [2 :0]icache_arprot ;
wire         icache_arvalid;
wire         icache_arready;
    //r
wire [3 :0] icache_rid    ;
wire [31:0] icache_rdata  ;
wire [1 :0] icache_rresp  ;
wire        icache_rlast  ;
wire        icache_rvalid ;
wire        icache_rready ;
    //aw
wire  [3 :0] icache_awid   ;
wire  [31:0] icache_awaddr ;
wire  [7 :0] icache_awlen  ;
wire  [2 :0] icache_awsize ;
wire  [1 :0] icache_awburst;
wire  [1 :0] icache_awlock ;
wire  [3 :0] icache_awcache;
wire  [2 :0] icache_awprot ;
wire         icache_awvalid;
wire         icache_awready;
    //w
wire  [3 :0] icache_wid    ;
wire  [31:0] icache_wdata  ;
wire  [3 :0] icache_wstrb  ;
wire         icache_wlast  ;
wire         icache_wvalid ;
wire         icache_wready ;
    //b
wire [3 :0] icache_bid    ;
wire [1 :0] icache_bresp  ;
wire        icache_bvalid ;
wire        icache_bready ;

wire  [3 :0]dcache_arid   ;
wire  [31:0]dcache_araddr ;
wire  [7 :0]dcache_arlen  ;
wire  [2 :0]dcache_arsize ;
wire  [1 :0]dcache_arburst;
wire  [1 :0]dcache_arlock ;
wire  [3 :0]dcache_arcache;
wire  [2 :0]dcache_arprot ;
wire        dcache_arvalid;
wire        dcache_arready;
//r
wire [3 :0] dcache_rid    ;
wire [31:0] dcache_rdata  ;
wire [1 :0] dcache_rresp  ;
wire        dcache_rlast  ;
wire        dcache_rvalid ;
wire        dcache_rready ;
//aw
wire  [3 :0]dcache_awid   ;
wire  [31:0]dcache_awaddr ;
wire  [7 :0]dcache_awlen  ;
wire  [2 :0]dcache_awsize ;
wire  [1 :0]dcache_awburst;
wire  [1 :0]dcache_awlock ;
wire  [3 :0]dcache_awcache;
wire  [2 :0]dcache_awprot ;
wire         dcache_awvalid;
wire         dcache_awready;
//w
wire  [3 :0]dcache_wid    ;
wire  [31:0]dcache_wdata  ;
wire  [3 :0]dcache_wstrb  ;
wire         dcache_wlast  ;
wire         dcache_wvalid ;
wire         dcache_wready ;
//b
wire [3 :0]dcache_bid    ;
wire [1 :0]dcache_bresp  ;
wire        dcache_bvalid ;
wire        dcache_bready ;

//wire for uncached inst read
//ar
wire  [3 :0] uncached_inst_arid    ;
wire  [31:0] uncached_inst_araddr  ;
wire  [7 :0] uncached_inst_arlen   ;
wire  [2 :0] uncached_inst_arsize  ;
wire  [1 :0] uncached_inst_arburst ;
wire  [1 :0] uncached_inst_arlock  ;
wire  [3 :0] uncached_inst_arcache ;
wire  [2 :0] uncached_inst_arprot  ;
wire         uncached_inst_arvalid  ;
wire         uncached_inst_arready;
//r
wire [3 :0] uncached_inst_rid  ;
wire [31:0] uncached_inst_rdata  ;
wire [1 :0] uncached_inst_rresp ;
wire        uncached_inst_rlast ;
wire        uncached_inst_rvalid ;
wire        uncached_inst_rready  ;
//aw
wire  [3 :0] uncached_inst_awid    ;
wire  [31:0] uncached_inst_awaddr  ;
wire  [7 :0] uncached_inst_awlen   ;
wire  [2 :0] uncached_inst_awsize  ;
wire  [1 :0] uncached_inst_awburst  ;
wire  [1 :0] uncached_inst_awlock  ;
wire  [3 :0] uncached_inst_awcache ;
wire  [2 :0] uncached_inst_awprot  ;
wire         uncached_inst_awvalid  ;
wire         uncached_inst_awready;
//w
wire  [3 :0]uncached_inst_wid     ;
wire  [31:0]uncached_inst_wdata   ;
wire  [3 :0]uncached_inst_wstrb   ;
wire         uncached_inst_wlast   ;
wire         uncached_inst_wvalid  ;
wire         uncached_inst_wready;
//b
wire [3 :0]uncached_inst_bid   ;
wire [1 :0]uncached_inst_bresp ;
wire        uncached_inst_bvalid ;
wire        uncached_inst_bready  ;

//wire for uncached data read/write
//ar
wire  [3 :0]uncached_data_arid   ;
wire  [31:0]uncached_data_araddr  ;
wire  [7 :0]uncached_data_arlen   ;
wire  [2 :0]uncached_data_arsize  ;
wire  [1 :0]uncached_data_arburst  ;
wire  [1 :0]uncached_data_arlock  ;
wire  [3 :0]uncached_data_arcache ;
wire  [2 :0]uncached_data_arprot  ;
wire        uncached_data_arvalid  ;
wire        uncached_data_arready;
//r
wire [3 :0] uncached_data_rid  ;
wire [31:0] uncached_data_rdata ;
wire [1 :0] uncached_data_rresp ;
wire        uncached_data_rlast ;
wire        uncached_data_rvalid ;
wire        uncached_data_rready  ;
//aw
wire  [3 :0]uncached_data_awid    ;
wire  [31:0]uncached_data_awaddr  ;
wire  [7 :0]uncached_data_awlen   ;
wire  [2 :0]uncached_data_awsize  ;
wire  [1 :0]uncached_data_awburst ;
wire  [1 :0]uncached_data_awlock  ;
wire  [3 :0]uncached_data_awcache ;
wire  [2 :0]uncached_data_awprot  ;
wire         uncached_data_awvalid  ;
wire         uncached_data_awready;
//w
wire  [3 :0]uncached_data_wid     ;
wire  [31:0]uncached_data_wdata   ;
wire  [3 :0]uncached_data_wstrb   ;
wire         uncached_data_wlast   ;
wire         uncached_data_wvalid  ;
wire         uncached_data_wready ;
//b
wire [3 :0]uncached_data_bid   ;
wire [1 :0]uncached_data_bresp ;
wire        uncached_data_bvalid ;
wire        uncached_data_bready  ;

Icache my_Icache(
    .clk          (aclk                     ),
    .resetn       (!reset                   ),
    //cpu
    .inst_valid   (icache_req            ),
    .inst_op      (inst_sram_wr             ),
    .inst_index   (inst_sram_addr[11:5]     ),
    .inst_tag     (inst_sram_addr[31:12]    ),
    .inst_offset  (inst_sram_addr[4:0]      ),
    .inst_wstrb   (inst_sram_wstrb          ),
    .inst_wdata   (inst_sram_wdata          ),
    .inst_addr_ok (icache_addr_ok        ),
    .inst_data_ok (icache_data_ok        ),
    .inst_rdata   (icache_data          ),
    //ar
    .arid         (icache_arid             ),
    .araddr       (icache_araddr           ),
    .arlen        (icache_arlen            ),
    .arsize       (icache_arsize           ),
    .arburst      (icache_arburst          ),
    .arlock       (icache_arlock           ),
    .arcache      (icache_arcache          ),
    .arprot       (icache_arprot           ),
    .arvalid      (icache_arvalid          ),
    .arready      (icache_arready          ),
    //r              
    .rid          (icache_rid              ),
    .rdata        (icache_rdata            ),
    .rresp        (icache_rresp            ),
    .rlast        (icache_rlast            ),
    .rvalid       (icache_rvalid           ),
    .rready       (icache_rready           ),
    //aw               
    .awid         (icache_awid             ),
    .awaddr       (icache_awaddr           ),
    .awlen        (icache_awlen            ),
    .awsize       (icache_awsize           ),
    .awburst      (icache_awburst          ),
    .awlock       (icache_awlock           ),
    .awcache      (icache_awcache          ),
    .awprot       (icache_awprot           ),
    .awvalid      (icache_awvalid          ),
    .awready      (icache_awready          ),
    //w               
    .wid          (icache_wid              ),
    .wdata        (icache_wdata            ),
    .wstrb        (icache_wstrb            ),
    .wlast        (icache_wlast            ),
    .wvalid       (icache_wvalid           ),
    .wready       (icache_wready           ),
        //b              
    .bid          (icache_bid              ),
    .bresp        (icache_bresp            ),
    .bvalid       (icache_bvalid           ),
    .bready       (icache_bready           )
    );
axi_cache_bridge u_axi_cache_bridge(

    .aclk             ( aclk              ), // i, 1                 
    .aresetn          ( aresetn           ), // i, 1                 

    .s_axi_arid       ( {dcache_arid, icache_arid, uncached_data_arid,uncached_inst_arid}        ),
    .s_axi_araddr     ( {dcache_araddr, icache_araddr, uncached_data_araddr,uncached_inst_araddr}      ),
    .s_axi_arlen      ( {dcache_arlen[3:0], icache_arlen[3:0], uncached_data_arlen[3:0], uncached_inst_arlen[3:0]}  ),
    .s_axi_arsize     ( {dcache_arsize, icache_arsize, uncached_data_arsize,3'b010}      ),
    .s_axi_arburst    ( {dcache_arburst, icache_arburst, uncached_data_arburst,uncached_inst_arburst}     ),
    .s_axi_arlock     ( {dcache_arlock, icache_arlock, uncached_data_arlock,uncached_inst_arlock}      ),
    .s_axi_arcache    ( {dcache_arcache, icache_arcache, uncached_data_arcache,uncached_inst_arcache}     ),
    .s_axi_arprot     ( {dcache_arprot, icache_arprot, uncached_data_arprot,uncached_inst_arprot}      ),
    .s_axi_arqos      ( {4'd0,4'd0,4'd0,4'd0}          ),
    .s_axi_arvalid    ( {dcache_arvalid, icache_arvalid, uncached_data_arvalid, uncached_inst_arvalid}     ),
    .s_axi_arready    ( {dcache_arready, icache_arready, uncached_data_arready, uncached_inst_arready}     ),
    .s_axi_rid        ( {dcache_rid, icache_rid, uncached_data_rid, uncached_inst_rid}         ),
    .s_axi_rdata      ( {dcache_rdata, icache_rdata, uncached_data_rdata, uncached_inst_rdata}       ),
    .s_axi_rresp      ( {dcache_rresp, icache_rresp, uncached_data_rresp, uncached_inst_rresp}       ),
    .s_axi_rlast      ( {dcache_rlast, icache_rlast, uncached_data_rlast, uncached_inst_rlast}       ),
    .s_axi_rvalid     ( {dcache_rvalid, icache_rvalid, uncached_data_rvalid, uncached_inst_rvalid}      ),
    .s_axi_rready     ( {dcache_rready, icache_rready, uncached_data_rready, uncached_inst_rready}      ),
    .s_axi_awid       ( {dcache_awid, icache_awid, uncached_data_awid, uncached_inst_awid}        ),
    .s_axi_awaddr     ( {dcache_awaddr, icache_awaddr, uncached_data_awaddr, 32'b0}      ),
    .s_axi_awlen      ( {dcache_awlen[3:0], icache_awlen[3:0], uncached_data_awlen[3:0], uncached_inst_awlen[3:0]}  ),
    .s_axi_awsize     ( {dcache_awsize, icache_awsize, uncached_data_awsize, uncached_inst_awsize}      ),
    .s_axi_awburst    ( {dcache_awburst, icache_awburst, uncached_data_awburst, uncached_inst_awburst}     ),
    .s_axi_awlock     ( {dcache_awlock, icache_awlock, uncached_data_awlock, uncached_inst_awlock}      ),
    .s_axi_awcache    ( {dcache_awcache, icache_awcache, uncached_data_awcache, uncached_inst_awcache}     ),
    .s_axi_awprot     ( {dcache_awprot, icache_awprot, uncached_data_awprot, uncached_inst_awprot}      ),
    .s_axi_awqos      ( {4'd0,4'd0,4'd0,4'd0}          ),
    .s_axi_awvalid    ( {dcache_awvalid, icache_awvalid, uncached_data_awvalid, uncached_inst_awvalid}     ),
    .s_axi_awready    ( {dcache_awready, icache_awready, uncached_data_awready, uncached_inst_awready}     ),
    .s_axi_wid        ( {dcache_wid, icache_wid, uncached_data_wid, uncached_inst_wid}         ),
    .s_axi_wdata      ( {dcache_wdata, icache_wdata, uncached_data_wdata, uncached_inst_wdata}       ),
    .s_axi_wstrb      ( {dcache_wstrb, icache_wstrb, uncached_data_wstrb, uncached_inst_wstrb}       ),
    .s_axi_wlast      ( {dcache_wlast, icache_wlast, uncached_data_wlast, uncached_inst_wlast}       ),
    .s_axi_wvalid     ( {dcache_wvalid, icache_wvalid, uncached_data_wvalid, uncached_inst_wvalid}      ),
    .s_axi_wready     ( {dcache_wready, icache_wready, uncached_data_wready, uncached_inst_wready}      ),
    .s_axi_bid        ( {dcache_bid, icache_bid, uncached_data_bid, uncached_inst_bid}         ),
    .s_axi_bresp      ( {dcache_bresp, icache_bresp, uncached_data_bresp, uncached_inst_bresp}       ),
    .s_axi_bvalid     ( {dcache_bvalid, icache_bvalid, uncached_data_bvalid, uncached_inst_bvalid}      ),
    .s_axi_bready     ( {dcache_bready, icache_bready, uncached_data_bready, uncached_inst_bready}      ),

    .m_axi_arid       (arid      ),
    .m_axi_araddr     (araddr    ),
    .m_axi_arlen      (arlen     ),
    .m_axi_arsize     (arsize    ),
    .m_axi_arburst    (arburst   ),
    .m_axi_arlock     (arlock    ),
    .m_axi_arcache    (arcache   ),
    .m_axi_arprot     (arprot    ),
    .m_axi_arqos      (          ),
    .m_axi_arvalid    (arvalid   ),
    .m_axi_arready    (arready   ),
    .m_axi_rid        (rid       ),
    .m_axi_rdata      (rdata     ),
    .m_axi_rresp      (rresp     ),
    .m_axi_rlast      (rlast     ),
    .m_axi_rvalid     (rvalid    ),
    .m_axi_rready     (rready    ),
    .m_axi_awid       (awid      ),
    .m_axi_awaddr     (awaddr    ),
    .m_axi_awlen      (awlen     ),
    .m_axi_awsize     (awsize    ),
    .m_axi_awburst    (awburst   ),
    .m_axi_awlock     (awlock    ),
    .m_axi_awcache    (awcache   ),
    .m_axi_awprot     (awprot    ),
    .m_axi_awqos      (          ),
    .m_axi_awvalid    (awvalid   ),
    .m_axi_awready    (awready   ),
    .m_axi_wid        (wid       ),
    .m_axi_wdata      (wdata     ),
    .m_axi_wstrb      (wstrb     ),
    .m_axi_wlast      (wlast     ),
    .m_axi_wvalid     (wvalid    ),
    .m_axi_wready     (wready    ),
    .m_axi_bid        (bid       ),
    .m_axi_bresp      (bresp     ),
    .m_axi_bvalid     (bvalid    ),
    .m_axi_bready     (bready    )

);

wire dcache_req;
wire dcache_data_ok;
wire dcache_addr_ok;
wire [31:0] dcache_data;
Dcache my_Dcache(
    .clk             (clk                    ),
    .reset           (reset                  ),
    .data_req        (dcache_req             ),
    .data_op         (data_sram_wr           ),
    .data_wstrb      (data_sram_wstrb        ),
    .data_index      (data_sram_addr[11: 5]  ),
    .data_tag        (data_sram_addr[31:12]  ),
    .data_offset     (data_sram_addr[ 4: 0]  ),
    .data_wdata      (data_sram_wdata        ),
    .data_addr_ok    (dcache_addr_ok         ),
    .data_ok         (dcache_data_ok         ),
    .cpu_data_o      (dcache_data           ),

    .arid         (dcache_arid             ),
    .araddr       (dcache_araddr           ),
    .arlen        (dcache_arlen            ),
    .arsize       (dcache_arsize           ),
    .arburst      (dcache_arburst          ),
    .arlock       (dcache_arlock           ),
    .arcache      (dcache_arcache          ),
    .arprot       (dcache_arprot           ),
    .arvalid      (dcache_arvalid          ),
    .arready      (dcache_arready          ),
    //r              
    .rid          (dcache_rid              ),
    .rdata        (dcache_rdata            ),
    .rresp        (dcache_rresp            ),
    .rlast        (dcache_rlast            ),
    .rvalid       (dcache_rvalid           ),
    .rready       (dcache_rready           ),
    //aw               
    .awid         (dcache_awid             ),
    .awaddr       (dcache_awaddr           ),
    .awlen        (dcache_awlen            ),
    .awsize       (dcache_awsize           ),
    .awburst      (dcache_awburst          ),
    .awlock       (dcache_awlock           ),
    .awcache      (dcache_awcache          ),
    .awprot       (dcache_awprot           ),
    .awvalid      (dcache_awvalid          ),
    .awready      (dcache_awready          ),
    //w               
    .wid          (dcache_wid              ),
    .wdata        (dcache_wdata            ),
    .wstrb        (dcache_wstrb            ),
    .wlast        (dcache_wlast            ),
    .wvalid       (dcache_wvalid           ),
    .wready       (dcache_wready           ),
    //b              
    .bid          (dcache_bid              ),
    .bresp        (dcache_bresp            ),
    .bvalid       (dcache_bvalid           ),
    .bready       (dcache_bready           )
    );
data_cache_control data_cache_control(
    .clk          (aclk                     ),
    .reset        (reset                   ),
    //cpu
    .data_req     (data_sram_req            ),
    .data_size    (data_sram_size           ),
    .data_op      (data_sram_wr             ),
    .data_index   (data_sram_addr[11:5]     ),
    .data_tag     (data_sram_addr[31:12]    ),
    .data_offset  (data_sram_addr[4:0]      ),
    .data_wstrb   (data_sram_wstrb          ),
    .data_wdata   (data_sram_wdata          ),
    .data_addr_ok (data_sram_addr_ok        ),
    .data_data_ok (data_sram_data_ok        ),
    .data_rdata   (data_sram_rdata          ),
    .data_cache   (data_cache),
    //decache
    .dcache_req       (dcache_req               ),
    .dcache_addr_ok   (dcache_addr_ok           ),
    .dcache_data_ok   (dcache_data_ok           ),
    .dcache_rdata     (dcache_data             ),

    //data uncache
    .arid         (uncached_data_arid             ),
    .araddr       (uncached_data_araddr           ),
    .arlen        (uncached_data_arlen            ),
    .arsize       (uncached_data_arsize           ),
    .arburst      (uncached_data_arburst          ),
    .arlock       (uncached_data_arlock           ),
    .arcache      (uncached_data_arcache          ),
    .arprot       (uncached_data_arprot           ),
    .arvalid      (uncached_data_arvalid          ),
    .arready      (uncached_data_arready          ),
    //r              
    .rid          (uncached_data_rid              ),
    .rdata        (uncached_data_rdata            ),
    .rresp        (uncached_data_rresp            ),
    .rlast        (uncached_data_rlast            ),
    .rvalid       (uncached_data_rvalid           ),
    .rready       (uncached_data_rready           ),
    //aw               
    .awid         (uncached_data_awid             ),
    .awaddr       (uncached_data_awaddr           ),
    .awlen        (uncached_data_awlen            ),
    .awsize       (uncached_data_awsize           ),
    .awburst      (uncached_data_awburst          ),
    .awlock       (uncached_data_awlock           ),
    .awcache      (uncached_data_awcache          ),
    .awprot       (uncached_data_awprot           ),
    .awvalid      (uncached_data_awvalid          ),
    .awready      (uncached_data_awready          ),
    //w               
    .wid          (uncached_data_wid              ),
    .wdata        (uncached_data_wdata            ),
    .wstrb        (uncached_data_wstrb            ),
    .wlast        (uncached_data_wlast            ),
    .wvalid       (uncached_data_wvalid           ),
    .wready       (uncached_data_wready           ),
        //b              
    .bid          (uncached_data_bid              ),
    .bresp        (uncached_data_bresp            ),
    .bvalid       (uncached_data_bvalid           ),
    .bready       (uncached_data_bready           )
    );
wire icache_req;
wire icache_addr_ok;
wire icache_data_ok;
wire [31:0] icache_data;
inst_cache_control inst_cache_control(
    .clk          (aclk                     ),
    .reset        (reset                   ),
    //cpu
    .inst_req     (inst_sram_req            ),
    .inst_size    (inst_sram_size           ),
    .inst_op      (inst_sram_wr             ),
    .inst_index   (inst_sram_addr[11:5]     ),
    .inst_tag     (inst_sram_addr[31:12]    ),
    .inst_offset  (inst_sram_addr[4:0]      ),
    .inst_wstrb   (inst_sram_wstrb          ),
    .inst_wdata   (inst_sram_wdata          ),
    .inst_addr_ok (inst_sram_addr_ok        ),
    .inst_data_ok (inst_sram_data_ok        ),
    .inst_rdata   (inst_sram_rdata          ),
    .inst_cache   (inst_cache),
    //decache
    .icache_req       (icache_req               ),
    .icache_addr_ok   (icache_addr_ok           ),
    .icache_data_ok   (icache_data_ok           ),
    .icache_rdata     (icache_data             ),

    //data uncache
    .arid         (uncached_inst_arid             ),
    .araddr       (uncached_inst_araddr           ),
    .arlen        (uncached_inst_arlen            ),
    .arsize       (uncached_inst_arsize           ),
    .arburst      (uncached_inst_arburst          ),
    .arlock       (uncached_inst_arlock           ),
    .arcache      (uncached_inst_arcache          ),
    .arprot       (uncached_inst_arprot           ),
    .arvalid      (uncached_inst_arvalid          ),
    .arready      (uncached_inst_arready          ),
    //r              
    .rid          (uncached_inst_rid              ),
    .rdata        (uncached_inst_rdata            ),
    .rresp        (uncached_inst_rresp            ),
    .rlast        (uncached_inst_rlast            ),
    .rvalid       (uncached_inst_rvalid           ),
    .rready       (uncached_inst_rready           ),
    //aw               
    .awid         (uncached_inst_awid             ),
    .awaddr       (uncached_inst_awaddr           ),
    .awlen        (uncached_inst_awlen            ),
    .awsize       (uncached_inst_awsize           ),
    .awburst      (uncached_inst_awburst          ),
    .awlock       (uncached_inst_awlock           ),
    .awcache      (uncached_inst_awcache          ),
    .awprot       (uncached_inst_awprot           ),
    .awvalid      (uncached_inst_awvalid          ),
    .awready      (uncached_inst_awready          ),
    //w               
    .wid          (uncached_inst_wid              ),
    .wdata        (uncached_inst_wdata            ),
    .wstrb        (uncached_inst_wstrb            ),
    .wlast        (uncached_inst_wlast            ),
    .wvalid       (uncached_inst_wvalid           ),
    .wready       (uncached_inst_wready           ),
        //b              
    .bid          (uncached_inst_bid              ),
    .bresp        (uncached_inst_bresp            ),
    .bvalid       (uncached_inst_bvalid           ),
    .bready       (uncached_inst_bready           )
    );
endmodule
