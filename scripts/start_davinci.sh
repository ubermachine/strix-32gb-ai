#!/usr/bin/env bash
# ==============================================================================
# Launch Davinci-Tool-30B (Browser Automation & Dirty Scraping Specialist)
# Optimized for AMD Radeon 8060S (Strix Halo 32GB)
# ==============================================================================
set -euo pipefail

LLAMA_SERVER="${LLAMA_SERVER:-$HOME/.local/bin/llama-server}"
if ! command -v "$LLAMA_SERVER" >/dev/null 2>&1; then
    LLAMA_SERVER=$(which llama-server 2>/dev/null || echo "")
fi

MODEL_PATHS=(
    "${MODEL_PATH:-}"
    "./models/Davinci-Tool-30B.gguf"
    "$HOME/models/Davinci-Tool-30B.gguf"
    "$HOME/Desktop/AI/llama/models/Davinci-Tool-30B.gguf"
)

MODEL=""
for p in "${MODEL_PATHS[@]}"; do
    if [[ -n "$p" && -f "$p" ]]; then
        MODEL="$p"
        break
    fi
done

if [[ -z "$MODEL" ]]; then
    echo "[-] Error: Davinci-Tool-30B model file not found. Set MODEL_PATH=/path/to/Davinci-Tool-30B.gguf"
    exit 1
fi

echo "[+] Launching Davinci-Tool-30B..."
echo "    Model: $MODEL"
echo "    Port:  8080"
echo "    Ctx:   65536 (64k)"

pkill -f llama-server 2>/dev/null || true
sleep 1

export GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1
export GGML_VK_DISABLE_MMVQ=1
export GGML_VK_SUBALLOCATION_BLOCK_SIZE=268435456
export GGML_VK_ASYNC_USE_TRANSFER_QUEUE=1
unset RADV_PERFTEST 2>/dev/null || true

exec "$LLAMA_SERVER" \
    --model "$MODEL" \
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
