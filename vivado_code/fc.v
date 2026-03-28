`timescale 1ps/1ps
// ====================================================================
// FULLY_CONNECTED (레지스터 추가로 타이밍 위반 수정 버전: LAT=11)
// ====================================================================
module fully_connected #(
    parameter integer INPUT_NUM   = 48,   // 16 * 3
    parameter integer OUTPUT_NUM  = 10,   // 10 classes
    parameter integer DATA_BITS   = 8,    // weight/bias (int8: ternary & Q2.6)
    parameter integer SHIFT       = 0     // optional post shift
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Input stream from Pool2 (4x4 per channel = 16 samples)
    input  wire                  valid_in,         // 1펄스/샘플 (총 16회)
    input  wire signed [11:0]    data_in_1,        // ch1
    input  wire signed [11:0]    data_in_2,        // ch2
    input  wire signed [11:0]    data_in_3,        // ch3

    // Output logits (sequential, one per pulse)
    output reg  signed [11:0]    data_out,
    output reg                   valid_out_fc,

    // Packed Weights/Bias/Scale
    input  wire [0:INPUT_NUM*OUTPUT_NUM*DATA_BITS-1] w_fc,     // 10*48*8 = 3840b
    input  wire [0:OUTPUT_NUM*DATA_BITS-1]           b_fc,     // 10*8 = 80b (Q2.6 bias)
    input  wire [0:OUTPUT_NUM*8-1]                   fc_scale  // 10*8 = 80b (Q2.6 alpha)
);
    // ---------------- Consts ----------------
    function integer CLOG2; input integer v; integer t; begin
        t=v-1; CLOG2=0; while(t>0) begin t=t>>1; CLOG2=CLOG2+1; end
    end endfunction

    localparam integer INPUT_WIDTH = 16;                 // per channel
    localparam integer FILL_W      = CLOG2(INPUT_WIDTH); // 4
    localparam integer OUT_W       = CLOG2(OUTPUT_NUM);  // 4
    localparam integer WB_DW       = INPUT_NUM*DATA_BITS;// 48*8=384
    localparam integer WB_AW       = CLOG2(OUTPUT_NUM);  // 4

    // 파이프라인 단계
    localparam integer BRAM_LAT    = 1;  
    localparam integer MUL_LAT     = 1;
    localparam integer AT_LAT      = 6;
    localparam integer OUT_LAT     = 3; // <--- 2차 수정: 2 -> 3
    localparam integer LAT         = BRAM_LAT + MUL_LAT + AT_LAT + OUT_LAT; // 11

    // 고정소수점 상수
    localparam integer SCALE_W     = 8;  // Q2.6
    localparam integer SHIFT_S     = 6;
    localparam integer ROUND_S     = 1 << (SHIFT_S-1); // 32

    // 내부 정밀도(시뮬 기준)
    localparam integer FC_ACC_BITS = 34; // prod 폭
    // s1(최종 psum) 폭 = FC_ACC_BITS + 6 (스테이지 누적 여유)
    
    // -------------------------------------------------------------
    // *********** NEW: 최종 단계 분리를 위한 레지스터 추가 ***********
    reg signed [63:0] shifted_r; 
    reg [OUT_W-1:0]   out_idx_final_r; 
    
    // 2차 수정으로 추가된 레지스터
    reg signed [63:0] mul_a_r; // 곱셈 결과 래치 (New Stage 9 output)
    wire signed [11:0] bias_int12_comb; // New intermediate signal for aligned bias
    reg signed [11:0] bias_int12_r; // 정렬된 bias 래치
    // -------------------------------------------------------------

    // -------- 입력 버퍼(48 x 14b) --------
    reg  signed [13:0] buffer [0:INPUT_NUM-1];
    reg  [FILL_W-1:0]  buf_idx;
    reg                state;     // 0: FILL, 1: COMPUTE
    reg  [OUT_W-1:0]   out_idx;   // 현재 뉴런 index (0..9)

    // 12b → 14b sign-extend
    wire signed [13:0] d1 = {{2{data_in_1[11]}}, data_in_1};
    wire signed [13:0] d2 = {{2{data_in_2[11]}}, data_in_2};
    wire signed [13:0] d3 = {{2{data_in_3[11]}}, data_in_3};

    // -------- Alpha/Bias 메모리 언팩(조합) --------
    reg  signed [DATA_BITS-1:0] bias_mem  [0:OUTPUT_NUM-1]; // int8 Q2.6
    reg  signed [SCALE_W-1:0]   alpha_mem [0:OUTPUT_NUM-1]; // int8 Q2.6

    integer bi;
    always @(*) begin
      for (bi=0; bi<OUTPUT_NUM; bi=bi+1) begin
        bias_mem [bi] = b_fc[(DATA_BITS*bi) +: DATA_BITS];
        alpha_mem[bi] = fc_scale[(8*bi)     +: 8];
      end
    end

    // -------- 로더 대체: 버스 슬라이스로 가중치 읽기 --------
    reg  [WB_AW-1:0]  wb_r_addr;            // 읽을 뉴런 index
    wire [WB_DW-1:0]  wb_r_data_mux;        // 버스 슬라이스 결과(가중치 48개)
    assign wb_r_data_mux = w_fc[(WB_DW*wb_r_addr) +: WB_DW];

    // 시뮬에서는 로더 생략 → 항상 load_done=1
    reg load_done, wb_w_en;
    reg [WB_AW-1:0] wb_w_addr;
    reg [WB_DW-1:0] wb_w_data;
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        load_done <= 1'b0;
        wb_w_en   <= 1'b0;
        wb_w_addr <= {WB_AW{1'b0}};
        wb_w_data <= {WB_DW{1'b0}};
      end else begin
        load_done <= 1'b1;
        wb_w_en   <= 1'b0;
      end
    end

    // -------- FILL/COMPUTE FSM --------
    wire fire_calc = state & load_done; // 계산 파이프 주입 트리거

    integer ii;
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        state   <= 1'b0;
        buf_idx <= 0;
        out_idx <= 0;
        for (ii=0; ii<INPUT_NUM; ii=ii+1) buffer[ii] <= 14'sd0;
      end else begin
        if (!state) begin
          // FILL: 16회 valid_in 펄스 동안 각 채널 한 칸씩 채움
          if (valid_in) begin
            buffer[buf_idx]                   <= d1;
            buffer[INPUT_WIDTH + buf_idx]     <= d2;
            buffer[INPUT_WIDTH*2 + buf_idx]   <= d3;
            buf_idx <= buf_idx + 1'b1;
            if (buf_idx == INPUT_WIDTH-1) begin
              buf_idx <= 0;
              out_idx <= 0;
              state   <= 1'b1; // COMPUTE 진입
            end
          end
        end else begin
          // COMPUTE: 뉴런 10개를 순차 계산
          if (load_done) begin
            if (fire_calc) begin
              if (out_idx == OUTPUT_NUM-1) begin
                out_idx <= 0;
                state   <= 1'b0; // 다시 FILL로
              end else begin
                out_idx <= out_idx + 1'b1;
              end
            end
          end
        end
      end
    end

    // -------- 파이프 제어 & 주소 --------
    reg [LAT-1:0] vpipe;
    reg [OUT_W-1:0] out_idx_pipe [0:LAT-1];

    integer pi;
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        vpipe <= {LAT{1'b0}};
        for (pi=0; pi<LAT; pi=pi+1) out_idx_pipe[pi] <= 0;
      end else begin
        vpipe <= {vpipe[LAT-2:0], fire_calc};
        for (pi=LAT-1; pi>0; pi=pi-1) out_idx_pipe[pi] <= out_idx_pipe[pi-1];
        if (fire_calc) out_idx_pipe[0] <= out_idx;
      end
    end

    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) wb_r_addr <= 0;
      else if (fire_calc)   wb_r_addr <= out_idx;
    end

    // -------- Stage 1: Weight Latch (BRAM_LAT=1) --------
    reg [WB_DW-1:0] weights_reg; // 48*8 = 384b
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) weights_reg <= {WB_DW{1'b0}};
      else if (vpipe[BRAM_LAT-1]) weights_reg <= wb_r_data_mux;
    end

    // -------- Stage 2: Ternary MUL (MUL_LAT=1) --------
    reg signed [FC_ACC_BITS-1:0] prod [0:INPUT_NUM-1]; // 34b

    integer mk;
    reg signed [DATA_BITS-1:0]   wk_tmp;
    reg signed [13:0]            x_tmp;
    reg signed [FC_ACC_BITS-1:0] x_ext;
    reg is_pos, is_neg;

    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        for (mk=0; mk<INPUT_NUM; mk=mk+1) prod[mk] <= 0;
      end else if (vpipe[BRAM_LAT]) begin
        for (mk=0; mk<INPUT_NUM; mk=mk+1) begin
          wk_tmp = weights_reg[(DATA_BITS*mk) +: DATA_BITS]; // -1/0/+1
          x_tmp  = buffer[mk];                                // 14b
          x_ext  = {{(FC_ACC_BITS-14){x_tmp[13]}}, x_tmp};    // sign-extend
          is_pos = (wk_tmp == 8'sd1);
          is_neg = (wk_tmp == -8'sd1);
          prod[mk] <= is_pos ?  x_ext :
                      is_neg ? -x_ext :
                               {FC_ACC_BITS{1'b0}};
        end
      end
    end

    // -------- Stages 3~8: Adder Tree (AT_LAT=6) --------
    // 폭 증가를 단계별로 1비트씩 여유
    reg signed [FC_ACC_BITS    :0] s24 [0:23]; // 48→24
    reg signed [FC_ACC_BITS+1  :0] s12 [0:11]; // 24→12
    reg signed [FC_ACC_BITS+2  :0] s6  [0:5];  // 12→6
    reg signed [FC_ACC_BITS+3  :0] s3  [0:2];  // 6 →3
    reg signed [FC_ACC_BITS+4  :0] s2  [0:1];  // 3 →(2,1)
    reg signed [FC_ACC_BITS+5  :0] s1;         // 최종 합(2→1)

    integer at_i;

    // Stage 3: prod -> s24
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) for (at_i=0; at_i<24; at_i=at_i+1) s24[at_i] <= 0;
      else if (vpipe[BRAM_LAT + MUL_LAT - 1 + 1]) begin 
        for (at_i=0; at_i<24; at_i=at_i+1)
          s24[at_i] <= prod[2*at_i] + prod[2*at_i+1];
      end
    end

    // Stage 4: s24 -> s12
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) for (at_i=0; at_i<12; at_i=at_i+1) s12[at_i] <= 0;
      else if (vpipe[BRAM_LAT + MUL_LAT + 1]) begin
        for (at_i=0; at_i<12; at_i=at_i+1)
          s12[at_i] <= s24[2*at_i] + s24[2*at_i+1];
      end
    end

    // Stage 5: s12 -> s6
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) for (at_i=0; at_i<6; at_i=at_i+1) s6[at_i] <= 0;
      else if (vpipe[BRAM_LAT + MUL_LAT + 2]) begin
        for (at_i=0; at_i<6; at_i=at_i+1)
          s6[at_i] <= s12[2*at_i] + s12[2*at_i+1];
      end
    end

    // Stage 6: s6 -> s3
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        s3[0] <= 0; s3[1] <= 0; s3[2] <= 0;
      end else if (vpipe[BRAM_LAT + MUL_LAT + 3]) begin
        s3[0] <= s6[0] + s6[1];
        s3[1] <= s6[2] + s6[3];
        s3[2] <= s6[4] + s6[5];
      end
    end

    // Stage 7: s3 -> s2
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        s2[0] <= 0; s2[1] <= 0;
      end else if (vpipe[BRAM_LAT + MUL_LAT + 4]) begin
        s2[0] <= s3[0] + s3[1]; 
        s2[1] <= s3[2];         
      end
    end

    // Stage 8: s2 -> s1 (final psum)
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) s1 <= 0;
      else if (vpipe[LAT-OUT_LAT-1]) begin // vpipe[8]
        s1 <= s2[0] + s2[1];
      end
    end

    // ********************************************************************
    // -------- Final Stage 1/3: Alpha Multiplication (New Stage 9) --------
    // ********************************************************************
    // Stage 9의 파이프라인 인덱스: vpipe[LAT-OUT_LAT] = vpipe[8]
    wire [OUT_W-1:0]            out_idx_comb    = out_idx_pipe[LAT-OUT_LAT];
    wire signed [SCALE_W-1:0] alphaS_comb = alpha_mem[out_idx_comb];
    wire signed [DATA_BITS-1:0] bias8_comb  = bias_mem[out_idx_comb];

    // s1(FC_ACC_BITS+6 bits)을 64b로 확장
    wire signed [63:0] psum64_comb = {{(64-(FC_ACC_BITS+6)){s1[FC_ACC_BITS+5]}}, s1};
    wire signed [63:0] alpha64_comb = {{(64-SCALE_W){alphaS_comb[SCALE_W-1]}}, alphaS_comb};
    wire signed [63:0] mul_a_comb  = psum64_comb * alpha64_comb; // <--- 이 곱셈이 가장 긴 경로의 원인

    // bias Q2.6 정렬
    wire signed [15:0] bias_q26_ext_comb = {{8{bias8_comb[7]}}, bias8_comb};
    assign bias_int12_comb   = (bias_q26_ext_comb + 16'sd32) >>> SHIFT_S;

    // *********** NEW: Stage 9 레지스터 ***********
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_a_r <= 64'sd0;
            bias_int12_r <= 12'sd0;
        end else if (vpipe[LAT-OUT_LAT]) begin  // vpipe[8]
            mul_a_r <= mul_a_comb; // 곱셈 결과 래치
            bias_int12_r <= bias_int12_comb; // bias 정렬 결과 래치
        end
    end

    // *******************************************************************
    // -------- Final Stage 2/3: Shift/Bias Add (New Stage 10) --------
    // *******************************************************************
    // Stage 10의 파이프라인 인덱스: vpipe[LAT-OUT_LAT+1] = vpipe[9]
    wire signed [63:0] scaled_comb_st10 = (mul_a_r + ROUND_S) >>> SHIFT_S; // mul_a_r 사용
    
    // bias_int12_r 사용
    wire signed [63:0] summed_comb_st10 = scaled_comb_st10 + {{52{bias_int12_r[11]}}, bias_int12_r};
    wire signed [63:0] shifted_comb_st10 = (SHIFT==0) ? summed_comb_st10 : (summed_comb_st10 >>> SHIFT);

    // *********** NEW: Stage 10 레지스터 ***********
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shifted_r       <= 64'sd0;
            out_idx_final_r <= 0;
        end else if (vpipe[LAT - OUT_LAT + 1]) begin // vpipe[9]
            shifted_r       <= shifted_comb_st10;
            out_idx_final_r <= out_idx_pipe[LAT - OUT_LAT];
        end
    end


    // **********************************************************************
    // -------- Final Stage 3/3: Saturation & Output (New Stage 11) --------
    // **********************************************************************
    // 12b 포화
    function automatic signed [11:0] sat12(input signed [63:0] v);
      begin
        if (v >  64'sd2047)      sat12 = 12'sd2047;
        else if (v < -64'sd2048) sat12 = -12'sd2048;
        else                     sat12 = v[11:0];
      end
    endfunction
    
    wire signed [11:0] final_data_out_comb = sat12(shifted_r);

    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        data_out     <= 12'sd0;
        valid_out_fc <= 1'b0;
      end else begin
        valid_out_fc <= vpipe[LAT-1];     // vpipe[10] (11번째 클럭)
        if (vpipe[LAT-1]) data_out <= final_data_out_comb;
      end
    end


endmodule