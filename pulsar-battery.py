#!/usr/bin/env python3
"""Waybar module: battery status of Pulsar Feinmann F01 via LINK 2 dongle.

Speaks the Pulsar vendor HID protocol on the dongle's vendor interface:
17-byte reports with report ID 0x08, command in byte 1, checksum in byte 16
(0x55 minus the sum of bytes 0..15). Battery is command 0x04; the response
carries percent in byte 6, charging flag in byte 7 and millivolts in bytes 8-9.
"""

import glob
import json
import os
import select
import sys

REPORT_ID = 0x08
CMD_STATUS = 0x03
CMD_POWER = 0x04
DONGLE_NAME = "LINK 2 Dongle"

ICON = "\U000f037d"  # nf-md-mouse


def find_device():
    for uevent in glob.glob("/sys/class/hidraw/hidraw*/device/uevent"):
        if DONGLE_NAME not in open(uevent).read():
            continue
        node = uevent.split("/")[4]
        desc = open(os.path.dirname(uevent) + "/report_descriptor", "rb").read()
        # vendor page 0xff02 with report ID 0x08 marks the command interface
        if b"\x06\x02\xff" in desc and b"\x85\x08" in desc:
            return "/dev/" + node
    return None


def checksum(buf):
    return (0x55 - sum(buf[:16])) & 0xFF


def query(fd, cmd):
    buf = bytearray(17)
    buf[0] = REPORT_ID
    buf[1] = cmd
    buf[16] = checksum(buf)
    for _ in range(3):
        while select.select([fd], [], [], 0)[0]:
            os.read(fd, 64)
        os.write(fd, bytes(buf))
        deadline = 1.0
        while deadline > 0:
            if not select.select([fd], [], [], 0.2)[0]:
                deadline -= 0.2
                continue
            data = os.read(fd, 64)
            if len(data) >= 17 and data[0] == REPORT_ID and data[1] == cmd \
                    and checksum(data) == data[16]:
                return data
    return None


def emit(text="", tooltip="", cls="", pct=None):
    out = {"text": text, "tooltip": tooltip, "class": cls}
    if pct is not None:
        out["percentage"] = pct
    print(json.dumps(out))
    sys.exit(0)


dev = find_device()
if not dev:
    emit()  # dongle unplugged: hide module

fd = os.open(dev, os.O_RDWR | os.O_NONBLOCK)
try:
    status = query(fd, CMD_STATUS)
    if status is None or status[6] != 1:
        emit(f"{ICON} --", "Feinmann F01: not connected", "disconnected")

    power = query(fd, CMD_POWER)
    if power is None:
        emit(f"{ICON} ?", "Feinmann F01: no battery response", "disconnected")

    pct = power[6]
    charging = power[7] == 0x01
    volts = ((power[8] << 8) | power[9]) / 1000

    cls = "charging" if charging else "critical" if pct <= 20 else ""
    bolt = "\U000f140b" if charging else ""  # nf-md-lightning_bolt
    state = "Charging" if charging else "Discharging"
    emit(f"{ICON} {pct}%{bolt}",
         f"Feinmann F01\n{state}: {pct}% ({volts:.2f} V)", cls, pct)
finally:
    os.close(fd)
