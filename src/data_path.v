`timescale 1ns / 1ps
/*******************************************************************
*
* Module: register.v
* Project: RISC-V FPGA Implementation and Testing 
* Author: 
* Ahmed Ibrahim  ahmeddibrahim@aucegypt.edu
* Abd El-Salam   solomspd@aucegypt.edu
* Andrew Kamal   andrewk.kamal@aucegypt.edu
* Rinal Mohamed  rinalmohamed@aucegypt.edu
* Description: This module is the core of our implememntaion is it the "top" module that conects everything together
*
* Change history: 09/17/2019 03:07:59 PM - Module created by Abd *El-Salam in the lab
* 17/9/19 - created by Abdelsalam in the lab
* 31/9/19 - adapted datapath to ALU and immediate modules provided by project material. Elaborated and implemented shift module as outlined in provided ALU
* 32/9/19 - fixed zero flag. anded and fixe brnch module
* 26/10/19 - modified control signals according to new control signals.
* 28/10/19 - polish. added jump muxes. lots of bug fixes.
* 29/10/19 - added muxes for break and call. bug fixes.
*
**********************************************************************/
`include "defines.v"
module data_path(input clk, input rst, output [31:0]inst_out_ext, output branch_ext, mem_read_ext, mem_to_reg_ext, mem_write_ext, alu_src_ext, reg_write_ext,
 output [1:0]alu_op_ext, output z_flag_ext, output [31:0]alu_ctrl_out_ext, output [31:0]PC_inc_ext, output [31:0]pc_gen_out_ext, output [31:0]PC_ext, output [31:0]PC_in_ext,
 output [31:0]data_read_1_ext, output [31:0]data_read_2_ext, output [31:0]write_data_ext, output [31:0]imm_out_ext, output [31:0]shift_ext, output [31:0]alu_mux_ext
 ,output [31:0]alu_out_ext, output [31:0]data_mem_out_ext);
 
    wire neg_clk = ~clk;

    wire [31:0] jump_mux; 
    wire [31:0]PC;
    wire [31:0]new_PC_in;
    wire [31:0] final_pc;
    wire [31:0]PC_in;
    wire [31:0]inst_out;
    wire can_branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write, pc_gen_sel, sys;
    wire [1:0]alu_op;
    wire [1:0]rd_sel;
    wire [31:0]write_data;
    wire [31:0]read_data_1;
    wire [31:0]imm_out;
    wire [31:0]read_data_2;
    wire carry_flag, zero_flag, over_flag, sign_flag;
    wire [31:0]alu_mux_out;
    wire [3:0] alu_ctrl_out;
    wire [31:0]alu_out;
    wire should_branch;
    wire [31:0]data_mem_out;
    wire [31:0]shift_out;
    wire [31:0]pc_gen_out;
    wire dummy_carry;
    wire [31:0]pc_gen_in;
    wire [31:0]pc_inc_out;
    wire dummy_carry_2;
    
    
    
// wires declarations for the pipelined implementation 
    wire [31:0] IF_ID_PC, IF_ID_Inst;
// IF-ID register initialization
    register #(64) IF_ID (clk,
    {PC,
    inst_out},
    rst,
    1'b1,
    {IF_ID_PC,
    IF_ID_Inst} );
    // wires declarations for the pipelined implementation 
    wire [31:0] ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm;
    wire [11:0] ID_EX_Ctrl;
    wire [3:0] ID_EX_Func;
    wire [4:0] ID_EX_Rs1, ID_EX_Rs2, ID_EX_Rd;
    
    register #(159) ID_EX (neg_clk,
    {reg_write,
    mem_to_reg,
    can_branch,
    mem_read,
    mem_write,
    alu_op,
    alu_src,
    pc_gen_sel,
    sys,
    rd_sel,
    IF_ID_PC,
    read_data_1,
    read_data_2,
    imm_out,
    IF_ID_Inst[30],
    IF_ID_Inst[`IR_funct3],
    IF_ID_Inst[`IR_rs1],
    IF_ID_Inst[`IR_rs2],
    IF_ID_Inst[`IR_rd]}, 
    rst,
    1'b1,                                                                                                           
    {ID_EX_Ctrl,
    ID_EX_PC,
    ID_EX_RegR1,
    ID_EX_RegR2,
    ID_EX_Imm,
    ID_EX_Func,
    ID_EX_Rs1,
    ID_EX_Rs2,
    ID_EX_Rd});

    wire [31:0] EX_MEM_BranchAddOut, EX_MEM_ALU_out, EX_MEM_RegR2;
    wire [8:0] EX_MEM_Ctrl;
    wire [4:0] EX_MEM_Rd;
    wire [3:0] EX_MEM_branch;
    wire [2:0]EX_MEM_func;
    register #(117) EX_MEM (clk,
    {
    ID_EX_Ctrl[11:7],
    ID_EX_Ctrl[3:0],
    pc_gen_out,
    carry_flag,
    zero_flag,
    over_flag,
    sign_flag,
    jump_mux,
    ID_EX_Func[2:0],
    ID_EX_RegR2,
    ID_EX_Rd
    },
    rst,
    1'b1,
    {EX_MEM_Ctrl,
     EX_MEM_BranchAddOut,
     EX_MEM_branch,
     EX_MEM_ALU_out,
     EX_MEM_func,
     EX_MEM_RegR2,
     EX_MEM_Rd}
       );
    wire [31:0] MEM_WB_Mem_out, MEM_WB_ALU_out;
    wire [4:0] MEM_WB_Ctrl;
    wire [4:0] MEM_WB_Rd;
    
    register #(74) MEM_WB (neg_clk,
    {
    EX_MEM_Ctrl[8:7],
    EX_MEM_Ctrl[2:0],
    data_mem_out,
    EX_MEM_ALU_out,
    EX_MEM_Rd
    },
    rst,
    1'b1,
    {MEM_WB_Ctrl,
    MEM_WB_Mem_out,
     MEM_WB_ALU_out,
    MEM_WB_Rd} );


    assign PC_ext = PC;
    
    assign PC_in_ext = PC_in;
    register#(32)program_counter (neg_clk, final_pc, rst, 1'b1, PC);
    
    
    wire [31:0]mem_addr;
    wire final_mem_read;
    wire final_mem_write;
    wire [2:0]final_mem_func;
    assign mem_addr = ~clk ? PC : EX_MEM_ALU_out[5:0];
    assign final_mem_read = ~clk ? 1'b1 : EX_MEM_Ctrl[5];
    assign final_mem_write = ~clk ? 1'b0 : EX_MEM_Ctrl[4];    
    assign final_mem_func = ~clk ? 3'b010 : EX_MEM_func;
    
    assign inst_out_ext = inst_out;
    wire [31:0]mem_out;
    DataMem inst_mem (~clk, final_mem_read, final_mem_write, mem_addr, final_mem_func, EX_MEM_RegR2, mem_out);
    assign inst_out = ~clk ? mem_out : 32'h00_00_00_33;
    assign data_mem_out = ~clk ? mem_out : 1'b1;
//    clk, EX_MEM_Ctrl[5], EX_MEM_Ctrl[4], EX_MEM_ALU_out[5:0], EX_MEM_func ,EX_MEM_RegR2, data_mem_out
    
    
    assign branch_ext = can_branch;
    assign mem_read_ext = mem_read;
    assign mem_to_reg_ext = mem_to_reg;
    assign mem_write_ext = mem_write;
    assign alu_src_ext = alu_src;
    assign reg_write_ext = reg_write;
    
    assign alu_op_ext = alu_op;
   
    control_unit controlUnit (IF_ID_Inst[6:2], can_branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write,sys, alu_op, rd_sel, pc_gen_sel);
    
    
    assign write_data_ext = write_data;
    
    assign data_read_1_ext = read_data_1;
       
    assign data_read_2_ext = read_data_2;
    RegFile reg_file (clk, rst, IF_ID_Inst[`IR_rs1],IF_ID_Inst[`IR_rs2], MEM_WB_Rd,
     write_data, MEM_WB_Ctrl[4], read_data_1, read_data_2);
    
  
    
    assign imm_out_ext = imm_out;
    imm_gen immGen (IF_ID_Inst , imm_out);
    
    
    assign alu_mux_ext = alu_mux_out;
    multiplexer alu_mux (ID_EX_RegR2, ID_EX_Imm, ID_EX_Ctrl[4], alu_mux_out);
    
   
    assign alu_ctrl_out_ext = alu_ctrl_out;
    ALU_op aluOp (ID_EX_Ctrl[6:5] ,ID_EX_Func[2:0],ID_EX_Func[3],alu_ctrl_out);
    
    
    assign z_flag_ext = zero_flag;
    
    assign alu_out_ext = alu_out;
    
    prv32_ALU alu (ID_EX_RegR1 , alu_mux_out, imm_out[4:0], alu_out, carry_flag, zero_flag, over_flag, sign_flag, alu_ctrl_out);

    
    branch branch_mod (ID_EX_Func[2:0] , EX_MEM_branch[3], EX_MEM_branch[2], EX_MEM_branch[1], EX_MEM_branch[0], should_branch);
    
    
    assign data_mem_out_ext = data_mem_out;
//    DataMem data_mem (clk, EX_MEM_Ctrl[5], EX_MEM_Ctrl[4], EX_MEM_ALU_out[5:0], EX_MEM_func ,EX_MEM_RegR2, data_mem_out);
   
    
    
    assign shift_ext = shift_out;
    shift pc_shift (ID_EX_Imm, shift_out);
    
   
    assign pc_gen_out_ext = pc_gen_out;
    assign pc_gen_in = EX_MEM_Ctrl[3] ?   ID_EX_RegR1 : EX_MEM_BranchAddOut;
    ripple pc_gen (ID_EX_PC, ID_EX_Imm, pc_gen_out, dummy_carry);
    
    
    
    
    assign PC_inc_ext = pc_inc_out;
   
    ripple pc_inc (PC, 4, pc_inc_out, dummy_carry_2);
    
    
    multiplexer write_back (MEM_WB_ALU_out, MEM_WB_Mem_out, MEM_WB_Ctrl[3], write_data);
        
    
    assign jump_mux = (ID_EX_Ctrl[1:0] == 2'b00) ? alu_out : (ID_EX_Ctrl[1:0] == 2'b01) ? pc_gen_out : (ID_EX_Ctrl[1:0] == 2'b10) ? (ID_EX_PC + 4) : ID_EX_RegR2;
    
    multiplexer pc_mux (pc_inc_out, EX_MEM_BranchAddOut, (EX_MEM_Ctrl[6] & should_branch) , PC_in);
    assign new_PC_in = pc_gen_sel ? PC_in >> 2 : PC_in;
    assign final_pc = (MEM_WB_Ctrl[2] & inst_out[20])? PC : new_PC_in;
endmodule