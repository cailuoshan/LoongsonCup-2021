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
    output [31:0] debug_wb_pc_1,
    output [ 3:0] debug_wb_rf_wen_1,
    output [ 4:0] debug_wb_rf_wnum_1,
    output [31:0] debug_wb_rf_wdata_1,
    output [31:0] debug_wb_pc_2,
    output [ 3:0] debug_wb_rf_wen_2,
    output [ 4:0] debug_wb_rf_wnum_2,
    output [31:0] debug_wb_rf_wdata_2
);

reg         reset;
wire        clk = aclk;
always @(posedge clk) reset <= ~aresetn;

// Signal
wire        fs_allowin;
wire        es1_allowin;
wire        es2_allowin;
wire        ms1_allowin;


wire        prefs_to_fs_valid;
wire        ds_to_es1_valid;
wire        ds_to_es2_valid;
wire        es1_to_ms1_valid;

wire [`TO_FS_BUS_WD -1:0] prefs_to_fs_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es1_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es2_bus;
wire        es1_to_ms1_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;

wire [42:0] es1_reg;
wire [41:0] ms1_reg;
wire [40:0] ws1_reg;
wire [42:0] es2_reg;
wire [41:0] ms2_reg;
wire [40:0] ws2_reg;
wire        ms1_loading;
wire        ms2_loading;

//Icache
wire        icache_req;
wire        icache_wr;
wire [ 1:0] icache_size;
wire [ 3:0] icache_wstrb;
wire [31:0] icache_addr;
wire [31:0] icache_wdata;
wire        icache_addr_ok;
wire        icache_data_ok;
wire [31:0] icache_rdata;

// Branch Predictor
wire [31:0] current_pc;  //predict
wire [31:0] predict_pc;
wire [31:0] bp_pc ;      //update
wire        is_br ;
wire        br_taken ;
wire [31:0] br_target;
// InstBuffer
wire        ib_flush;
wire        ib_fetch_req;
wire [INST_BUF_LINE_WD-1:0] ib_rline1;
wire [INST_BUF_LINE_WD-1:0] ib_rline2;
wire        ib_write_req;
wire [31:0] ib_pc;
wire [31:0] ib_inst;
wire [2:0]  ib_exc;
wire        ib_empty;
wire        ib_full;
//   


wire        dcache_req;
wire        dcache_wr;
wire [ 1:0] dcache_size;
wire [ 3:0] dcache_wstrb;
wire [31:0] dcache_addr;
wire [31:0] dcache_wdata;
wire        dcache_addr_ok;
wire        dcache_data_ok;
wire [31:0] dcache_rdata;

wire [18:0] s0_vpn2;
wire        s0_odd_page;
wire        s0_found;     
wire [ 3:0] s0_index;     
wire [19:0] s0_pfn;     
wire [ 2:0] s0_c;     
wire        s0_d;     
wire        s0_v;




// preIF stage
preif_stage preif_stage(
    .clk             (clk            ),
    .reset           (reset          ),
    
    .fs_allowin      (fs_allowin     ),
    .prefs_to_fs_valid (prefs_to_fs_valid),
    .prefs_to_fs_bus (prefs_to_fs_bus),

    .current_pc      (current_pc     ),
    .predict_pc      (predict_pc     ),

    .icache_req      (icache_req     ),
    .icache_size     (icache_size    ),
    .icache_addr     (icache_addr    ),
    .icache_addr_ok  (icache_addr_ok ),
    
    .s0_vpn2         (s0_vpn2        ),
    .s0_odd_page     (s0_odd_page    ),
    .s0_found        (s0_found       ),
    .s0_index        (s0_index       ),
    .s0_pfn          (s0_pfn         ),
    .s0_c            (s0_c           ),
    .s0_d            (s0_d           ),
    .s0_v            (s0_v           )
    //TLB refetch tag

    // Exception related

);

// IF stage
if_stage if_stage(
    .clk             (clk            ),
    .reset           (reset          ),

    .prefs_to_fs_valid (prefs_to_fs_valid),
    .prefs_to_fs_bus (prefs_to_fs_bus),
    .fs_allowin      (fs_allowin     ),

    .bp_pc           (bp_pc          ),
    .is_br           (is_br          ),
    .br_taken        (br_taken       ),
    .br_target       (br_target      ),
    
    .icache_data_ok  (icache_data_ok ),
    .icache_rdata    (icache_rdata   ),

    .ib_full         (ib_full        ),
    .ib_write_req    (ib_write_req   ),
    .ib_pc           (ib_pc          ),
    .ib_inst         (ib_inst        ),
    .ib_exc          (ib_exc         )
    //TLB refetch tag

    // Exception related

);

// IDIS stage
idis_stage idis_stage(
    .clk             (clk            ),
    .reset           (reset          ),
    
    .es1_allowin     (es1_allowin    ),
    .es2_allowin     (es2_allowin    ),
    .ds_to_es1_valid (ds_to_es1_valid),
    .ds_to_es2_valid (ds_to_es2_valid),
    .ds_to_es1_bus   (ds_to_es1_bus  ),
    .ds_to_es2_bus   (ds_to_es2_bus  ),

    .es1_reg         (es1_reg        ),
    .ms1_reg         (ms1_reg        ),
    .ws1_reg         (ws1_reg        ),
    .es2_reg         (es2_reg        ),
    .ms2_reg         (ms2_reg        ),
    .ws2_reg         (ws2_reg        ),
    .ms1_loading     (ms1_loading    ),
    .ms2_loading     (ms2_loading    ),

    .ib_empty        (ib_empty       ),
    .ib_fetch_req    (ib_fetch_req   ),
    .ib_rline1       (ib_rline1      ),
    .ib_rline2       (ib_rline2      ),

    .ws_to_rf_bus    (ws_to_rf_bus   )
    // Exception related

);

// EXE stage
exe1_stage exe1_stage(
    .clk             (clk            ),
    .reset           (reset          ),
    
    .ms1_allowin     (ms1_allowin    ),
    .es1_to_ms1_valid (es1_to_ms1_valid),
    .es1_to_ms1_bus  (es1_to_ms1_bus ),

);
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
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

endmodule