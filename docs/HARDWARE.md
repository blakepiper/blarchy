# Hardware detection

`install/hardware.sh` is sourced by `install.sh` before any package
installation. It inspects the machine and appends the needed drivers
and guest tools to the base list in `install/packages`, so every
machine gets exactly its own stack.

| Signal | Source | Packages added |
| --- | --- | --- |
| Intel CPU | `/proc/cpuinfo` vendor | `intel-ucode`, `sof-firmware` |
| AMD CPU | `/proc/cpuinfo` vendor | `amd-ucode` |
| Intel GPU | `lspci` | `vulkan-intel`, `intel-media-driver` |
| AMD GPU | `lspci` | `vulkan-radeon` |
| NVIDIA GPU | `lspci` | `nvidia`, `nvidia-utils`, `lib32-nvidia-utils`, `nvidia-settings` |
| Laptop chassis or battery | DMI `chassis_type`, `/sys/class/power_supply/BAT*` | enables `power-profiles-daemon` |
| Bluetooth adapter | sysfs, `lsusb`, `lspci` | enables `bluetooth.service` |
| QEMU/KVM, VMware, VirtualBox | `systemd-detect-virt` | matching guest tools |
| Fingerprint reader | `lsusb` | `fprintd` |
| Wireless interface | `/sys/class/net/w*` | informational; NetworkManager manages it |

Detection results print during the install under the `hardware:` prefix.

## Notes

- NVIDIA machines print a reminder to add `nvidia-drm.modeset=1` to the
  bootloader kernel parameters. The installer never touches the
  bootloader; that one edit stays manual.
- Fingerprint readers get the `fprintd` package only. Enroll with
  `fprintd-enroll` after installing.
- Anything undetected falls back to the base `mesa` stack, which is
  always installed.

## Battery charge limit

On laptops the installer enables `blarchy-battery-limit.service`, which
sets `charge_control_end_threshold=80` (and `charge_control_start_threshold=75`
where supported) on every battery at boot. This uses the kernel
charge-control API, so it works on most modern ThinkPads, Dells, ASUS,
Framework, and LG laptops with no vendor tools. Batteries without the API
are silently skipped.

Check the live thresholds with:

```sh
cat /sys/class/power_supply/BAT*/charge_control_*threshold*
```

Very old ThinkPads predate the kernel API; those need `tpacpi-bat`
from the AUR instead.
