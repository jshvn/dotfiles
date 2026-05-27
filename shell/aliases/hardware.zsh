#!/bin/zsh

# =============================================================================
# shell/aliases/hardware.zsh -- hardware introspection shortcuts
#
# Purpose:      Aliases that pipe macOS `system_profiler` / `sysctl` /
#               `diskutil` data through `highlight` for color-friendly
#               terminal display.
# Depends on:   highlight, system_profiler, sysctl, diskutil.
# Side effects: defines aliases gpu, cpu, ram, disk, bluetooth, speaker,
#               webcam, power, monitor.
# =============================================================================

alias gpu="system_profiler SPDisplaysDataType | highlight --syntax=markdown"
alias cpu="sysctl -n machdep.cpu.brand_string | highlight --syntax=markdown"
alias ram="system_profiler SPMemoryDataType | highlight --syntax=markdown"
alias disk="diskutil list | highlight --syntax=markdown"
alias bluetooth="system_profiler SPBluetoothDataType | highlight --syntax=markdown"
alias speaker="system_profiler SPAudioDataType | highlight --syntax=markdown"
alias webcam="system_profiler SPCameraDataType | highlight --syntax=markdown"
alias power="system_profiler SPPowerDataType | highlight --syntax=markdown"
alias monitor="system_profiler SPDisplaysDataType | highlight --syntax=markdown"