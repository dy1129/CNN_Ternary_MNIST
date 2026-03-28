/*-------------------------------------------------------------------
 * Module: comparator (Final Corrected Version)
 *------------------------------------------------------------------*/
module comparator (
  input clk,
  input rst_n,
  input valid_in,
  input [11:0] data_in,
  output reg [3:0] decision,
  output reg valid_out
);

  // 버퍼: 입력 10개 저장
  reg signed [11:0] buffer [0:9];
  reg [3:0]   buf_idx;
  reg   collecting;
  reg   collecting_d;

  reg signed [11:0] cmp1_val [0:4];
  reg [3:0]    cmp1_idx [0:4];

  reg signed [11:0] cmp2_val [0:2];
  reg [3:0]    cmp2_idx [0:2];

  reg signed [11:0] cmp3_val [0:1];
  reg [3:0]    cmp3_idx [0:1];

  reg signed [11:0] max_val;
  reg [3:0]    max_idx;

  // 파이프라인 유효 신호
  reg valid_pipe1, valid_pipe2, valid_pipe3, valid_pipe4;

  integer i;
  integer p;
  
    localparam signed [11:0] NEG_INF = 12'sh800;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // --- ★★★★★ 완전한 리셋 로직 ★★★★★ ---
      // 모든 상태, 인덱스, 값, 유효 신호를 0 또는 초기값으로 설정합니다.
      buf_idx <= 0;
      collecting <= 1'b1;
      collecting_d <= 1'b1;
      
      valid_pipe1 <= 0;
      valid_pipe2 <= 0;
      valid_pipe3 <= 0;
      valid_pipe4 <= 0;
      
      decision <= 0;
      valid_out <= 0;
      
      max_val <= 0;
      max_idx <= 0;

      for (i=0; i<10; i=i+1) begin
        buffer[i] <= 0;
      end
      
      for (i=0; i<5; i=i+1) begin
        cmp1_val[i] <= 0;
        cmp1_idx[i] <= 0;
      end

      for (i=0; i<3; i=i+1) begin
        cmp2_val[i] <= 0;
        cmp2_idx[i] <= 0;
      end

      for (i=0; i<2; i=i+1) begin
        cmp3_val[i] <= 0;
        cmp3_idx[i] <= 0;
      end
      // --- 리셋 로직 끝 ---

    end else begin
      // 매 클럭마다 collecting 상태를 collecting_d에 업데이트
      collecting_d <= collecting;

      // 1) 입력 데이터 수집
      if (valid_in && collecting) begin
        buffer[buf_idx] <= data_in;
        if (buf_idx == 9) begin
          collecting <= 0; // 10개 수집 완료
        end else begin
          buf_idx <= buf_idx + 1;
        end
      end

      // 2) Stage 1: 데이터 수집이 "막 끝난 시점"에만 시작
      if (collecting_d && !collecting) begin
        cmp1_val[0] <= (buffer[0] >= buffer[1]) ? buffer[0] : buffer[1];
        cmp1_idx[0] <= (buffer[0] >= buffer[1]) ? 4'd0 : 4'd1;

        cmp1_val[1] <= (buffer[2] >= buffer[3]) ? buffer[2] : buffer[3];
        cmp1_idx[1] <= (buffer[2] >= buffer[3]) ? 4'd2 : 4'd3;

        cmp1_val[2] <= (buffer[4] >= buffer[5]) ? buffer[4] : buffer[5];
        cmp1_idx[2] <= (buffer[4] >= buffer[5]) ? 4'd4 : 4'd5;

        cmp1_val[3] <= (buffer[6] >= buffer[7]) ? buffer[6] : buffer[7];
        cmp1_idx[3] <= (buffer[6] >= buffer[7]) ? 4'd6 : 4'd7;

        cmp1_val[4] <= (buffer[8] >= buffer[9]) ? buffer[8] : buffer[9];
        cmp1_idx[4] <= (buffer[8] >= buffer[9]) ? 4'd8 : 4'd9;

        valid_pipe1 <= 1;
      end else begin
        valid_pipe1 <= 0;
      end

      // 3) Stage 2
      if (valid_pipe1) begin
        cmp2_val[0] <= (cmp1_val[0] >= cmp1_val[1]) ? cmp1_val[0] : cmp1_val[1];
        cmp2_idx[0] <= (cmp1_val[0] >= cmp1_val[1]) ? cmp1_idx[0] : cmp1_idx[1];

        cmp2_val[1] <= (cmp1_val[2] >= cmp1_val[3]) ? cmp1_val[2] : cmp1_val[3];
        cmp2_idx[1] <= (cmp1_val[2] >= cmp1_val[3]) ? cmp1_idx[2] : cmp1_idx[3];

        cmp2_val[2] <= cmp1_val[4];
        cmp2_idx[2] <= cmp1_idx[4];

        valid_pipe2 <= 1;
      end else begin
        valid_pipe2 <= 0;
      end

      // 4) Stage 3
      if (valid_pipe2) begin
        cmp3_val[0] <= (cmp2_val[0] >= cmp2_val[1]) ? cmp2_val[0] : cmp2_val[1];
        cmp3_idx[0] <= (cmp2_val[0] >= cmp2_val[1]) ? cmp2_idx[0] : cmp2_idx[1];

        cmp3_val[1] <= cmp2_val[2];
        cmp3_idx[1] <= cmp2_idx[2];

        valid_pipe3 <= 1;
      end else begin
        valid_pipe3 <= 0;
      end

      // 5) Stage 4: 최종 비교
      if (valid_pipe3) begin
        if (cmp3_val[0] >= cmp3_val[1]) begin
          max_val <= cmp3_val[0];
          max_idx <= cmp3_idx[0];
        end else begin
          max_val <= cmp3_val[1];
          max_idx <= cmp3_idx[1];
        end
        valid_pipe4 <= 1;
      end 

        if (valid_pipe4) begin
        decision   <= max_idx;
        valid_out  <= 1'b1;
        collecting <= 1'b0;
        buf_idx    <= 4'd0;

        // 빈칸은 다시 -INF로 초기화(선택이지만 권장)
        for (i=0; i<10; i=i+1) begin
          buffer[i] <= NEG_INF;
        end
      end else begin
        valid_out  <= 1'b0;
      end

    end
  end

endmodule