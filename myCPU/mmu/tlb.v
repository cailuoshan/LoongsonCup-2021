module tlb
#(parameter TLBNUM = 16)
(
    input                         clk,
    input                         reset,
    // Search Port 0
    input  [                18:0] s0_vpn2,
    input                         s0_odd_page,
    input  [                 7:0] s0_asid,
    output                        s0_found,
    output [$clog2(TLBNUM) - 1:0] s0_index,
    output [                19:0] s0_pfn,
    output [                 2:0] s0_c,
    output                        s0_d,
    output                        s0_v,

    // Search Port 1
    input  [                18:0] s1_vpn2,
    input                         s1_odd_page,
    input  [                 7:0] s1_asid,
    output                        s1_found,
    output [$clog2(TLBNUM) - 1:0] s1_index,
    output [                19:0] s1_pfn,
    output [                 2:0] s1_c,
    output                        s1_d,
    output                        s1_v,

    // Write Port
    input                         we,
    input  [$clog2(TLBNUM) - 1:0] w_index,
    input  [                18:0] w_vpn2,
    input  [                 7:0] w_asid,
    input                         w_g,
    input  [                19:0] w_pfn0,
    input  [                 2:0] w_c0,
    input                         w_d0,
    input                         w_v0,
    input  [                19:0] w_pfn1,
    input  [                 2:0] w_c1,
    input                         w_d1,
    input                         w_v1,

    // Read Port
    input  [$clog2(TLBNUM) - 1:0] r_index,
    output [                18:0] r_vpn2,
    output [                 7:0] r_asid,
    output                        r_g,
    output [                19:0] r_pfn0,
    output [                 2:0] r_c0,
    output                        r_d0,
    output                        r_v0,
    output [                19:0] r_pfn1,
    output [                 2:0] r_c1,
    output                        r_d1,
    output                        r_v1
);

// PTEs
(* max_fanout = "10" *)reg [   18:0] tlb_vpn2     [TLBNUM - 1:0];
(* max_fanout = "10" *)reg [    7:0] tlb_asid     [TLBNUM - 1:0];
(* max_fanout = "10" *)reg           tlb_g        [TLBNUM - 1:0];
(* max_fanout = "10" *)reg [   19:0] tlb_pfn0     [TLBNUM - 1:0];
(* max_fanout = "10" *)reg [    2:0] tlb_c0       [TLBNUM - 1:0];
(* max_fanout = "10" *)reg           tlb_d0       [TLBNUM - 1:0];
(* max_fanout = "10" *)reg           tlb_v0       [TLBNUM - 1:0];
(* max_fanout = "10" *)reg [   19:0] tlb_pfn1     [TLBNUM - 1:0];
(* max_fanout = "10" *)reg [    2:0] tlb_c1       [TLBNUM - 1:0];
(* max_fanout = "10" *)reg           tlb_d1       [TLBNUM - 1:0];
(* max_fanout = "10" *)reg           tlb_v1       [TLBNUM - 1:0];

wire [TLBNUM - 1:0] s0_match;
wire [TLBNUM - 1:0] s1_match;

/* 
 * Search result Output
 */

// Match
genvar i;
generate for (i = 0; i < TLBNUM; i = i + 1) begin : gen_for_s0_match
    assign s0_match[i] = (s0_vpn2 == tlb_vpn2[i]) && (s0_asid == tlb_asid[i] || tlb_g[i]);
end endgenerate

genvar j;
generate for (j = 0; j < TLBNUM; j = j + 1) begin : gen_for_s1_match
    assign s1_match[j] = (s1_vpn2 == tlb_vpn2[j]) && (s1_asid == tlb_asid[j] || tlb_g[j]);
end endgenerate

// Found
assign s0_found = |s0_match;
assign s1_found = |s1_match;

// Index
encoder_16_4 u_s0(
    .in  (s0_match),
    .out (s0_index)
);

encoder_16_4 u_s1(
    .in  (s1_match),
    .out (s1_index)
);

// PTE related
assign s0_pfn = ~s0_odd_page ? tlb_pfn0[s0_index] : tlb_pfn1[s0_index];
assign s0_c   = ~s0_odd_page ? tlb_c0  [s0_index] : tlb_c1  [s0_index];
assign s0_d   = ~s0_odd_page ? tlb_d0  [s0_index] : tlb_d1  [s0_index];
assign s0_v   = ~s0_odd_page ? tlb_v0  [s0_index] : tlb_v1  [s0_index];

assign s1_pfn = ~s1_odd_page ? tlb_pfn0[s1_index] : tlb_pfn1[s1_index];
assign s1_c   = ~s1_odd_page ? tlb_c0  [s1_index] : tlb_c1  [s1_index];
assign s1_d   = ~s1_odd_page ? tlb_d0  [s1_index] : tlb_d1  [s1_index];
assign s1_v   = ~s1_odd_page ? tlb_v0  [s1_index] : tlb_v1  [s1_index];

/* 
 * Read Channel
 */
assign r_vpn2 = tlb_vpn2[r_index];
assign r_asid = tlb_asid[r_index];
assign r_g    = tlb_g   [r_index];
assign r_pfn0 = tlb_pfn0[r_index];
assign r_c0   = tlb_c0  [r_index];
assign r_d0   = tlb_d0  [r_index];
assign r_v0   = tlb_v0  [r_index];
assign r_pfn1 = tlb_pfn1[r_index];
assign r_c1   = tlb_c1  [r_index];
assign r_d1   = tlb_d1  [r_index];
assign r_v1   = tlb_v1  [r_index];    

/* 
 * Write Channel
 */
genvar tlb_i;
generate for (tlb_i = 0; tlb_i < TLBNUM; tlb_i = tlb_i + 1) begin:gen_tlb
    always @(posedge clk) begin
        if (reset) begin
            tlb_vpn2[tlb_i] <= 0;
            tlb_asid[tlb_i] <= 0;    
            tlb_g   [tlb_i] <= 0;
            tlb_pfn0[tlb_i] <= 0;
            tlb_c0  [tlb_i] <= 0;
            tlb_d0  [tlb_i] <= 0;
            tlb_v0  [tlb_i] <= 0;
            tlb_pfn1[tlb_i] <= 0;
            tlb_c1  [tlb_i] <= 0;
            tlb_d1  [tlb_i] <= 0;
            tlb_v1  [tlb_i] <= 0;
        end else if (we && w_index == tlb_i) begin
            tlb_vpn2[tlb_i] <= w_vpn2;
            tlb_asid[tlb_i] <= w_asid;    
            tlb_g   [tlb_i] <= w_g;
            tlb_pfn0[tlb_i] <= w_pfn0;
            tlb_c0  [tlb_i] <= w_c0;
            tlb_d0  [tlb_i] <= w_d0;
            tlb_v0  [tlb_i] <= w_v0;
            tlb_pfn1[tlb_i] <= w_pfn1;
            tlb_c1  [tlb_i] <= w_c1;
            tlb_d1  [tlb_i] <= w_d1;
            tlb_v1  [tlb_i] <= w_v1;
        end
    end
end endgenerate
endmodule

module encoder_16_4(
    input  [15:0] in,
    output [ 3:0] out 
);

assign out = ({4{in[ 0]}} & 4'd0 )
           | ({4{in[ 1]}} & 4'd1 )
           | ({4{in[ 2]}} & 4'd2 )
           | ({4{in[ 3]}} & 4'd3 )
           | ({4{in[ 4]}} & 4'd4 )
           | ({4{in[ 5]}} & 4'd5 )
           | ({4{in[ 6]}} & 4'd6 )
           | ({4{in[ 7]}} & 4'd7 )
           | ({4{in[ 8]}} & 4'd8 )
           | ({4{in[ 9]}} & 4'd9 )
           | ({4{in[10]}} & 4'd10)
           | ({4{in[11]}} & 4'd11)
           | ({4{in[12]}} & 4'd12)
           | ({4{in[13]}} & 4'd13)
           | ({4{in[14]}} & 4'd14)
           | ({4{in[15]}} & 4'd15);
endmodule
