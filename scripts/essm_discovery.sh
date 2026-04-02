#!/bin/bash

# ESSM Embedded System Discovery Script
# Purpose: Enumerate all hardware + platform components and build baseline

OUTPUT_DIR="$HOME/essm-baseline"
mkdir -p "$OUTPUT_DIR"

echo "[*] ESSM Discovery Started..."
echo "[*] Output directory: $OUTPUT_DIR"

# 1. System Identity
echo "[+] Collecting system identity..."
uname -a > "$OUTPUT_DIR/system_uname.txt"
hostnamectl > "$OUTPUT_DIR/system_hostnamectl.txt"

# 2. CPU + Architecture
echo "[+] Collecting CPU info..."
lscpu > "$OUTPUT_DIR/cpu_lscpu.txt"
cat /proc/cpuinfo > "$OUTPUT_DIR/cpu_proc.txt"

# 3. Motherboard / Platform
echo "[+] Collecting DMI / BIOS info..."
sudo dmidecode -t system > "$OUTPUT_DIR/dmi_system.txt"
sudo dmidecode -t baseboard > "$OUTPUT_DIR/dmi_baseboard.txt"
sudo dmidecode -t bios > "$OUTPUT_DIR/dmi_bios.txt"

# 4. Firmware / UEFI
echo "[+] Collecting firmware / UEFI info..."
ls /sys/firmware/efi > "$OUTPUT_DIR/uefi_present.txt" 2>/dev/null
bootctl status > "$OUTPUT_DIR/bootctl_status.txt" 2>/dev/null
sudo fwupdmgr get-devices > "$OUTPUT_DIR/fwupd_devices.txt" 2>/dev/null
sudo fwupdmgr get-updates > "$OUTPUT_DIR/fwupd_updates.txt" 2>/dev/null

# 5. PCI Devices
echo "[+] Collecting PCI devices..."
lspci -nn > "$OUTPUT_DIR/pci.txt"

# 6. USB Devices
echo "[+] Collecting USB devices..."
lsusb > "$OUTPUT_DIR/usb.txt"

# 7. Storage Devices
echo "[+] Collecting storage info..."
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT > "$OUTPUT_DIR/storage_lsblk.txt"
sudo fdisk -l > "$OUTPUT_DIR/storage_fdisk.txt" 2>/dev/null
cat /sys/block/*/device/model > "$OUTPUT_DIR/storage_models.txt" 2>/dev/null

# 8. Network Interfaces
echo "[+] Collecting network interfaces..."
ip link > "$OUTPUT_DIR/network_link.txt"
ip addr > "$OUTPUT_DIR/network_addr.txt"

# Collect driver info per interface
for iface in $(ls /sys/class/net/ | grep -v lo); do
    ethtool -i "$iface" > "$OUTPUT_DIR/network_${iface}_driver.txt" 2>/dev/null
done

# 9. Kernel Modules
echo "[+] Collecting loaded kernel modules..."
lsmod > "$OUTPUT_DIR/modules.txt"

# 10. Hardware Sensors
echo "[+] Collecting sensor data..."
sensors > "$OUTPUT_DIR/sensors.txt" 2>/dev/null
ls /sys/class/hwmon/ > "$OUTPUT_DIR/hwmon.txt" 2>/dev/null

# 11. TPM Check
echo "[+] Checking TPM..."
ls /dev/tpm* > "$OUTPUT_DIR/tpm_devices.txt" 2>/dev/null
dmesg | grep -i tpm > "$OUTPUT_DIR/tpm_dmesg.txt" 2>/dev/null

# 12. Power / Embedded Controller
echo "[+] Collecting power info..."
upower -d > "$OUTPUT_DIR/power_upower.txt" 2>/dev/null
cat /sys/class/power_supply/*/uevent > "$OUTPUT_DIR/power_supply.txt" 2>/dev/null

# 13. Device Tree / Udev
echo "[+] Collecting device tree / udev..."
ls /sys/devices/ > "$OUTPUT_DIR/devices_tree.txt"
udevadm info --export-db > "$OUTPUT_DIR/udev_db.txt"

# 14. Running Services
echo "[+] Collecting running services..."
systemctl list-units --type=service > "$OUTPUT_DIR/services.txt"

# 15. Interrupts
echo "[+] Collecting interrupt table..."
cat /proc/interrupts > "$OUTPUT_DIR/interrupts.txt"

# 16. Full Kernel Log
echo "[+] Collecting dmesg..."
dmesg > "$OUTPUT_DIR/dmesg.txt"

echo "[*] ESSM Discovery Complete."
echo "[*] Baseline saved to: $OUTPUT_DIR"

