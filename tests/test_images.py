import pathlib
import struct
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"

def sector(data, track, r):
    pos = struct.unpack_from("<I", data, 0x20 + 4 * track)[0]
    while pos < len(data):
        c, h, actual, n = data[pos:pos+4]
        length = struct.unpack_from("<H", data, pos+14)[0]
        if actual == r:
            return (c, h, n, bytes(data[pos+16:pos+16+length]))
        pos += 16 + length
    raise AssertionError(f"missing track={track} sector={r}")

class TestBootImages(unittest.TestCase):
    def test_rom_vectors(self):
        for name in ("2d", "2hd"):
            rom = (BUILD/f"diag_boot_{name}.bin").read_bytes()
            self.assertEqual(len(rom), 4096)
            self.assertEqual(rom[-2:], b"\x50\x00")

    def test_2d_ipl_and_os(self):
        data = (BUILD/"diag_2d.d88").read_bytes()
        self.assertEqual(struct.unpack_from("<I", data, 0x1c)[0], len(data))
        ipl = (BUILD/"ipl_2d.bin").read_bytes().ljust(512, b"\0")
        self.assertEqual(sector(data, 0, 1)[3]+sector(data, 0, 2)[3], ipl)
        self.assertEqual(sector(data, 0, 3)[3], (BUILD/"minimal.bin").read_bytes().ljust(256, b"\0"))

    def test_2hd_ipl_and_os(self):
        data = (BUILD/"diag_2hd.d88").read_bytes()
        self.assertEqual(struct.unpack_from("<I", data, 0x1c)[0], len(data))
        ipl = (BUILD/"ipl_2hd.bin").read_bytes().ljust(512, b"\0")
        self.assertEqual(b"".join(sector(data, 0, r)[3] for r in range(1, 5)), ipl)
        self.assertTrue(all(sector(data, 0, r)[2] == 0 for r in range(1, 27)))
        self.assertEqual(sector(data, 1, 1)[3], (BUILD/"minimal.bin").read_bytes().ljust(256, b"\0"))

if __name__ == "__main__":
    unittest.main()
