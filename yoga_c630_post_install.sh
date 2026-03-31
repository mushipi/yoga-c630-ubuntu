#!/usr/bin/env bash
# Yoga C630 — Ubuntu 24.04.4 LTS ARM64 Post-Installation Script
# Run AFTER first boot into Ubuntu on the external SSD
# Usage: sudo bash yoga_c630_post_install.sh
#
# Hardware: Snapdragon 850 (SDM850), 8GB RAM, Adreno 630
# Firmware backup expected at: /media/$USER/*/firmware_backup/

set -euo pipefail

# ===== Config =====
FIRMWARE_DEST="/lib/firmware/qcom/sdm850"
SYSCTL_CONF="/etc/sysctl.d/99-yoga-c630.conf"
ZRAMSWAP_CONF="/etc/default/zramswap"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

log_section() { echo -e "\n${CYAN}${BOLD}========================================${NC}"; echo -e "${CYAN}${BOLD}  $1${NC}"; echo -e "${CYAN}${BOLD}========================================${NC}"; }
log_ok()      { echo -e "  ${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
log_fail()    { echo -e "  ${RED}[FAIL]${NC} $1"; }
log_info()    { echo -e "  [*] $1"; }

# ===== Root check =====
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Run as root: sudo bash $0${NC}"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"

# ===== Phase 5-1: Firmware Placement =====

log_section "Phase 5-1: Firmware Placement"

mkdir -p "$FIRMWARE_DEST"
log_ok "Created: $FIRMWARE_DEST"

# Auto-locate firmware backup on mounted volumes
BACKUP_DIR=""
for mount in /media/"$REAL_USER"/*/firmware_backup /mnt/*/firmware_backup; do
    if [[ -d "$mount" ]]; then
        BACKUP_DIR="$mount"
        log_ok "Found firmware backup: $BACKUP_DIR"
        break
    fi
done

if [[ -z "$BACKUP_DIR" ]]; then
    log_warn "Firmware backup directory not found at expected paths."
    log_warn "Mount the SSD backup and set BACKUP_DIR manually, or copy files to:"
    log_warn "  $FIRMWARE_DEST"
    log_warn "Expected files: qcdxkmsuc850.mbn, qcadsp850.mbn, bdwlan.bin, etc."
else
    # Copy firmware files
    FIRMWARE_FILES=(
        "qcadsp850.mbn"
        "bdwlan.bin"
        "qcvss850.mbn"
        "qcslpi850.mbn"
        "qccdsp850.mbn"
    )

    for fw in "${FIRMWARE_FILES[@]}"; do
        src="$BACKUP_DIR/$fw"
        if [[ -f "$src" ]]; then
            cp "$src" "$FIRMWARE_DEST/"
            log_ok "Copied: $fw"
        else
            log_warn "Not found: $fw (skipping)"
        fi
    done

    # GPU ZAP shader requires pil-splitter conversion
    log_section "GPU ZAP Shader (Adreno 630)"
    ZAP_SRC="$BACKUP_DIR/qcdxkmsuc850.mbn"

    if [[ -f "$ZAP_SRC" ]]; then
        log_info "Installing pil-splitter for ZAP shader conversion..."

        # Install pip3 if needed
        apt-get install -y python3-pip python3-venv --quiet

        # Use virtual environment to avoid PEP 668 issues
        VENV_DIR="/tmp/pil_splitter_venv"
        python3 -m venv "$VENV_DIR"
        "$VENV_DIR/bin/pip" install pil-splitter --quiet

        # Run conversion
        cd /tmp
        cp "$ZAP_SRC" /tmp/qcdxkmsuc850.mbn
        "$VENV_DIR/bin/pil-splitter" /tmp/qcdxkmsuc850.mbn qcdxkmsuc850

        # Copy split files to firmware directory
        if ls /tmp/qcdxkmsuc850.* 1>/dev/null 2>&1; then
            cp /tmp/qcdxkmsuc850.* "$FIRMWARE_DEST/"
            log_ok "ZAP shader converted and installed"
        else
            log_warn "pil-splitter produced no output — copying original .mbn as fallback"
            cp "$ZAP_SRC" "$FIRMWARE_DEST/"
        fi

        # Cleanup
        rm -f /tmp/qcdxkmsuc850.mbn /tmp/qcdxkmsuc850.*
        rm -rf "$VENV_DIR"
    else
        log_warn "qcdxkmsuc850.mbn not found — GPU acceleration may not work"
    fi

    # Set proper permissions
    chmod 644 "$FIRMWARE_DEST"/*.mbn "$FIRMWARE_DEST"/*.bin 2>/dev/null || true
    log_ok "Firmware permissions set"
fi

# ===== Phase 5-2: HWE Kernel =====

log_section "Phase 5-2: HWE Kernel Installation"

log_info "Updating package lists..."
apt-get update -q

log_info "Installing HWE kernel (linux-generic-hwe-24.04)..."
apt-get install -y linux-generic-hwe-24.04

CURRENT_KERNEL=$(uname -r)
log_ok "Current kernel: $CURRENT_KERNEL"
log_ok "HWE kernel installed — reboot to activate"

# ===== Phase 5-3: ZRAM Setup =====

log_section "Phase 5-3: ZRAM Configuration (8GB RAM)"

apt-get install -y zram-config

# Configure ZRAM: 50% of 8GB = 4GB, zstd compression
if [[ -f "$ZRAMSWAP_CONF" ]]; then
    # Update existing config
    sed -i 's/^#\?ALGO=.*/ALGO=zstd/' "$ZRAMSWAP_CONF"
    sed -i 's/^#\?PERCENT=.*/PERCENT=50/' "$ZRAMSWAP_CONF"
    log_ok "Updated: $ZRAMSWAP_CONF"
else
    # Create new config
    cat > "$ZRAMSWAP_CONF" << 'EOF'
# ZRAM swap configuration for Yoga C630 (8GB RAM)
ALGO=zstd
PERCENT=50
EOF
    log_ok "Created: $ZRAMSWAP_CONF"
fi

systemctl enable zram-config 2>/dev/null || true
log_ok "ZRAM service enabled (4GB zstd swap)"

# ===== Phase 5-4: Kernel Parameters =====

log_section "Phase 5-4: Kernel Parameter Optimization"

cat > "$SYSCTL_CONF" << 'EOF'
# Yoga C630 — Snapdragon 850 / 8GB RAM optimization
# Applied: post-install script

# Aggressive swap usage (beneficial with ZRAM zstd)
vm.swappiness = 150

# Keep more file metadata in cache
vm.vfs_cache_pressure = 50

# Reduce dirty page writeback aggressiveness
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Disable NUMA balancing (single-package ARM SoC)
kernel.numa_balancing = 0
EOF

sysctl -p "$SYSCTL_CONF" 2>/dev/null || sysctl --system
log_ok "Applied: $SYSCTL_CONF"

# ===== Phase 5-5: CPU Governor =====

log_section "Phase 5-5: CPU Governor (schedutil)"

apt-get install -y cpufrequtils

# Set schedutil as default governor for all CPUs
CPU_CONF="/etc/default/cpufrequtils"
cat > "$CPU_CONF" << 'EOF'
# Yoga C630 — Snapdragon 850 CPU governor
GOVERNOR="schedutil"
EOF

# Apply immediately
for cpu_gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo schedutil > "$cpu_gov" 2>/dev/null || true
done

log_ok "CPU governor set to: schedutil"

# ===== Phase 5-6: Battery Optimization =====

log_section "Phase 5-6: Battery Optimization (TLP)"

apt-get install -y tlp tlp-rdw

systemctl enable tlp
systemctl start tlp

log_ok "TLP installed and enabled"

# ===== Verification =====

log_section "Post-Install Verification"

echo ""

# WiFi
if nmcli dev status 2>/dev/null | grep -q "wifi"; then
    log_ok "WiFi: device detected"
else
    log_warn "WiFi: not detected (may need reboot + firmware)"
fi

# Battery
if upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep -q "state:"; then
    log_ok "Battery: recognized by UPower"
else
    log_warn "Battery: not detected via UPower yet"
fi

# ZRAM
if zramctl 2>/dev/null | grep -q "zram"; then
    log_ok "ZRAM: active"
else
    log_warn "ZRAM: not active yet (needs reboot)"
fi

# Firmware files
FW_COUNT=$(ls "$FIRMWARE_DEST" 2>/dev/null | wc -l)
log_ok "Firmware files in $FIRMWARE_DEST: $FW_COUNT"

# Current kernel
log_info "Current kernel: $(uname -r)"

# ===== Summary =====

log_section "Summary"

echo ""
echo -e "  ${BOLD}Completed steps:${NC}"
echo "  [5-1] Firmware placement"
echo "  [5-2] HWE kernel installation"
echo "  [5-3] ZRAM (4GB zstd)"
echo "  [5-4] Kernel parameters"
echo "  [5-5] CPU governor (schedutil)"
echo "  [5-6] TLP battery optimization"
echo ""
echo -e "  ${YELLOW}REBOOT REQUIRED to activate HWE kernel and ZRAM${NC}"
echo ""
echo -e "  ${CYAN}After reboot, verify with:${NC}"
echo "    uname -r                          # should show HWE kernel"
echo "    zramctl                           # should show zram0"
echo "    nmcli dev status                  # WiFi should appear"
echo "    upower -i .../battery_BAT0        # battery status"
echo "    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
echo ""
