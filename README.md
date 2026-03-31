# CNN_MNIST_ternary

> **🥈 Silver Award — Kyungpook National University IDEC 2024 Creative Circuit Design Challenge**

**Ternary MAC Architecture with Scaling for Energy-Efficient NPU Design**

This project optimizes a Reference Verilog CNN accelerator for MNIST handwritten digit classification by applying **Adder Tree Pipelining** and **Ternary MAC** architecture. By eliminating multipliers and replacing them with sign-select addition, we achieved a 93% power reduction and ~47× TOPS/W improvement at the cost of only a 3%p accuracy drop.

---

## Project Overview

| Item | Details |
|------|---------|
| **Title** | Ternary MAC Architecture with Scaling for Energy-Efficient NPU Design |
| **Team** | TernaryX |
| **Competition** | Kyungpook National University IDEC 2024 Creative Circuit Design Challenge |
| **Award** | 🥈 Silver Award |
| **Design Tools** | Verilog HDL, Vivado, OpenROAD |
| **Dataset** | MNIST (28×28, 1000 test images) |

---

## Architecture

The NPU processes data through the following pipeline:

```
                     ┌──────────────────────────┐
                     │      Input (28×28)       │
                     └────────────┬─────────────┘
                                  ▼
                     ┌──────────────────────────┐
                     │   Conv1 (5×5 × 3ch)      │  INT8 weight
                     │   Adder Tree Pipelining   │  ──→ 24×24×3
                     └────────────┬─────────────┘
                                  ▼
                     ┌──────────────────────────┐
                     │  MaxPool (2×2) + ReLU     │  ──→ 12×12×3
                     └────────────┬─────────────┘
                                  ▼
                     ┌──────────────────────────┐
                     │   Conv2 (5×5 × 3ch)      │  Ternary MAC {-1,0,+1}
                     │   Adder Tree + α scale    │  ──→ 8×8×3
                     └────────────┬─────────────┘
                                  ▼
                     ┌──────────────────────────┐
                     │  MaxPool (2×2) + ReLU     │  ──→ 4×4×3
                     └────────────┬─────────────┘
                                  ▼
                     ┌──────────────────────────┐
                     │   FC (48-tap × 10 class)  │  Ternary MAC {-1,0,+1}
                     │   6-stage Adder Tree      │  ──→ 10 scores
                     └────────────┬─────────────┘
                                  ▼
                     ┌──────────────────────────┐
                     │  Comparator (tournament)  │  4-stage pipeline
                     └────────────┬─────────────┘
                                  ▼
                          Decision (0~9)
```

### Reference Code vs Proposed Architecture

The **Reference code** uses a conventional INT8 multiply-accumulate (MAC) structure. Multipliers dominate both area and power, and the long combinational logic paths cause timing violations (Worst Slack −1618.61).

The **proposed architecture** applies two key optimizations incrementally:

**Stage 1 — Adder Tree Pipelining**: The 25 multiplication results from a 5×5 kernel are reduced through a balanced tree (25→13→7→4→2→1), with pipeline registers inserted between each stage to improve Fmax. This alone resolves timing violations (Slack −1618 → +171), and accuracy actually increases from 96% to 97%.

**Stage 2 — Ternary MAC**: Weights in Conv2 and FC layers are ternarized to {−1, 0, +1}, completely eliminating multipliers. Each tap performs only sign selection on the input: +x (add) / 0 (skip) / −x (negate), requiring only MUXes and adders. The expressiveness lost through ternarization is recovered via per-channel scale factors α (Q2.6 fixed-point).

### Module Details

**Conv1** — Generates 5×5 windows from 28×28 input via line buffer, with 3-channel parallel processing. Uses INT8 weights + Adder Tree Pipelining. (Ternary was tested on Conv1 but caused significant accuracy degradation, so INT8 is retained.)

**Conv2** — Takes 12×12×3 input through per-channel buffers + Bus Packer. Applies Ternary MAC + Adder Tree Pipelining. Per-channel α scaling and bias are applied, followed by 12-bit saturation.

**FC** — Processes 4×4×3 = 48 inputs through a 48-tap Ternary MAC with a 6-stage pipelined adder tree (48→24→12→6→3→2→1). Outputs are streamed per class (idx 0~9).

**Comparator** — Selects the maximum value using a tournament-style pipeline (10→5→3→2→1), improving timing over the original linear comparison approach.

### Training Pipeline (Python/PyTorch)

Ternary weights and scale factors are trained through PyTorch QAT (Quantization-Aware Training). `TernaryQuantFn` projects weights to {−1, 0, +1} based on a threshold Δ (= 0.7 × E(|w|)), and α is estimated as the mean absolute value of non-zero weights. Backpropagation through the non-differentiable ternarization is handled via STE (Straight-Through Estimator). The trained ternary weights, α, and bias values are exported as HEX files (Q2.6 format) and loaded in RTL via `$readmemh`, ensuring LSB-level numerical agreement between the PyTorch model and RTL output.

---

## Results

| Metric | Reference | Intermediate (AT Pipelining) | Final (AT + Ternary MAC) | Change (Ref→Final) |
|--------|-----------|------------------------------|--------------------------|---------------------|
| **Accuracy** | 96% | 97% | 93% | −3%p |
| **Area** | 23,033 | 38,531 | 28,968 | +25.8% |
| **Power** | 789 mW | 121 mW | 54 mW | **−93.2%** |
| **Worst Slack** | −1,618.61 (violation) | +171.86 | +40.17 | Violation resolved |
| **TOPS/W** | 0.2683 | 5.64 | 12.65 | **×47.1** |

An energy-efficiency-oriented design that achieves 93% power reduction and 47× energy efficiency improvement at the cost of a 3%p accuracy trade-off.

---

## Hardware Deployment

### System Pipeline

```
PC (Python GUI) → UART (460,800 baud) → Artix-7 FPGA → CNN Inference → LED Output
```

- Developed Python-based GUI for real-time handwritten digit input and UART transmission
- Integrated full inference pipeline on Xilinx Artix-7 FPGA (Conv1 → Pool → Conv2 → Pool → FC → Comparator)
- **Verification**: Confirmed LSB-level agreement between PyTorch model and RTL output through cycle-accurate testbench simulation
- **Hardware Debugging (In Progress)**: Identified UART synchronization and timing constraints during physical board testing; investigating clock domain crossing (CDC) and FIFO buffering for stable output

> **Note**: All RTL logic is verified to be functionally correct in simulation. The current challenge is physical-layer integration (UART timing, pin constraints), not logic correctness.

---

## Award

🥈 **Silver Award** — Kyungpook National University IDEC 2024 Creative Circuit Design Challenge

---

## Tech Stack

`Verilog HDL` · `Vivado` · `OpenROAD` · `PyTorch (QAT)` · `Ternary Quantization` · `CNN` · `MNIST` · `ASIC / NPU`

---

## References

1. Qi et al., "Efficient On-board Remote Sensing Scene Classification Using FPGA With Ternary Weight," Beijing Institute of Technology
2. [CNN-Implementation-in-Verilog](https://github.com/boaaaang/CNN-Implementation-in-Verilog) — Reference code base
