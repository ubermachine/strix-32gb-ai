#!/usr/bin/env bash
# ==============================================================================
# Stop All Local AI Daemons Cleanly
# ==============================================================================
set -euo pipefail

echo "[+] Terminating llama-server and associated inference processes..."
pkill -TERM -f llama-server 2>/dev/null || true
pkill -TERM -f llama-bench 2>/dev/null || true

# Wait up to 5 seconds for clean exit
for i in {1..5}; do
    if ! pgrep -f llama-server >/dev/null 2>&1; then
        echo "[✓] All inference daemons stopped successfully."
        exit 0
    fi
    sleep 1
done

# If still running, force kill
if pgrep -f llama-server >/dev/null 2>&1; then
    echo "[!] Forcing kill (SIGKILL)..."
    pkill -KILL -f llama-server 2>/dev/null || true
fi

echo "[✓] Clean."
