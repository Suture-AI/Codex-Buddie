import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from macho import inject, DYLIB


def fixture(padding=128):
    command_size = 72 + 80
    section_offset = 32 + command_size + padding
    header = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 1, command_size, 0, 0)
    segment = bytearray(command_size)
    struct.pack_into("<II", segment, 0, 0x19, command_size)
    struct.pack_into("<I", segment, 64, 1)
    struct.pack_into("<I", segment, 72 + 48, section_offset)
    return header + segment + bytes(padding) + b"EXECUTABLE MUST NOT CHANGE"


class MachOTests(unittest.TestCase):
    def test_adds_dependency_without_moving_code(self):
        original = fixture()
        result = inject(original)
        self.assertEqual(len(result), len(original))
        self.assertEqual(result[312:], original[312:])
        self.assertEqual(struct.unpack_from("<I", result, 16)[0], 2)
        self.assertIn(DYLIB, result)

    def test_repeated_patch_rejected(self):
        with self.assertRaisesRegex(ValueError, "already present"):
            inject(inject(fixture()))

    def test_insufficient_padding_rejected(self):
        with self.assertRaisesRegex(ValueError, "padding"):
            inject(fixture(8))

    def test_nonzero_padding_rejected(self):
        data = bytearray(fixture()); data[190] = 1
        with self.assertRaisesRegex(ValueError, "padding"):
            inject(data)

    def test_other_architecture_rejected(self):
        data = bytearray(fixture()); struct.pack_into("<I", data, 4, 0x01000007)
        with self.assertRaisesRegex(ValueError, "arm64"):
            inject(data)

    def test_corrupt_command_rejected(self):
        data = bytearray(fixture()); struct.pack_into("<I", data, 36, 0)
        with self.assertRaisesRegex(ValueError, "size"):
            inject(data)

    def test_truncated_files_rejected(self):
        for n in [0, 16, 32, 150]:
            with self.subTest(n=n), self.assertRaises(ValueError):
                inject(fixture()[:n])


if __name__ == "__main__":
    unittest.main()
