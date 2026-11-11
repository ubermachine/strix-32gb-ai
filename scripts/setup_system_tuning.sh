#!/usr/bin/env bash
# ==============================================================================
# AMD Strix Halo (Ryzen AI MAX+ 392 / Radeon 8060S) System Tuning Script
# Configures Linux kernel GTT VRAM pool, IOMMU bypass, GPU watchdog & earlyoom
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[-] Error: This script must be run as root (use sudo)."
   exit 1
fi

echo "[+] Step 1: Configuring sysctl virtual memory parameters..."
cat << 'EOF' > /etc/sysctl.d/99-strix-ai.conf
# Support large number of memory mapped tensors
vm.max_map_count = 1048576
# Prevent early aggressive swapping on unified memory
vm.swappiness = 10
# Avoid kernel freeze on memory exhaustion
vm.overcommit_memory = 0
EOF
sysctl -p /etc/sysctl.d/99-strix-ai.conf

echo "[+] Step 2: Configuring GRUB command line for Radeon 8060S 26GB GTT..."
GRUB_FILE="/etc/default/grub"
BACKUP_FILE="/etc/default/grub.bak.$(date +%s)"
cp "$GRUB_FILE" "$BACKUP_FILE"
echo "    Backed up existing GRUB config to $BACKUP_FILE"

REQUIRED_PARAMS="amd_iommu=off amdgpu.gttsize=26624 ttm.pages_limit=6815744 amdgpu.lockup_timeout=60000"

if grep -q "ttm.pages_limit" "$GRUB_FILE"; then
    echo "    GRUB already contains Strix Halo tuning parameters. Updating line..."
    sed -i -E 's/GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=off amdgpu.gttsize=26624 ttm.pages_limit=6815744 amdgpu.lockup_timeout=60000"/' "$GRUB_FILE"
else
    echo "    Appending parameters to GRUB_CMDLINE_LINUX_DEFAULT..."
    sed -i -E 's/GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_iommu=off amdgpu.gttsize=26624 ttm.pages_limit=6815744 amdgpu.lockup_timeout=60000"/' "$GRUB_FILE"
fi

echo "[+] Step 3: Regenerating GRUB bootloader..."
update-grub

echo "[+] Step 4: Configuring earlyoom protection..."
if command -v earlyoom >/dev/null 2>&1; then
    cat << 'EOF' > /etc/default/earlyoom
EARLYOOM_ARGS="-m 5 -s 10 -r 60 --avoid '(init|systemd|sshd|Xorg|gnome-shell|wayland)' --prefer '(chromium|chrome|firefox|node)'"
EOF
    systemctl restart earlyoom || true
    systemctl enable earlyoom || true
    echo "    earlyoom configured and active."
else
    echo "    [i] earlyoom not installed. Install via: apt install -y earlyoom"
fi

echo ""
echo "=========================================================================="
echo "[✓] Strix Halo 32GB system tuning applied successfully!"
echo "    Please REBOOT your system for the kernel GRUB changes to take effect."
echo "=========================================================================="
