`ifndef MYCPU_H
    `define MYCPU_H
    
    `define BR_BUS_WD       33
    `define PS_TO_FS_BUS_WD 50
    `define FS_TO_DS_BUS_WD 105
    `define DS_TO_ES_BUS_WD 214  
    `define ES_TO_RS_BUS_WD 530
    `define RS_TO_MS_BUS_WD 141
    `define MS_TO_WS_BUS_WD 133 
    `define WS_TO_RF_BUS_WD 41 
    
    `define EX_INT  0
	`define EX_MOD  1
	`define EX_TLBL 2
	`define EX_TLBS 3
    `define EX_ADEL 4    
    `define EX_ADES 5  
    `define EX_SYS  8  
    `define EX_BP   9   
    `define EX_RI   10
    `define EX_OV   12  

	`define TLBNUM  16
	`define ICACHELINE 3'h2
	`define ICACHECONN 3'h1
	`define DCACHELINE 3'h2
	`define DCACHECONN 3'h1
	
	    `define USE_DCACHE 1
	
`endif
