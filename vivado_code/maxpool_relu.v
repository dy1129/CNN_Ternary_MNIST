`timescale 1ps/1ps
/*------------------------------------------------------------------------
 * Module: maxpool_relu (FINAL VERSION)
 * Design: 2x2 non-overlap pooling + CORRECT Signed ReLU
 * Fix   : 1. 2x2 Max Pool FSM (Line Buffer + p3 latch)
 * 2. Combinational 'wire' path for final max (Timing Fix)
 * 3. CORRECT Signed ReLU ($signed > 12'sd0) to match F.relu
 *------------------------------------------------------------------------*/
module maxpool_relu #(
    parameter integer CONV_BIT       = 12,
    parameter integer HALF_WIDTH     = 12,    // (default, overridden by chip.v)
    parameter integer HALF_HEIGHT    = 12,    // (default, overridden by chip.v)
    parameter integer HALF_WIDTH_BIT = (HALF_WIDTH <= 1) ? 1 : $clog2(HALF_WIDTH)
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      valid_in,
    input  wire signed [CONV_BIT-1:0]  conv_out_1,
    input  wire signed [CONV_BIT-1:0]  conv_out_2,
    input  wire signed [CONV_BIT-1:0]  conv_out_3,
    output reg  signed [CONV_BIT-1:0]  max_value_1,
    output reg  signed [CONV_BIT-1:0]  max_value_2,
    output reg  signed [CONV_BIT-1:0]  max_value_3,
    output reg                       valid_out_relu
);

    // Derived sizes
    localparam integer OUT_WIDTH       = HALF_WIDTH  / 2;
    localparam integer OUT_HEIGHT      = HALF_HEIGHT / 2;
    localparam integer OUT_WIDTH_BIT   = (OUT_WIDTH  <= 1) ? 1 : $clog2(OUT_WIDTH);
    localparam integer HALF_HEIGHT_BIT = (HALF_HEIGHT<= 1) ? 1 : $clog2(HALF_HEIGHT);
    localparam signed [CONV_BIT-1:0] SIGNED_MIN = {1'b1, {(CONV_BIT-1){1'b0}}};

    // Position counters
    reg [HALF_WIDTH_BIT-1:0]   x_cnt;
    reg [HALF_HEIGHT_BIT-1:0]  y_cnt;

    // Window state flags
    wire x_is_odd_now = x_cnt[0];
    wire y_is_odd_now = y_cnt[0];
    wire [OUT_WIDTH_BIT-1:0] pcount_now = x_cnt[HALF_WIDTH_BIT-1:1];

    // Line buffers: max(p1, p2)
    reg signed [CONV_BIT-1:0] line_buf_ch1 [0:OUT_WIDTH-1];
    reg signed [CONV_BIT-1:0] line_buf_ch2 [0:OUT_WIDTH-1];
    reg signed [CONV_BIT-1:0] line_buf_ch3 [0:OUT_WIDTH-1];

    // p3 latches
    reg signed [CONV_BIT-1:0] p3_ch1, p3_ch2, p3_ch3;

    // --- [TIMING FIX] Combinational max logic ---
    wire signed [CONV_BIT-1:0] max_row2_ch1, max_row2_ch2, max_row2_ch3;
    wire signed [CONV_BIT-1:0] final_max_ch1, final_max_ch2, final_max_ch3;
    
    // Row-2 max: max(p3,p4)
    assign max_row2_ch1 = ($signed(conv_out_1) > $signed(p3_ch1)) ? conv_out_1 : p3_ch1;
    assign max_row2_ch2 = ($signed(conv_out_2) > $signed(p3_ch2)) ? conv_out_2 : p3_ch2;
    assign max_row2_ch3 = ($signed(conv_out_3) > $signed(p3_ch3)) ? conv_out_3 : p3_ch3;

    // Final max: max( max(p1,p2), max(p3,p4) )
    assign final_max_ch1 = ($signed(max_row2_ch1) > $signed(line_buf_ch1[pcount_now])) ? max_row2_ch1 : line_buf_ch1[pcount_now];
    assign final_max_ch2 = ($signed(max_row2_ch2) > $signed(line_buf_ch2[pcount_now])) ? max_row2_ch2 : line_buf_ch2[pcount_now];
    assign final_max_ch3 = ($signed(max_row2_ch3) > $signed(line_buf_ch3[pcount_now])) ? max_row2_ch3 : line_buf_ch3[pcount_now];

    integer i;

    // --- Sequential FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt          <= {HALF_WIDTH_BIT{1'b0}};
            y_cnt          <= {HALF_HEIGHT_BIT{1'b0}};
            p3_ch1         <= {CONV_BIT{1'b0}};
            p3_ch2         <= {CONV_BIT{1'b0}};
            p3_ch3         <= {CONV_BIT{1'b0}};
            max_value_1    <= {CONV_BIT{1'b0}};
            max_value_2    <= {CONV_BIT{1'b0}};
            max_value_3    <= {CONV_BIT{1'b0}};
            valid_out_relu <= 1'b0;
            for (i = 0; i < OUT_WIDTH; i = i + 1) begin
                line_buf_ch1[i] <= SIGNED_MIN;
                line_buf_ch2[i] <= SIGNED_MIN;
                line_buf_ch3[i] <= SIGNED_MIN;
            end
        end else begin
            valid_out_relu <= 1'b0;

            if (valid_in) begin
                // --- FSM ---
                if (!y_is_odd_now) begin
                    // Even row (Row 0, 2...): p1 or p2
                    if (!x_is_odd_now) begin
                        // (0,0) : p1 -> seed line buffer (temporarily)
                        line_buf_ch1[pcount_now] <= conv_out_1;
                        line_buf_ch2[pcount_now] <= conv_out_2;
                        line_buf_ch3[pcount_now] <= conv_out_3;
                    end else begin
                        // (0,1) : p2 -> update line buffer with max(p1,p2)
                        if ($signed(conv_out_1) > $signed(line_buf_ch1[pcount_now]))
                            line_buf_ch1[pcount_now] <= conv_out_1;
                        if ($signed(conv_out_2) > $signed(line_buf_ch2[pcount_now]))
                            line_buf_ch2[pcount_now] <= conv_out_2;
                        if ($signed(conv_out_3) > $signed(line_buf_ch3[pcount_now]))
                            line_buf_ch3[pcount_now] <= conv_out_3;
                    end
                end else begin
                    // Odd row (Row 1, 3...): p3 or p4
                    if (!x_is_odd_now) begin
                        // (1,0) : p3 -> latch
                        p3_ch1 <= conv_out_1;
                        p3_ch2 <= conv_out_2;
                        p3_ch3 <= conv_out_3;
                    end else begin
                        // (1,1) : p4 -> emit pooled output
                        
                        // [ACCURACY FIX] Use CORRECT Signed ReLU (matches F.relu)
                        max_value_1    <= ($signed(final_max_ch1) > 12'sd0) ? final_max_ch1 : 12'sd0;
                        max_value_2    <= ($signed(final_max_ch2) > 12'sd0) ? final_max_ch2 : 12'sd0;
                        max_value_3    <= ($signed(final_max_ch3) > 12'sd0) ? final_max_ch3 : 12'sd0;
                        
                        valid_out_relu <= 1'b1;
                    end
                end

                // --- Counters ---
                if (x_cnt == HALF_WIDTH-1) begin
                    x_cnt <= {HALF_WIDTH_BIT{1'b0}};
                    if (y_cnt == HALF_HEIGHT-1)
                        y_cnt <= {HALF_HEIGHT_BIT{1'b0}};
                    else
                        y_cnt <= y_cnt + 1'b1;
                end else begin
                    x_cnt <= x_cnt + 1'b1;
                end
            end 
        end
    end
endmodule