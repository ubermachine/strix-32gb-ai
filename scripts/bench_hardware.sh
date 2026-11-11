#!/usr/bin/env bash
# ==============================================================================
# Hardware Throughput Profiler (llama-bench) for Radeon 8060S
# Measures prompt processing (pp512, pp2048) and text generation (tg128)
# ==============================================================================
set -euo pipefail

LLAMA_BENCH="${LLAMA_BENCH:-$HOME/.local/bin/llama-bench}"
if ! command -v "$LLAMA_BENCH" >/dev/null 2>&1; then
    LLAMA_BENCH=$(which llama-bench 2>/dev/null || find "$HOME" -name "llama-bench" 2>/dev/null | head -n 1)
fi

if [[ -z "$LLAMA_BENCH" || ! -x "$LLAMA_BENCH" ]]; then
    echo "[-] Error: llama-bench binary not found."
    exit 1
fi

MODEL="${1:-$HOME/Desktop/AI/llama/models/gpt-oss-20b-heretic-v2.i1-MXFP4_MOE.gguf}"

if [[ ! -f "$MODEL" ]]; then
    echo "[-] Error: Model file not found: $MODEL"
    echo "    Usage: $0 [/path/to/model.gguf]"
    exit 1
fi

echo "[+] Profiling Hardware Throughput on Radeon 8060S..."
echo "    Model: $MODEL"

export GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1
export GGML_VK_DISABLE_MMVQ=1
export GGML_VK_SUBALLOCATION_BLOCK_SIZE=268435456
export GGML_VK_ASYNC_USE_TRANSFER_QUEUE=1
unset RADV_PERFTEST 2>/dev/null || true

"$LLAMA_BENCH" \
    -m "$MODEL" \
    -p 512,2048 \
    -n 128 \
    -ngl 999 \
    -fa 1 \
    -b 2048 \
    -ub 512 \
    -t 6 \
    -o md
