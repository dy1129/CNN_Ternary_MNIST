/*------------------------------------------------------------------------
 *
 *  Copyright (c) 2021 by Bo Young Kang, All rights reserved.
 *
 *  File name  : conv1_layer.v
 *  Written by : Kang, Bo Young
 *  Written on : Sep 30, 2021
 *  Version    : 21.2
 *  Design     : 1st Convolution Layer for CNN MNIST dataset
 *
 *------------------------------------------------------------------------*/

/*-------------------------------------------------------------------
 *  Module: conv1_layer  
 *------------------------------------------------------------------*/
`timescale 1ps/1ps

module conv1_layer (
  input  clk,
  input  rst_n,
  input  [7:0] data_in,

  output [11:0] conv_out_1, conv_out_2, conv_out_3,
  output        valid_out_conv,

  // weights/bias (버스 방향 기존 그대로)
  input  [0:199] w_11,
  input  [0:199] w_12,
  input  [0:199] w_13,
  input  [0:23]  b_1,

  input  signed [15:0] scale_1,
  input  signed [15:0] scale_2,
  input  signed [15:0] scale_3
);

  wire [7:0] data_out_0, data_out_1, data_out_2, data_out_3, data_out_4,
             data_out_5, data_out_6, data_out_7, data_out_8, data_out_9,
             data_out_10, data_out_11, data_out_12, data_out_13, data_out_14,
             data_out_15, data_out_16, data_out_17, data_out_18, data_out_19,
             data_out_20, data_out_21, data_out_22, data_out_23, data_out_24;
  wire valid_out_buf;

  conv1_buf #(.WIDTH(28), .HEIGHT(28), .DATA_BITS(8)) u_conv1_buf (
    .clk(clk), .rst_n(rst_n), .data_in(data_in),
    .data_out_0(data_out_0),   .data_out_1(data_out_1),   .data_out_2(data_out_2),
    .data_out_3(data_out_3),   .data_out_4(data_out_4),   .data_out_5(data_out_5),
    .data_out_6(data_out_6),   .data_out_7(data_out_7),   .data_out_8(data_out_8),
    .data_out_9(data_out_9),   .data_out_10(data_out_10), .data_out_11(data_out_11),
    .data_out_12(data_out_12), .data_out_13(data_out_13), .data_out_14(data_out_14),
    .data_out_15(data_out_15), .data_out_16(data_out_16), .data_out_17(data_out_17),
    .data_out_18(data_out_18), .data_out_19(data_out_19), .data_out_20(data_out_20),
    .data_out_21(data_out_21), .data_out_22(data_out_22), .data_out_23(data_out_23),
    .data_out_24(data_out_24),
    .valid_out_buf(valid_out_buf)
  );


  conv1_calc #(.DATA_BITS(8), .MUL_LAT(1), .SHIFT_S(15)) u_conv1_calc (
    .clk(clk), .rst_n(rst_n),
    .valid_out_buf(valid_out_buf),

    .data_out_0(data_out_0),   .data_out_1(data_out_1),   .data_out_2(data_out_2),
    .data_out_3(data_out_3),   .data_out_4(data_out_4),   .data_out_5(data_out_5),
    .data_out_6(data_out_6),   .data_out_7(data_out_7),   .data_out_8(data_out_8),
    .data_out_9(data_out_9),   .data_out_10(data_out_10), .data_out_11(data_out_11),
    .data_out_12(data_out_12), .data_out_13(data_out_13), .data_out_14(data_out_14),
    .data_out_15(data_out_15), .data_out_16(data_out_16), .data_out_17(data_out_17),
    .data_out_18(data_out_18), .data_out_19(data_out_19), .data_out_20(data_out_20),
    .data_out_21(data_out_21), .data_out_22(data_out_22), .data_out_23(data_out_23),
    .data_out_24(data_out_24),

    .w_11(w_11), .w_12(w_12), .w_13(w_13), .b_1(b_1),

    .scale_1(scale_1), .scale_2(scale_2), .scale_3(scale_3),

    .conv_out_1(conv_out_1), .conv_out_2(conv_out_2), .conv_out_3(conv_out_3),
    .valid_out_calc(valid_out_conv)
  );
  
  
endmodule




/*------------------------------------------------------------------------
 *
 *  Copyright (c) 2021 by Bo Young Kang, All rights reserved.
 *
 *  File name  : conv1_buf.v
 *  Written by : Kang, Bo Young
 *  Written on : Sep 30, 2021
 *  Version    : 21.2
 *  Design     : 1st Convolution Layer for CNN MNIST dataset
 *               Input Buffer
 *
 *------------------------------------------------------------------------*/

/*-------------------------------------------------------------------
 *  Module: conv1_buf
 *------------------------------------------------------------------*/
 
 module conv1_buf #(parameter WIDTH = 28, HEIGHT = 28, DATA_BITS = 8)(
   input clk,
   input rst_n,
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
 reg [DATA_BITS - 1:0] buf_idx;
 reg [4:0] w_idx, h_idx;
 reg [2:0] buf_flag;  // 0 ~ 4
 reg state;

 always @(posedge clk) begin
   if(~rst_n) begin
     buf_idx <= -1;
     w_idx <= 0;
     h_idx <= 0;
     buf_flag <= 0;
     state <= 0;
     valid_out_buf <= 0;
     data_out_0 <= 12'bx;
     data_out_1 <= 12'bx;
     data_out_2 <= 12'bx;
     data_out_3 <= 12'bx;
     data_out_4 <= 12'bx;
     data_out_5 <= 12'bx;
     data_out_6 <= 12'bx;
     data_out_7 <= 12'bx;
     data_out_8 <= 12'bx;
     data_out_9 <= 12'bx;
     data_out_10 <= 12'bx;
     data_out_11 <= 12'bx;
     data_out_12 <= 12'bx;
     data_out_13 <= 12'bx;
     data_out_14 <= 12'bx;
     data_out_15 <= 12'bx;
     data_out_16 <= 12'bx;
     data_out_17 <= 12'bx;
     data_out_18 <= 12'bx;
     data_out_19 <= 12'bx;
     data_out_20 <= 12'bx;
     data_out_21 <= 12'bx;
     data_out_22 <= 12'bx;
     data_out_23 <= 12'bx;
     data_out_24 <= 12'bx;
   end else begin
   buf_idx <= buf_idx + 1;
   if(buf_idx == WIDTH * FILTER_SIZE - 1) begin // buffer size = 140 = 28(w) * 5(h)
     buf_idx <= 0;
   end
   
   buffer[buf_idx] <= data_in;  // data input
   
   // Wait until first 140 input data filled in buffer
   if(!state) begin
     if(buf_idx == WIDTH * FILTER_SIZE - 1) begin
       state <= 1'b1;
     end
   end else begin // valid state
     w_idx <= w_idx + 1'b1; // move right

     if(w_idx == WIDTH - FILTER_SIZE + 1) begin
       valid_out_buf <= 1'b0; // unvalid area
     end else if(w_idx == WIDTH - 1) begin
       buf_flag <= buf_flag + 1'b1;
       if(buf_flag == FILTER_SIZE - 1) begin
         buf_flag <= 0;
       end
       w_idx <= 0;

       if(h_idx == HEIGHT - FILTER_SIZE) begin  // done 1 input read -> 28 * 28
         h_idx <= 0;
         state <= 1'b0;
       end 
       
       h_idx <= h_idx + 1'b1;

     end else if(w_idx == 0) begin
       valid_out_buf <= 1'b1; // start valid area
     end

     // Buffer Selection -> 5 * 5
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
// integer nz;
//always @(posedge clk) begin
//  if (valid_out_buf) begin
    
//    nz = (data_out_0!=0)+(data_out_1!=0)+(data_out_2!=0)+(data_out_3!=0)+(data_out_4!=0)
//       + (data_out_5!=0)+(data_out_6!=0)+(data_out_7!=0)+(data_out_8!=0)+(data_out_9!=0)
//       + (data_out_10!=0)+(data_out_11!=0)+(data_out_12!=0)+(data_out_13!=0)+(data_out_14!=0)
//       + (data_out_15!=0)+(data_out_16!=0)+(data_out_17!=0)+(data_out_18!=0)+(data_out_19!=0)
//       + (data_out_20!=0)+(data_out_21!=0)+(data_out_22!=0)+(data_out_23!=0)+(data_out_24!=0);
//    $display("[BUF] w=%0d h=%0d valid=1  nonzero=%0d  d0..4=%0d,%0d,%0d,%0d,%0d",
//             w_idx, h_idx, nz, data_out_0, data_out_1, data_out_2, data_out_3, data_out_4);
//  end else begin
//    $display("[BUF] w=%0d h=%0d valid=0", w_idx, h_idx);
//  end
//end



endmodule

/*------------------------------------------------------------------------
 *
 *  Copyright (c) 2021 by Bo Young Kang, All rights reserved.
 *
 *  File name  : conv1_calc.v
 *  Written by : Kang, Bo Young
 *  Written on : Oct 1, 2021
 *  Version    : 21.2
 *  Design     : 1st Convolution Layer for CNN MNIST dataset
 *               Convolution Sum Calculation
 *
 *------------------------------------------------------------------------*/

/*------------------------------------------------------------------------
 *
 * Copyright (c) 2021 by Bo Young Kang, All rights reserved.
 *
 * File name  : conv1_calc.v
 * Written by : Kang, Bo Young
 * Written on : Oct 1, 2021
 * Version    : 21.2
 * Design     : 1st Convolution Layer for CNN MNIST dataset
 * Convolution Sum Calculation
 *
 *------------------------------------------------------------------------*/

/*-------------------------------------------------------------------
 * Module: conv1_calc 
 * - 25탭 × 3채널 곱-합
 *------------------------------------------------------------------*/
module conv1_calc #(
  parameter integer DATA_BITS = 8,
  parameter integer MUL_LAT   = 1,   // 곱 파이프
  parameter integer SHIFT_S   = 15   
)(
  input  wire clk,
  input  wire rst_n,

  input  wire valid_out_buf,

  input  wire [DATA_BITS-1:0] data_out_0,  input wire [DATA_BITS-1:0] data_out_1,
  input  wire [DATA_BITS-1:0] data_out_2,  input wire [DATA_BITS-1:0] data_out_3,
  input  wire [DATA_BITS-1:0] data_out_4,  input wire [DATA_BITS-1:0] data_out_5,
  input  wire [DATA_BITS-1:0] data_out_6,  input wire [DATA_BITS-1:0] data_out_7,
  input  wire [DATA_BITS-1:0] data_out_8,  input wire [DATA_BITS-1:0] data_out_9,
  input  wire [DATA_BITS-1:0] data_out_10, input wire [DATA_BITS-1:0] data_out_11,
  input  wire [DATA_BITS-1:0] data_out_12, input wire [DATA_BITS-1:0] data_out_13,
  input  wire [DATA_BITS-1:0] data_out_14, input wire [DATA_BITS-1:0] data_out_15,
  input  wire [DATA_BITS-1:0] data_out_16, input wire [DATA_BITS-1:0] data_out_17,
  input  wire [DATA_BITS-1:0] data_out_18, input wire [DATA_BITS-1:0] data_out_19,
  input  wire [DATA_BITS-1:0] data_out_20, input wire [DATA_BITS-1:0] data_out_21,
  input  wire [DATA_BITS-1:0] data_out_22, input wire [DATA_BITS-1:0] data_out_23,
  input  wire [DATA_BITS-1:0] data_out_24,

  input  wire [0:199] w_11, input wire [0:199] w_12, input wire [0:199] w_13,
  input  wire [0:23]  b_1,

  input  wire signed [15:0] scale_1,
  input  wire signed [15:0] scale_2,
  input  wire signed [15:0] scale_3,

  output reg  signed [11:0] conv_out_1,
  output reg  signed [11:0] conv_out_2,
  output reg  signed [11:0] conv_out_3,
  output wire               valid_out_calc
);
  localparam integer K        = 5;
  localparam integer N_TAPS   = K*K;                  // 25
  localparam integer A_W      = DATA_BITS + 1;        // 9  (px: 8u → 9s 0-확장)
  localparam integer B_W      = DATA_BITS;            // 8  (weight)
  localparam integer MUL_W    = A_W + B_W;            // 17 (곱 결과)
  localparam integer SUM_W    = 22;                   // 17 + ceil(log2(25)) ? 22
  localparam integer LAT_TREE = 5;                    // adder tree 파이프 단계
  localparam integer LAT_OUT  = 2;                  // <--- 수정됨: 출력 레지스터 1 -> 2
  localparam integer LAT_TOT  = MUL_LAT + LAT_TREE + LAT_OUT; // <--- 총 레이턴시 7 -> 8
  
  // *********** NEW: 최종 단계 분리를 위한 레지스터 추가 ***********
  reg signed [31:0] s1_sc_r, s2_sc_r, s3_sc_r; // 스케일/시프트 결과 저장 (32b)
  reg signed [11:0] bias1_r, bias2_r, bias3_r; // 바이어스 래치 (12b)
  // -------------------------------------------------------------


  // === Stage-0: 입력/valid 1클럭 래치 ===
reg [DATA_BITS-1:0] din_r [0:24];
reg                 vbuf_r;
integer di;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    for (di=0; di<25; di=di+1) din_r[di] <= {DATA_BITS{1'b0}};
    vbuf_r <= 1'b0;
  end else begin
    // data_out_* 는 매클럭 갱신, valid는 그대로 래치
    din_r[ 0] <= data_out_0 ; din_r[ 1] <= data_out_1 ; din_r[ 2] <= data_out_2 ;
    din_r[ 3] <= data_out_3 ; din_r[ 4] <= data_out_4 ; din_r[ 5] <= data_out_5 ;
    din_r[ 6] <= data_out_6 ; din_r[ 7] <= data_out_7 ; din_r[ 8] <= data_out_8 ;
    din_r[ 9] <= data_out_9 ; din_r[10] <= data_out_10; din_r[11] <= data_out_11;
    din_r[12] <= data_out_12; din_r[13] <= data_out_13; din_r[14] <= data_out_14;
    din_r[15] <= data_out_15; din_r[16] <= data_out_16; din_r[17] <= data_out_17;
    din_r[18] <= data_out_18; din_r[19] <= data_out_19; din_r[20] <= data_out_20;
    din_r[21] <= data_out_21; din_r[22] <= data_out_22; din_r[23] <= data_out_23;
    din_r[24] <= data_out_24;
    vbuf_r    <= valid_out_buf;
  end
end

// 래치된 입력으로 x 생성 (0-확장 9b)
wire signed [A_W-1:0] x [0:N_TAPS-1];
genvar xi;
generate for (xi=0; xi<25; xi=xi+1) begin: XCAST
  assign x[xi] = $signed({1'b0, din_r[xi]});
end endgenerate

 // ===== 가중치/바이어스 언팩 =====
  reg  signed [B_W-1:0] w1 [0:N_TAPS-1], w2 [0:N_TAPS-1], w3 [0:N_TAPS-1];
  reg  signed [7:0]     b  [0:2];

  integer i;
  always @* begin
    for (i=0; i<N_TAPS; i=i+1) begin
      w1[i] = w_11[(8*i)+:8];
      w2[i] = w_12[(8*i)+:8];
      w3[i] = w_13[(8*i)+:8];
    end
    b[0] = b_1[ 0 +: 8];
    b[1] = b_1[ 8 +: 8];
    b[2] = b_1[16 +: 8];
  end

  wire signed [11:0] bias1 = b[0][7] ? {4'hF, b[0]} : {4'h0, b[0]};
  wire signed [11:0] bias2 = b[1][7] ? {4'hF, b[1]} : {4'h0, b[1]};
  wire signed [11:0] bias3 = b[2][7] ? {4'hF, b[2]} : {4'h0, b[2]};

  // ===== 25×3 곱 (MUL_LAT 파이프) =====
  (* use_dsp="yes" *) wire signed [MUL_W-1:0] p1_w [0:N_TAPS-1];
  (* use_dsp="yes" *) wire signed [MUL_W-1:0] p2_w [0:N_TAPS-1];
  (* use_dsp="yes" *) wire signed [MUL_W-1:0] p3_w [0:N_TAPS-1];

  genvar gi;
  generate
    for (gi=0; gi<N_TAPS; gi=gi+1) begin: MULS
      assign p1_w[gi] = x[gi] * w1[gi];
      assign p2_w[gi] = x[gi] * w2[gi];
      assign p3_w[gi] = x[gi] * w3[gi];
    end
  endgenerate

  // 곱 파이프 레지스터
  reg signed [MUL_W-1:0] p1 [0:MUL_LAT-1][0:N_TAPS-1];
  reg signed [MUL_W-1:0] p2 [0:MUL_LAT-1][0:N_TAPS-1];
  reg signed [MUL_W-1:0] p3 [0:MUL_LAT-1][0:N_TAPS-1];

  integer m,n;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (m=0; m<MUL_LAT; m=m+1)
        for (n=0; n<N_TAPS; n=n+1) begin
          p1[m][n] <= {MUL_W{1'b0}};
          p2[m][n] <= {MUL_W{1'b0}};
          p3[m][n] <= {MUL_W{1'b0}};
        end
    end else begin
      // shift
      for (m=MUL_LAT-1; m>0; m=m-1)
        for (n=0; n<N_TAPS; n=n+1) begin
          p1[m][n] <= p1[m-1][n];
          p2[m][n] <= p2[m-1][n];
          p3[m][n] <= p3[m-1][n];
        end
      // insert
      for (n=0; n<N_TAPS; n=n+1) begin
          p1[0][n] <= vbuf_r ? p1_w[n] : {MUL_W{1'b0}};
          p2[0][n] <= vbuf_r ? p2_w[n] : {MUL_W{1'b0}};
          p3[0][n] <= vbuf_r ? p3_w[n] : {MUL_W{1'b0}};
        end
    end
  end

  // ===== 25→1 adder tree (채널별) =====
wire signed [SUM_W-1:0] sum1;
wire signed [SUM_W-1:0] sum2;
wire signed [SUM_W-1:0] sum3;

  // [!!!] 32비트로 올바르게 수동 부호 확장 (Sign-Extension)
  wire signed [31:0] sum1_se = {{(32-SUM_W){sum1[SUM_W-1]}}, sum1};
  wire signed [31:0] sum2_se = {{(32-SUM_W){sum2[SUM_W-1]}}, sum2};
  wire signed [31:0] sum3_se = {{(32-SUM_W){sum3[SUM_W-1]}}, sum3};
    

  adder_tree25_pipe #(.IN_W(MUL_W), .SUM_W(SUM_W)) AT1 (
    .clk(clk), .rst_n(rst_n),
    .in0(p1[MUL_LAT-1][0]),  .in1(p1[MUL_LAT-1][1]),  .in2(p1[MUL_LAT-1][2]),
    .in3(p1[MUL_LAT-1][3]),  .in4(p1[MUL_LAT-1][4]),  .in5(p1[MUL_LAT-1][5]),
    .in6(p1[MUL_LAT-1][6]),  .in7(p1[MUL_LAT-1][7]),  .in8(p1[MUL_LAT-1][8]),
    .in9(p1[MUL_LAT-1][9]),  .in10(p1[MUL_LAT-1][10]),.in11(p1[MUL_LAT-1][11]),
    .in12(p1[MUL_LAT-1][12]),.in13(p1[MUL_LAT-1][13]),.in14(p1[MUL_LAT-1][14]),
    .in15(p1[MUL_LAT-1][15]),.in16(p1[MUL_LAT-1][16]),.in17(p1[MUL_LAT-1][17]),
    .in18(p1[MUL_LAT-1][18]),.in19(p1[MUL_LAT-1][19]),.in20(p1[MUL_LAT-1][20]),
    .in21(p1[MUL_LAT-1][21]),.in22(p1[MUL_LAT-1][22]),.in23(p1[MUL_LAT-1][23]),
    .in24(p1[MUL_LAT-1][24]),
    .sum(sum1)
  );

  adder_tree25_pipe #(.IN_W(MUL_W), .SUM_W(SUM_W)) AT2 (
    .clk(clk), .rst_n(rst_n),
    .in0(p2[MUL_LAT-1][0]),  .in1(p2[MUL_LAT-1][1]),  .in2(p2[MUL_LAT-1][2]),
    .in3(p2[MUL_LAT-1][3]),  .in4(p2[MUL_LAT-1][4]),  .in5(p2[MUL_LAT-1][5]),
    .in6(p2[MUL_LAT-1][6]),  .in7(p2[MUL_LAT-1][7]),  .in8(p2[MUL_LAT-1][8]),
    .in9(p2[MUL_LAT-1][9]),  .in10(p2[MUL_LAT-1][10]),.in11(p2[MUL_LAT-1][11]),
    .in12(p2[MUL_LAT-1][12]),.in13(p2[MUL_LAT-1][13]),.in14(p2[MUL_LAT-1][14]),
    .in15(p2[MUL_LAT-1][15]),.in16(p2[MUL_LAT-1][16]),.in17(p2[MUL_LAT-1][17]),
    .in18(p2[MUL_LAT-1][18]),.in19(p2[MUL_LAT-1][19]),.in20(p2[MUL_LAT-1][20]),
    .in21(p2[MUL_LAT-1][21]),.in22(p2[MUL_LAT-1][22]),.in23(p2[MUL_LAT-1][23]),
    .in24(p2[MUL_LAT-1][24]),
    .sum(sum2)
  );

  adder_tree25_pipe #(.IN_W(MUL_W), .SUM_W(SUM_W)) AT3 (
    .clk(clk), .rst_n(rst_n),
    .in0(p3[MUL_LAT-1][0]), .in1(p3[MUL_LAT-1][1]), .in2(p3[MUL_LAT-1][2]),
    .in3(p3[MUL_LAT-1][3]), .in4(p3[MUL_LAT-1][4]), .in5(p3[MUL_LAT-1][5]),
    .in6(p3[MUL_LAT-1][6]), .in7(p3[MUL_LAT-1][7]), .in8(p3[MUL_LAT-1][8]),
    .in9(p3[MUL_LAT-1][9]), .in10(p3[MUL_LAT-1][10]), .in11(p3[MUL_LAT-1][11]),
    .in12(p3[MUL_LAT-1][12]), .in13(p3[MUL_LAT-1][13]), .in14(p3[MUL_LAT-1][14]),
    .in15(p3[MUL_LAT-1][15]), .in16(p3[MUL_LAT-1][16]), .in17(p3[MUL_LAT-1][17]),
    .in18(p3[MUL_LAT-1][18]), .in19(p3[MUL_LAT-1][19]), .in20(p3[MUL_LAT-1][20]),
    .in21(p3[MUL_LAT-1][21]), .in22(p3[MUL_LAT-1][22]), .in23(p3[MUL_LAT-1][23]),
    .in24(p3[MUL_LAT-1][24]),
    .sum(sum3)
  );

  // ===== valid 파이프 =====
  reg [LAT_TOT-1:0] vpipe;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) vpipe <= {LAT_TOT{1'b0}};
    else        vpipe <= {vpipe[LAT_TOT-2:0], vbuf_r};
  end
  assign valid_out_calc = vpipe[LAT_TOT-1];
  
  // ===== 포화 함수(12b) =====
  function automatic signed [11:0] sat12(input signed [31:0] v);
    begin
      if (v >  32'sd2047)      sat12 = 12'sd2047;
      else if (v < -32'sd2048) sat12 = -12'sd2048;
      else                     sat12 = v[11:0];
    end
  endfunction

  // --------------------------------------------------------------------------
  // === Stage 7: Scaling / Shift (Combinational -> Register) ===
  // --------------------------------------------------------------------------
  wire signed [31:0] s1_mul = sum1_se * $signed(scale_1);
  wire signed [31:0] s2_mul = sum2_se * $signed(scale_2);
  wire signed [31:0] s3_mul = sum3_se * $signed(scale_3);
  
  //>>>15 (Q1.15) 라운딩
  localparam integer ROUND = 1 << (SHIFT_S-1);
  wire signed [31:0] s1_sc_comb = (s1_mul + ROUND) >>> SHIFT_S;
  wire signed [31:0] s2_sc_comb = (s2_mul + ROUND) >>> SHIFT_S;
  wire signed [31:0] s3_sc_comb = (s3_mul + ROUND) >>> SHIFT_S;

  // *********** NEW: Stage 7 레지스터 ***********
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_sc_r <= 32'sd0;
      s2_sc_r <= 32'sd0;
      s3_sc_r <= 32'sd0;
      bias1_r <= 12'sd0;
      bias2_r <= 12'sd0;
      bias3_r <= 12'sd0;
    end else if (vpipe[LAT_TOT - LAT_OUT]) begin // Stage 7 Trigger (vpipe[6])
      s1_sc_r <= s1_sc_comb;
      s2_sc_r <= s2_sc_comb;
      s3_sc_r <= s3_sc_comb;
      // 바이어스도 함께 래치 (조합 로직이므로)
      bias1_r <= bias1;
      bias2_r <= bias2;
      bias3_r <= bias3;
    end
  end

  // --------------------------------------------------------------------------
  // === Stage 8: Bias / Saturation (Register -> Output) ===
  // --------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      conv_out_1 <= 12'sd0;
      conv_out_2 <= 12'sd0;
      conv_out_3 <= 12'sd0;
    end else if (vpipe[LAT_TOT - 1]) begin // Stage 8 Trigger (vpipe[7])
      // *********** MODIFIED: 레지스터 s_sc_r과 래치된 bias_r 사용 ***********
      conv_out_1 <= sat12( s1_sc_r + $signed(bias1_r) );
      conv_out_2 <= sat12( s2_sc_r + $signed(bias2_r) );
      conv_out_3 <= sat12( s3_sc_r + $signed(bias3_r) );
    end
  end
 
endmodule
