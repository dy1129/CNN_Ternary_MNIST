`timescale 1ps/1ps

module maxpool_relu_static #(
    parameter integer CONV_BIT       = 12,
    parameter integer HALF_WIDTH     = 4,    // 출력 가로 (4)
    parameter integer HALF_HEIGHT    = 4,    // 출력 세로 (4)
    parameter integer HALF_WIDTH_BIT = 3
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 valid_in,       // Conv2 Layer의 valid_calc_final (64 클럭 연속 1)
    input  wire signed [CONV_BIT-1:0]   conv_out_1, // Conv2 Layer 출력 1
    input  wire signed [CONV_BIT-1:0]   conv_out_2, // Conv2 Layer 출력 2
    input  wire signed [CONV_BIT-1:0]   conv_out_3, // Conv2 Layer 출력 3

    output reg  [CONV_BIT-1:0]      max_value_1, // 12-bit output (to FC Layer)
    output reg  [CONV_BIT-1:0]      max_value_2, // 12-bit output
    output reg  [CONV_BIT-1:0]      max_value_3, // 12-bit output
    output reg                      valid_out_relu // Output valid (1 클럭 펄스, 4클럭마다 발생)
);
    // ---- geometry ----
    localparam integer IN_W   = (HALF_WIDTH  << 1); // 2*4 = 8
    localparam integer IN_H   = (HALF_HEIGHT << 1); // 2*4 = 8
    localparam integer IN_PIX = IN_W * IN_H;        // 64 (Total pixels to capture)
    localparam integer OUT_PIX= HALF_WIDTH * HALF_HEIGHT; // 16 (Total pixels to emit)

    // ---- FSM ----
    localparam [1:0] S_CAP = 2'd0, S_EMIT = 2'd1;
    reg [1:0] state;

    // ---- buffers (8x8x3 = 64 pixels storage) ----
    reg signed [CONV_BIT-1:0] buf1 [0:IN_H-1][0:IN_W-1];
    reg signed [CONV_BIT-1:0] buf2 [0:IN_H-1][0:IN_W-1];
    reg signed [CONV_BIT-1:0] buf3 [0:IN_H-1][0:IN_W-1];

    // ---- capture counters (Data Consumption) ----
    reg [15:0] cap_cnt; // 0..63 valid 픽셀 수 (for S_CAP)
    reg [15:0] cap_x;   // 0..7
    reg [15:0] cap_y;   // 0..7

    // ---- emit counters (Output Generation) ----
    reg [1:0] emit_delay_cnt; // 0, 1, 2, 3 (4 클럭 지연 카운터)
    reg [15:0] out_x;   // 0..3
    reg [15:0] out_y;   // 0..3
    reg [15:0] emit_cnt; // 0..15

    // ---- 2x2 window wires (Read from buffer based on out_x, out_y) ----
    // Channel 1
    wire signed [CONV_BIT-1:0] a1 = buf1[out_y*2][out_x*2];
    wire signed [CONV_BIT-1:0] b1 = buf1[out_y*2][out_x*2 + 1];
    wire signed [CONV_BIT-1:0] c1 = buf1[out_y*2 + 1][out_x*2];
    wire signed [CONV_BIT-1:0] d1 = buf1[out_y*2 + 1][out_x*2 + 1];
    // Channel 2
    wire signed [CONV_BIT-1:0] a2 = buf2[out_y*2][out_x*2];
    wire signed [CONV_BIT-1:0] b2 = buf2[out_y*2][out_x*2 + 1];
    wire signed [CONV_BIT-1:0] c2 = buf2[out_y*2 + 1][out_x*2];
    wire signed [CONV_BIT-1:0] d2 = buf2[out_y*2 + 1][out_x*2 + 1];
    // Channel 3
    wire signed [CONV_BIT-1:0] a3 = buf3[out_y*2][out_x*2];
    wire signed [CONV_BIT-1:0] b3 = buf3[out_y*2][out_x*2 + 1];
    wire signed [CONV_BIT-1:0] c3 = buf3[out_y*2 + 1][out_x*2];
    wire signed [CONV_BIT-1:0] d3 = buf3[out_y*2 + 1][out_x*2 + 1];

    // pairwise max (Combinational Max calculation)
    wire signed [CONV_BIT-1:0] m1 = ((a1>b1?a1:b1) > (c1>d1?c1:d1)) ? (a1>b1?a1:b1) : (c1>d1?c1:d1);
    wire signed [CONV_BIT-1:0] m2 = ((a2>b2?a2:b2) > (c2>d2?c2:d2)) ? (a2>b2?a2:b2) : (c2>d2?c2:d2);
    wire signed [CONV_BIT-1:0] m3 = ((a3>b3?a3:b3) > (c3>d3?c3:d3)) ? (a3>b3?a3:b3) : (c3>d3?c3:d3);

    // ReLU (max(0, x))
    wire [CONV_BIT-1:0] relu1 = m1[CONV_BIT-1] ? {CONV_BIT{1'b0}} : m1[CONV_BIT-1:0];
    wire [CONV_BIT-1:0] relu2 = m2[CONV_BIT-1] ? {CONV_BIT{1'b0}} : m2[CONV_BIT-1:0];
    wire [CONV_BIT-1:0] relu3 = m3[CONV_BIT-1] ? {CONV_BIT{1'b0}} : m3[CONV_BIT-1:0];

    // ---- sequential ----
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        state          <= S_CAP;
        cap_cnt        <= 0; cap_x <= 0; cap_y <= 0;
        out_x          <= 0; out_y <= 0; emit_cnt <= 0;
        emit_delay_cnt <= 0; // 지연 카운터 초기화
        valid_out_relu <= 1'b0;
        max_value_1    <= {CONV_BIT{1'b0}};
        max_value_2    <= {CONV_BIT{1'b0}};
        max_value_3    <= {CONV_BIT{1'b0}};
      end else begin
        valid_out_relu <= 1'b0; // default

        case (state)
          S_CAP: begin
            // 1. 데이터 저장 (1픽셀/클럭 소비)
            if (valid_in) begin
              // [데이터 소비 로직]
              buf1[cap_y][cap_x] <= conv_out_1;
              buf2[cap_y][cap_x] <= conv_out_2;
              buf3[cap_y][cap_x] <= conv_out_3;

              // 2. 라스터 인덱스 전진 (데이터 중복 없이 매 유효 입력마다 저장)
              if (cap_x == IN_W-1) begin
                cap_x <= 0;
                cap_y <= cap_y + 1'b1;
              end else begin
                cap_x <= cap_x + 1'b1;
              end

              if (cap_cnt == IN_PIX-1) begin
                // 3. 캡처 완료 → S_EMIT으로 전환
                cap_cnt  <= 0;
                cap_x    <= 0;
                cap_y    <= 0;

                out_x    <= 0;
                out_y    <= 0;
                emit_cnt <= 0;
                emit_delay_cnt <= 0; // 지연 카운터 리셋
                state    <= S_EMIT;
              end else begin
                cap_cnt <= cap_cnt + 1'b1;
              end
            end
          end

          S_EMIT: begin
            // 1. 출력 데이터 레지스터링 (매 클럭 수행, out_x/out_y가 변하지 않아도 Max/ReLU 값은 일정)
            max_value_1    <= relu1;
            max_value_2    <= relu2;
            max_value_3    <= relu3;
            
            // 2. 출력 지연 카운터 증가 (4클럭 지연 구현)
            if (emit_delay_cnt < 2'd3) begin
                emit_delay_cnt <= emit_delay_cnt + 1'b1;
                valid_out_relu <= 1'b0; // 3클럭 동안 대기
            end else begin
                // 3. 4클럭째: 픽셀 출력 및 카운터 전진
                emit_delay_cnt <= 0; // 리셋
                valid_out_relu <= 1'b1; // 1 클럭 펄스 출력 (4클럭마다)
                
                emit_cnt <= emit_cnt + 1'b1;
                
                // 출력 위치 전진 (4클럭마다 한 번)
                if (out_x == HALF_WIDTH-1) begin
                    out_x <= 0;
                    if (out_y == HALF_HEIGHT-1) begin
                        out_y    <= 0;
                        // 16개 픽셀 출력 완료 → S_CAP로 복귀
                        state    <= S_CAP; 
                    end else begin
                        out_y <= out_y + 1'b1;
                    end
                end else begin
                    out_x <= out_x + 1'b1;
                end
            end
          end

          default: state <= S_CAP;
        endcase
      end
    end
endmodule