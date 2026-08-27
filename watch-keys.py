#!/usr/bin/env python3
# Emit one "k" line per keyboard press/repeat from evdev devices we can open.
import glob
import os
import select
import struct
import sys
import time

EVENT = struct.Struct("llHHi")
EV_KEY = 1


def open_keyboards():
    fds = []
    paths = glob.glob("/dev/input/by-path/*-event-kbd")
    paths += glob.glob("/dev/input/by-id/*-event-kbd")
    if not paths:
        paths = glob.glob("/dev/input/event*")
    seen = set()
    for path in paths:
        real = os.path.realpath(path)
        if real in seen:
            continue
        seen.add(real)
        try:
            fds.append(os.open(real, os.O_RDONLY | os.O_NONBLOCK))
        except OSError:
            continue
    return fds


def main():
    fds = open_keyboards()
    if not fds:
        while True:
            time.sleep(3600)
    while True:
        ready, _, _ = select.select(fds, [], [], 2.0)
        for fd in ready:
            try:
                buf = os.read(fd, EVENT.size * 32)
            except OSError:
                continue
            for offset in range(0, len(buf) - EVENT.size + 1, EVENT.size):
                _sec, _usec, etype, _code, value = EVENT.unpack_from(buf, offset)
                if etype == EV_KEY and value >= 1:
                    sys.stdout.write("k\n")
                    sys.stdout.flush()


if __name__ == "__main__":
    main()
