`timescale 1ps/1ps
module chip(
    input              clk,
    input              rst_n,
    input      [7:0]   data_in,
    output     [3:0]   decision,
    output             valid_out_6,

    // ===== TB가 주는 가중치/바이어스 =====
    // conv1
    input      [0:199] w_11,
    input      [0:199] w_12,
    input      [0:199] w_13,
    input      [0:23]  b_1,
    // ★ conv1 채널별 스케일(Q2.6 등)
    input signed [15:0] scale_1,
    input signed [15:0] scale_2,
    input signed [15:0] scale_3,

    // conv2 (TB → WB 입력)
    input      [0:23]  b_2,
    input      [0:199] w_211, w_212, w_213,
    input      [0:199] w_221, w_222, w_223,
    input      [0:199] w_231, w_232, w_233,

    // fully-connected
    input      [0:3839] w_fc,
    input      [0:79]   b_fc,
    input      [0:79]   fc_scale,

    // ===== conv2 α 및 WB 로드 트리거 =====
    input      [7:0]   alpha_1_tb,
    input      [7:0]   alpha_2_tb,
    input      [7:0]   alpha_3_tb,
    input              wb_load_tb
);

  // -----------------------------
  // 내부 배선
  // -----------------------------
  wire signed [11:0] conv_out_1, conv_out_2, conv_out_3;
  wire signed [11:0] conv2_out_1, conv2_out_2, conv2_out_3;
  wire signed [11:0] max_value_1, max_value_2, max_value_3;
  wire signed [11:0] max2_value_1, max2_value_2, max2_value_3;
  wire signed [11:0] fc_out_data;
  wire valid_out_1, valid_out_2, valid_out_3, valid_out_4, valid_out_5, pool2_in_valid;

  // =============================
  // WB: TB → (1클럭 래치) → conv2
  // =============================
  wire [0:199] w_211_wb, w_212_wb, w_213_wb;
  wire [0:199] w_221_wb, w_222_wb, w_223_wb;
  wire [0:199] w_231_wb, w_232_wb, w_233_wb;
  wire [0:23]  b_2_wb;
  wire [7:0]   alpha_1_wb, alpha_2_wb, alpha_3_wb;
  wire         wb_valid;

  WB_ternary u_wb2 (
    .clk        (clk),
    .rst_n      (rst_n),
    .wb_load    (wb_load_tb),
    .wb_valid   (wb_valid),

    .in_w_211   (w_211), .in_w_212 (w_212), .in_w_213 (w_213),
    .in_w_221   (w_221), .in_w_222 (w_222), .in_w_223 (w_223),
    .in_w_231   (w_231), .in_w_232 (w_232), .in_w_233 (w_233),
    .in_b_2     (b_2),
    .in_alpha_1 (alpha_1_tb), .in_alpha_2(alpha_2_tb), .in_alpha_3(alpha_3_tb),

    .w_211      (w_211_wb), .w_212 (w_212_wb), .w_213 (w_213_wb),
    .w_221      (w_221_wb), .w_222 (w_222_wb), .w_223 (w_223_wb),
    .w_231      (w_231_wb), .w_232 (w_232_wb), .w_233 (w_233_wb),
    .b_2        (b_2_wb),
    .alpha_1    (alpha_1_wb), .alpha_2(alpha_2_wb), .alpha_3(alpha_3_wb)
  );

  // =============================
  // conv1  ← ★ 스케일 연결 추가됨
  // =============================
  conv1_layer u_conv1 (
    .clk            (clk),
    .rst_n          (rst_n),
    .data_in        (data_in),
    .conv_out_1     (conv_out_1),
    .conv_out_2     (conv_out_2),
    .conv_out_3     (conv_out_3),
    .valid_out_conv (valid_out_1),
    .w_11           (w_11),
    .w_12           (w_12),
    .w_13           (w_13),
    .b_1            (b_1),
    .scale_1        (scale_1),
    .scale_2        (scale_2),
    .scale_3        (scale_3)
  );

  // =============================
  // maxpool + ReLU (1)
  // =============================
  maxpool_relu #(
    .CONV_BIT(12), .HALF_WIDTH(24), .HALF_HEIGHT(24), .HALF_WIDTH_BIT(5)
  ) u_pool1 (
    .clk            (clk),
    .rst_n          (rst_n),
    .valid_in       (valid_out_1),
    .conv_out_1     (conv_out_1),
    .conv_out_2     (conv_out_2),
    .conv_out_3     (conv_out_3),
    .max_value_1    (max_value_1),
    .max_value_2    (max_value_2),
    .max_value_3    (max_value_3),
    .valid_out_relu (valid_out_2)
  );

  // =============================
  // conv2 (삼진 + α + bias)  ← WB 출력 연결
  // =============================
  conv2_layer u_conv2 (
    .clk            (clk),
    .rst_n          (rst_n),
    .valid_in       (valid_out_2 & wb_valid), // WB 완료 후에만 진행
    .max_value_1    (max_value_1),
    .max_value_2    (max_value_2),
    .max_value_3    (max_value_3),
    .alpha_1        (alpha_1_wb),
    .alpha_2        (alpha_2_wb),
    .alpha_3        (alpha_3_wb),
    .b_2            (b_2_wb),
    .conv2_out_1    (conv2_out_1),
    .conv2_out_2    (conv2_out_2),
    .conv2_out_3    (conv2_out_3),
    .valid_out_conv2(valid_out_3),
    .valid_in_pooling (pool2_in_valid),
    .w_211          (w_211_wb), .w_212 (w_212_wb), .w_213 (w_213_wb),
    .w_221          (w_221_wb), .w_222 (w_222_wb), .w_223 (w_223_wb),
    .w_231          (w_231_wb), .w_232 (w_232_wb), .w_233 (w_233_wb)
  );
 
// =============================
// maxpool + ReLU (2)  ← 정적 2D 버퍼형
// =============================
maxpool_relu_static #(
  .CONV_BIT(12), .HALF_WIDTH(4), .HALF_HEIGHT(4), .HALF_WIDTH_BIT(2)
) u_pool2 (
  .clk            (clk),
  .rst_n          (rst_n),
  .valid_in       (pool2_in_valid),    // conv2의 valid_out_conv2
  .conv_out_1     (conv2_out_1),
  .conv_out_2     (conv2_out_2),
  .conv_out_3     (conv2_out_3),
  .max_value_1    (max2_value_1),   // ★ FC 입력 신호명으로 교체
  .max_value_2    (max2_value_2),
  .max_value_3    (max2_value_3),
  .valid_out_relu (valid_out_4)     // ★ 다음 스테이지 valid
);


  // =============================
  // FC
  // =============================
  fully_connected #(
    .INPUT_NUM(48), .OUTPUT_NUM(10), .DATA_BITS(8)
  ) u_fc (
    .clk          (clk),
    .rst_n        (rst_n),
    .valid_in     (valid_out_4),
    .data_in_1    (max2_value_1),
    .data_in_2    (max2_value_2),
    .data_in_3    (max2_value_3),
    .data_out     (fc_out_data),
    .valid_out_fc (valid_out_5),
    .w_fc         (w_fc),
    .b_fc         (b_fc),
    .fc_scale     (fc_scale)
  );

  // =============================
  // Comparator
  // =============================
  comparator u_cmp (
    .clk       (clk),
    .rst_n     (rst_n),
    .valid_in  (valid_out_5),
    .data_in   (fc_out_data),
    .decision  (decision),
    .valid_out (valid_out_6)
  );

endmodule
