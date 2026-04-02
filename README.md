# ESSM

Embedded Systems Security Module for x86 and SBC-class embedded Linux platforms.

## Current components

- scripts/essm_discovery.sh
- scripts/essm_discovery_menu.sh
- baseline/ : discovery outputs and platform surface report
- docs/ : architecture, attack surface reduction, and enforcement planning

## Current reference platform

- Dell Inspiron
- Arch Linux
- x86_64
- UEFI boot
- GRUB bootloader
- Secure Boot currently disabled
- TPM present in firmware tables but not currently usable by Linux

## Current project phase

ESSM Phase 1:
- hardware and platform discovery
- firmware and boot assessment
- attack surface classification baseline

ESSM Phase 2:
- attack surface reduction matrix
- management plane hardening
- enforcement policy design

## Goals

ESSM is intended to provide:

- embedded Linux hardware and platform discovery
- firmware and boot trust assessment
- service and interface reduction
- local integrity and security enforcement planning
- reusable security profiles for x86 and SBC platforms
