"""Regression checks for 6809 polling loops that use the U register.

LEAU does not modify condition codes on MC6809; BNE immediately after
LEAU tests an unrelated prior instruction and can cause a premature
DMA/RESTORE timeout. This static check prevents that specific regression.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class TestPollingSource(unittest.TestCase):
    def test_leau_is_followed_by_cmpu(self):
        for relative in ("rom/boot6809.asm", "ipl/boot_ipl.asm"):
            with self.subTest(relative=relative):
                source = (ROOT / relative).read_text()
                for match in re.finditer(r"\bleau\s+-1,u\s*\n", source, re.I):
                    following = source[match.end():].splitlines()
                    self.assertTrue(following, "LEAU at end of file")
                    self.assertRegex(following[0], r"(?i)\bcmpu\s+#0\b")

if __name__ == "__main__":
    unittest.main()
