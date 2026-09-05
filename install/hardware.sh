# Hardware detection for the blarchy installer. Sourced by install.sh,
# never executed directly. Sets BLARCHY_* variables and fills the
# BLARCHY_HW_PACKAGES array with the extra pacman packages the detected
# hardware needs.
# shellcheck shell=bash
# shellcheck disable=SC2034 # variables are consumed by the sourcing install.sh

BLARCHY_HW_PACKAGES=()
BLARCHY_IS_LAPTOP=0
BLARCHY_HAS_BLUETOOTH=0
BLARCHY_HAS_NVIDIA=0
BLARCHY_HAS_INTEL_GPU=0
BLARCHY_HAS_AMD_GPU=0
BLARCHY_CPU_VENDOR=""
BLARCHY_VIRT=""
BLARCHY_SUMMARY=()

blarchy_hw_note() {
  BLARCHY_SUMMARY+=("$1")
  printf '  hardware: %s\n' "$1"
}

blarchy_detect_cpu() {
  local vendor=""

  if [[ -r /proc/cpuinfo ]]; then
    vendor=$(grep -m1 -o -E 'vendor_id\s*:\s*\S+' /proc/cpuinfo | awk '{print $3}')
  fi
  BLARCHY_CPU_VENDOR=$vendor
  case $vendor in
    GenuineIntel)
      BLARCHY_HW_PACKAGES+=(intel-ucode sof-firmware)
      blarchy_hw_note "Intel CPU (intel-ucode, sof-firmware for audio)"
      ;;
    AuthenticAMD)
      BLARCHY_HW_PACKAGES+=(amd-ucode)
      blarchy_hw_note "AMD CPU (amd-ucode)"
      ;;
    *)
      blarchy_hw_note "Unknown CPU vendor (${vendor:-unreadable}); skipping microcode"
      ;;
  esac
}

blarchy_detect_gpu() {
  local pci=""

  if command -v lspci >/dev/null 2>&1; then
    pci=$(lspci -nnk 2>/dev/null || true)
  elif [[ -d /sys/bus/pci/devices ]]; then
    pci=$(grep -h -o -E 'VGA|3D|Display' -r /sys/bus/pci/devices/*/class 2>/dev/null || true)
  fi

  if grep -qi 'intel.*graphics\|intel.*vga\|intel.*display\|8086' <<<"$pci"; then
    BLARCHY_HAS_INTEL_GPU=1
    BLARCHY_HW_PACKAGES+=(vulkan-intel intel-media-driver)
    blarchy_hw_note "Intel GPU (vulkan-intel, intel-media-driver)"
  fi
  if grep -qi 'amd.*radeon\|amd.*graphics\|amd.*vga\|1002' <<<"$pci"; then
    BLARCHY_HAS_AMD_GPU=1
    BLARCHY_HW_PACKAGES+=(vulkan-radeon)
    blarchy_hw_note "AMD GPU (vulkan-radeon)"
  fi
  if grep -qi 'nvidia\|10de' <<<"$pci"; then
    BLARCHY_HAS_NVIDIA=1
    BLARCHY_HW_PACKAGES+=(nvidia nvidia-utils lib32-nvidia-utils nvidia-settings)
    blarchy_hw_note "NVIDIA GPU (nvidia, nvidia-utils, lib32 compat, nvidia-settings)"
  fi
  if (( BLARCHY_HAS_INTEL_GPU == 0 && BLARCHY_HAS_AMD_GPU == 0 && BLARCHY_HAS_NVIDIA == 0 )); then
    blarchy_hw_note "No discrete GPU identifier found; using base mesa stack"
  fi
  if (( BLARCHY_HAS_NVIDIA == 1 )); then
    cat <<'NOTE'
  hardware: NOTE for NVIDIA: enable DRM modesetting by adding
  hardware:   nvidia-drm.modeset=1
  hardware: to your bootloader kernel parameters, then reboot.
NOTE
  fi
}

blarchy_detect_form_factor() {
  local chassis=""

  if [[ -r /sys/class/dmi/id/chassis_type ]]; then
    chassis=$(< /sys/class/dmi/id/chassis_type)
  fi
  # 8 portable, 9 laptop, 10 notebook, 11 hand held, 14 sub notebook,
  # 31 convertible/detachable.
  case $chassis in
    8|9|10|11|14|31)
      BLARCHY_IS_LAPTOP=1
      ;;
  esac
  if compgen -G '/sys/class/power_supply/BAT*' >/dev/null; then
    BLARCHY_IS_LAPTOP=1
  fi
  if (( BLARCHY_IS_LAPTOP == 1 )); then
    blarchy_hw_note "Laptop form factor (power-profiles-daemon, brightnessctl enabled)"
  else
    blarchy_hw_note "Desktop form factor"
  fi
}

blarchy_detect_bluetooth() {
  if [[ -d /sys/class/bluetooth ]] ||
    { command -v lsusb >/dev/null 2>&1 && lsusb 2>/dev/null | grep -qi bluetooth; } ||
    { command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -qi bluetooth; }; then
    BLARCHY_HAS_BLUETOOTH=1
    blarchy_hw_note "Bluetooth adapter present (bluetooth.service will be enabled)"
  else
    blarchy_hw_note "No Bluetooth adapter detected; bluetooth.service left disabled"
  fi
}

blarchy_detect_virt() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    BLARCHY_VIRT=$(systemd-detect-virt 2>/dev/null || true)
  fi
  case $BLARCHY_VIRT in
    qemu|kvm)
      BLARCHY_HW_PACKAGES+=(qemu-guest-agent spice-vdagent)
      blarchy_hw_note "QEMU/KVM guest (qemu-guest-agent, spice-vdagent)"
      ;;
    vmware)
      BLARCHY_HW_PACKAGES+=(open-vm-tools)
      blarchy_hw_note "VMware guest (open-vm-tools)"
      ;;
    oracle)
      BLARCHY_HW_PACKAGES+=(virtualbox-guest-utils)
      blarchy_hw_note "VirtualBox guest (virtualbox-guest-utils)"
      ;;
    none|"")
      ;;
    *)
      blarchy_hw_note "Virtualized environment ($BLARCHY_VIRT); no guest tools added"
      ;;
  esac
}

blarchy_detect_fingerprint() {
  if command -v lsusb >/dev/null 2>&1 &&
    lsusb 2>/dev/null | grep -qi -E 'fingerprint|validity|synaptics.*fp|elan.*fp'; then
    BLARCHY_HW_PACKAGES+=(fprintd)
    blarchy_hw_note "Fingerprint reader present (fprintd; enroll with fprintd-enroll)"
  fi
}

blarchy_detect_wifi() {
  if compgen -G '/sys/class/net/w*' >/dev/null; then
    blarchy_hw_note "Wireless interface present (NetworkManager will manage it)"
  fi
}

blarchy_detect_hardware() {
  echo "Detect hardware"
  blarchy_detect_cpu
  blarchy_detect_gpu
  blarchy_detect_form_factor
  blarchy_detect_bluetooth
  blarchy_detect_virt
  blarchy_detect_fingerprint
  blarchy_detect_wifi
}
