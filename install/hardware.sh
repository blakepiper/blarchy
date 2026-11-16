# Hardware detection for the installer. Sourced by install.sh,
# never executed directly. Sets INSTALL_* values and fills the
# INSTALL_HW_PACKAGES array with the extra pacman packages the detected
# hardware needs.
# shellcheck shell=bash
# shellcheck disable=SC2034 # variables are consumed by the sourcing install.sh

INSTALL_HW_PACKAGES=()
INSTALL_IS_LAPTOP=0
INSTALL_HAS_BLUETOOTH=0
INSTALL_HAS_NVIDIA=0
INSTALL_HAS_INTEL_GPU=0
INSTALL_HAS_AMD_GPU=0
INSTALL_CPU_VENDOR=""
INSTALL_VIRT=""
INSTALL_SUMMARY=()

installer_note() {
  INSTALL_SUMMARY+=("$1")
  printf '  hardware: %s\n' "$1"
}

installer_detect_cpu() {
  local vendor=""

  if [[ -r /proc/cpuinfo ]]; then
    vendor=$(awk '/^vendor_id/ {print $3; exit}' /proc/cpuinfo)
  fi
  INSTALL_CPU_VENDOR=$vendor
  case $vendor in
    GenuineIntel)
      INSTALL_HW_PACKAGES+=(intel-ucode sof-firmware)
      installer_note "Intel CPU (intel-ucode, sof-firmware for audio)"
      ;;
    AuthenticAMD)
      INSTALL_HW_PACKAGES+=(amd-ucode)
      installer_note "AMD CPU (amd-ucode)"
      ;;
    *)
      installer_note "Unknown CPU vendor (${vendor:-unreadable}); skipping microcode"
      ;;
  esac
}

installer_detect_gpu() {
  local pci_root="${1:-/sys/bus/pci/devices}"
  local device class vendor id subvendor subdevice
  local nvidia_ids=()

  for device in "$pci_root"/*; do
    [[ -r $device/class && -r $device/vendor ]] || continue
    class=$(<"$device/class")
    [[ $class == 0x03* ]] || continue
    vendor=$(<"$device/vendor")
    case $vendor in
      0x8086) INSTALL_HAS_INTEL_GPU=1 ;;
      0x1002) INSTALL_HAS_AMD_GPU=1 ;;
      0x10de)
        INSTALL_HAS_NVIDIA=1
        id=$(<"$device/device")
        subvendor=$(<"$device/subsystem_vendor")
        subdevice=$(<"$device/subsystem_device")
        nvidia_ids+=("${id#0x} ${subvendor#0x} ${subdevice#0x}")
        ;;
    esac
  done

  if (( INSTALL_HAS_INTEL_GPU )); then
    INSTALL_HW_PACKAGES+=(vulkan-intel intel-media-driver)
    installer_note "Intel GPU (vulkan-intel, intel-media-driver)"
  fi
  if (( INSTALL_HAS_AMD_GPU )); then
    INSTALL_HW_PACKAGES+=(vulkan-radeon)
    installer_note "AMD GPU (vulkan-radeon)"
  fi
  if (( INSTALL_HAS_NVIDIA )); then
    installer_nvidia_packages "${nvidia_ids[@]}"
  fi
  if (( INSTALL_HAS_INTEL_GPU == 0 && INSTALL_HAS_AMD_GPU == 0 && INSTALL_HAS_NVIDIA == 0 )); then
    installer_note "No vendor-specific GPU packages needed; using base mesa stack"
  fi
}

installer_nvidia_packages() {
  local version supported gpu id subsystem kernel_file kernel
  local modules_root="${INSTALL_MODULES_PATH:-/usr/lib/modules}"
  local kernels=()
  # Use the compatibility table for Arch's current driver, not a bundled
  # GPU-generation list that goes stale when NVIDIA changes support.
  version=$(LC_ALL=C pacman -Si nvidia-utils | awk '/^Version / {print $3}')
  version=${version##*:}
  version=${version%-*}
  [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Error: cannot resolve the current NVIDIA driver version." >&2
    return 1
  }
  supported=$(curl --fail --silent --show-error --location --retry 3 --max-time 60 \
    "https://raw.githubusercontent.com/NVIDIA/open-gpu-kernel-modules/$version/README.md")
  for gpu in "$@"; do
    id=${gpu%% *}
    subsystem=${gpu#* }
    if ! grep -qiE "\|[[:space:]]*$id([[:space:]]+$subsystem)?[[:space:]]*\|" <<<"$supported"; then
      echo "Error: NVIDIA GPU $gpu is not supported by Arch's current open driver ($version)." >&2
      echo "Legacy GPU setup is outside this installer's supported path. See https://wiki.archlinux.org/title/NVIDIA" >&2
      return 1
    fi
  done

  # pkgbase reflects installed kernels even after an upgrade, when uname
  # still reports the old running kernel. DKMS covers all installed kernels.
  for kernel_file in "$modules_root"/*/pkgbase; do
    [[ -r $kernel_file ]] || continue
    kernel=$(<"$kernel_file")
    [[ " ${kernels[*]-} " == *" $kernel "* ]] && continue
    if ! pacman -Si "$kernel-headers" >/dev/null; then
      echo "Error: headers for kernel $kernel are unavailable in the enabled Arch repositories." >&2
      return 1
    fi
    kernels+=("$kernel")
    INSTALL_HW_PACKAGES+=("$kernel-headers")
  done
  if (( ${#kernels[@]} == 0 )); then
    echo "Error: no installed kernel pkgbase found under /usr/lib/modules." >&2
    return 1
  fi
  INSTALL_HW_PACKAGES+=(nvidia-open-dkms nvidia-utils)
  installer_note "NVIDIA GPU supported by driver $version (DKMS for ${kernels[*]})"
}

installer_detect_form_factor() {
  local sys_root="${1:-/sys}"
  local chassis=""

  if [[ -r $sys_root/class/dmi/id/chassis_type ]]; then
    chassis=$(< "$sys_root/class/dmi/id/chassis_type")
  fi
  # 8 portable, 9 laptop, 10 notebook, 11 hand held, 14 sub notebook,
  # 31 convertible/detachable.
  case $chassis in
    8|9|10|11|14|31)
      INSTALL_IS_LAPTOP=1
      ;;
  esac
  if compgen -G "$sys_root/class/power_supply/BAT*" >/dev/null; then
    INSTALL_IS_LAPTOP=1
  fi
  if (( INSTALL_IS_LAPTOP == 1 )); then
    INSTALL_HW_PACKAGES+=(power-profiles-daemon)
    installer_note "Laptop form factor (power-profiles-daemon enabled)"
  else
    installer_note "Desktop form factor"
  fi
  if compgen -G "$sys_root/class/backlight/*" >/dev/null || (( INSTALL_IS_LAPTOP )); then
    INSTALL_HW_PACKAGES+=(brightnessctl)
  fi
}

installer_detect_bluetooth() {
  local sys_root="${1:-/sys}"
  if compgen -G "$sys_root/class/bluetooth/hci*" >/dev/null ||
    { command -v lsusb >/dev/null 2>&1 && lsusb 2>/dev/null | grep -qi bluetooth; } ||
    { command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -qi bluetooth; }; then
    INSTALL_HAS_BLUETOOTH=1
    INSTALL_HW_PACKAGES+=(bluez bluez-utils blueman)
    installer_note "Bluetooth adapter present (bluetooth.service will be enabled)"
  else
    installer_note "No Bluetooth adapter detected; bluetooth.service left disabled"
  fi
}

installer_detect_virt() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    INSTALL_VIRT=$(systemd-detect-virt 2>/dev/null || true)
  fi
  case $INSTALL_VIRT in
    qemu|kvm)
      INSTALL_HW_PACKAGES+=(qemu-guest-agent spice-vdagent)
      installer_note "QEMU/KVM guest (qemu-guest-agent, spice-vdagent)"
      ;;
    vmware)
      INSTALL_HW_PACKAGES+=(open-vm-tools)
      installer_note "VMware guest (open-vm-tools)"
      ;;
    oracle)
      INSTALL_HW_PACKAGES+=(virtualbox-guest-utils)
      installer_note "VirtualBox guest (virtualbox-guest-utils)"
      ;;
    none|"")
      ;;
    *)
      installer_note "Virtualized environment ($INSTALL_VIRT); no guest tools added"
      ;;
  esac
}

installer_detect_fingerprint() {
  if command -v lsusb >/dev/null 2>&1 &&
    lsusb 2>/dev/null | grep -qi -E 'fingerprint|validity|synaptics.*fp|elan.*fp'; then
    INSTALL_HW_PACKAGES+=(fprintd)
    installer_note "Fingerprint reader present (fprintd; enroll with fprintd-enroll)"
  fi
}

installer_detect_wifi() {
  if compgen -G '/sys/class/net/w*' >/dev/null; then
    installer_note "Wireless interface present (existing archinstall networking is preserved)"
  fi
}

installer_detect_displays() {
  local displays_script="${INSTALL_REPO:-}/bin/displays"
  local drm_line connector status preferred kind connected_count

  if [[ ! -x $displays_script ]]; then
    installer_note "Display detection skipped (bin/displays not found)"
    return
  fi

  # Report DRM outputs at install time. The session config handles hotplug;
  # this report does not write machine-specific display rules.
  connected_count=0
  while IFS= read -r drm_line; do
    [[ -n $drm_line ]] || continue
    connector=${drm_line%%:*}
    status=$(awk -F'[()]' '{print $1}' <<<"$drm_line" | awk '{print $2}')
    preferred=$(awk -F'[()]' '{print $2}' <<<"$drm_line")
    case $connector in
      eDP-*|LVDS-*|DSI-*) kind="laptop panel" ;;
      *) kind="external display" ;;
    esac
    if [[ $status == connected ]]; then
      connected_count=$((connected_count + 1))
      installer_note "$kind $connector connected (preferred mode $preferred)"
    fi
  done < <(bash "$displays_script" --drm 2>/dev/null || true)
  if (( connected_count == 0 )); then
    installer_note "No connected displays detected through DRM"
  fi
}

installer_detect_hardware() {
  echo "Detect hardware"
  installer_detect_cpu
  installer_detect_gpu
  installer_detect_form_factor
  installer_detect_bluetooth
  installer_detect_virt
  installer_detect_fingerprint
  installer_detect_wifi
  installer_detect_displays
}
