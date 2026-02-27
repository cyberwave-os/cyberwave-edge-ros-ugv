#!/usr/bin/env python3
"""
Mock ESP32 serial emulator for UGV Beast smoke testing.

Emulates the Waveshare UGV Beast ESP32 slave controller over a virtual serial
port. Receives JSON commands (velocity, servo, LED) and generates realistic
T:1001 telemetry at 20 Hz — encoder ticks, IMU with gravity, and battery voltage.

Usage:
    python3 mock_esp32.py /dev/pts/X          # listen on a specific PTY
    python3 mock_esp32.py /dev/pts/X --verbose # show commands received
"""

import argparse
import json
import math
import random
import select
import signal
import sys
import threading
import time

import serial


TELEMETRY_HZ = 20
TRACK_WIDTH_M = 0.23
WHEEL_RADIUS_M = 0.04

GRAVITY_RAW = 8192  # az value representing 1g
GYRO_SCALE = 16.4 * 180  # raw units per rad/s
NOMINAL_VOLTAGE_CV = 1180  # 11.80 V in centivolts


class MockESP32:
    def __init__(self, port: str, verbose: bool = False):
        self.ser = serial.Serial(port, 115200, timeout=0.01)
        self.verbose = verbose

        self.linear_vel = 0.0
        self.angular_vel = 0.0
        self.odl_cm = 0.0
        self.odr_cm = 0.0
        self.pan_deg = 0
        self.tilt_deg = 0
        self.io4 = 0.0
        self.io5 = 0.0
        self.voltage_cv = NOMINAL_VOLTAGE_CV
        self.commands_received = 0

        self._running = True
        self._reader_thread = threading.Thread(target=self._read_loop, daemon=True)

    def start(self):
        self._reader_thread.start()
        self._telemetry_loop()

    def stop(self):
        self._running = False
        self.ser.close()

    def _read_loop(self):
        buf = b""
        while self._running:
            try:
                if self.ser.in_waiting:
                    buf += self.ser.read(self.ser.in_waiting)
                    while b"\n" in buf:
                        line, buf = buf.split(b"\n", 1)
                        self._handle_line(line)
                else:
                    time.sleep(0.005)
            except (serial.SerialException, OSError):
                break

    def _handle_line(self, raw: bytes):
        try:
            cmd = json.loads(raw.decode("utf-8", errors="replace"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            return

        self.commands_received += 1
        t = cmd.get("T")

        if str(t) == "13":
            self.linear_vel = float(cmd.get("X", 0))
            self.angular_vel = float(cmd.get("Z", 0))
            if self.verbose:
                print(f"  CMD vel  lin={self.linear_vel:.2f} ang={self.angular_vel:.2f}")

        elif t == 134:
            self.pan_deg = int(cmd.get("X", 0))
            self.tilt_deg = int(cmd.get("Y", 0))
            if self.verbose:
                print(f"  CMD servo pan={self.pan_deg} tilt={self.tilt_deg}")

        elif t == 132:
            self.io4 = float(cmd.get("IO4", 0))
            self.io5 = float(cmd.get("IO5", 0))
            if self.verbose:
                print(f"  CMD LED IO4={self.io4} IO5={self.io5}")

        elif self.verbose:
            print(f"  CMD unknown T={t}: {cmd}")

    def _telemetry_loop(self):
        dt = 1.0 / TELEMETRY_HZ
        while self._running:
            t0 = time.monotonic()

            v_left = self.linear_vel - (self.angular_vel * TRACK_WIDTH_M / 2.0)
            v_right = self.linear_vel + (self.angular_vel * TRACK_WIDTH_M / 2.0)
            self.odl_cm += v_left * dt * 100.0
            self.odr_cm += v_right * dt * 100.0

            noise = lambda scale=50: random.randint(-scale, scale)

            packet = {
                "T": 1001,
                "L": int(self.odl_cm * 10),
                "R": int(self.odr_cm * 10),
                "ax": noise(200),
                "ay": noise(200),
                "az": GRAVITY_RAW + noise(100),
                "gx": int(self.angular_vel * GYRO_SCALE * 0.01) + noise(30),
                "gy": noise(30),
                "gz": int(self.angular_vel * GYRO_SCALE) + noise(30),
                "mx": noise(100),
                "my": noise(100),
                "mz": noise(100),
                "odl": round(self.odl_cm, 2),
                "odr": round(self.odr_cm, 2),
                "v": self.voltage_cv + random.randint(-5, 5),
            }

            try:
                self.ser.write((json.dumps(packet) + "\n").encode("utf-8"))
            except (serial.SerialException, OSError):
                break

            elapsed = time.monotonic() - t0
            time.sleep(max(0, dt - elapsed))


def main():
    parser = argparse.ArgumentParser(description="Mock ESP32 serial emulator")
    parser.add_argument("port", help="Serial port / PTY to listen on")
    parser.add_argument("--verbose", "-v", action="store_true", help="Log received commands")
    args = parser.parse_args()

    mock = MockESP32(args.port, verbose=args.verbose)
    signal.signal(signal.SIGTERM, lambda *_: mock.stop())
    signal.signal(signal.SIGINT, lambda *_: mock.stop())

    print(f"Mock ESP32 listening on {args.port} @ 115200 baud ({TELEMETRY_HZ} Hz telemetry)")
    try:
        mock.start()
    except KeyboardInterrupt:
        pass
    finally:
        mock.stop()
        print(f"\nMock ESP32 stopped. Commands received: {mock.commands_received}")


if __name__ == "__main__":
    main()
