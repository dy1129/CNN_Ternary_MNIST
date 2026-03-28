// WB_ternary_capture_0.v : TB가 준 버스를 wb_load 한 사이클에 래치해서 conv2에 공급
module WB_ternary (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wb_load,      // 1 사이클 High → 입력 버스 래치
    output reg         wb_valid,     // 래치 완료 플래그

    // TB → WB (입력 버스, [0:MSB] 방향)
    input  wire [0:199] in_w_211, in_w_212, in_w_213,
    input  wire [0:199] in_w_221, in_w_222, in_w_223,
    input  wire [0:199] in_w_231, in_w_232, in_w_233,
    input  wire [0:23]  in_b_2,
    input  wire [7:0]   in_alpha_1, in_alpha_2, in_alpha_3,

    // WB → conv2 (출력 버스, [0:MSB] 방향)
    output reg  [0:199] w_211, w_212, w_213,
    output reg  [0:199] w_221, w_222, w_223,
    output reg  [0:199] w_231, w_232, w_233,
    output reg  [0:23]  b_2,
    output reg  [7:0]   alpha_1, alpha_2, alpha_3
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_211<=0; w_212<=0; w_213<=0;
      w_221<=0; w_222<=0; w_223<=0;
      w_231<=0; w_232<=0; w_233<=0;
      b_2<=0; alpha_1<=0; alpha_2<=0; alpha_3<=0;
      wb_valid <= 1'b0;
    end else begin
      if (wb_load) begin
        w_211<=in_w_211; w_212<=in_w_212; w_213<=in_w_213;
        w_221<=in_w_221; w_222<=in_w_222; w_223<=in_w_223;
        w_231<=in_w_231; w_232<=in_w_232; w_233<=in_w_233;
        b_2<=in_b_2;
        alpha_1<=in_alpha_1; alpha_2<=in_alpha_2; alpha_3<=in_alpha_3;
        wb_valid <= 1'b1;
      end
    end
  end
endmodule
