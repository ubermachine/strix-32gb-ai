# Empirical Benchmark Scorecards (AMD Strix Halo / Radeon 8060S)

All benchmarks recorded empirically on bare-metal **AMD Ryzen AI MAX+ 392 (Strix Halo)**, **Radeon 8060S iGPU (40 CUs, RDNA 3.5, `gfx1151`)**, and **32GB LPDDR5X-8000** unified memory on Linux Kernel with Mesa RADV Vulkan.

---

## 1. Official Hardware Profiling (`llama-bench`)
*Tested across prompt sizes (512, 2048) and token generation (128 tokens) on Vulkan WMMA (6 CCX0 cores):*

| Model Architecture | Size | Active Parameters | Prompt Processing (pp512) | Prompt Processing (pp2048) | Text Generation (tg128) | Peak Generation (Speculative) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`gpt-oss-20b-heretic-v2`** | **11.28 GiB** | ~3.6 B (MXFP4) | **1,984.68 t/s** | **2,171.48 t/s** | **81.64 t/s** | **125.11 t/s** |
| **`openai/gpt-oss-20b`** | 11.27 GiB | ~3.6 B (MXFP4) | 1,984.68 t/s | 2,171.48 t/s | 81.64 t/s | 125.11 t/s |
| **`Davinci-Tool-30B`** | 17.28 GiB | ~3.0 B (Q4_K_M) | 1,248.66 t/s | 1,049.79 t/s | 83.95 t/s | 110.00 t/s |
| **`Qwen3-Coder-30B-A3B`**| 17.28 GiB | ~3.0 B (Q4_K_M) | 1,241.01 t/s | 1,047.63 t/s | 82.99 t/s | **352.00 t/s** |
| **`Tiel-Coder-35B-A3B` (Strix Lean)** | **17.45 GiB** | ~3.0 B (ROCmFP4) | **856.28 t/s** | **1,002.83 t/s** | **71.54 t/s** | N/A |
| `Cyber-Tiel-Coder-35B-A3B` | 20.81 GiB | ~3.0 B (Q4_K_XL) | 768.52 t/s | 670.95 t/s | 58.71 t/s | N/A |

---

## 2. Aider Code Editing Benchmark (`aider_code_benchmark.py`)
*Validates exact SEARCH/REPLACE diff syntax compliance, fuzzy hunk application, and automated unit test execution:*

| Problem / Test | `gpt-oss-20b-heretic-v2` | `openai/gpt-oss-20b` | `Qwen3-Coder-30B` | `Tiel-Coder-35B` (Strix Lean) |
| :--- | :--- | :--- | :--- | :--- |
| **1. Two Sum (Duplicates & Multi-Index)** | **PASSED [Zero-Shot]** (101.6 t/s) | **PASSED [Zero-Shot]** (88.8 t/s) | **PASSED [Zero-Shot]** (93.6 t/s) | **PASSED [Reflection]** (62.2 t/s) |
| **2. Expiring LRU Cache (TTL Eviction)** | **PASSED [Zero-Shot]** (114.8 t/s) | **PASSED [Zero-Shot]** (108.7 t/s) | FAILED (diff drift) | **PASSED [Zero-Shot]** (55.1 t/s) |
| **3. SemVer 2.0 Parser & Comparator** | **PASSED [Reflection]** (95.4 t/s) | **PASSED [Reflection]** (81.7 t/s) | **PASSED [Reflection]** (73.6 t/s) | **PASSED [Reflection]** (62.0 t/s) |
| **Total Solved Pass Rate** | **3 / 3 (100.0%)** | **3 / 3 (100.0%)** | 2 / 3 (66.7%) | **3 / 3 (100.0%)** |

---

## 3. Berkeley Function Calling Leaderboard (`bfcl_standard_suite.py`)
*Evaluates single-tool, multi-tool disambiguation, parallel calls, enum checking, and anti-hallucination refusal:*

| Test Category | `gpt-oss-20b-heretic-v2` | `Davinci-Tool-30B` | `Tiel-Coder-35B` (Strix Lean) |
| :--- | :--- | :--- | :--- |
| **1. Simple Typed Function Call** | **PASSED** (57.7 t/s) | **PASSED** (29.2 t/s) | **PASSED** (32.4 t/s) |
| **2. Multi-Tool Disambiguation** | **PASSED** (58.2 t/s) | **PASSED** (29.6 t/s) | **PASSED** (31.5 t/s) |
| **3. Parallel Tool Calling (3 calls / turn)**| FAILED (Emitted 1 call) | **PASSED** (Emitted 3 calls) | **PASSED** (43.5 t/s) |
| **4. Enum & Constraint Validation** | **PASSED** (62.0 t/s) | **PASSED** (34.9 t/s) | **PASSED** (38.7 t/s) |
| **5. Missing Parameter Anti-Hallucination** | **PASSED** (Refrained & asked) | FAILED (Hallucinated param) | **PASSED** (Refrained & asked) |
| **6. Complex Nested JSON Schema** | **PASSED** (71.1 t/s) | **PASSED** (51.7 t/s) | **PASSED** (48.5 t/s) |
| **Total BFCL Score** | **5 / 6 (83.3%)** | **5 / 6 (83.3%)** | **6 / 6 (100.0%) PERFECT** |

---

## 4. Frontier Challenge V4 Benchmark (`challenge_v4_frontier.py`)
*Adversarial agent engineering edge cases:*

| Edge Case Test | `gpt-oss-20b-heretic-v2` | `Davinci-Tool-30B` | `Tiel-Coder-35B` (Strix Lean) |
| :--- | :--- | :--- | :--- |
| **V4-1: Obfuscated JS Unpacking** | **PASSED (113.1 t/s)** | **PASSED** | FAILED |
| **V4-2: Cloudflare Turnstile Iframe** | **PASSED (72.2 t/s)** | **PASSED** | **PASSED (49.2 t/s)** |
| **V4-3: Range Assembly & SHA256** | **PASSED (75.9 t/s)** | **PASSED** | **PASSED (61.1 t/s)** |
| **V4-4: WebSocket Stream Sniffing** | **PASSED (74.9 t/s)** | FAILED | FAILED |
| **V4-5: Fuzzy Git Patch Drift** | **PASSED (68.1 t/s)** | FAILED | FAILED |
| **V4-6: SQL Injection Parameterization**| **PASSED (75.3 t/s)** | FAILED | FAILED |
| **V4-7: Resumable Multipart cURL** | **PASSED (75.1 t/s)** | FAILED | FAILED |
| **V4-8: Zombie Subtree Process Kill** | **PASSED (104.0 t/s)** | **PASSED** | **PASSED (65.3 t/s)** |
| **Total Frontier V4 Score** | **8 / 8 (100.0%)** | 4 / 8 (50.0%) | 3 / 8 (37.5%) |

---

## 5. Real-World LibGen Failure Trace Replay (`trace_replay_test.py`)
*Replays stranded agent state trapped on LibGen's 22k-token raw `json.php` API endpoint:*

| Model | Turn 1: Zero-Shot | Turn 2: Self-Healing Reflection | Final Result | Latency / Speed |
| :--- | :--- | :--- | :--- | :--- |
| **`gpt-oss-20b-heretic-v2`** | FAILED (Trapped in Viewport) | **PASSED (Navigated with MD5/ID)** | **PASSED (Reflection)** | **1.43s @ 61.6 t/s** |
| **`openai/gpt-oss-20b`** | **PASSED (Navigation)** | **PASSED (Navigated with MD5/ID)** | **PASSED (100% Recovery)** | **0.90s @ 101.2 t/s** |
| **`Davinci-Tool-30B`** | **PASSED (Zero-Shot bash/curl)** | N/A (Solved in Turn 1) | **PASSED (Zero-Shot)** | **1.80s @ 31.4 t/s** |
| **`Tiel-Coder-35B` (Strix Lean)** | **PASSED (Playwright code: extracted MD5/ID)** | N/A (Solved in Turn 1) | **PASSED (Zero-Shot Code)** | **5.28s @ 50.4 t/s** |
