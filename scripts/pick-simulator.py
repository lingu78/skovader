#!/usr/bin/env python3
"""Skriver ut id för den nyaste tillgängliga iPhone-simulatorn (för CI)."""
import json
import subprocess

devices = json.loads(subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "-j"]))["devices"]

def version(runtime):
    # "com.apple.CoreSimulator.SimRuntime.iOS-18-2" → (18, 2)
    return tuple(int(p) for p in runtime.rsplit("iOS-", 1)[1].split("-"))

candidates = [
    (version(runtime), device["name"], device["udid"])
    for runtime, items in devices.items() if ".iOS-" in runtime
    for device in items if device["name"].startswith("iPhone")
]
if not candidates:
    raise SystemExit("Ingen iPhone-simulator hittades")
print(max(candidates)[2])
