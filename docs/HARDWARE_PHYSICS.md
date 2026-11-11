# AMD Strix Halo Hardware Physics & Inference Mechanics

This document provides the formal mathematical models and physical memory constraints governing LLM inference on the **AMD Ryzen AI MAX+ 392 (Strix Halo)** architecture.

---

## 1. Physical Architecture Specifications

| Component | Specification |
| :--- | :--- |
| **SoC Processor** | AMD Ryzen AI MAX+ 392 |
| **CPU Microarchitecture** | Zen 5 (Dual CCX: Cores 0-5 and Cores 6-11) |
| **L3 Cache** | 32 MB per CCX (64 MB total, non-shared between CCXs) |
| **Integrated GPU** | AMD Radeon 8060S (`gfx1151`, RDNA 3.5) |
| **Compute Units (CUs)** | 40 CUs (2560 Stream Processors, 80 Matrix Accelerators / WMMA) |
| **Memory Bus** | 256-bit wide LPDDR5X-8000 (8000 MT/s) |
| **Theoretical Peak Bandwidth** | $256 \text{ bits} \times \frac{8000 \times 10^6 \text{ transfers/sec}}{8 \text{ bits/byte}} \approx 256.0 \text{ GB/s}$ (Up to 273 GB/s @ 8533 MT/s) |
| **Sustained Measured DRAM Bandwidth** | **~220.0 GB/s** (accounting for refresh cycles, protocol overhead, and crossbar contention) |
| **Unified Memory Size** | 32 GB physical (~29.9 GiB accessible by Linux kernel) |

---

## 2. Bandwidth Physics & Token Generation Speed

Autoregressive language model generation (single batch, text decoding) is strictly **memory bandwidth bound**. For every token generated, all active model weights must be streamed from unified system memory into GPU registers:

$$\text{Tokens per Second (t/s)} \approx \frac{\text{Sustained DRAM Bandwidth}}{\text{Active Weights Loaded per Token}}$$

$$\text{t/s} \approx \frac{220 \text{ GB/s}}{\text{Active Memory Size (GB)}}$$

### Dense vs. Sparse MoE Comparison on 32GB Strix Halo

| Model Architecture | Total Params | Active Params / Token | Quantization Format | Active Weights Memory | Theoretical Max Speed | Real Sustained Speed | Free System RAM (64k Ctx) | OOM Risk Factor |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Dense 70B** | 70 B | 70 B | Q4_K_M (~40 GB) | 40 GB | 5.5 t/s | **N/A (Exceeds Physical RAM)** | 0 GB | **Immediate Crash** |
| **Dense 32B** | 32 B | 32 B | Q4_K_M (~20 GB) | 20 GB | 11.0 t/s | **~10.8 t/s** | < 1.5 GB | **Extreme (System Freeze)** |
| **Dense 24B** | 24 B | 24 B | Q4_K_M (~14 GB) | 14 GB | 15.7 t/s | **~15.2 t/s** | ~10.5 GB | Low |
| **Dense 14B** | 14 B | 14 B | Q4_K_M (~8.5 GB) | 8.5 GB | 25.8 t/s | **~24.5 t/s** | ~16.0 GB | Zero |
| **Dense 7B/8B** | 8 B | 8 B | Q4_K_M (~4.8 GB) | 4.8 GB | 45.8 t/s | **~42.0 t/s** | ~20.0 GB | Zero |
| **MoE 35B / 3.0B Active** | 35 B | 3.0 B | ROCmFP4 (~17.4 GB) | ~2.3 GB | 95.6 t/s | **~71.5 t/s** | ~7.9 GB | Low |
| **MoE 30B / 3.0B Active** | 30 B | 3.0 B | Q4_K_M (~17.3 GB) | ~2.3 GB | 95.6 t/s | **~84.0 t/s** | ~7.9 GB | Low |
| **MoE 21B / 3.6B Active** | 20.9 B | 3.6 B | MXFP4 (~11.3 GB) | ~2.0 GB | 110.0 t/s | **~81.6 t/s (Peak 125 t/s)**| **~15.0 GB** | **Zero (Ideal Daily)** |
| **MoE 16B / 2.4B Active** | 16 B | 2.4 B | Q4_K_M (~9.8 GB) | ~1.6 GB | 137.5 t/s | **~135.0 t/s** | ~19.5 GB | Zero |

### Key Architectural Takeaways

1. **Dense 32B is a Non-Viable Trap on 32GB Unified Memory**: Loading a 20 GB dense model leaves less than 1.5 GB of free RAM once a 64k context KV-cache is allocated. Running any real agent tool (such as Playwright, Docker, or gcc) will trigger the Linux OOM-killer.
2. **MoE is Mandatory for High Performance**: Mixture-of-Experts architectures decouple total reasoning capacity from active inference bandwidth. A 20B–35B MoE matches or beats a dense 32B model in reasoning, but requires streaming only 2.0–2.3 GB of weights per token, unlocking **70–95 t/s generation**.
3. **KV Cache Compression**: At 64k–128k context lengths, standard 16-bit KV cache takes:
   $$\text{KV Size (FP16, 128k)} \approx 2 \times n_{\text{layers}} \times n_{\text{kv\_heads}} \times d_{\text{head}} \times 131,072 \times 2 \approx 8.5 \text{ GB}$$
   By applying `-ctk q8_0 -ctv q4_0` (8-bit keys to preserve attention matrix resolution, 4-bit values to halve storage), KV cache size drops to **~3.2 GB**, saving over 5 GB of precious unified RAM.

---

## 3. Dual-CCX Topology & Thread Isolation

The Ryzen AI MAX+ 392 contains two distinct Core Complex Dies (CCXs):
- **CCX0**: Cores 0–5 (Threads 0–5, 12–17) with dedicated 32MB L3 cache.
- **CCX1**: Cores 6–11 (Threads 6–11, 18–23) with dedicated 32MB L3 cache.

### Interconnect Latency Penalty
Inter-core latency within the same CCX is **< 18 nanoseconds**. Traversing the Infinity Fabric interconnect to access the adjacent CCX spikes latency to **> 72 nanoseconds (a 4x penalty)**.

### The CCX0 Mask Solution
By passing `--cpu-mask 0x3F` (binary `000000111111`, locking execution strictly to Cores 0 through 5):
- All 6 inference CPU worker threads share the same fast 32MB L3 cache.
- L3 cache thrashing and cross-die bus traffic are eliminated.
- CCX1 (Cores 6–11) remains 100% idle and available for the host operating system, web browser agents, network I/O, and test execution harnesses.
