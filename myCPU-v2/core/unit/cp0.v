module cp0(
    input clk,
    input rst,
    
    // Exception
    input wb_ex,
    input wb_ex_tlb,
    input wb_bd,
    input eret_flush,
    input [4:0] wb_exccode,
    input [31:0] wb_pc,
    input [31:0] wb_badvaddr,

    // Write port
    input [4:0] dst,
    input sel,
    input mtc0_we,
    input [31:0] data,
    
    // External interrupt
    input [5:0] ext_int_in,

    // TLB related
    input tlbp,
    input tlbp_found,
    input [3:0] index,
    input tlbr,
    
    input [18:0] r_vpn2,     
    input [ 7:0] r_asid,     
    input r_g,     
    input [19:0] r_pfn0,     
    input [ 2:0] r_c0,     
    input r_d0,     
    input r_v0,     
    input [19:0] r_pfn1,     
    input [ 2:0] r_c1,     
    input r_d1,     
    input r_v1,  

    // Read port
	output has_int,      //Luoshan?
    output [31:0] rdata,
    output reg [31:0] cp0_epc,
    output [31:0] cp0_entryhi,
    output [31:0] cp0_entrylo0,
    output [31:0] cp0_entrylo1,
    output [31:0] cp0_index
    
);

localparam REG_STATUS   = 12;
localparam REG_CAUSE    = 13;
localparam REG_EPC      = 14;
localparam REG_COUNT    = 9;
localparam REG_COMPARE  = 11;
localparam REG_BADVADDR = 8;
localparam REG_ENTRYHI  = 10;
localparam REG_ENTRYLO0 = 2;
localparam REG_ENTRYLO1 = 3;
localparam REG_INDEX    = 0;


wire cp0_count_eq;
// STATUS
wire [31:0] cp0_status;
reg [7:0] cp0_status_im;
reg cp0_status_exl;
reg cp0_status_ie;

// CAUSE
wire [31:0] cp0_cause;
reg cp0_cause_bd;
reg cp0_cause_ti;
reg [7:0] cp0_cause_ip;
reg [4:0] cp0_cause_exccode;

reg [31:0] cp0_count;
reg [31:0] cp0_compare;
reg [31:0] cp0_badvaddr;

// entryhi
reg [18:0] cp0_entryhi_vpn2;
reg [ 7:0] cp0_entryhi_asid;

// entrylo
reg [19:0] cp0_entrylo0_pfn0;
reg [ 2:0] cp0_entrylo0_c0;
reg        cp0_entrylo0_d0;
reg        cp0_entrylo0_v0;
reg        cp0_entrylo0_g0;

reg [19:0] cp0_entrylo1_pfn1;
reg [ 2:0] cp0_entrylo1_c1;
reg        cp0_entrylo1_d1;
reg        cp0_entrylo1_v1;
reg        cp0_entrylo1_g1;

// index
reg        cp0_index_p;
reg [ 3:0] cp0_index_index; 

// STATUS
assign cp0_status = { 9'b0, //31:23
                      1'b1, //22:22
                      6'b0, //21:16
                      cp0_status_im, //15:8
                      6'b0, //7:2
                      cp0_status_exl, //1:1 
                      cp0_status_ie //0:0
                     };

always @(posedge clk) begin
    if (mtc0_we && dst == REG_STATUS)
        cp0_status_im <= data[15:8];
end

always @(posedge clk) begin
    if (rst)
        cp0_status_exl <= 1'b0;
    else if (wb_ex)
        cp0_status_exl <= 1'b1;
    else if (eret_flush)
        cp0_status_exl <= 1'b0;
    else if (mtc0_we && dst == REG_STATUS)
        cp0_status_exl <= data[1];
end

always @(posedge clk) begin
    if (rst)
        cp0_status_ie <= 1'b0;
    else if (mtc0_we && dst == REG_STATUS)
        cp0_status_ie <= data[0];
end

// CAUSE
assign cp0_cause = { cp0_cause_bd, //31:31
                     cp0_cause_ti, //30:30
                     14'b0, //29:16
                     cp0_cause_ip, //15:8
                     1'b0, //7:7
                     cp0_cause_exccode, //6:2
                     2'b0 //1:0
                    };

always @(posedge clk) begin
    if (rst)
        cp0_cause_bd <= 1'b0;
    else if (wb_ex && !cp0_status_exl)
        cp0_cause_bd <= wb_bd;
end

always @(posedge clk) begin
    if (rst)
        cp0_cause_ti <= 1'b0;
    else if (mtc0_we && dst == REG_COMPARE)
        cp0_cause_ti <= 1'b0;
    else if (cp0_count_eq)
        cp0_cause_ti <= 1'b1;
end

always @(posedge clk) begin
    if (rst)
        cp0_cause_ip[7:2] <= 6'b0;
    else begin
        cp0_cause_ip[7]   <= ext_int_in[5] | cp0_cause_ti;
        cp0_cause_ip[6:2] <= ext_int_in[4:0];
    end
end

always @(posedge clk) begin
    if (rst)
        cp0_cause_ip[1:0] <= 2'b0;
    else if (mtc0_we && dst == REG_CAUSE)
        cp0_cause_ip[1:0] <= data[9:8];
end 

always @(posedge clk) begin
    if (rst)
        cp0_cause_exccode <= 5'b0;
    else if (wb_ex)
        cp0_cause_exccode <= wb_exccode;
end
// EPC
always @(posedge clk) begin
    if (wb_ex && !cp0_status_exl)
        cp0_epc <= wb_bd ? wb_pc - 3'h4 : wb_pc;
    else if (mtc0_we && dst == REG_EPC)
        cp0_epc <= data;
end

// Badvaddr
always @(posedge clk) begin
    if (wb_ex && (wb_exccode == `EX_ADEL || wb_exccode == `EX_ADES))
        cp0_badvaddr <= wb_badvaddr;
end
// Count
reg tick;
always @(posedge clk) begin
    if (rst)
        tick <= 0;
    else
        tick <= ~tick;
    if (mtc0_we && dst == REG_COUNT)
        cp0_count <= data;
    else if (tick)
        cp0_count <= cp0_count + 1'b1;
end
// Compare
always @(posedge clk) begin
    if(mtc0_we && dst == REG_COMPARE)
        cp0_compare <= data;
end
assign cp0_count_eq = cp0_count == cp0_compare;

// EntryHi
assign cp0_entryhi = { cp0_entryhi_vpn2,
                       5'b0,
                       cp0_entryhi_asid};

// vpn2
always @(posedge clk) begin
    if (rst)
        cp0_entryhi_vpn2 <= 19'b0;
    else if (wb_ex_tlb)
        cp0_entryhi_vpn2 <= wb_badvaddr[31:13];
    else if (mtc0_we && dst == REG_ENTRYHI)
        cp0_entryhi_vpn2 <= data[31:13];
    else if (tlbr)
        cp0_entryhi_vpn2 <= r_vpn2;
end

// vpn1
always @(posedge clk) begin
    if (rst)
        cp0_entryhi_asid <= 8'b0;
    else if (mtc0_we && dst == REG_ENTRYHI)
        cp0_entryhi_asid <= data[7:0];
    else if (tlbr)
        cp0_entryhi_asid <= r_asid;
end


// EntryLo
assign cp0_entrylo0 = { 6'b0,
                        cp0_entrylo0_pfn0,
                        cp0_entrylo0_c0,
                        cp0_entrylo0_d0,
                        cp0_entrylo0_v0,
                        cp0_entrylo0_g0};

always @(posedge clk) begin
    if (rst)
        cp0_entrylo0_pfn0 <= 20'b0;
    else if (mtc0_we && dst == REG_ENTRYLO0)
        cp0_entrylo0_pfn0 <= data[25:6];
    else if (tlbr)
        cp0_entrylo0_pfn0 <= r_pfn0;
end

always @(posedge clk) begin
    if (rst)
        cp0_entrylo0_c0 <= 3'b0;
    else if (mtc0_we && dst == REG_ENTRYLO0)
        cp0_entrylo0_c0 <= data[5:3];
    else if (tlbr)
        cp0_entrylo0_c0 <= r_c0;
end

always @(posedge clk) begin
    if (rst)
        cp0_entrylo0_d0 <= 1'b0;
    else if (mtc0_we && dst == REG_ENTRYLO0)
        cp0_entrylo0_d0 <= data[2];
    else if (tlbr)
        cp0_entrylo0_d0 <= r_d0;
end

always @(posedge clk) begin
    if (rst)
        cp0_entrylo0_v0 <= 1'b0;
    else if (mtc0_we && dst == REG_ENTRYLO0)
        cp0_entrylo0_v0 <= data[1];
    else if (tlbr)
        cp0_entrylo0_v0 <= r_v0;
end

always @(posedge clk) begin
    if (rst)
        cp0_entrylo0_g0 <= 1'b0;
    else if (mtc0_we && dst == REG_ENTRYLO0)
        cp0_entrylo0_g0 <= data[0];
    else if (tlbr)
        cp0_entrylo0_g0 <= r_g;
end

assign cp0_entrylo1 = { 6'b0,
                        cp0_entrylo1_pfn1,
                        cp0_entrylo1_c1,
                        cp0_entrylo1_d1,
                        cp0_entrylo1_v1,
                        cp0_entrylo1_g1};

always @(posedge clk) begin
    if (rst)
        cp0_entrylo1_pfn1 <= 20'b0;
    else if (mtc0_we && dst == REG_ENTRYLO1)
        cp0_entrylo1_pfn1 <= data[25:6];
    else if (tlbr)
        cp0_entrylo1_pfn1 <= r_pfn1;
end

always @(posedge clk) begin
    if (rst)
        cp0_entrylo1_c1 <= 3'b0;
    else if (mtc0_we && dst == REG_ENTRYLO1)
        cp0_entrylo1_c1 <= data[5:3];
    else if (tlbr)
        cp0_entrylo1_c1 <= r_c1;
end

always @(posedge clk) begin
    if (rst)
        cp0_entrylo1_d1 <= 1'b0;
    else if (mtc0_we && dst == REG_ENTRYLO1)
        cp0_entrylo1_d1 <= data[2];
    else if (tlbr)
        cp0_entrylo1_d1 <= r_d1;
end

always @(posedge clk) begin
    if (rst)
        cp0_entrylo1_v1 <= 1'b0;
    else if (mtc0_we && dst == REG_ENTRYLO1)
        cp0_entrylo1_v1 <= data[1];
    else if (tlbr)
        cp0_entrylo1_v1 <= r_v1;
end

always @(posedge clk) begin
    if (rst)
        cp0_entrylo1_g1 <= 1'b0;
    else if (mtc0_we && dst == REG_ENTRYLO1)
        cp0_entrylo1_g1 <= data[0];
    else if (tlbr)
        cp0_entrylo1_g1 <= r_g;
end

// Index
assign cp0_index = { cp0_index_p,
                     27'b0,
                     cp0_index_index};

always @(posedge clk) begin
    if (rst)
        cp0_index_p <= 1'b0;
    else if (tlbp && !tlbp_found)
        cp0_index_p <= 1'b1;
    else if (tlbp &&  tlbp_found)
        cp0_index_p <= 1'b0;
end

always @(posedge clk) begin
    if (rst)
        cp0_index_index <= 4'b0;
    else if (mtc0_we && dst == REG_INDEX)
        cp0_index_index <= data[3:0];
    else if (tlbp &&  tlbp_found)
        cp0_index_index <= index;
end

assign rdata = (dst == REG_EPC     ) ? cp0_epc      :
               (dst == REG_STATUS  ) ? cp0_status   :
               (dst == REG_CAUSE   ) ? cp0_cause    :
               (dst == REG_COUNT   ) ? cp0_count    :
               (dst == REG_BADVADDR) ? cp0_badvaddr :
               (dst == REG_ENTRYHI ) ? cp0_entryhi  :
               (dst == REG_INDEX   ) ? cp0_index    :
               (dst == REG_ENTRYLO0) ? cp0_entrylo0 :
               (dst == REG_ENTRYLO1) ? cp0_entrylo1 :
               (dst == REG_COMPARE ) ? cp0_compare  : 32'h0;
			   
assign has_int = ((cp0_cause_ip[7:0] & cp0_status_im[7:0]) != 8'h00) && cp0_status_ie && !cp0_status_exl;
endmodule
