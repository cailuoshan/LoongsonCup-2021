`ifndef MYCPU_H
    `define MYCPU_H
    
    `define TO_FS_BUS_WD     35    //32'pc+3'exc
    `define INST_BUF_LINE_WD 67    //32'pc+32'inst+3'exc
    `define INST_BUF_SIZE    8

    `define BR_BUS_WD       35   
    `define DS_TO_ES_BUS_WD 212  
    `define ES_TO_MS_BUS_WD 140
    `define MS_TO_WS_BUS_WD 133 
    `define WS_TO_RF_BUS_WD 82     //(4'we+5'waddr+32'wdata)*2
    
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
	
`endif