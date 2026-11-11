# Vulkan & Runtime Tuning Invariants for AMD Radeon 8060S

This document details the environment variables, compiler flags, and `llama-server` CLI parameters engineered to achieve maximum throughput and stability on the Radeon 8060S (`gfx1151`, 40 CUs, RDNA 3.5).

---

## 1. Vulkan Environment Variables

The following environment variables must be exported prior to starting `llama-server` or `llama-bench`:

```bash
# 1. Eliminate host-visible page-table mapping of VRAM (drops host RSS from 6.8 GB to 84 MB)
export GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1

# 2. Disable MMVQ compute shader; routes matrix ops through hardware WMMA / KHR_coopmat
export GGML_VK_DISABLE_MMVQ=1

# 3. 256MB suballocation blocks prevent 1GB coarse memory padding and fragmentation
export GGML_VK_SUBALLOCATION_BLOCK_SIZE=268435456

# 4. Enable dedicated Vulkan transfer queue for concurrent DMA transfers
export GGML_VK_ASYNC_USE_TRANSFER_QUEUE=1

# 5. Allow Mesa ACO compiler to select native Wave64 for reduction/norm passes (+11% prefill on GFX1151)
unset RADV_PERFTEST 2>/dev/null || true
```

### In-Depth Explanations

### `GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1`
By default, Vulkan backends often request `VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT` memory for buffers. On unified memory systems, this causes the Linux kernel to create duplicate CPU page-table mappings for device memory, inflating host Resident Set Size (RSS) by 5–7 GiB. Setting this to `1` forces allocations into purely device-local memory (`VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT`), instantly recovering ~6.7 GB of host memory.

### `GGML_VK_DISABLE_MMVQ=1`
`MMVQ` (Matrix-Multiplication-Vector Quantized) is a custom compute shader originally designed for older GCN/RDNA1 architectures lacking hardware tensor cores. On RDNA 3.5 (`gfx1151`), the hardware features dedicated **WMMA (Wave Matrix Multiply-Accumulate)** units via the Vulkan `VK_KHR_cooperative_matrix` extension. Disabling MMVQ forces the GGML Vulkan backend to route single-token decoding through hardware WMMA, boosting generation efficiency and lowering GPU power consumption.

### `GGML_VK_SUBALLOCATION_BLOCK_SIZE=268435456` (256 MB)
The default GGML Vulkan memory allocator provisions memory in large 1 GiB coarse chunks. When running multiple context buffers or loading quantized tensors, this coarse granularity wastes up to 2–3 GiB in internal fragmentation padding. Reducing the block size to 256 MB ($256 \times 1024 \times 1024 = 268,435,456$ bytes) gives fine-grained control and prevents memory exhaustion.

### Mesa ACO Wave64 Compiler Dynamic Selection
The Mesa ACO shader compiler for RADV natively optimizes matrix dot products using Wave64 mode on RDNA 3.5 compute units. Forcing `RADV_PERFTEST=wave32` harms prompt prefill throughput by up to 11%. Unsetting `RADV_PERFTEST` allows Mesa to pick Wave64 for reduction and norm passes and Wave32 for branch-heavy control kernels.

---

## 2. Recommended `llama-server` CLI Invariants

```bash
llama-server \
  --model /path/to/model.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  --ctx-size 65536 \
  --n-gpu-layers 999 \
  --batch-size 2048 \
  --ubatch-size 512 \
  --flash-attn on \
  --load-mode mmap \
  --cache-type-k q8_0 \
  --cache-type-v q4_0 \
  --cpu-mask 0x3F \
  --cpu-strict 1 \
  --threads 6 \
  --threads-http 2
```

### Parameter Explanations

| Flag | Recommended Value | Purpose |
| :--- | :--- | :--- |
| `--load-mode` | `mmap` | Keeps model weights backed directly by the Linux page cache file rather than allocating anonymous RAM pages. Enables instant OS teardown and prevents double-allocation. |
| `--flash-attn` | `on` | Enables Flash Attention kernel in Vulkan, dropping attention compute complexity from $O(N^2)$ to $O(N)$ and drastically reducing VRAM usage at large contexts. |
| `-ctk` / `-ctv` | `q8_0` / `q4_0` | Compresses Key cache to 8-bit and Value cache to 4-bit. Saves ~40-50% KV memory with virtually zero perplexity loss, permitting 64k–128k contexts. |
| `-b` / `-ub` | `2048` / `512` | Decouples logical prompt batch (`-b 2048`) from compute sub-batch (`-ub 512`). Prevents GPU queue starvation while avoiding large kernel dispatch timeouts on the Radeon 8060S. |
| `--cpu-mask` | `0x3F` | Restricts CPU worker threads to CCX0 (Cores 0-5), sharing the 32MB L3 cache and leaving CCX1 (Cores 6-11) for system tasks and agent browsers. |
| `--threads` | `6` | Matches the 6 physical cores of CCX0. Hyperthreading/SMT threads are unnecessary for Vulkan offloading and cause context-switch overhead. |
