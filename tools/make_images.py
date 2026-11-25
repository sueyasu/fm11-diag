#!/usr/bin/env python3
"""Build FM-11 2D/2HD diagnostic D88 disks from raw lwasm outputs."""
import argparse
import pathlib
import struct

HEADER = 0x2B0

def slotted(path: pathlib.Path, length: int, name: str) -> bytes:
    data = path.read_bytes()
    if len(data) > length:
        raise ValueError(f"{name}: {len(data)} bytes, maximum {length}")
    return data.ljust(length, b"\0")

def build_image(hd: bool, ipl: bytes, os_payload: bytes) -> bytes:
    tracks = 77 if hd else 40
    sectors = 26 if hd else 16
    out = bytearray(HEADER)
    out[0:14] = b"FM11 DIAG 2HD" if hd else b"FM11 DIAG 2D"
    out[0x1B] = 0x20 if hd else 0x10
    for track in range(tracks * 2):
        struct.pack_into("<I", out, 0x20 + track * 4, len(out))
        cyl, side = divmod(track, 2)
        size = 128 if hd and track == 0 else 256
        for r in range(1, sectors + 1):
            data = bytearray([0xE5] * size)
            if track == 0:
                if hd and r <= 4:
                    data[:] = ipl[(r - 1)*128:r*128]
                elif not hd and r <= 2:
                    data[:] = ipl[(r - 1)*256:r*256]
                elif not hd and r == 3:
                    data[:] = os_payload
            if hd and track == 1 and r == 1:
                data[:] = os_payload
            sec = bytearray(16)
            sec[0:4] = bytes((cyl, side, r, 0 if size == 128 else 1))
            struct.pack_into("<H", sec, 4, sectors)
            struct.pack_into("<H", sec, 14, size)
            out.extend(sec)
            out.extend(data)
    struct.pack_into("<I", out, 0x1C, len(out))
    return bytes(out)

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", type=pathlib.Path, default=pathlib.Path("build"))
    args = ap.parse_args()
    b = args.build
    payload = slotted(b / "minimal.bin", 256, "diagnostic OS")
    for name, hd in (("2d", False), ("2hd", True)):
        rom = slotted(b / f"rom_{name}.bin", 4094, "diagnostic ROM")
        # The FM-11 copies the last two ROM bytes into the reset vector at FFFE.
        (b / f"diag_boot_{name}.bin").write_bytes(rom + bytes((0x50, 0x00)))
        ipl = slotted(b / f"ipl_{name}.bin", 512, "diagnostic IPL")
        (b / f"diag_{name}.d88").write_bytes(build_image(hd, ipl, payload))
        print(f"{name}: ROM {len(rom)} bytes incl. padding, IPL 512, OS 256")

if __name__ == "__main__":
    main()
