/*------------------------------------------------------------------------
 *
 *  Copyright (c) 2021 by Bo Young Kang, All rights reserved.
 *
 *  File name  : top_tb.v
 *  Written by : Kang, Bo Young
 *  Written on : Oct 15, 2021
 *  Version    : 21.2
 *  Design     : Testbench for CNN MNIST dataset - single input image
 *
 *------------------------------------------------------------------------*/

/*-------------------------------------------------------------------
 *  Module: top_tb
 *------------------------------------------------------------------*/
`timescale 1ps/1ps
module top_tb();
  parameter DATA_BITS = 8;

  reg clk, rst_n;
  reg [7:0] pixels [0:783];
  reg [9:0] img_idx;
  reg [7:0] data_in;

  wire [3:0] decision;
  wire         valid_out_6;

  // ===== conv2 alpha & wb_load =====
  reg [7:0] alpha_1_tb, alpha_2_tb, alpha_3_tb;
  reg         wb_load_tb;
  reg [7:0] conv2_alpha [0:2];

  // ===== conv1 scaling =====
  reg  signed [15:0] conv1_scale_mem [0:2];
  wire signed [15:0] scale_1_tb = conv1_scale_mem[0];
  wire signed [15:0] scale_2_tb = conv1_scale_mem[1];
  wire signed [15:0] scale_3_tb = conv1_scale_mem[2];
  

  // conv1
  reg signed [7:0] weight_11 [0:24];
  reg signed [7:0] weight_12 [0:24];
  reg signed [7:0] weight_13 [0:24];
  reg signed [7:0] bias_1    [0:2];
  // conv2
  reg signed [7:0] bias_2    [0:2];
  reg signed [7:0] weight_211[0:24];
  reg signed [7:0] weight_212[0:24];
  reg signed [7:0] weight_213[0:24];
  reg signed [7:0] weight_221[0:24];
  reg signed [7:0] weight_222[0:24];
  reg signed [7:0] weight_223[0:24];
  reg signed [7:0] weight_231[0:24];
  reg signed [7:0] weight_232[0:24];
  reg signed [7:0] weight_233[0:24];
  // fc
  reg signed [7:0] weight_fc [0:479];
  reg signed [7:0] bias_fc   [0:9];
  reg signed [7:0] fc_scale_mem [0:9];  // CHANGED: 16-bit -> 8-bit (Q2.6)

  wire signed [0:199] w_11, w_12, w_13;
  wire signed [0:23]  b_1, b_2;
  wire signed [0:199] w_211, w_212, w_213, w_221, w_222, w_223, w_231, w_232, w_233;
  wire signed [0:3839] w_fc;
  wire signed [0:79]   b_fc;
  wire        [0:79]   fc_scale; // CHANGED: 160-bit -> 80-bit (10 * 8b)

  // clock
  always #5 clk = ~clk;

  // image
  initial begin
   $readmemh("C:/Users/dayes/verilog/CNN_1/Reference code/cnn_verilog/data/6_0.txt", pixels);
    //$readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/00_input_u8_28x28.txt", pixels);
    clk   <= 1'b0;
    rst_n <= 1'b1;  #3
    rst_n <= 1'b0;  #3
    rst_n <= 1'b1;
  end
    integer k; // Output Channel Index
    integer h; // Input Feature Index (0 to 47)
  // weights/bias/scales
  initial begin 
    // conv1
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_weight_1.txt", weight_11);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_weight_2.txt", weight_12);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_weight_3.txt", weight_13);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_bias.txt",     bias_1);
    // conv1 scale 
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_scale.txt",     conv1_scale_mem);

    // conv2
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_bias.txt",      bias_2);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_11.txt", weight_211);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_12.txt", weight_212);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_13.txt", weight_213);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_21.txt", weight_221);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_22.txt", weight_222);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_23.txt", weight_223);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_31.txt", weight_231);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_32.txt", weight_232);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_33.txt", weight_233);

    // conv2 alpha
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_alpha.txt", conv2_alpha);
    alpha_1_tb = conv2_alpha[0];
    alpha_2_tb = conv2_alpha[1];
    alpha_3_tb = conv2_alpha[2];

    // fc
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/fc_weight.txt", weight_fc);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/fc_bias.txt",   bias_fc);
    // fc scale
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/fc_scale.txt",  fc_scale_mem); // NOTE: 10진수(decimal)로 읽도록 readmemd 추천

    // WB trigger
    wb_load_tb = 1'b1;
  end



  // drive pixels
  always @(posedge clk) begin
    if(~rst_n) begin
      img_idx <= 0;
    end else begin
      if(img_idx < 10'd784) img_idx <= img_idx + 1'b1;
      data_in <= pixels[img_idx];
    end
  end

  always @(*) if(valid_out_6==1) #5 $finish;

  // === chip (named mapping) ===
  chip chip1 (
    .clk           (clk),
    .rst_n         (rst_n),
    .data_in       (data_in),
    .decision      (decision),
    .valid_out_6   (valid_out_6),

    // conv1
    .w_11          (w_11),
    .w_12          (w_12),
    .w_13          (w_13),
    .b_1           (b_1),
    .scale_1       (scale_1_tb),  
    .scale_2       (scale_2_tb),
    .scale_3       (scale_3_tb),

    // conv2
    .b_2           (b_2),
    .w_211         (w_211), .w_212(w_212), .w_213(w_213),
    .w_221         (w_221), .w_222(w_222), .w_223(w_223),
    .w_231         (w_231), .w_232(w_232), .w_233(w_233),

    // fc
    .w_fc          (w_fc),
    .b_fc          (b_fc),
    .fc_scale      (fc_scale),    

    // conv2 α / WB
    .alpha_1_tb    (alpha_1_tb),
    .alpha_2_tb    (alpha_2_tb),
    .alpha_3_tb    (alpha_3_tb),
    .wb_load_tb    (wb_load_tb)
  );

  // pack buses
  genvar i;
  generate
    for(i=0;i<=24;i=i+1) begin
      assign w_11[(8*i)+:8]=weight_11[i];
      assign w_12[(8*i)+:8]=weight_12[i];
      assign w_13[(8*i)+:8]=weight_13[i];
      assign w_211[(8*i)+:8]=weight_211[i];
      assign w_212[(8*i)+:8]=weight_212[i];
      assign w_213[(8*i)+:8]=weight_213[i];
      assign w_221[(8*i)+:8]=weight_221[i]; 
      assign w_222[(8*i)+:8]=weight_222[i];
      assign w_223[(8*i)+:8]=weight_223[i];
      assign w_231[(8*i)+:8]=weight_231[i];
      assign w_232[(8*i)+:8]=weight_232[i];
      assign w_233[(8*i)+:8]=weight_233[i];
    end
    for(i=0;i<=2;i=i+1) begin
      assign b_1[(8*i)+:8]=bias_1[i];
      assign b_2[(8*i)+:8]=bias_2[i];
    end
    for(i = 0; i <= 479; i = i + 1) begin
    assign w_fc[(8 * i) +: 8] = weight_fc[i];
    end
    for(i=0;i<=9;i=i+1)  begin assign b_fc[(8*i)+:8]=bias_fc[i];   end
    for(i=0;i<=9;i=i+1)  begin assign fc_scale[(8*i)+:8] = fc_scale_mem[i]; end
  endgenerate
  

endmodule


/*------------------------------------------------------------------------
 *
 *  Copyright (c) 2021 by Bo Young Kang, All rights reserved.
 *
 *  File name  : top_tb_2.v
 *  Written by : Kang, Bo Young
 *  Written on : Oct 20, 2021
 *  Version    : 21.2
 *  Design     : Testbench for CNN MNIST dataset - multiple input image (1000)
 *
 *------------------------------------------------------------------------*/

/*-------------------------------------------------------------------
 *  Module: top_tb_2
 *------------------------------------------------------------------*/
/*------------------------------------------------------------------------
 *
 *  Copyright (c) 2021 by Bo Young Kang, All rights reserved.
 *
 *  File name  : top_tb.v
 *  Written by : Kang, Bo Young
 *  Written on : Oct 15, 2021
 *  Version    : 21.2
 *  Design     : Testbench for CNN MNIST dataset - single input image
 *
 *------------------------------------------------------------------------*/

/*-------------------------------------------------------------------
 *  Module: top_tb
 *------------------------------------------------------------------*/
`timescale 1ps/1ps
module top_tb_1000();
    parameter DATA_BITS = 8;
  reg clk, rst_n;
  reg [7:0] pixels [0:783999];
  reg [9:0] img_idx;
  reg [7:0] data_in;
  reg [9:0] cnt, input_cnt, rand_num;
  reg state;
  integer i_cnt;
  reg [9:0] accuracy;

  wire [3:0] decision;
  wire       valid_out_6;

  // ===== conv2 alpha & wb_load =====
  reg [7:0] alpha_1_tb, alpha_2_tb, alpha_3_tb;
  reg         wb_load_tb;
  reg [7:0] conv2_alpha [0:2];

  // ===== conv1 scaling (Q9.7, 16-bit) =====
  reg  signed [15:0] conv1_scale_mem [0:2];
  wire signed [15:0] scale_1_tb = conv1_scale_mem[0];
  wire signed [15:0] scale_2_tb = conv1_scale_mem[1];
  wire signed [15:0] scale_3_tb = conv1_scale_mem[2];


  // conv1
  reg signed [7:0] weight_11 [0:24];
  reg signed [7:0] weight_12 [0:24];
  reg signed [7:0] weight_13 [0:24];
  reg signed [7:0] bias_1    [0:2];
  // conv2
  reg signed [7:0] bias_2    [0:2];
  reg signed [7:0] weight_211[0:24];
  reg signed [7:0] weight_212[0:24];
  reg signed [7:0] weight_213[0:24];
  reg signed [7:0] weight_221[0:24];
  reg signed [7:0] weight_222[0:24];
  reg signed [7:0] weight_223[0:24];
  reg signed [7:0] weight_231[0:24];
  reg signed [7:0] weight_232[0:24];
  reg signed [7:0] weight_233[0:24];
  // fc
  reg signed [7:0] weight_fc [0:479];
  reg signed [7:0] bias_fc   [0:9];
  reg signed [7:0] fc_scale_mem [0:9];  // CHANGED: 16-bit -> 8-bit (Q2.6)

  wire signed [0:199] w_11, w_12, w_13;
  wire signed [0:23]  b_1, b_2;
  wire signed [0:199] w_211, w_212, w_213, w_221, w_222, w_223, w_231, w_232, w_233;
  wire signed [0:3839] w_fc;
  wire signed [0:79]   b_fc;
  wire        [0:79]   fc_scale;

  always #5 clk = ~clk;

  // weights/bias/scale load
  initial begin
    // conv1
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_weight_1.txt", weight_11);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_weight_2.txt", weight_12);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_weight_3.txt", weight_13);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_bias.txt",      bias_1);
    // conv1 scale (Q9.7)
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv1_scale.txt",     conv1_scale_mem);

    // conv2
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_bias.txt",      bias_2);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_11.txt", weight_211);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_12.txt", weight_212);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_13.txt", weight_213);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_21.txt", weight_221);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_22.txt", weight_222);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_23.txt", weight_223);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_31.txt", weight_231);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_32.txt", weight_232);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_weight_33.txt", weight_233);

    // conv2 alpha (Q2.6)
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/conv2_alpha.txt", conv2_alpha);
    alpha_1_tb = conv2_alpha[0];
    alpha_2_tb = conv2_alpha[1];
    alpha_3_tb = conv2_alpha[2];

    // fc
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/fc_weight.txt", weight_fc);
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/fc_bias.txt",   bias_fc);
    // fc scale (Q2.6, 8-bit * 10)
    $readmemh("C:/Users/dayes/verilog/CNN_AT/weights/SH/fc_scale.txt",  fc_scale_mem);

    wb_load_tb = 1'b1;
  end

  // chip
  chip chip1 (
    .clk           (clk),
    .rst_n         (rst_n),
    .data_in       (data_in),
    .decision      (decision),
    .valid_out_6   (valid_out_6),

    // conv1
    .w_11          (w_11),
    .w_12          (w_12),
    .w_13          (w_13),
    .b_1           (b_1),
    .scale_1       (scale_1_tb),   // 16-bit Q9.7
    .scale_2       (scale_2_tb),
    .scale_3       (scale_3_tb),

    // conv2
    .b_2           (b_2),
    .w_211         (w_211), .w_212(w_212), .w_213(w_213),
    .w_221         (w_221), .w_222(w_222), .w_223(w_223),
    .w_231         (w_231), .w_232(w_232), .w_233(w_233),

    // fc
    .w_fc          (w_fc),
    .b_fc          (b_fc),
    .fc_scale      (fc_scale),     // 8-bit * 10

    // conv2 α / WB
    .alpha_1_tb    (alpha_1_tb),
    .alpha_2_tb    (alpha_2_tb),
    .alpha_3_tb    (alpha_3_tb),
    .wb_load_tb    (wb_load_tb)
  );

  // pack buses
  genvar i;
  generate
    for(i=0;i<=24;i=i+1) begin
      assign w_11[(8*i)+:8]=weight_11[i];
      assign w_12[(8*i)+:8]=weight_12[i];
      assign w_13[(8*i)+:8]=weight_13[i];
      assign w_211[(8*i)+:8]=weight_211[i];
      assign w_212[(8*i)+:8]=weight_212[i];
      assign w_213[(8*i)+:8]=weight_213[i];
      assign w_221[(8*i)+:8]=weight_221[i];
      assign w_222[(8*i)+:8]=weight_222[i];
      assign w_223[(8*i)+:8]=weight_223[i];
      assign w_231[(8*i)+:8]=weight_231[i];
      assign w_232[(8*i)+:8]=weight_232[i];
      assign w_233[(8*i)+:8]=weight_233[i];
    end
    for(i=0;i<=2;i=i+1) begin
      assign b_1[(8*i)+:8]=bias_1[i];
      assign b_2[(8*i)+:8]=bias_2[i];
    end
        for(i = 0; i < 480; i = i + 1) begin
    assign w_fc[(DATA_BITS * i) +: DATA_BITS] = weight_fc[i];
    end
    for(i=0;i<=9;i=i+1)  begin assign b_fc[(8*i)+:8]=bias_fc[i];   end
    for(i=0;i<=9;i=i+1)  begin assign fc_scale[(8*i)+:8] = fc_scale_mem[i]; end
  endgenerate

  // images & flow (원본 로직 유지)
  initial begin
    $readmemh("C:/Users/dayes/verilog/CNN_1/Reference code/cnn_verilog/data/input_1000.txt", pixels);
    cnt <= 0; img_idx <= 0; clk <= 1'b0; input_cnt <= -1; rst_n <= 1'b1;
    rand_num <= 1'b0; accuracy <= 0;
    #3 rst_n <= 1'b0; #3 rst_n <= 1'b1;
  end

  always @(posedge clk) begin
    if(~rst_n) begin

      #3
      rst_n <= 1'b1;
    end else begin
      // decision done
      if(valid_out_6 == 1'b1) begin
        if(state !== 1'bx) begin
          if(cnt % 10 == 1) begin
            if(rand_num % 10 == decision) begin
              $display("%0dst input image : original value = %0d, decision = %0d at %0t ps ==> Success", cnt, rand_num % 10, decision, $time);
              accuracy <= accuracy + 1'b1;
            end else begin
              $display("%0dst input image : original value = %0d, decision = %0d at %0t ps ==> Fail", cnt, rand_num % 10, decision, $time);
            end
          end else if(cnt % 10 == 2) begin
            if(rand_num % 10 == decision) begin
              $display("%0dnd input image : original value = %0d, decision = %0d at %0t ps ==> Success", cnt, rand_num % 10, decision, $time);
              accuracy <= accuracy + 1'b1;
            end else begin
              $display("%0dnd input image : original value = %0d, decision = %0d at %0t ps ==> Fail", cnt, rand_num % 10, decision, $time);
            end
          end else if(cnt % 10 == 3)
            if(rand_num % 10 == decision) begin
              $display("%0drd input image : original value = %0d, decision = %0d at %0t ps ==> Success", cnt, rand_num % 10, decision, $time);
              accuracy <= accuracy + 1'b1;
            end else begin
              $display("%0drd input image : original value = %0d, decision = %0d at %0t ps ==> Fail", cnt, rand_num % 10, decision, $time);
            end
          else begin
            if(rand_num % 10 == decision) begin
              $display("%0dth input image : original value = %0d, decision = %0d at %0t ps ==> Success", cnt, rand_num % 10, decision, $time);
              accuracy <= accuracy + 1'b1;
            end else begin
              $display("%0dth input image : original value = %0d, decision = %0d at %0t ps ==> Fail", cnt, rand_num % 10, decision, $time);
            end
          end
        end

        state <= 1'b0;
        rst_n <= 1'b0;
        input_cnt <= input_cnt + 1'b1;
        rand_num <= $urandom_range(0, 1000);
      end

      if(state == 1'b0) begin
        data_in <= pixels[rand_num*784 + img_idx];
        img_idx <= img_idx + 1'b1;

        if(img_idx == 10'd784) begin
          cnt <= cnt + 1'b1;
          if(cnt == 10'd1000) begin
            $display("\n\n------ Final Accuracy for 1000 Input Image ------");
            $display("Accuracy : %3d%%", accuracy/10);
            $stop;
          end
          img_idx <= 0;
          state <= 1'b1;
        end
      end
    end
  end
endmodule
   