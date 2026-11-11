# AMD Strix Halo Model Fleet & Recommendation Matrix

This document provides complete architectural specifications, memory footprints, and practical specializations for each verified model in the Strix Halo fleet.

---

## 1. Fleet Overview

| Model Identifier | Architecture | Quant Format | On-Disk Size | Active Params / Token | Generation Speed | Prompt Prefill (pp2048) | Recommended Context | Free System RAM | Primary Specialization |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`gpt-oss-20b-heretic-v2`** | MoE (20.9B) | MXFP4 | 11.28 GB | ~3.6 B | **81–89 t/s** (Peak 125 t/s) | **2,171.4 t/s** | **131,072 (128k)** | **~15.0 GB** | **Daily Driver & Multi-Agent Loops** |
| **`Tiel-Coder-35B-A3B` (Strix Lean)** | MoE (35.0B) | ROCmFP4 | 17.45 GB | ~3.0 B | **71.5 t/s** | **1,002.8 t/s** | **65,536 (64k)** | **~7.9 GB** | **Flawless Multi-Tool Calling (100% BFCL)** |
| **`Davinci-Tool-30B`** | MoE (30.0B) | Q4_K_M | 17.28 GB | ~3.0 B | **83.9 t/s** | **1,049.8 t/s** | **65,536 (64k)** | **~7.9 GB** | **Browser Agents & Dirty Web Extraction** |
| **`Qwen3-Coder-30B-A3B`** | MoE (30.0B) | Q4_K_M | 17.28 GB | ~3.0 B | **94.0 t/s** (Peak 352 t/s) | **1,047.6 t/s** | **65,536 (64k)** | **~7.9 GB** | **Systems Coding & AST Refactoring** |

---

## 2. Model Deep Dives

### 1. `gpt-oss-20b-heretic-v2` (The Uncensored Daily Driver)
* **Weights & Quantization:** MXFP4 (Microscaling FP4 weights, unquantized FP16 attention norms).
* **Context Capacity:** 131,072 tokens native context.
* **Why it wins:**
  - Consumes only 11.28 GB of weights. With 128k context and compressed KV cache, total memory is under 15 GB, leaving **15 GB of host RAM completely free**.
  - Blazing **2,171 t/s prefill** speeds up ingestion of massive multi-file repositories in seconds.
  - Passes 100% of Aider code-editing benchmarks and 100% of Frontier V4 adversarial cases.
  - Zero safety refusals: will not block security audits, vulnerability scanning, or complex reverse engineering code.

### 2. `Tiel-Coder-35B-A3B` Strix Lean (The Tool-Calling Champion)
* **Weights & Quantization:** ROCmFP4 GGML format.
* **Context Capacity:** 65,536 tokens.
* **Why it wins:**
  - **100% score (6/6) on Berkeley Function Calling Leaderboard (BFCL)**: the only local model tested that reliably succeeds at 3-way parallel tool execution in a single turn without hallucinating missing arguments.
  - **100% on Aider Code Editing (3/3)** with zero-shot and reflection capabilities.
  - Tuned with custom FP4 GEMM matrix kernels running at 71.5 t/s sustained generation.

### 3. `Davinci-Tool-30B` (The Browser Automation Specialist)
* **Weights & Quantization:** Q4_K_M.
* **Context Capacity:** 65,536 tokens.
* **Why it wins:**
  - DPO fine-tuned directly on real headless browser traces, dynamic JavaScript navigation, and Playwright execution loops.
  - Capable of extracting direct download URLs and API endpoints from obfuscated, broken HTML and raw 22k-token JSON dumps zero-shot.
  - Emits parallel bash/curl calls with automated fallback logic.

### 4. `Qwen3-Coder-30B-A3B` (The Systems & Refactoring Engine)
* **Weights & Quantization:** Q4_K_M.
* **Context Capacity:** 65,536 tokens.
* **Why it wins:**
  - **Fastest raw generation speed in the fleet**: Sustained **94 tokens/second** generation.
  - Deep domain knowledge of C, C++, Rust, and Linux system calls.
  - Excellent at multi-file diff hunks and understanding complex compiler errors and stack traces.

---

## 3. Workflow Decision Tree

```
Are you running an agent task?
├── Coding & General Software Engineering
│   ├── Everyday coding, broad tasks, large context repo ingestion (>=64k)
│   │   └──> gpt-oss-20b-heretic-v2 (Fastest prefill, 128k ctx, 15GB free RAM)
│   └── Low-level systems, C++/Rust refactoring, compiler debug loops
│       └──> Qwen3-Coder-30B-A3B (94 t/s generation)
│
├── Autonomous Agent & Tool Loops
│   ├── Complex JSON schemas, multi-tool APIs, parallel function calls
│   │   └──> Tiel-Coder-35B-A3B (100% BFCL, zero parameter hallucination)
│   └── Browser automation, Playwright, web scraping, dirty HTML/JSON
│       └──> Davinci-Tool-30B (Browser trace DPO tuned)
```
