module branch_predictor(
	input         clk,
	input         reset,
	input  [31:0] inst,
	input  [31:0] pc,
	input  [15:0] b_offset,
	input  [25:0] j_offset,
	input         jr_we,
	input  [31:0] jr_realtarget,

	output        taken,
	output [31:0] pc_predict
);

wire [31:0] target_n;
wire [31:0] target_b;
wire [31:0] target_jt;
wire [15:0] imm;
wire [15:0] jidx;

assign imm  = inst[15: 0];
assign jidx = inst[25: 0];

wire [63:0] op_d;
wire [63:0] func_d;
wire [31:0] rt_d;
reg  [31:0] jr_target;

always @(posedge clk) begin
	if (reset)
		jr_target <= 32'b0;
	else if (jr_we)
		jr_target <= jr_realtarget;
end 

// FAST DECODE
decoder_6_64 f_decoder_6_64(
	.in  (inst[31:26]),
	.out (op_d       )
);

decoder_6_64 d_decoder_6_64(
	.in  (inst[ 5: 0]),
	.out (func_d     )
);

decoder_5_32 d_decoder_5_32(
	.in  (inst[20:16]),
	.out (rt_d       )
);

assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_j      = op_d[6'h02];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];

assign inst_b      = inst_beq | inst_bne | inst_bgez   | inst_bltz  | inst_blez | inst_bgtz;
assign inst_jt     = inst_j   | inst_jal | inst_bgezal | inst_bltzal;

assign taken       = 1;//(inst_beq && !inst[25:21] && !inst[20:16) | inst_jal | inst_jr | inst_j | inst_jalr;
assign target_n    = pc + 4'h4;
assign target_b    =  target_n + {{14{imm[15]}}, imm[15:0], 2'b0};
assign target_jt   = {target_n[31:28], jidx[25:0], 2'b0};
assign pc_predict  = ({32{inst_b }} & target_b) | 
					 ({32{inst_jt}} & target_j) |
					 ({32{inst_jr | inst_jalr}} & jr_target);

endmodule
