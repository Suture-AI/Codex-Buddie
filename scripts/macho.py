"""Add one dylib dependency using verified, unused Mach-O header padding.

No executable instructions, section offsets, or original dependencies change.
Only thin arm64 executables are supported. Signing is a separate step.
"""
import struct

DYLIB = b"@executable_path/../Frameworks/libBuddie.dylib\0"


def inject(data: bytes) -> bytes:
    if len(data) < 32:
        raise ValueError("Truncated Mach-O header")
    magic, cpu, subtype, kind, ncmds, sizeofcmds, flags, reserved = struct.unpack_from("<8I", data)
    if magic != 0xFEEDFACF or cpu != 0x0100000C or kind != 2:
        raise ValueError("Only thin arm64 Mach-O executables are supported")
    end = 32 + sizeofcmds
    if end > len(data) or ncmds > sizeofcmds // 8:
        raise ValueError("Invalid load-command table")
    cursor = 32
    sections = []
    for _ in range(ncmds):
        if cursor + 8 > end:
            raise ValueError("Truncated load command")
        cmd, size = struct.unpack_from("<II", data, cursor)
        if size < 8 or size % 8 or cursor + size > end:
            raise ValueError("Invalid load-command size")
        if cmd == 0x19:  # LC_SEGMENT_64, followed by section_64 records
            if size < 72:
                raise ValueError("Truncated segment")
            nsects = struct.unpack_from("<I", data, cursor + 64)[0]
            if 72 + nsects * 80 > size:
                raise ValueError("Truncated section table")
            for i in range(nsects):
                sec = cursor + 72 + i * 80
                offset = struct.unpack_from("<I", data, sec + 48)[0]
                if offset:
                    sections.append(offset)
        if cmd in (0xC, 0x80000018, 0x8000001F, 0x80000023):
            if size < 24:
                raise ValueError("Truncated dylib command")
            name_offset = struct.unpack_from("<I", data, cursor + 8)[0]
            if name_offset < 24 or name_offset >= size:
                raise ValueError("Invalid dylib name offset")
            name = data[cursor + name_offset:cursor + size].split(b"\0", 1)[0]
            if name == DYLIB.rstrip(b"\0"):
                raise ValueError("Buddie dependency is already present")
        cursor += size
    if cursor != end or not sections:
        raise ValueError("Inconsistent Mach-O layout")
    size = (24 + len(DYLIB) + 7) & ~7
    first = min(sections)
    if first > len(data) or end + size > first or any(data[end:end + size]):
        raise ValueError("No verified zero-filled header padding; refusing to shift executable data")
    command = struct.pack("<6I", 0xC, size, 24, 0, 0x10000, 0x10000) + DYLIB
    result = bytearray(data)
    result[end:end + size] = command.ljust(size, b"\0")
    struct.pack_into("<II", result, 16, ncmds + 1, sizeofcmds + size)
    return bytes(result)
