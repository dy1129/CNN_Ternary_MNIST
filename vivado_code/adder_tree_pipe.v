module adder_tree25_pipe #(
  parameter IN_W  = 17,  // ê³±ì…ˆ ê²°ê³¼ ?­ (?˜ˆ: 9x8 -> 17)
  parameter SUM_W = 22   // IN_W + ceil(log2(25)) = 17+5
)(
  input                 clk,
  input                 rst_n,
  input signed [IN_W-1:0] in0,  input signed [IN_W-1:0] in1,
  input signed [IN_W-1:0] in2,  input signed [IN_W-1:0] in3,
  input signed [IN_W-1:0] in4,  input signed [IN_W-1:0] in5,
  input signed [IN_W-1:0] in6,  input signed [IN_W-1:0] in7,
  input signed [IN_W-1:0] in8,  input signed [IN_W-1:0] in9,
  input signed [IN_W-1:0] in10, input signed [IN_W-1:0] in11,
  input signed [IN_W-1:0] in12, input signed [IN_W-1:0] in13,
  input signed [IN_W-1:0] in14, input signed [IN_W-1:0] in15,
  input signed [IN_W-1:0] in16, input signed [IN_W-1:0] in17,
  input signed [IN_W-1:0] in18, input signed [IN_W-1:0] in19,
  input signed [IN_W-1:0] in20, input signed [IN_W-1:0] in21,
  input signed [IN_W-1:0] in22, input signed [IN_W-1:0] in23,
  input signed [IN_W-1:0] in24,
  output reg signed [SUM_W-1:0] sum  // 5?´ë¡? ?’¤ ?œ ?š¨
);

  // sign-extend helper
  function [SUM_W-1:0] sx;
    input signed [IN_W-1:0] a;
    begin
      sx = {{(SUM_W-IN_W){a[IN_W-1]}}, a};
    end
  endfunction

  // L1: 25 -> 13
  reg signed [SUM_W-1:0] L1_0,L1_1,L1_2,L1_3,L1_4,L1_5,L1_6,L1_7,L1_8,L1_9,L1_10,L1_11,L1_12;
  always @(posedge clk) begin
    if (!rst_n) begin
      L1_0<=0; L1_1<=0; L1_2<=0; L1_3<=0; L1_4<=0; L1_5<=0; L1_6<=0; L1_7<=0; L1_8<=0; L1_9<=0; L1_10<=0; L1_11<=0; L1_12<=0;
    end else begin
      L1_0  <= sx(in0 ) + sx(in1 );
      L1_1  <= sx(in2 ) + sx(in3 );
      L1_2  <= sx(in4 ) + sx(in5 );
      L1_3  <= sx(in6 ) + sx(in7 );
      L1_4  <= sx(in8 ) + sx(in9 );
      L1_5  <= sx(in10) + sx(in11);
      L1_6  <= sx(in12) + sx(in13);
      L1_7  <= sx(in14) + sx(in15);
      L1_8  <= sx(in16) + sx(in17);
      L1_9  <= sx(in18) + sx(in19);
      L1_10 <= sx(in20) + sx(in21);
      L1_11 <= sx(in22) + sx(in23);
      L1_12 <= sx(in24); // pass-up
    end
  end

  // L2: 13 -> 7
  reg signed [SUM_W-1:0] L2_0,L2_1,L2_2,L2_3,L2_4,L2_5,L2_6;
  always @(posedge clk) begin
    if (!rst_n) begin
      L2_0<=0;L2_1<=0;L2_2<=0;L2_3<=0;L2_4<=0;L2_5<=0;L2_6<=0;
    end else begin
      L2_0 <= L1_0 + L1_1;
      L2_1 <= L1_2 + L1_3;
      L2_2 <= L1_4 + L1_5;
      L2_3 <= L1_6 + L1_7;
      L2_4 <= L1_8 + L1_9;
      L2_5 <= L1_10 + L1_11;
      L2_6 <= L1_12; // pass-up
    end
  end

  // L3: 7 -> 4
  reg signed [SUM_W-1:0] L3_0,L3_1,L3_2,L3_3;
  always @(posedge clk) begin
    if (!rst_n) begin
      L3_0<=0;L3_1<=0;L3_2<=0;L3_3<=0;
    end else begin
      L3_0 <= L2_0 + L2_1;
      L3_1 <= L2_2 + L2_3;
      L3_2 <= L2_4 + L2_5;
      L3_3 <= L2_6; // pass-up
    end
  end

  // L4: 4 -> 2
  reg signed [SUM_W-1:0] L4_0,L4_1;
  always @(posedge clk) begin
    if (!rst_n) begin
      L4_0<=0; L4_1<=0;
    end else begin
      L4_0 <= L3_0 + L3_1;
      L4_1 <= L3_2 + L3_3;
    end
  end

  // L5: 2 -> 1 (ìµœì¢… ?•©)
  always @(posedge clk) begin
    if (!rst_n) sum <= 0;
    else        sum <= L4_0 + L4_1;
  end
endmodule
