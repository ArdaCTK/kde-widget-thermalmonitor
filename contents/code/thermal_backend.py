#!/usr/bin/env python3
"""
thermal_backend.py — Thermal Monitor Widget Backend
Reads CPU, GPU1 (dGPU), GPU2 (iGPU) temperatures and fan speeds.
Works universally: coretemp (Intel/AMD CPU), nvidia-smi (NVIDIA dGPU),
amdgpu hwmon (AMD dGPU), and ASUS fan data.

Output: single-line JSON to stdout.
"""

import json
import os
import subprocess
import sys

# ─── helpers ──────────────────────────────────────────────────────────────────

def read_file(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except Exception:
        return None


def millideg_to_celsius(val_str):
    """Convert millidegree string (e.g. '61000') to int Celsius."""
    try:
        return int(int(val_str) / 1000)
    except Exception:
        return None


def run(cmd):
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=3
        )
        return result.stdout.strip()
    except Exception:
        return ""


# ─── CPU temperature ──────────────────────────────────────────────────────────

def get_cpu_temp():
    """
    Compute the average of all individual Core temps from coretemp hwmon.
    This matches what KDE System Monitor shows as 'cpu/all/averageTemperature'.
    Falls back to Package id 0, then k10temp (Tdie/Tccd1), then acpitz.
    """
    hwmon_base = "/sys/class/hwmon"
    try:
        dirs = os.listdir(hwmon_base)
    except Exception:
        return None

    # ── Intel: coretemp — average of all 'Core N' labels ─────────────────
    for d in sorted(dirs):
        path = os.path.join(hwmon_base, d)
        name = read_file(os.path.join(path, "name"))
        if name != "coretemp":
            continue

        core_vals = []
        package_val = None
        for i in range(1, 60):
            label_path = os.path.join(path, f"temp{i}_label")
            input_path = os.path.join(path, f"temp{i}_input")
            label = read_file(label_path)
            val_str = read_file(input_path)
            if val_str is None:
                continue
            val = millideg_to_celsius(val_str)
            if label and label.startswith("Core"):
                core_vals.append(val)
            elif label == "Package id 0" and package_val is None:
                package_val = val

        if core_vals:
            # Average of individual cores — matches KDE System Monitor
            return round(sum(core_vals) / len(core_vals))
        if package_val is not None:
            return package_val

    # ── AMD: k10temp — prefer Tdie (die average) or Tccd1 ────────────────
    for d in sorted(dirs):
        path = os.path.join(hwmon_base, d)
        name = read_file(os.path.join(path, "name"))
        if name != "k10temp":
            continue
        for i in range(1, 20):
            label = read_file(os.path.join(path, f"temp{i}_label"))
            val_str = read_file(os.path.join(path, f"temp{i}_input"))
            if val_str and label in ("Tdie", "Tccd1"):
                return millideg_to_celsius(val_str)

    # ── Fallback: acpitz ──────────────────────────────────────────────────
    for d in sorted(dirs):
        path = os.path.join(hwmon_base, d)
        if read_file(os.path.join(path, "name")) == "acpitz":
            val_str = read_file(os.path.join(path, "temp1_input"))
            if val_str:
                return millideg_to_celsius(val_str)

    return None


# ─── GPU temperatures ──────────────────────────────────────────────────────────

def get_nvidia_temp():
    """Query nvidia-smi for temperature and GPU name."""
    out = run("nvidia-smi --query-gpu=temperature.gpu,name --format=csv,noheader,nounits 2>/dev/null")
    if not out:
        return None, None
    lines = [l.strip() for l in out.splitlines() if l.strip()]
    if not lines:
        return None, None
    # Take first (primary) GPU
    parts = lines[0].split(",", 1)
    try:
        temp = int(parts[0].strip())
        name = parts[1].strip() if len(parts) > 1 else "NVIDIA GPU"
        # Shorten name for display
        name = (name.replace("NVIDIA GeForce ", "")
                     .replace(" Laptop GPU", "")
                     .replace("NVIDIA ", ""))
        return temp, name
    except Exception:
        return None, None


def get_amd_gpu_temp():
    """Find amdgpu hwmon sensor for temperature."""
    hwmon_base = "/sys/class/hwmon"
    try:
        dirs = os.listdir(hwmon_base)
    except Exception:
        return None, None
    for d in sorted(dirs):
        path = os.path.join(hwmon_base, d)
        name = read_file(os.path.join(path, "name"))
        if name in ("amdgpu", "radeon"):
            # temp1 is edge (junction), temp2 is hotspot — prefer hotspot
            for tidx in (2, 1):
                val_str = read_file(os.path.join(path, f"temp{tidx}_input"))
                if val_str:
                    return millideg_to_celsius(val_str), "AMD GPU"
    return None, None


def get_intel_igpu_temp():
    """
    Intel iGPU has no direct temperature sensor in most setups.
    Try i915 hwmon if available, otherwise return None gracefully.
    """
    hwmon_base = "/sys/class/hwmon"
    try:
        dirs = os.listdir(hwmon_base)
    except Exception:
        return None, None
    for d in sorted(dirs):
        path = os.path.join(hwmon_base, d)
        name = read_file(os.path.join(path, "name"))
        if name in ("i915", "xe"):
            val_str = read_file(os.path.join(path, "temp1_input"))
            if val_str:
                return millideg_to_celsius(val_str), "Intel GPU"
    return None, None


def get_gpu_temps():
    """
    Returns (gpu1_temp, gpu1_name, gpu2_temp, gpu2_name).
    GPU1 = dGPU (NVIDIA/AMD), GPU2 = iGPU (Intel) if distinct.
    """
    gpu1_temp, gpu1_name = None, None
    gpu2_temp, gpu2_name = None, None

    # Try NVIDIA first (dGPU)
    nv_temp, nv_name = get_nvidia_temp()
    if nv_temp is not None:
        gpu1_temp, gpu1_name = nv_temp, nv_name

    # Try AMD dGPU
    if gpu1_temp is None:
        amd_temp, amd_name = get_amd_gpu_temp()
        if amd_temp is not None:
            gpu1_temp, gpu1_name = amd_temp, amd_name

    # Try Intel iGPU as gpu2 (only if we already have a dGPU)
    if gpu1_temp is not None:
        igpu_temp, igpu_name = get_intel_igpu_temp()
        gpu2_temp, gpu2_name = igpu_temp, igpu_name

    # If no dGPU found, try iGPU as primary gpu1
    if gpu1_temp is None:
        igpu_temp, igpu_name = get_intel_igpu_temp()
        gpu1_temp, gpu1_name = igpu_temp, igpu_name

    return gpu1_temp, gpu1_name, gpu2_temp, gpu2_name


# ─── Fan speeds (ASUS) ────────────────────────────────────────────────────────

def get_asus_fans():
    """Read cpu_fan, gpu_fan, mid_fan from asus hwmon."""
    hwmon_base = "/sys/class/hwmon"
    fans = {}
    try:
        dirs = os.listdir(hwmon_base)
    except Exception:
        return fans
    for d in sorted(dirs):
        path = os.path.join(hwmon_base, d)
        name = read_file(os.path.join(path, "name"))
        if name == "asus":
            # Scan fan inputs
            fan_labels = {
                "fan1": "cpu_fan",
                "fan2": "gpu_fan",
                "fan3": "mid_fan",
            }
            for i in range(1, 10):
                rpm_str = read_file(os.path.join(path, f"fan{i}_input"))
                label = read_file(os.path.join(path, f"fan{i}_label"))
                if rpm_str is None:
                    continue
                try:
                    rpm = int(rpm_str)
                except Exception:
                    continue
                key = label if label else f"fan{i}"
                fans[key] = rpm
            break
    return fans


# ─── main ─────────────────────────────────────────────────────────────────────

def main():
    cpu_temp = get_cpu_temp()
    gpu1_temp, gpu1_name, gpu2_temp, gpu2_name = get_gpu_temps()
    fans = get_asus_fans()

    result = {
        "cpu": cpu_temp,
        "gpu1": gpu1_temp,
        "gpu1_name": gpu1_name or "GPU",
        "gpu2": gpu2_temp,
        "gpu2_name": gpu2_name,
        "fans": fans,
    }

    print(json.dumps(result))


if __name__ == "__main__":
    main()
