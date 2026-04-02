#!/usr/bin/env bash

set -u

OUTPUT_DIR="$HOME/essm-baseline"
REPORT_FILE="$OUTPUT_DIR/01_platform_surface_report.txt"
PREVIEW_LINES=12

declare -A CMD_TO_PKG=(
  [dmidecode]="dmidecode"
  [lsusb]="usbutils"
  [ethtool]="ethtool"
  [fwupdmgr]="fwupd"
  [sensors]="lm_sensors"
  [upower]="upower"
  [lspci]="pciutils"
  [fdisk]="util-linux"
  [bootctl]="systemd"
  [udevadm]="systemd"
)

MISSING_PKGS=()

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

need_root_read_dmesg() {
  sudo -n dmesg >/dev/null 2>&1
}

collect_cmd() {
  local outfile="$1"
  shift
  {
    echo "### COMMAND: $*"
    echo "### DATE: $(date -Is)"
    echo
    "$@"
  } >"$outfile" 2>&1
}

collect_cmd_sudo() {
  local outfile="$1"
  shift
  {
    echo "### COMMAND: sudo $*"
    echo "### DATE: $(date -Is)"
    echo
    sudo "$@"
  } >"$outfile" 2>&1
}

check_missing_tools() {
  MISSING_PKGS=()
  local cmd pkg
  for cmd in "${!CMD_TO_PKG[@]}"; do
    if ! have_cmd "$cmd"; then
      pkg="${CMD_TO_PKG[$cmd]}"
      if [[ ! " ${MISSING_PKGS[*]} " =~ " ${pkg} " ]]; then
        MISSING_PKGS+=("$pkg")
      fi
    fi
  done
}

install_missing_tools() {
  check_missing_tools
  if ((${#MISSING_PKGS[@]} == 0)); then
    echo
    echo "[*] No missing packages detected."
    return 0
  fi

  echo
  echo "[*] Missing packages:"
  printf '  - %s\n' "${MISSING_PKGS[@]}"
  echo
  read -r -p "Install them now with sudo pacman -S --needed ? [y/N]: " ans
  case "$ans" in
    y|Y|yes|YES)
      sudo pacman -S --needed "${MISSING_PKGS[@]}"
      ;;
    *)
      echo "[!] Skipping installation."
      ;;
  esac
}

write_section() {
  local title="$1"
  local file="$2"

  {
    echo "=================================================================="
    echo "$title"
    echo "=================================================================="
    if [[ -f "$file" ]]; then
      cat "$file"
    else
      echo "Missing file: $file"
    fi
    echo
  } >> "$REPORT_FILE"
}

write_limited_section() {
  local title="$1"
  local file="$2"
  local lines="${3:-80}"

  {
    echo "=================================================================="
    echo "$title"
    echo "=================================================================="
    if [[ -f "$file" ]]; then
      sed -n "1,${lines}p" "$file"
      total_lines=$(wc -l < "$file" 2>/dev/null || echo 0)
      if [[ "$total_lines" -gt "$lines" ]]; then
        echo
        echo "[...truncated after $lines lines; inspect the full file separately: $(basename "$file")]"
      fi
    else
      echo "Missing file: $file"
    fi
    echo
  } >> "$REPORT_FILE"
}

generate_summary_file() {
  check_missing_tools
  {
    echo "ESSM Discovery Summary"
    echo "Generated: $(date -Is)"
    echo "Output dir: $OUTPUT_DIR"
    echo
    echo "Missing packages at run time:"
    if ((${#MISSING_PKGS[@]} == 0)); then
      echo "none"
    else
      printf '%s\n' "${MISSING_PKGS[@]}"
    fi
  } > "$OUTPUT_DIR/00_summary.txt"
}

generate_platform_surface_report() {
  : > "$REPORT_FILE"

  {
    echo "ESSM PHASE 1 — PLATFORM SURFACE REPORT"
    echo "Generated: $(date -Is)"
    echo "Host: $(hostname)"
    echo "Output Directory: $OUTPUT_DIR"
    echo
    echo "Purpose:"
    echo "This report presents the full embedded-relevant platform inventory in the"
    echo "framework order used for ESSM baseline development."
    echo
  } >> "$REPORT_FILE"

  write_section "0. DISCOVERY SUMMARY" "$OUTPUT_DIR/00_summary.txt"

  write_section "1. SYSTEM IDENTITY (CORE PLATFORM) — uname" "$OUTPUT_DIR/system_uname.txt"
  write_section "1. SYSTEM IDENTITY (CORE PLATFORM) — hostnamectl" "$OUTPUT_DIR/system_hostnamectl.txt"

  write_section "2. CPU + ARCHITECTURE — lscpu" "$OUTPUT_DIR/cpu_lscpu.txt"
  write_limited_section "2. CPU + ARCHITECTURE — /proc/cpuinfo (first 120 lines)" "$OUTPUT_DIR/cpu_proc.txt" 120

  write_section "3. MOTHERBOARD / PLATFORM — dmidecode system" "$OUTPUT_DIR/dmi_system.txt"
  write_section "3. MOTHERBOARD / PLATFORM — dmidecode baseboard" "$OUTPUT_DIR/dmi_baseboard.txt"
  write_section "3. MOTHERBOARD / PLATFORM — dmidecode bios" "$OUTPUT_DIR/dmi_bios.txt"

  write_section "4. FIRMWARE / UEFI STATE — /sys/firmware/efi" "$OUTPUT_DIR/uefi_present.txt"
  write_section "4. FIRMWARE / UEFI STATE — bootctl status" "$OUTPUT_DIR/bootctl_status.txt"
  write_section "4. FIRMWARE / UEFI STATE — fwupdmgr get-devices" "$OUTPUT_DIR/fwupd_devices.txt"
  write_section "4. FIRMWARE / UEFI STATE — fwupdmgr get-updates" "$OUTPUT_DIR/fwupd_updates.txt"

  write_section "5. PCI BUS / CORE EMBEDDED COMPONENTS — lspci -nn" "$OUTPUT_DIR/pci.txt"
  write_section "6. USB DEVICES / EXTERNAL ATTACK SURFACE — lsusb" "$OUTPUT_DIR/usb.txt"

  write_section "7. STORAGE DEVICES — lsblk" "$OUTPUT_DIR/storage_lsblk.txt"
  write_section "7. STORAGE DEVICES — fdisk -l" "$OUTPUT_DIR/storage_fdisk.txt"
  write_section "7. STORAGE DEVICES — device models" "$OUTPUT_DIR/storage_models.txt"

  write_section "8. NETWORK INTERFACES — ip link" "$OUTPUT_DIR/network_link.txt"
  write_section "8. NETWORK INTERFACES — ip addr" "$OUTPUT_DIR/network_addr.txt"

  for f in "$OUTPUT_DIR"/network_*_driver.txt; do
    if [[ -f "$f" ]]; then
      write_section "8. NETWORK INTERFACES — driver info ($(basename "$f"))" "$f"
    fi
  done

  write_limited_section "9. KERNEL MODULES / ACTIVE HARDWARE DRIVERS — lsmod (first 200 lines)" "$OUTPUT_DIR/modules.txt" 200

  write_section "10. HARDWARE SENSORS / EMBEDDED CONTROLLERS — sensors" "$OUTPUT_DIR/sensors.txt"
  write_section "10. HARDWARE SENSORS / EMBEDDED CONTROLLERS — hwmon" "$OUTPUT_DIR/hwmon.txt"

  write_section "11. TPM / HARDWARE ROOT OF TRUST — device paths" "$OUTPUT_DIR/tpm_devices.txt"
  write_section "11. TPM / HARDWARE ROOT OF TRUST — kernel messages" "$OUTPUT_DIR/tpm_dmesg.txt"

  write_section "12. POWER / EMBEDDED CONTROLLER — upower" "$OUTPUT_DIR/power_upower.txt"
  write_section "12. POWER / EMBEDDED CONTROLLER — power_supply uevent" "$OUTPUT_DIR/power_supply.txt"

  write_section "13. KERNEL DEVICE TREE / LOGICAL VIEW — /sys/devices" "$OUTPUT_DIR/devices_tree.txt"
  write_limited_section "13. KERNEL DEVICE TREE / LOGICAL VIEW — udev export db (first 250 lines)" "$OUTPUT_DIR/udev_db.txt" 250

  write_limited_section "14. RUNNING SERVICES / HARDWARE INTERACTION LAYER — systemctl services (first 250 lines)" "$OUTPUT_DIR/services.txt" 250
  write_limited_section "15. INTERRUPTS / LOW-LEVEL HARDWARE ACTIVITY — /proc/interrupts" "$OUTPUT_DIR/interrupts.txt" 250
  write_limited_section "16. FULL ESSM SNAPSHOT / KERNEL LOG — dmesg (first 250 lines)" "$OUTPUT_DIR/dmesg.txt" 250

  {
    echo "=================================================================="
    echo "END OF PLATFORM SURFACE REPORT"
    echo "=================================================================="
    echo
    echo "Next ESSM phase:"
    echo "- classify critical vs non-critical components"
    echo "- classify exposed vs internal interfaces"
    echo "- classify trusted vs untrusted devices"
    echo "- reduce attack surface"
    echo "- validate firmware trust"
    echo "- harden boot chain"
    echo "- define module restriction policy"
    echo "- create ESSM enforcement policy"
    echo
  } >> "$REPORT_FILE"
}

run_discovery() {
  echo
  echo "[*] Running ESSM discovery..."
  mkdir -p "$OUTPUT_DIR"

  collect_cmd "$OUTPUT_DIR/system_uname.txt" uname -a
  collect_cmd "$OUTPUT_DIR/system_hostnamectl.txt" hostnamectl

  collect_cmd "$OUTPUT_DIR/cpu_lscpu.txt" lscpu
  collect_cmd "$OUTPUT_DIR/cpu_proc.txt" cat /proc/cpuinfo

  if have_cmd dmidecode; then
    collect_cmd_sudo "$OUTPUT_DIR/dmi_system.txt" dmidecode -t system
    collect_cmd_sudo "$OUTPUT_DIR/dmi_baseboard.txt" dmidecode -t baseboard
    collect_cmd_sudo "$OUTPUT_DIR/dmi_bios.txt" dmidecode -t bios
  else
    echo "dmidecode not installed" > "$OUTPUT_DIR/dmi_system.txt"
    echo "dmidecode not installed" > "$OUTPUT_DIR/dmi_baseboard.txt"
    echo "dmidecode not installed" > "$OUTPUT_DIR/dmi_bios.txt"
  fi

  collect_cmd "$OUTPUT_DIR/uefi_present.txt" ls /sys/firmware/efi

  if have_cmd bootctl; then
    collect_cmd "$OUTPUT_DIR/bootctl_status.txt" bootctl status
  else
    echo "bootctl not installed" > "$OUTPUT_DIR/bootctl_status.txt"
  fi

  if have_cmd fwupdmgr; then
    collect_cmd_sudo "$OUTPUT_DIR/fwupd_devices.txt" fwupdmgr get-devices
    collect_cmd_sudo "$OUTPUT_DIR/fwupd_updates.txt" fwupdmgr get-updates
  else
    echo "fwupdmgr not installed" > "$OUTPUT_DIR/fwupd_devices.txt"
    echo "fwupdmgr not installed" > "$OUTPUT_DIR/fwupd_updates.txt"
  fi

  if have_cmd lspci; then
    collect_cmd "$OUTPUT_DIR/pci.txt" lspci -nn
  else
    echo "lspci not installed" > "$OUTPUT_DIR/pci.txt"
  fi

  if have_cmd lsusb; then
    collect_cmd "$OUTPUT_DIR/usb.txt" lsusb
  else
    echo "lsusb not installed" > "$OUTPUT_DIR/usb.txt"
  fi

  collect_cmd "$OUTPUT_DIR/storage_lsblk.txt" lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
  if have_cmd fdisk; then
    collect_cmd_sudo "$OUTPUT_DIR/storage_fdisk.txt" fdisk -l
  else
    echo "fdisk not installed" > "$OUTPUT_DIR/storage_fdisk.txt"
  fi
  collect_cmd "$OUTPUT_DIR/storage_models.txt" bash -lc 'cat /sys/block/*/device/model 2>/dev/null'

  collect_cmd "$OUTPUT_DIR/network_link.txt" ip link
  collect_cmd "$OUTPUT_DIR/network_addr.txt" ip addr

  if have_cmd ethtool; then
    for iface in $(ls /sys/class/net/ | grep -v '^lo$'); do
      collect_cmd "$OUTPUT_DIR/network_${iface}_driver.txt" ethtool -i "$iface"
    done
  else
    for iface in $(ls /sys/class/net/ | grep -v '^lo$'); do
      echo "ethtool not installed" > "$OUTPUT_DIR/network_${iface}_driver.txt"
    done
  fi

  collect_cmd "$OUTPUT_DIR/modules.txt" lsmod

  if have_cmd sensors; then
    collect_cmd "$OUTPUT_DIR/sensors.txt" sensors
  else
    echo "sensors not installed" > "$OUTPUT_DIR/sensors.txt"
  fi
  collect_cmd "$OUTPUT_DIR/hwmon.txt" ls /sys/class/hwmon/

  collect_cmd "$OUTPUT_DIR/tpm_devices.txt" bash -lc 'ls /dev/tpm* 2>/dev/null || true'
  if need_root_read_dmesg; then
    collect_cmd_sudo "$OUTPUT_DIR/tpm_dmesg.txt" bash -lc 'dmesg | grep -i tpm || true'
  else
    echo "dmesg access denied; run with active sudo session for TPM kernel messages" > "$OUTPUT_DIR/tpm_dmesg.txt"
  fi

  if have_cmd upower; then
    collect_cmd "$OUTPUT_DIR/power_upower.txt" upower -d
  else
    echo "upower not installed" > "$OUTPUT_DIR/power_upower.txt"
  fi
  collect_cmd "$OUTPUT_DIR/power_supply.txt" bash -lc 'cat /sys/class/power_supply/*/uevent 2>/dev/null'

  collect_cmd "$OUTPUT_DIR/devices_tree.txt" ls /sys/devices/
  if have_cmd udevadm; then
    collect_cmd "$OUTPUT_DIR/udev_db.txt" udevadm info --export-db
  else
    echo "udevadm not installed" > "$OUTPUT_DIR/udev_db.txt"
  fi

  collect_cmd "$OUTPUT_DIR/services.txt" systemctl list-units --type=service
  collect_cmd "$OUTPUT_DIR/interrupts.txt" cat /proc/interrupts

  if need_root_read_dmesg; then
    collect_cmd_sudo "$OUTPUT_DIR/dmesg.txt" dmesg
  else
    echo "dmesg access denied; run with active sudo session for full kernel log capture" > "$OUTPUT_DIR/dmesg.txt"
  fi

  generate_summary_file
  generate_platform_surface_report

  echo
  echo "[*] Discovery complete."
  echo "[*] Baseline saved to: $OUTPUT_DIR"
  echo "[*] Main readable report: $REPORT_FILE"
}

pause() {
  read -r -p "Press Enter to continue..."
}

view_file() {
  local file="$1"
  clear
  echo "===== $(basename "$file") ====="
  echo
  if command -v less >/dev/null 2>&1; then
    less -R "$file"
  else
    cat "$file"
    echo
    pause
  fi
}

preview_all_files() {
  clear
  echo "ESSM Output Preview"
  echo "Showing first $PREVIEW_LINES lines of each file in $OUTPUT_DIR"
  echo

  mapfile -t files < <(find "$OUTPUT_DIR" -maxdepth 1 -type f | sort)
  if ((${#files[@]} == 0)); then
    echo "No files found. Run discovery first."
    echo
    pause
    return
  fi

  for f in "${files[@]}"; do
    echo "##################################################################"
    echo "FILE: $(basename "$f")"
    echo "##################################################################"
    sed -n "1,${PREVIEW_LINES}p" "$f"
    echo
  done

  pause
}

files_menu() {
  while true; do
    clear
    echo "ESSM Baseline Viewer"
    echo "Output directory: $OUTPUT_DIR"
    echo

    mapfile -t files < <(find "$OUTPUT_DIR" -maxdepth 1 -type f | sort)
    if ((${#files[@]} == 0)); then
      echo "No files found. Run discovery first."
      echo
      pause
      return
    fi

    local i=1
    for f in "${files[@]}"; do
      printf "%2d) %s\n" "$i" "$(basename "$f")"
      ((i++))
    done
    echo " p) Preview first $PREVIEW_LINES lines of every file"
    echo " r) Re-run discovery"
    echo " i) Install missing tools"
    echo " q) Back to main menu"
    echo
    read -r -p "Choose an item: " choice

    case "$choice" in
      q|Q) return ;;
      r|R) run_discovery; pause ;;
      i|I) install_missing_tools; pause ;;
      p|P) preview_all_files ;;
      '' ) ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#files[@]} )); then
          view_file "${files[$((choice-1))]}"
        else
          echo "Invalid selection."
          pause
        fi
        ;;
    esac
  done
}

main_menu() {
  while true; do
    clear
    check_missing_tools
    echo "ESSM Discovery Console"
    echo
    echo "1) Install missing tools"
    echo "2) Run full discovery"
    echo "3) Browse saved outputs"
    echo "4) Preview first $PREVIEW_LINES lines of every file"
    echo "5) Open main platform surface report"
    echo "6) Show missing tools"
    echo "7) Quit"
    echo
    read -r -p "Select: " choice

    case "$choice" in
      1) install_missing_tools; pause ;;
      2) run_discovery; pause ;;
      3) files_menu ;;
      4) preview_all_files ;;
      5)
        if [[ -f "$REPORT_FILE" ]]; then
          view_file "$REPORT_FILE"
        else
          echo
          echo "Main report not found. Run discovery first."
          echo
          pause
        fi
        ;;
      6)
        echo
        if ((${#MISSING_PKGS[@]} == 0)); then
          echo "No missing packages detected."
        else
          echo "Missing packages:"
          printf '  - %s\n' "${MISSING_PKGS[@]}"
        fi
        echo
        pause
        ;;
      7|q|Q) exit 0 ;;
      *) echo "Invalid selection."; pause ;;
    esac
  done
}

main_menu
