# AMD Strix Halo (32GB) AI Inference Fleet & Engineering Guide

Production-grade deployment blueprints, hardware-tuned runtime invariants, and curated local model configurations for the **AMD Ryzen AI MAX+ 392 (Strix Halo)** APU with **Radeon 8060S** graphics (40 Compute Units, RDNA 3.5, `gfx1151`) and **32 GB unified LPDDR5X-8000** memory.

---

## 1. Why Strix Halo 32GB is Different

Running local AI models on unified-memory APUs is fundamentally different from discrete PCIe GPUs:

1. **Bandwidth Physics dictate Model Selection**: With a 256-bit bus delivering **~220 GB/s sustained DRAM throughput**, dense 32B models run at only **~11 tokens/sec** and consume $\approx$20 GB VRAM, triggering system-wide OOM panics when browser agents launch. Sparse **MoE models (20B–35B with 2.4B–3.6B active parameters)** achieve **70–95+ tokens/sec** while consuming only 11–17 GB, leaving 13–15 GB of host RAM completely free for headless Chromium, compiler subagents, and OS tasks.
2. **Eliminating the UMA Carve-out Bottleneck**: Setting BIOS UMA VRAM to 512 MB (minimum) allows Linux GTT dynamic memory allocation (`ttm.pages_limit=6815744`) to dynamically supply up to 26 GB of device memory without static RAM reservation.
3. **CCX L3 Cache Locality**: The 12 Zen 5 cores are split into two CCXs (Cores 0-5 and 6-11) each with an independent 32MB L3 cache. Thread pinning (`--cpu-mask 0x3F`) guarantees worker threads never pay cross-CCX interconnect penalty.
4. **Vulkan WMMA & Buffer Alignment**: Leveraging Mesa ACO Wave64 matrix operations (`KHR_coopmat` / WMMA) and 256MB suballocation blocks prevents device fragmentation and Host-Visible RAM bloat.

---

## 2. Model Fleet Matrix

All models serve standard OpenAI-compatible endpoints (`http://127.0.0.1:8080/v1`):

| Model Architecture | Size | Active / Total | Gen Speed | Free Host RAM | Specialization | Launcher |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`gpt-oss-20b-heretic-v2`** | 11.28 GB (MXFP4) | 3.6B / 20.9B | **71–89 t/s** | **~15.0 GB** | **Daily Driver**, Coding (100% Aider), Native 128k Context, Zero Safety Refusals | `scripts/start_gpt_oss.sh` |
| **`Tiel-Coder-35B-A3B` (Strix Lean)** | 17.45 GB (ROCmFP4) | 3.0B / 35.0B | **71 t/s** | **~7.9 GB** | **Flawless Multi-Tool Calling** (100% BFCL 6/6), Parallel Tool Execution, 100% Aider | `scripts/start_tiel_lean.sh` |
| **`Davinci-Tool-30B`** | 17.28 GB (Q4_K_M) | 3.0B / 30.0B | **84 t/s** | **~7.9 GB** | **Browser Automation**, Media Extraction, Broken HTML parsing, Parallel Dispatch | `scripts/start_davinci.sh` |
| **`Qwen3-Coder-30B-A3B`** | 17.28 GB (Q4_K_M) | 3.0B / 30.0B | **94 t/s** | **~7.9 GB** | **Systems Engineering**, C++/Rust AST Refactoring, High-Throughput Batch Gen | `scripts/start_qwen3_coder.sh` |

---

## 3. Quick Start

### Prerequisites
- AMD Ryzen AI MAX+ 392 / Radeon 8060S (`gfx1151`)
- Linux Kernel 6.12+ (tested on 6.14/7.2 generic)
- Mesa 25.0+ RADV Vulkan driver with `KHR_coopmat` support
- `llama.cpp` built with Vulkan (`-DGGML_VULKAN=ON`)

### 1. Apply System & Kernel Tuning
Run the setup script (requires sudo to update GRUB and limits):
```bash
sudo bash scripts/setup_system_tuning.sh
```

### 2. Launch a Model
```bash
# Launch Daily Driver (GPT-OSS-20B Heretic v2 @ 128k Context):
bash scripts/start_gpt_oss.sh

# Or launch the 100% BFCL Tool Calling Specialist:
bash scripts/start_tiel_lean.sh
```

### 3. Check Health
```bash
curl -s http://127.0.0.1:8080/health
```

### 4. Stop Daemons
```bash
bash scripts/stop_all.sh
```

---

## 4. Repository Structure

```
├── README.md                      # Fleet dashboard & runtime guide
├── LICENSE                        # MIT License
├── docs/
│   ├── HARDWARE_PHYSICS.md        # Mathematical memory bandwidth & t/s derivations
│   ├── KERNEL_TUNING.md           # GRUB, TTM 26GB pool, IOMMU, earlyoom configs
│   ├── VULKAN_RUNTIME.md          # Environment variables, WMMA shaders, suballocation
│   ├── MODEL_FLEET.md             # Detailed breakdown of active models & quantizations
│   └── SCORECARDS.md              # Empirical benchmarks (llama-bench, BFCL, Aider, V4)
├── scripts/
│   ├── setup_system_tuning.sh     # One-shot system and kernel configuration
│   ├── start_gpt_oss.sh           # Daily Driver launcher (128k context, FP16 KV)
│   ├── start_tiel_lean.sh         # Tool calling launcher (100% BFCL)
│   ├── start_davinci.sh           # Web / Browser agent launcher
│   ├── start_qwen3_coder.sh       # Systems coding launcher
│   ├── stop_all.sh                # Clean daemon terminator
│   └── bench_hardware.sh          # llama-bench throughput test runner
└── config/
    └── earlyoom.default           # Aggressive OOM prevention configuration
```

---

## 5. Technical Documentation Index

- **[HARDWARE_PHYSICS.md](docs/HARDWARE_PHYSICS.md)**: Derivations of LPDDR5X-8000 memory bandwidth, single-token decode limits, and CCX latency isolation.
- **[KERNEL_TUNING.md](docs/KERNEL_TUNING.md)**: Kernel cmdline flags (`ttm.pages_limit`, `amd_iommu=off`, `amdgpu.lockup_timeout`) and earlyoom tuning.
- **[VULKAN_RUNTIME.md](docs/VULKAN_RUNTIME.md)**: Vulkan runtime flags (`GGML_VK_DISABLE_MMVQ`, suballocation sizing, Wave64 ACO compiler flags).
- **[MODEL_FLEET.md](docs/MODEL_FLEET.md)**: Complete quant, context, and specialization parameters.
- **[SCORECARDS.md](docs/SCORECARDS.md)**: Verified test scores across Aider diff editing, BFCL tool calling, Frontier V4 adversarial cases, and raw throughput.

---

## License
MIT License. See [LICENSE](LICENSE) for details.
