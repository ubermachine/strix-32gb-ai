# Linux Kernel & OS Tuning for AMD Strix Halo (32GB)

To maximize stable unified memory allocation and prevent system freeze/OOM kills, the Linux kernel, driver subsystem, and memory manager must be configured to treat the integrated Radeon 8060S as a high-bandwidth accelerator with dynamic access to system RAM.

---

## 1. BIOS Configuration (Pre-boot)

1. Enter UEFI/BIOS settings (usually `F2` or `Del` on boot).
2. Locate **Advanced -> AMD CBS -> NBIO Common Options -> GFX Configuration**.
3. Set **UMA Frame Buffer Size** to **512M** (or lowest allowed option, e.g. Auto / 512M).

> **Why:** The BIOS UMA setting creates a static, permanent memory carve-out that is quarantined from the Linux kernel. A 16 GB carve-out permanently steals half your RAM, leaving standard desktop processes starved. Setting 512MB allows Linux to boot with 29.9+ GiB accessible RAM, while the AMDGPU driver dynamically provisions up to 26 GiB of VRAM on-demand via the Graphics Translation Table (GTT).

---

## 2. Kernel Parameters (`/etc/default/grub`)

Edit `/etc/default/grub` and update `GRUB_CMDLINE_LINUX_DEFAULT`:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=off amdgpu.gttsize=26624 ttm.pages_limit=6815744 amdgpu.lockup_timeout=60000"
```

Then regenerate grub configuration:
```bash
sudo update-grub
```

### Parameter Breakdown

| Parameter | Value | Technical Justification |
| :--- | :--- | :--- |
| **`ttm.pages_limit`** | `6815744` | Configures Translation Table Manager (TTM) pool limit. Formula: $\frac{26 \text{ GiB} \times 1024 \times 1024 \times 1024}{4096 \text{ bytes/page}} = 6,815,744\text{ pages}$. Default Linux TTM caps device memory to 50% of RAM (15 GiB), which forces large models to fail allocation. Setting this allows the iGPU to safely allocate up to 26 GiB. |
| **`amdgpu.gttsize`** | `26624` | Sets the AMDGPU GTT aperture to 26,624 MiB (26.0 GiB), matching the TTM limit. |
| **`amd_iommu=off`** | `off` | Bypasses IOMMU translation for unified memory DMA. Eliminates IOMMU page table walk overhead and TLB shootdown latency when streaming model weights from host RAM to GPU compute units. |
| **`amdgpu.lockup_timeout`** | `60000` | Extends GPU job dispatch watchdog timeout to 60,000 ms (60 seconds). During massive prompt prefill (e.g. 64k–128k prompt ingest), compute shaders can hold GPU queues for >10 seconds; the default 10s kernel timeout would trigger a spurious GPU reset. |

---

## 3. Sysctl Virtual Memory Invariants (`/etc/sysctl.d/99-strix-ai.conf`)

Create `/etc/sysctl.d/99-strix-ai.conf`:

```ini
# Support high count of memory mapped model weights
vm.max_map_count = 1048576

# Prevent aggressive swapping during large prompt ingest
vm.swappiness = 10

# Ensure memory allocations fail immediately instead of kernel freeze
vm.overcommit_memory = 0
```

Apply immediately:
```bash
sudo sysctl -p /etc/sysctl.d/99-strix-ai.conf
```

---

## 4. EarlyOOM Supervisor Setup

On a 32GB unified memory machine running heavy LLM inference alongside web scrapers or compilers, standard Linux kernel OOM killer takes too long to respond, leading to complete desktop freeze. `earlyoom` monitors free RAM and sends `SIGTERM` / `SIGKILL` cleanly before the kernel panics.

### Installation
```bash
sudo apt update && sudo apt install -y earlyoom
```

### Configuration (`/etc/default/earlyoom`)
```ini
# Terminate when free RAM is below 5% and swap below 10%
EARLYOOM_ARGS="-m 5 -s 10 -r 60 --avoid '(init|systemd|sshd|Xorg|gnome-shell|wayland)' --prefer '(chromium|chrome|firefox|node)'"
```

Restart service:
```bash
sudo systemctl restart earlyoom && sudo systemctl enable earlyoom
```
