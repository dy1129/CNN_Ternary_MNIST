
`timescale 1ps/1ps

module conv2_layer ( 
   input clk,
   input rst_n,  
   input valid_in,  
   input [11:0] max_value_1, max_value_2, max_value_3, 

   // === 추가: 채널별 스케일 α (예: Q2.6 고정소수점) ===
   input  signed [7:0] alpha_1, alpha_2, alpha_3,

   // bias (8b × 3채널, 기존과 동일)
   input  [0:23] b_2,

   // 출력
   output signed [11:0] conv2_out_1, conv2_out_2, conv2_out_3,
   output               valid_out_conv2,
     // 풀2에 줄 1-클럭 유효 펄스 (새 신호)
  output wire                valid_in_pooling,


   // 가중치 버스 (각 8b × 25 = 200b). 값은 -1/0/+1 로 주어진다고 가정
   input [0:199] w_211, w_212, w_213,
   input [0:199] w_221, w_222, w_223,
   input [0:199] w_231, w_232, w_233
);

localparam CHANNEL_LEN = 3;
localparam integer DATA_BITS = 12;
localparam integer K = 5;
localparam integer N_TAPS = K*K;
localparam integer DBUS_W = DATA_BITS*N_TAPS; // 12*25 = 300

localparam integer ALPHA_W = 8;
localparam integer SHIFT_S = 6;

// -----------------------------
// conv2_buf outputs (원본 유지)
// -----------------------------
wire [11:0] data_out1_0,  data_out1_1,  data_out1_2,  data_out1_3,  data_out1_4,
            data_out1_5,  data_out1_6,  data_out1_7,  data_out1_8,  data_out1_9,
            data_out1_10, data_out1_11, data_out1_12, data_out1_13, data_out1_14,
            data_out1_15, data_out1_16, data_out1_17, data_out1_18, data_out1_19,
            data_out1_20, data_out1_21, data_out1_22, data_out1_23, data_out1_24;
wire valid_out1_buf;

wire [11:0] data_out2_0,  data_out2_1,  data_out2_2,  data_out2_3,  data_out2_4,
            data_out2_5,  data_out2_6,  data_out2_7,  data_out2_8,  data_out2_9,
            data_out2_10, data_out2_11, data_out2_12, data_out2_13, data_out2_14,
            data_out2_15, data_out2_16, data_out2_17, data_out2_18, data_out2_19,
            data_out2_20, data_out2_21, data_out2_22, data_out2_23, data_out2_24;
wire valid_out2_buf;

wire [11:0] data_out3_0,  data_out3_1,  data_out3_2,  data_out3_3,  data_out3_4,
            data_out3_5,  data_out3_6,  data_out3_7,  data_out3_8,  data_out3_9,
            data_out3_10, data_out3_11, data_out3_12, data_out3_13, data_out3_14,
            data_out3_15, data_out3_16, data_out3_17, data_out3_18, data_out3_19,
            data_out3_20, data_out3_21, data_out3_22, data_out3_23, data_out3_24;
wire valid_out3_buf;

wire valid_out_buf = valid_out1_buf & valid_out2_buf & valid_out3_buf;

// -----------------------------
// data_out 버스화 + 레지스터
// -----------------------------
reg [0:DBUS_W-1] d1_q, d2_q, d3_q;
reg              valid_out_buf_d;

wire [DATA_BITS-1:0] d1 [0:N_TAPS-1];
wire [DATA_BITS-1:0] d2 [0:N_TAPS-1];
wire [DATA_BITS-1:0] d3 [0:N_TAPS-1];

// 배열 매핑(채널1)
assign d1[0]=data_out1_0;   assign d1[1]=data_out1_1;   assign d1[2]=data_out1_2;   assign d1[3]=data_out1_3;   assign d1[4]=data_out1_4;
assign d1[5]=data_out1_5;   assign d1[6]=data_out1_6;   assign d1[7]=data_out1_7;   assign d1[8]=data_out1_8;   assign d1[9]=data_out1_9;
assign d1[10]=data_out1_10; assign d1[11]=data_out1_11; assign d1[12]=data_out1_12; assign d1[13]=data_out1_13; assign d1[14]=data_out1_14;
assign d1[15]=data_out1_15; assign d1[16]=data_out1_16; assign d1[17]=data_out1_17; assign d1[18]=data_out1_18; assign d1[19]=data_out1_19;
assign d1[20]=data_out1_20; assign d1[21]=data_out1_21; assign d1[22]=data_out1_22; assign d1[23]=data_out1_23; assign d1[24]=data_out1_24;

// 배열 매핑(채널2)
assign d2[0]=data_out2_0;   assign d2[1]=data_out2_1;   assign d2[2]=data_out2_2;   assign d2[3]=data_out2_3;   assign d2[4]=data_out2_4;
assign d2[5]=data_out2_5;   assign d2[6]=data_out2_6;   assign d2[7]=data_out2_7;   assign d2[8]=data_out2_8;   assign d2[9]=data_out2_9;
assign d2[10]=data_out2_10; assign d2[11]=data_out2_11; assign d2[12]=data_out2_12; assign d2[13]=data_out2_13; assign d2[14]=data_out2_14;
assign d2[15]=data_out2_15; assign d2[16]=data_out2_16; assign d2[17]=data_out2_17; assign d2[18]=data_out2_18; assign d2[19]=data_out2_19;
assign d2[20]=data_out2_20; assign d2[21]=data_out2_21; assign d2[22]=data_out2_22; assign d2[23]=data_out2_23; assign d2[24]=data_out2_24;

// 배열 매핑(채널3)
assign d3[0]=data_out3_0;   assign d3[1]=data_out3_1;   assign d3[2]=data_out3_2;   assign d3[3]=data_out3_3;   assign d3[4]=data_out3_4;
assign d3[5]=data_out3_5;   assign d3[6]=data_out3_6;   assign d3[7]=data_out3_7;   assign d3[8]=data_out3_8;   assign d3[9]=data_out3_9;
assign d3[10]=data_out3_10; assign d3[11]=data_out3_11; assign d3[12]=data_out3_12; assign d3[13]=data_out3_13; assign d3[14]=data_out3_14;
assign d3[15]=data_out3_15; assign d3[16]=data_out3_16; assign d3[17]=data_out3_17; assign d3[18]=data_out3_18; assign d3[19]=data_out3_19;
assign d3[20]=data_out3_20; assign d3[21]=data_out3_21; assign d3[22]=data_out3_22; assign d3[23]=data_out3_23; assign d3[24]=data_out3_24;

// 버스 레지스터링
integer i_pack;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    d1_q <= {DBUS_W{1'b0}};
    d2_q <= {DBUS_W{1'b0}};
    d3_q <= {DBUS_W{1'b0}};
    valid_out_buf_d <= 1'b0;
  end else begin
    valid_out_buf_d <= valid_out_buf;
    if (valid_out_buf) begin
      for (i_pack=0; i_pack<N_TAPS; i_pack=i_pack+1) begin
        d1_q[(DATA_BITS*i_pack)+:DATA_BITS] <= d1[i_pack];
        d2_q[(DATA_BITS*i_pack)+:DATA_BITS] <= d2[i_pack];
        d3_q[(DATA_BITS*i_pack)+:DATA_BITS] <= d3[i_pack];
      end
    end
  end
end

// -----------------------------
// conv2_buf instances (원본 유지)
// -----------------------------
conv2_buf #(.WIDTH(12), .HEIGHT(12), .DATA_BITS(12)) conv2_buf_1(
   .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .data_in(max_value_1),
   .data_out_0(data_out1_0),  .data_out_1(data_out1_1),  .data_out_2(data_out1_2),  .data_out_3(data_out1_3),  .data_out_4(data_out1_4),
   .data_out_5(data_out1_5),  .data_out_6(data_out1_6),  .data_out_7(data_out1_7),  .data_out_8(data_out1_8),  .data_out_9(data_out1_9),
   .data_out_10(data_out1_10),.data_out_11(data_out1_11),.data_out_12(data_out1_12),.data_out_13(data_out1_13),.data_out_14(data_out1_14),
   .data_out_15(data_out1_15),.data_out_16(data_out1_16),.data_out_17(data_out1_17),.data_out_18(data_out1_18),.data_out_19(data_out1_19),
   .data_out_20(data_out1_20),.data_out_21(data_out1_21),.data_out_22(data_out1_22),.data_out_23(data_out1_23),.data_out_24(data_out1_24),
   .valid_out_buf(valid_out1_buf)
);

conv2_buf #(.WIDTH(12), .HEIGHT(12), .DATA_BITS(12)) conv2_buf_2(
   .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .data_in(max_value_2),
   .data_out_0(data_out2_0),  .data_out_1(data_out2_1),  .data_out_2(data_out2_2),  .data_out_3(data_out2_3),  .data_out_4(data_out2_4),
   .data_out_5(data_out2_5),  .data_out_6(data_out2_6),  .data_out_7(data_out2_7),  .data_out_8(data_out2_8),  .data_out_9(data_out2_9),
   .data_out_10(data_out2_10),.data_out_11(data_out2_11),.data_out_12(data_out2_12),.data_out_13(data_out2_13),.data_out_14(data_out2_14),
   .data_out_15(data_out2_15),.data_out_16(data_out2_16),.data_out_17(data_out2_17),.data_out_18(data_out2_18),.data_out_19(data_out2_19),
   .data_out_20(data_out2_20),.data_out_21(data_out2_21),.data_out_22(data_out2_22),.data_out_23(data_out2_23),.data_out_24(data_out2_24),
   .valid_out_buf(valid_out2_buf)
);

conv2_buf #(.WIDTH(12), .HEIGHT(12), .DATA_BITS(12)) conv2_buf_3(
   .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .data_in(max_value_3),
   .data_out_0(data_out3_0),  .data_out_1(data_out3_1),  .data_out_2(data_out3_2),  .data_out_3(data_out3_3),  .data_out_4(data_out3_4),
   .data_out_5(data_out3_5),  .data_out_6(data_out3_6),  .data_out_7(data_out3_7),  .data_out_8(data_out3_8),  .data_out_9(data_out3_9),
   .data_out_10(data_out3_10),.data_out_11(data_out3_11),.data_out_12(data_out3_12),.data_out_13(data_out3_13),.data_out_14(data_out3_14),
   .data_out_15(data_out3_15),.data_out_16(data_out3_16),.data_out_17(data_out3_17),.data_out_18(data_out3_18),.data_out_19(data_out3_19),
   .data_out_20(data_out3_20),.data_out_21(data_out3_21),.data_out_22(data_out3_22),.data_out_23(data_out3_23),.data_out_24(data_out3_24),
   .valid_out_buf(valid_out3_buf)
);

// -----------------------------
// Weights 1회 로딩(_q) 유지
// -----------------------------
reg [0:199] w_211_q, w_212_q, w_213_q;
reg [0:199] w_221_q, w_222_q, w_223_q;
reg [0:199] w_231_q, w_232_q, w_233_q;
reg         w_loaded;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    w_loaded <= 1'b0;
    w_211_q <= 200'd0; w_212_q <= 200'd0; w_213_q <= 200'd0;
    w_221_q <= 200'd0; w_222_q <= 200'd0; w_223_q <= 200'd0;
    w_231_q <= 200'd0; w_232_q <= 200'd0; w_233_q <= 200'd0;
  end else begin
    if (!w_loaded && valid_in) begin
      w_211_q <= w_211; w_212_q <= w_212; w_213_q <= w_213;
      w_221_q <= w_221; w_222_q <= w_222; w_223_q <= w_223;
      w_231_q <= w_231; w_232_q <= w_232; w_233_q <= w_233;
      w_loaded <= 1'b1;
    end
  end
end

// -----------------------------
// conv2 계산부: Ternary + α/bias
// -----------------------------
localparam integer SUM_W = 22; // 12 + ceil(log2(25)) + sign 여유

wire signed [SUM_W-1:0] psum1, psum2, psum3;
wire vld1, vld2, vld3;
assign valid_out_conv2 = vld1 & vld2 & vld3;

// Ternary 계산기 3개 (각 출력채널)
conv2_calc #(.DATA_BITS(12), .SUM_W(SUM_W)) u_c2_1 (
  .clk(clk), .rst_n(rst_n), .valid_out_buf(valid_out_buf_d),
  .x_1(d1_q), .x_2(d2_q), .x_3(d3_q),
  .w_1(w_211_q), .w_2(w_212_q), .w_3(w_213_q),
  .psum_raw(psum1), .valid_out_calc(vld1)
);
conv2_calc #(.DATA_BITS(12), .SUM_W(SUM_W)) u_c2_2 (
  .clk(clk), .rst_n(rst_n), .valid_out_buf(valid_out_buf_d),
  .x_1(d1_q), .x_2(d2_q), .x_3(d3_q),
  .w_1(w_221_q), .w_2(w_222_q), .w_3(w_223_q),
  .psum_raw(psum2), .valid_out_calc(vld2)
);
conv2_calc #(.DATA_BITS(12), .SUM_W(SUM_W)) u_c2_3 (
  .clk(clk), .rst_n(rst_n), .valid_out_buf(valid_out_buf_d),
  .x_1(d1_q), .x_2(d2_q), .x_3(d3_q),
  .w_1(w_231_q), .w_2(w_232_q), .w_3(w_233_q),
  .psum_raw(psum3), .valid_out_calc(vld3)
);

// bias (입력: 8b Q2.6) → 출력 정수 도메인으로 정렬(+라운딩) 후 더하기
reg  signed [7:0]  bias8      [0:CHANNEL_LEN-1];
wire signed [15:0] bias_q26   [0:CHANNEL_LEN-1]; // 8b sign-extend → 16b
wire signed [11:0] exp_bias   [0:CHANNEL_LEN-1]; // 최종 12b로 사용

integer i;
always @(*) begin
  for (i=0; i<CHANNEL_LEN; i=i+1) begin
    bias8[i] = b_2[(8*i)+:8];  // 8비트 bias 로드
  end
end

genvar bi;
generate
  for (bi=0; bi<CHANNEL_LEN; bi=bi+1) begin: BIAS_ALIGN
    // 8b → 16b 부호확장 (Q2.6 유지)
    assign bias_q26[bi] = {{8{bias8[bi][7]}}, bias8[bi]};
    // Q2.6을 정수로 맞추기: (x + 2^(6-1)) >> 6  (라운딩 포함)
    assign exp_bias[bi] = (bias_q26[bi] + 16'sd32) >>> 6;
  end
endgenerate


// 포화 함수
function automatic signed [11:0] sat12(input signed [31:0] v);
  begin
    if (v >  32'sd2047)      sat12 = 12'sd2047;
    else if (v < -32'sd2048) sat12 = -12'sd2048;
    else                     sat12 = v[11:0];
  end
endfunction

// α 곱(고정소수점) + 시프트 + bias
wire signed [ALPHA_W-1:0] a1 = alpha_1, a2 = alpha_2, a3 = alpha_3;

localparam integer ROUND_BIAS = (1 << (SHIFT_S-1));

wire signed [SUM_W+ALPHA_W-1:0] m1 = psum1 * a1;
wire signed [SUM_W+ALPHA_W-1:0] m2 = psum2 * a2;
wire signed [SUM_W+ALPHA_W-1:0] m3 = psum3 * a3;

wire signed [SUM_W+ALPHA_W-1:0] s1 = (m1 + ROUND_BIAS) >>> SHIFT_S;
wire signed [SUM_W+ALPHA_W-1:0] s2 = (m2 + ROUND_BIAS) >>> SHIFT_S;
wire signed [SUM_W+ALPHA_W-1:0] s3 = (m3 + ROUND_BIAS) >>> SHIFT_S;

assign conv2_out_1 = sat12( $signed(s1) + $signed(exp_bias[0]) );
assign conv2_out_2 = sat12( $signed(s2) + $signed(exp_bias[1]) );
assign conv2_out_3 = sat12( $signed(s3) + $signed(exp_bias[2]) );

// === 2클럭 주기로 H/L 토글 생성 (conv2_valid가 1인 동안만) ===
// valid_out_conv2: 기존 레벨(valid area) 신호는 그대로 사용
reg valid_out_conv2_d;
reg phase_toggle;  // 1클럭마다 토글 → 2클럭 주기(H/L)

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    valid_out_conv2_d <= 1'b0;
    phase_toggle      <= 1'b0;
  end else begin
    valid_out_conv2_d <= valid_out_conv2;

    if (valid_out_conv2) begin
      // 유효구간 진입 순간(상승엣지)에는 High로 시작
      if (!valid_out_conv2_d) phase_toggle <= 1'b1;
      else                    phase_toggle <= ~phase_toggle; // 그 다음부터 1클럭마다 토글
    end else begin
      // 유효구간이 끝나면 0으로 리셋
      phase_toggle <= 1'b0;
    end
  end
end

// 풀2에 넣을 valid: conv2_valid 구간 내에서만 1클럭 High / 1클럭 Low 반복
assign valid_in_pooling = phase_toggle;



endmodule


/*-------------------------------------------------------------------
 *  Module: conv2_buf (원본 유지, buf_idx 폭만 안전하게 조정)
 *------------------------------------------------------------------*/
module conv2_buf #(parameter WIDTH = 12, HEIGHT = 12, DATA_BITS = 12) (
  input clk,
  input rst_n,
  input valid_in,
  input [DATA_BITS - 1:0] data_in,
  output reg [DATA_BITS - 1:0] data_out_0, data_out_1, data_out_2, data_out_3, data_out_4,
  data_out_5, data_out_6, data_out_7, data_out_8, data_out_9,
  data_out_10, data_out_11, data_out_12, data_out_13, data_out_14,
  data_out_15, data_out_16, data_out_17, data_out_18, data_out_19,
  data_out_20, data_out_21, data_out_22, data_out_23, data_out_24,
  output reg valid_out_buf
);

 localparam FILTER_SIZE = 5;
 
 reg [DATA_BITS - 1:0] buffer [0:WIDTH * FILTER_SIZE - 1];
 reg [4:0] w_idx, h_idx;
 reg [2:0] buf_flag;  // 0 ~ 4
 reg state;

 // 0..(WIDTH*FILTER_SIZE-1)=0..59 → 6~8비트면 충분
 reg [7:0] buf_idx;

always @(posedge clk) begin
   if(~rst_n) begin
     buf_idx <= 0;
     w_idx <= 0;
     h_idx <= 0;
     buf_flag <= 0;
     state <= 0;
     valid_out_buf <= 0;
     data_out_0 <= 12'bx;     data_out_1 <= 12'bx;     data_out_2 <= 12'bx;     data_out_3 <= 12'bx;     data_out_4 <= 12'bx;
     data_out_5 <= 12'bx;     data_out_6 <= 12'bx;     data_out_7 <= 12'bx;     data_out_8 <= 12'bx;     data_out_9 <= 12'bx;
     data_out_10 <= 12'bx;     data_out_11 <= 12'bx;     data_out_12 <= 12'bx;     data_out_13 <= 12'bx;     data_out_14 <= 12'bx;
     data_out_15 <= 12'bx;     data_out_16 <= 12'bx;     data_out_17 <= 12'bx;     data_out_18 <= 12'bx;     data_out_19 <= 12'bx;
     data_out_20 <= 12'bx;     data_out_21 <= 12'bx;     data_out_22 <= 12'bx;     data_out_23 <= 12'bx;     data_out_24 <= 12'bx;
   end else begin
     if(valid_in) begin
       buf_idx <= buf_idx + 1'b1;
       if(buf_idx == WIDTH * FILTER_SIZE - 1) begin
         buf_idx <= 0;
       end
       
       buffer[buf_idx] <= data_in;  // data input
       // Wait until first WIDTH*FILTER_SIZE input data filled in buffer
       if(!state) begin
         if(buf_idx == WIDTH * FILTER_SIZE - 1) begin
           state <= 1;
         end
       end else begin // valid state
         w_idx <= w_idx + 1'b1; // move right

         if(w_idx == WIDTH - FILTER_SIZE + 1) begin
           valid_out_buf <= 1'b0;  // unvalid area
         end else if(w_idx == WIDTH - 1) begin
           buf_flag <= buf_flag + 1;
           if(buf_flag == FILTER_SIZE - 1) begin
             buf_flag <= 0;
           end

           w_idx <= 0;

           if(h_idx == HEIGHT - FILTER_SIZE) begin // done 1 input read
             h_idx <= 0;
             state <= 0;
           end
           h_idx <= h_idx + 1;

         end else if(w_idx == 0) begin
           valid_out_buf <= 1'b1;  // start valid area
         end

         // Buffer Selection -> 5 * 5 (동일)
         if(buf_flag == 3'd0) begin
           data_out_0 <= buffer[w_idx];
           data_out_1 <= buffer[w_idx + 1];
           data_out_2 <= buffer[w_idx + 2];
           data_out_3 <= buffer[w_idx + 3];
           data_out_4 <= buffer[w_idx + 4];

           data_out_5 <= buffer[w_idx + WIDTH];
           data_out_6 <= buffer[w_idx + 1 + WIDTH];
           data_out_7 <= buffer[w_idx + 2 + WIDTH];
           data_out_8 <= buffer[w_idx + 3 + WIDTH];
           data_out_9 <= buffer[w_idx + 4 + WIDTH];

           data_out_10 <= buffer[w_idx + WIDTH * 2];
           data_out_11 <= buffer[w_idx + 1 + WIDTH * 2];
           data_out_12 <= buffer[w_idx + 2 + WIDTH * 2];
           data_out_13 <= buffer[w_idx + 3 + WIDTH * 2];
           data_out_14 <= buffer[w_idx + 4 + WIDTH * 2];

           data_out_15 <= buffer[w_idx + WIDTH * 3];
           data_out_16 <= buffer[w_idx + 1 + WIDTH * 3];
           data_out_17 <= buffer[w_idx + 2 + WIDTH * 3];
           data_out_18 <= buffer[w_idx + 3 + WIDTH * 3];
           data_out_19 <= buffer[w_idx + 4 + WIDTH * 3];

           data_out_20 <= buffer[w_idx + WIDTH * 4];
           data_out_21 <= buffer[w_idx + 1 + WIDTH * 4];
           data_out_22 <= buffer[w_idx + 2 + WIDTH * 4];
           data_out_23 <= buffer[w_idx + 3 + WIDTH * 4];
           data_out_24 <= buffer[w_idx + 4 + WIDTH * 4];
         end else if(buf_flag == 3'd1) begin
           data_out_0 <= buffer[w_idx + WIDTH];
           data_out_1 <= buffer[w_idx + 1 + WIDTH];
           data_out_2 <= buffer[w_idx + 2 + WIDTH];
           data_out_3 <= buffer[w_idx + 3 + WIDTH];
           data_out_4 <= buffer[w_idx + 4 + WIDTH];

           data_out_5 <= buffer[w_idx + WIDTH * 2];
           data_out_6 <= buffer[w_idx + 1 + WIDTH * 2];
           data_out_7 <= buffer[w_idx + 2 + WIDTH * 2];
           data_out_8 <= buffer[w_idx + 3 + WIDTH * 2];
           data_out_9 <= buffer[w_idx + 4 + WIDTH * 2];

           data_out_10 <= buffer[w_idx + WIDTH * 3];
           data_out_11 <= buffer[w_idx + 1 + WIDTH * 3];
           data_out_12 <= buffer[w_idx + 2 + WIDTH * 3];
           data_out_13 <= buffer[w_idx + 3 + WIDTH * 3];
           data_out_14 <= buffer[w_idx + 4 + WIDTH * 3];

           data_out_15 <= buffer[w_idx + WIDTH * 4];
           data_out_16 <= buffer[w_idx + 1 + WIDTH * 4];
           data_out_17 <= buffer[w_idx + 2 + WIDTH * 4];
           data_out_18 <= buffer[w_idx + 3 + WIDTH * 4];
           data_out_19 <= buffer[w_idx + 4 + WIDTH * 4];

           data_out_20 <= buffer[w_idx];
           data_out_21 <= buffer[w_idx + 1];
           data_out_22 <= buffer[w_idx + 2];
           data_out_23 <= buffer[w_idx + 3];
           data_out_24 <= buffer[w_idx + 4];
         end else if(buf_flag == 3'd2) begin
           data_out_0 <= buffer[w_idx + WIDTH * 2];
           data_out_1 <= buffer[w_idx + 1 + WIDTH * 2];
           data_out_2 <= buffer[w_idx + 2 + WIDTH * 2];
           data_out_3 <= buffer[w_idx + 3 + WIDTH * 2];
           data_out_4 <= buffer[w_idx + 4 + WIDTH * 2];

           data_out_5 <= buffer[w_idx + WIDTH * 3];
           data_out_6 <= buffer[w_idx + 1 + WIDTH * 3];
           data_out_7 <= buffer[w_idx + 2 + WIDTH * 3];
           data_out_8 <= buffer[w_idx + 3 + WIDTH * 3];
           data_out_9 <= buffer[w_idx + 4 + WIDTH * 3];

           data_out_10 <= buffer[w_idx + WIDTH * 4];
           data_out_11 <= buffer[w_idx + 1 + WIDTH * 4];
           data_out_12 <= buffer[w_idx + 2 + WIDTH * 4];
           data_out_13 <= buffer[w_idx + 3 + WIDTH * 4];
           data_out_14 <= buffer[w_idx + 4 + WIDTH * 4];

           data_out_15 <= buffer[w_idx];
           data_out_16 <= buffer[w_idx + 1];
           data_out_17 <= buffer[w_idx + 2];
           data_out_18 <= buffer[w_idx + 3];
           data_out_19 <= buffer[w_idx + 4];

           data_out_20 <= buffer[w_idx + WIDTH];
           data_out_21 <= buffer[w_idx + 1 + WIDTH];
           data_out_22 <= buffer[w_idx + 2 + WIDTH];
           data_out_23 <= buffer[w_idx + 3 + WIDTH];
           data_out_24 <= buffer[w_idx + 4 + WIDTH];
         end else if(buf_flag == 3'd3) begin
           data_out_0 <= buffer[w_idx + WIDTH * 3];
           data_out_1 <= buffer[w_idx + 1 + WIDTH * 3];
           data_out_2 <= buffer[w_idx + 2 + WIDTH * 3];
           data_out_3 <= buffer[w_idx + 3 + WIDTH * 3];
           data_out_4 <= buffer[w_idx + 4 + WIDTH * 3];

           data_out_5 <= buffer[w_idx + WIDTH * 4];
           data_out_6 <= buffer[w_idx + 1 + WIDTH * 4];
           data_out_7 <= buffer[w_idx + 2 + WIDTH * 4];
           data_out_8 <= buffer[w_idx + 3 + WIDTH * 4];
           data_out_9 <= buffer[w_idx + 4 + WIDTH * 4];

           data_out_10 <= buffer[w_idx];
           data_out_11 <= buffer[w_idx + 1];
           data_out_12 <= buffer[w_idx + 2];
           data_out_13 <= buffer[w_idx + 3];
           data_out_14 <= buffer[w_idx + 4];

           data_out_15 <= buffer[w_idx + WIDTH];
           data_out_16 <= buffer[w_idx + 1 + WIDTH];
           data_out_17 <= buffer[w_idx + 2 + WIDTH];
           data_out_18 <= buffer[w_idx + 3 + WIDTH];
           data_out_19 <= buffer[w_idx + 4 + WIDTH];

           data_out_20 <= buffer[w_idx + WIDTH * 2];
           data_out_21 <= buffer[w_idx + 1 + WIDTH * 2];
           data_out_22 <= buffer[w_idx + 2 + WIDTH * 2];
           data_out_23 <= buffer[w_idx + 3 + WIDTH * 2];
           data_out_24 <= buffer[w_idx + 4 + WIDTH * 2];      
         end else if(buf_flag == 3'd4) begin
           data_out_0 <= buffer[w_idx + WIDTH * 4];
           data_out_1 <= buffer[w_idx + 1 + WIDTH * 4];
           data_out_2 <= buffer[w_idx + 2 + WIDTH * 4];
           data_out_3 <= buffer[w_idx + 3 + WIDTH * 4];
           data_out_4 <= buffer[w_idx + 4 + WIDTH * 4];

           data_out_5 <= buffer[w_idx];
           data_out_6 <= buffer[w_idx + 1];
           data_out_7 <= buffer[w_idx + 2];
           data_out_8 <= buffer[w_idx + 3];
           data_out_9 <= buffer[w_idx + 4];

           data_out_10 <= buffer[w_idx + WIDTH];
           data_out_11 <= buffer[w_idx + 1 + WIDTH];
           data_out_12 <= buffer[w_idx + 2 + WIDTH];
           data_out_13 <= buffer[w_idx + 3 + WIDTH];
           data_out_14 <= buffer[w_idx + 4 + WIDTH];

           data_out_15 <= buffer[w_idx + WIDTH * 2];
           data_out_16 <= buffer[w_idx + 1 + WIDTH * 2];
           data_out_17 <= buffer[w_idx + 2 + WIDTH * 2];
           data_out_18 <= buffer[w_idx + 3 + WIDTH * 2];
           data_out_19 <= buffer[w_idx + 4 + WIDTH * 2];

           data_out_20 <= buffer[w_idx + WIDTH * 3];
           data_out_21 <= buffer[w_idx + 1 + WIDTH * 3];
           data_out_22 <= buffer[w_idx + 2 + WIDTH * 3];
           data_out_23 <= buffer[w_idx + 3 + WIDTH * 3];
           data_out_24 <= buffer[w_idx + 4 + WIDTH * 3];   
         end
       end
     end
   end
end
endmodule

/*-------------------------------------------------------------------
 *  conv2_calc_ternary : -1/0/+1 가중치 → add/sub/skip, 채널별 합산 원시 psum 출력
 *  adder_tree25_pipe(IN_W=DATA_BITS+1, SUM_W=DATA_BITS+6) 필요
 *------------------------------------------------------------------*/
module conv2_calc #(
  parameter integer DATA_BITS = 12,
  parameter integer K         = 5,
  parameter integer N_TAPS    = K*K,
  parameter integer ADD_W     = DATA_BITS+1, // ±x 용 부호확장
  parameter integer SUM_W     = DATA_BITS+6, // 25개 합산 여유
  parameter integer LAT_TREE  = 5            // adder_tree 내부 파이프 단계
)(
  input  wire                    clk,
  input  wire                    rst_n,
  input  wire                    valid_out_buf,

  input  wire [0:DATA_BITS*N_TAPS-1] x_1,
  input  wire [0:DATA_BITS*N_TAPS-1] x_2,
  input  wire [0:DATA_BITS*N_TAPS-1] x_3,

  input  wire [0:199] w_1,
  input  wire [0:199] w_2,
  input  wire [0:199] w_3,

  output reg  signed [SUM_W-1:0] psum_raw,
  output reg                     valid_out_calc
);
  localparam B_W = DATA_BITS;

  // x 슬라이스
  wire signed [B_W-1:0] x1 [0:N_TAPS-1];
  wire signed [B_W-1:0] x2 [0:N_TAPS-1];
  wire signed [B_W-1:0] x3 [0:N_TAPS-1];

  genvar xi;
  generate
    for (xi=0; xi<N_TAPS; xi=xi+1) begin: XSLICE
      assign x1[xi] = x_1[(B_W*xi)+:B_W];
      assign x2[xi] = x_2[(B_W*xi)+:B_W];
      assign x3[xi] = x_3[(B_W*xi)+:B_W];
    end
  endgenerate

  // w 슬라이스(8b로 들어오되 값은 -1/0/+1)
  wire signed [7:0] w1 [0:N_TAPS-1];
  wire signed [7:0] w2 [0:N_TAPS-1];
  wire signed [7:0] w3 [0:N_TAPS-1];

  genvar wi;
  generate
    for (wi=0; wi<N_TAPS; wi=wi+1) begin: WSLICE
      assign w1[wi] = w_1[(8*wi)+:8];
      assign w2[wi] = w_2[(8*wi)+:8];
      assign w3[wi] = w_3[(8*wi)+:8];
    end
  endgenerate

  // add/sub/skip addend
  wire signed [ADD_W-1:0] a1 [0:N_TAPS-1];
  wire signed [ADD_W-1:0] a2 [0:N_TAPS-1];
  wire signed [ADD_W-1:0] a3 [0:N_TAPS-1];

  genvar ti;
  generate
    for (ti=0; ti<N_TAPS; ti=ti+1) begin: ADDENDS
      wire is_pos1 = (w1[ti] ==  8'sd1);
      wire is_neg1 = (w1[ti] == -8'sd1);
      wire is_pos2 = (w2[ti] ==  8'sd1);
      wire is_neg2 = (w2[ti] == -8'sd1);
      wire is_pos3 = (w3[ti] ==  8'sd1);
      wire is_neg3 = (w3[ti] == -8'sd1);

      wire signed [ADD_W-1:0] x1e = {{(ADD_W-B_W){x1[ti][B_W-1]}}, x1[ti]};
      wire signed [ADD_W-1:0] x2e = {{(ADD_W-B_W){x2[ti][B_W-1]}}, x2[ti]};
      wire signed [ADD_W-1:0] x3e = {{(ADD_W-B_W){x3[ti][B_W-1]}}, x3[ti]};

      assign a1[ti] = is_pos1 ?  x1e : (is_neg1 ? -x1e : 0);
      assign a2[ti] = is_pos2 ?  x2e : (is_neg2 ? -x2e : 0);
      assign a3[ti] = is_pos3 ?  x3e : (is_neg3 ? -x3e : 0);
    end
  endgenerate

  // 25개 합산(채널별)
  wire signed [SUM_W-1:0] sum1, sum2, sum3;

  adder_tree25_pipe #(.IN_W(ADD_W), .SUM_W(SUM_W)) AT1 (
    .clk(clk), .rst_n(rst_n),
    .in0(a1[0]),  .in1(a1[1]),  .in2(a1[2]),  .in3(a1[3]),  .in4(a1[4]),
    .in5(a1[5]),  .in6(a1[6]),  .in7(a1[7]),  .in8(a1[8]),  .in9(a1[9]),
    .in10(a1[10]),.in11(a1[11]),.in12(a1[12]),.in13(a1[13]),.in14(a1[14]),
    .in15(a1[15]),.in16(a1[16]),.in17(a1[17]),.in18(a1[18]),.in19(a1[19]),
    .in20(a1[20]),.in21(a1[21]),.in22(a1[22]),.in23(a1[23]),.in24(a1[24]),
    .sum(sum1)
  );
  adder_tree25_pipe #(.IN_W(ADD_W), .SUM_W(SUM_W)) AT2 (
    .clk(clk), .rst_n(rst_n),
    .in0(a2[0]),  .in1(a2[1]),  .in2(a2[2]),  .in3(a2[3]),  .in4(a2[4]),
    .in5(a2[5]),  .in6(a2[6]),  .in7(a2[7]),  .in8(a2[8]),  .in9(a2[9]),
    .in10(a2[10]),.in11(a2[11]),.in12(a2[12]),.in13(a2[13]),.in14(a2[14]),
    .in15(a2[15]),.in16(a2[16]),.in17(a2[17]),.in18(a2[18]),.in19(a2[19]),
    .in20(a2[20]),.in21(a2[21]),.in22(a2[22]),.in23(a2[23]),.in24(a2[24]),
    .sum(sum2)
  );
  adder_tree25_pipe #(.IN_W(ADD_W), .SUM_W(SUM_W)) AT3 (
    .clk(clk), .rst_n(rst_n),
    .in0(a3[0]),  .in1(a3[1]),  .in2(a3[2]),  .in3(a3[3]),  .in4(a3[4]),
    .in5(a3[5]),  .in6(a3[6]),  .in7(a3[7]),  .in8(a3[8]),  .in9(a3[9]),
    .in10(a3[10]),.in11(a3[11]),.in12(a3[12]),.in13(a3[13]),.in14(a3[14]),
    .in15(a3[15]),.in16(a3[16]),.in17(a3[17]),.in18(a3[18]),.in19(a3[19]),
    .in20(a3[20]),.in21(a3[21]),.in22(a3[22]),.in23(a3[23]),.in24(a3[24]),
    .sum(sum3)
  );

  // 합 + valid 파이프
  reg [LAT_TREE-1:0] vpipe;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) vpipe <= 0;
    else        vpipe <= {vpipe[LAT_TREE-2:0], valid_out_buf};
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      psum_raw       <= 0;
      valid_out_calc <= 1'b0;
    end else begin
      psum_raw       <= sum1 + sum2 + sum3;
      valid_out_calc <= vpipe[LAT_TREE-1];
    end
  end
  
  
endmodule

