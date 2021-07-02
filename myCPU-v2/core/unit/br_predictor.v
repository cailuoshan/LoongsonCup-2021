module branch_predictor(
    input         clk,
    input         reset,
    // IF-Predict PORT
    input  [127:0] current_pcs;
    output [127:0] next_pcs;
    
    // ID-Update PORT
    input  []      Real_br_info1; //ID级译码得到真实分支信息:分支类型2bit + 是否跳转1bit + 目标地址32bit
    input  []      Real_br_info2; 
    
    // 预测错误信号？
    
);