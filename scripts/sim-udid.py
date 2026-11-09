#!/usr/bin/env python3
"""يطبع معرّف محاكٍ بعينه: الاسم ونسخة iOS مثبّتان. يفشل إن لم يوجد.
الاستعمال: xcrun simctl list devices available -j | sim-udid.py "iPhone 17 Pro Max" 26.5
"""
import json, sys

name, os_version = sys.argv[1], sys.argv[2]
runtime = "com.apple.CoreSimulator.SimRuntime.iOS-" + os_version.replace(".", "-")
devices = json.load(sys.stdin)["devices"]
devs = devices.get(runtime, [])
hits = [d["udid"] for d in devs if d["name"] == name]
if not hits:
    names = [d["name"] for d in devs]
    sys.exit(f"لا محاكي: {name} على {runtime}\nالمتاح عليه: {names}\nنسخ iOS المتاحة: {sorted(devices)}")
print(hits[0])
