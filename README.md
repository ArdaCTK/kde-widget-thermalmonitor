# Thermal Monitor — KDE Plasma 6 Widget

Real-time CPU and GPU temperature monitor for the KDE Plasma 6 taskbar.

## Features
- Live CPU and GPU temperature chips in the taskbar
- Temperature-reactive colour coding (cool → warm → hot)
- Popup panel with circular gauges, fan RPM, and mini history graph
- ASUS ROG fan speed support (cpu_fan, gpu_fan, mid_fan)
- Universal sensor detection: coretemp, k10temp, nvidia-smi, amdgpu

## Requirements
- KDE Plasma 6
- python3, lm-sensors
- nvidia-smi (for NVIDIA GPUs)

## Installation
```bash
bash install.sh
nohup plasmashell --replace > /dev/null 2>&1 & disown
```

Then right-click the panel → **Add Widgets** → **Thermal Monitor**
