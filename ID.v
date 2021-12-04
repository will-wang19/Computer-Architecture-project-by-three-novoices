`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,  
    output wire stallreq,
    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,
    input wire [31:0] inst_sram_rdata,
    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,
    input wire [`EX_TO_ID_WD-1:0] ex_to_id_bus,
    input wire [`MEM_TO_ID_WD-1:0] mem_to_id_bus,
    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,
    output wire [`BR_WD-1:0] br_bus, //��֧bus
    output wire is_indelayslot_o,//�����ex ��ָ���Ƿ�λ���ӳٲ�
    output wire next_is_indelayslot,//��һ��ָ���Ƿ�λ���ӳٲ�
    input  wire is_indelayslot_i,//id��ָ���Ƿ�λ���ӳٲ�
    output wire stallreq_id,//����ID�ε���ͣ�ź�
    input wire [5:0] ex_aluop,//ex������ִ�еĲ���
    input wire [4:0] ex_addr//ex��Ҫ���ʵļĴ���
);
    wire ex_inst_isload;//ex���Ƿ�load
    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;//if to id ������
    wire [31:0] inst;//ָ��
    wire [31:0] id_pc;//id�ε�ָ���ַ
    wire ce;//ʹ���ź�
    
    //we ex mem ������
    wire wb_rf_we;//WB�λ�д���ź�
    wire [4:0] wb_rf_waddr;//WB�λ�д�����ݵ�ַ
    wire [31:0] wb_rf_wdata;//WB�λ�д������
    wire ex_rf_we;//ex�λ�дʹ���ź�
    wire [4:0] ex_rf_waddr;//ex�λ�д�Ĵ���
    wire [31:0] ex_rf_wdata;//ex�λ�д����
    wire mem_rf_we;//ex�λ�дʹ���ź�
    wire [4:0] mem_rf_waddr;//mem�λ�д�Ĵ���
    wire [31:0] mem_rf_wdata;//mem�λ�д����
    
    //reg��
    wire [31:0] data1;
    wire [31:0] data2;
    reg id_stop;
    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            id_stop <=1'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            id_stop <=1'b1;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
            id_stop <=1'b0;
        end
        else begin
            id_stop <=1'b1;
            end
    end
    
    
    assign ex_inst_isload =(ex_aluop==6'b10_0000)|
                            (ex_aluop==6'b10_0100)|
                            (ex_aluop==6'b10_0001)|
                            (ex_aluop==6'b10_0101)|
                            (ex_aluop==6'b10_0011);
    assign stallreq_id=(ex_inst_isload==1'b0)?1'b0:
                        (ex_addr==rs|ex_addr==rt)?1'b1:1'b0;
    assign inst=id_stop?inst:inst_sram_rdata;//PC��Ӧ��ָ����
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    //wb ex mem��д
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;
    assign {
        ex_rf_we,
        ex_rf_waddr,
        ex_rf_wdata
    }=ex_to_id_bus;
    assign {
        mem_rf_we,
        mem_rf_waddr,
        mem_rf_wdata
    }=mem_to_id_bus;
    
    
    
    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;// ������

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;

    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    );
    assign data1=(ex_rf_we==1'b1)&&(ex_rf_waddr==rs)?ex_rf_wdata:
                (mem_rf_we==1'b1)&&(mem_rf_waddr==rs)?mem_rf_wdata:
                (wb_rf_we==1'b1)&&(wb_rf_waddr==rs)?wb_rf_wdata:rdata1;
    assign data2=(ex_rf_we==1'b1)&&(ex_rf_waddr==rt)?ex_rf_wdata:
                 (mem_rf_we==1'b1)&&(mem_rf_waddr==rt)?mem_rf_wdata:
                 (wb_rf_we==1'b1)&&(wb_rf_waddr==rt)?wb_rf_wdata:rdata2;


    assign opcode = inst[31:26];//ȡ������
    assign rs = inst[25:21];//rs��Ӧ�Ĵ���
    assign rt = inst[20:16];//rt��Ӧ�Ĵ���
    assign rd = inst[15:11];//rd��Ӧ�Ĵ���
    assign sa = inst[10:6];//R��ָ���еĵ�6��10λ
    assign func = inst[5:0];//R��ָ��func��
    assign imm = inst[15:0];//I��ָ����������
    assign instr_index = inst[25:0];//J��ָ���ַ��
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];//��������

    wire inst_ori, inst_lui, inst_addiu;
    wire inst_sub,inst_slt,inst_sltu;
    wire inst_and,inst_nor,inst_or,inst_xor;
    wire inst_sll,inst_srl,inst_sra;
    wire inst_subu;
    wire inst_addu;
    //load store
    wire inst_lb,inst_lbu,inst_lh,inst_lhu,inst_lw;
    wire inst_sb,inst_sh,inst_sw;
    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;
    //��תָ��
    wire inst_j,inst_jal,inst_jr,inst_jalr;
    //��ָ֧��
    wire inst_beq,inst_bne,inst_bgez,inst_bgtz,inst_blez,inst_bltz,inst_bgezal,inst_bltzal;
    //��ָ��
//    wire inst_nop;
    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )//����Ķ��ȱ��룬ֻ��һλΪ1��������ָ�����������Ϊ��һ��
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )//func�Ķ��ȱ��룬ֻ��һλΪ1��������ָ�����������Ϊ��һ��
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )//rs��Ӧ�Ĵ����Ķ��ȱ��룬
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )//rt��Ӧ�Ĵ����Ķ��ȱ��룬
    );
    decoder_5_32 u2_decoder_5_32(
    	.in  (rd  ),
        .out (rd_d )//rt��Ӧ�Ĵ����Ķ��ȱ��룬
    );
    decoder_5_32 u3_decoder_5_32(
    	.in  (sa  ),
        .out (sa_d )//rt��Ӧ�Ĵ����Ķ��ȱ��룬
    );

    
    assign inst_ori     = op_d[6'b00_1101];//6'b00_1101��ʾ������ȡ���������һλ��
    //ͬʱ00_1101Ϊori�����ָ���� ����ö�������ori�Ķ����룬��ô��ȡ��1 ���� ȡ��0
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    //�µ��������Ͷ�Ӧ��ʹ���ź�
    assign inst_sub     = op_d[6'b00_0000]&func_d[6'b10_0010];
    assign inst_subu    = op_d[6'b00_0000]&func_d[6'b10_0011];
    assign inst_slt     = op_d[6'b00_0000]&func_d[6'b10_1010];
    assign inst_sltu    = op_d[6'b00_0000]&func_d[6'b10_1011];
    assign inst_and     = op_d[6'b00_0000]&func_d[6'b10_0100];
    assign inst_nor     = op_d[6'b00_0000]&func_d[6'b10_0111];
    assign inst_or      = op_d[6'b00_0000]&func_d[6'b10_0101];
    assign inst_xor     = op_d[6'b00_0000]&func_d[6'b10_0110];
    assign inst_sll     = op_d[6'b00_0000]&func_d[6'b00_0000];
    assign inst_srl     = op_d[6'b00_0000]&func_d[6'b00_0010];
    assign inst_sra     = op_d[6'b00_0000]&func_d[6'b00_0011];
    assign inst_addu    = op_d[6'b00_0000]&func_d[6'b10_0001];
    //load storeָ��
    assign inst_lb     =op_d[6'b10_0000];
    assign inst_lbu    =op_d[6'b10_0100];
    assign inst_lh     =op_d[6'b10_0001];
    assign inst_lhu    =op_d[6'b10_0101];
    assign inst_lw     =op_d[6'b10_0011];
    assign inst_sb     =op_d[6'b10_1000];
    assign inst_sh     =op_d[6'b10_1001];
    assign inst_sw     =op_d[6'b10_1011]; 
    //��תָ��
    assign inst_jr      =op_d[6'b00_0000]&&func_d[6'b00_1000];
    assign inst_jalr    =op_d[6'b00_0000]&&func_d[6'b00_1001];
    assign inst_jal     =op_d[6'b00_0011];
    assign inst_j       =op_d[6'b00_0010];
    //��ָ֧��
    assign inst_beq     = op_d[6'b00_0100];
    assign inst_bne     = op_d[6'b00_0101];
    assign inst_bgez    = op_d[6'b00_0001];
    assign inst_bgtz    = op_d[6'b00_0111];
    assign inst_blez    = op_d[6'b00_0110];
    assign inst_bltz    = op_d[6'b00_0001]&rt_d[6'b00_0000];
    assign inst_bgezal  = op_d[6'b00_0001]&rt_d[6'b10_0001];
    assign inst_bltzal  = op_d[6'b00_0001]&rt_d[6'b10_0000];
    
    // rs to reg1
    assign sel_alu_src1[0] = inst_ori | inst_addiu |inst_addu|inst_sub|inst_subu |inst_slt|inst_sltu|inst_and|inst_nor|inst_or|inst_xor
                             |inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh|inst_sw;//rs��ֵ��src1

    // pc to reg1
    assign sel_alu_src1[1] = 1'b0;//src1Ϊpcֵ

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = 1'b0|inst_sll|inst_srl|inst_sra;//�޷�����չ����src1

    // rt to reg2
    assign sel_alu_src2[0] = 1'b0|inst_sub|inst_subu|inst_slt|inst_sltu|inst_and|inst_nor|inst_or|inst_xor|inst_sll|inst_srl|inst_sra|inst_addu;//rt��src2
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu|inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh|inst_sw;//�з�����չ����src2

    // 32'b8 to reg2
    assign sel_alu_src2[2] = 1'b0;//32λ������8��Ϊsrc2

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori;//���������޷�����չ��src2



    assign op_add = inst_addiu|inst_addu|inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh|inst_sw;
    assign op_sub = inst_sub |inst_subu;
    assign op_slt = inst_slt;
    assign op_sltu = inst_sltu;
    assign op_and = inst_and;
    assign op_nor = inst_nor;
    assign op_or = inst_ori|inst_or;
    assign op_xor = inst_xor;
    assign op_sll = inst_sll;
    assign op_srl = inst_srl;
    assign op_sra = inst_sra;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};//op������


    //!!!!!!!!��������loadָ��
    // load and store enable
    assign data_ram_en = inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh|inst_sw;

//    // write enable
    assign data_ram_wen = inst_sb?4'b0001:
                          inst_sh?4'b0011:
                          inst_sw?4'b1111:
                          inst_lb|inst_lbu|inst_lh|inst_lhu|inst_lw?4'b0000:4'b1110;
    //һ���ֽ� ���� ���� ������
    
    // regfile sotre enable
    assign rf_we = inst_ori |inst_lui| inst_addiu|inst_addu|inst_sub|inst_subu|inst_and|inst_nor|inst_or|inst_xor|inst_slt|inst_sltu|inst_sll|inst_srl|inst_sra
                            |inst_jal|inst_jalr
                            |inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu;



    // store in [rd]
    assign sel_rf_dst[0] = 1'b0|inst_sub|inst_subu|inst_addu|inst_and|inst_nor|inst_or|inst_xor|inst_slt|inst_sltu|inst_sll|inst_srl|inst_sra;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori|inst_lui|inst_addiu|inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu;
    // store in [31]
    assign sel_rf_dst[2] = 1'b0|inst_jal;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;//ѡ�����洢�ļĴ���

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = 1'b0|inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu; //ѡ��洢�Ĵ����е�ֵ����Դ
 
    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        data1,         // 63:32
        data2          // 31:0
    };


    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_neq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;
    
    assign rs_eq_rt = (data1 == data2);
    assign rs_neq_rt=(data1!=data2);
    assign rs_ge_z=(data1>=32'b0);
    assign rs_gt_z=(data1>32'b0);
    assign rs_le_z=(data1<=32'b0);
    assign rs_lt_z=(data1<32'b0);
    
    //��תָ��
    assign br_e = inst_j|inst_jr|inst_jal|inst_jalr|(inst_beq & rs_eq_rt)|(inst_bne&rs_neq_rt)|(inst_bgez&rs_ge_z)
                        |(inst_bgtz&rs_gt_z)|(inst_blez&rs_le_z)|(inst_bltz&rs_lt_z)|(inst_bgezal&rs_ge_z)|(inst_bltzal&rs_lt_z);
    assign br_addr =(inst_j|inst_jal)?{pc_plus_4[31:28],instr_index,2'b0}:
                    ((inst_jr|inst_jalr)?data1:
                    (inst_beq|inst_bne|inst_bgez|inst_bgtz|inst_blez|inst_bltz|inst_bgezal|inst_bltzal)?(pc_plus_4 + {{14{offset[15]}},offset,2'b0}):32'b0 );
    //��ת��֧�������תbrʹ���źź�br��ַ����ı�
    assign next_is_indelayslot=1'b0|inst_jal|inst_jr|inst_jalr|inst_j|inst_bgtz|inst_blez|inst_bne|inst_bgez|inst_bgezal|inst_bltz|inst_bltzal;
    assign is_indelayslot_o=is_indelayslot_i;
    assign br_bus = {
        br_e,
        br_addr
    };


endmodule