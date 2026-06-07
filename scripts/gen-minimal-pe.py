#!/usr/bin/env python3
"""Generate a minimal valid PE32+ executable (x64) that exits with code 0.

Used for mock-build / local pipeline tests when a Windows linker is unavailable.
The binary is not a real game — only a structurally valid PE for fixture copy tests.
On Windows CI, prefer building game/ via build-mock-game.ps1 instead.
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

# Minimal x64 PE: ExitProcess(0) via kernel32
# Machine: AMD64 (0x8664), 1 section (.text), subsystem: CONSOLE
CODE = bytes([
    0x48, 0x83, 0xEC, 0x28,             # sub rsp, 0x28
    0x33, 0xC9,                         # xor ecx, ecx  (exit code 0)
    0xFF, 0x15, 0x02, 0x00, 0x00, 0x00, # call [rip+2] -> IAT
    0x48, 0x83, 0xC4, 0x28,             # add rsp, 0x28
    0xC3,                               # ret
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # IAT placeholder
])

IMPORTS = b"kernel32.dll\x00"
EXIT_NAME = b"ExitProcess\x00"


def align(value: int, alignment: int) -> int:
    return (value + alignment - 1) // alignment * alignment


def build_pe() -> bytes:
    file_align = 0x200
    sect_align = 0x1000

    # DOS header + stub
    dos = bytearray(0x80)
    dos[0:2] = b"MZ"
    struct.pack_into("<H", dos, 0x3C, 0x80)  # e_lfanew

    # PE signature
    pe_sig = b"PE\x00\x00"

    # COFF header
    coff = struct.pack(
        "<HHIIIHH",
        0x8664,  # Machine AMD64
        2,       # NumberOfSections (.text + .idata)
        0,       # TimeDateStamp
        0,       # PointerToSymbolTable
        0,       # NumberOfSymbols
        0xF0,    # SizeOfOptionalHeader (PE32+)
        0x22,    # Characteristics EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE
    )

    # Optional header PE32+ (240 bytes)
    size_of_code = align(len(CODE), file_align)
    size_of_headers = align(0x80 + 4 + 20 + 240 + 40 * 2, file_align)
    image_base = 0x140000000
    entry_rva = sect_align  # .text at 0x1000

    opt = bytearray(240)
    struct.pack_into("<H", opt, 0, 0x20B)  # Magic PE32+
    struct.pack_into("<I", opt, 16, size_of_code)
    struct.pack_into("<I", opt, 20, 0)  # SizeOfInitializedData
    struct.pack_into("<I", opt, 24, entry_rva)
    struct.pack_into("<I", opt, 28, 0x1000)  # BaseOfCode
    struct.pack_into("<Q", opt, 32, image_base)
    struct.pack_into("<I", opt, 40, sect_align)
    struct.pack_into("<I", opt, 44, file_align)
    struct.pack_into("<H", opt, 48, 6)  # MajorOperatingSystemVersion
    struct.pack_into("<H", opt, 52, 0)
    struct.pack_into("<H", opt, 56, 6)  # MajorSubsystemVersion
    struct.pack_into("<H", opt, 60, 0)
    struct.pack_into("<I", opt, 64, 0)
    struct.pack_into("<I", opt, 68, sect_align * 3)
    struct.pack_into("<I", opt, 72, size_of_headers)
    struct.pack_into("<H", opt, 76, 3)  # Subsystem CONSOLE
    struct.pack_into("<Q", opt, 96, 0x100000)  # SizeOfStackReserve
    struct.pack_into("<Q", opt, 104, 0x1000)
    struct.pack_into("<Q", opt, 112, 0x100000)
    struct.pack_into("<Q", opt, 120, 0x1000)
    struct.pack_into("<I", opt, 128, 16)  # NumberOfRvaAndSizes

    # Section .text
    text_raw_size = align(len(CODE), file_align)
    text = bytearray(40)
    text[0:8] = b".text\x00\x00\x00"
    struct.pack_into("<I", text, 8, len(CODE))
    struct.pack_into("<I", text, 12, entry_rva)
    struct.pack_into("<I", text, 16, len(CODE))
    struct.pack_into("<I", text, 20, size_of_headers)
    struct.pack_into("<I", text, 36, 0x60000020)  # CODE | EXECUTE | READ

    # Section .idata (imports)
    idata_rva = entry_rva + sect_align
    idata = bytearray(40)
    idata[0:8] = b".idata\x00\x00"
    struct.pack_into("<I", idata, 8, 0x200)
    struct.pack_into("<I", idata, 12, idata_rva)
    struct.pack_into("<I", idata, 16, 0x200)
    struct.pack_into("<I", idata, 20, size_of_headers + text_raw_size)
    struct.pack_into("<I", idata, 36, 0xC0000040)  # INITIALIZED_DATA | READ

    headers = dos + pe_sig + coff + opt + text + idata
    headers = headers + b"\x00" * (size_of_headers - len(headers))

    text_section = CODE + b"\x00" * (text_raw_size - len(CODE))

    # Minimal import directory (placeholder — enough for PE parsers)
    import_blob = bytearray(0x200)
    import_blob[0:12] = struct.pack("<III", idata_rva, 0, 0)
    import_blob[0x20:0x20 + len(IMPORTS)] = IMPORTS
    import_blob[0x80:0x80 + len(EXIT_NAME)] = EXIT_NAME

    return headers + text_section + import_blob


def main() -> int:
    out = Path(__file__).resolve().parent.parent / "fixtures" / "mock-game" / "game.exe"
    out.parent.mkdir(parents=True, exist_ok=True)
    data = build_pe()
    out.write_bytes(data)
    print(f"✓ wrote minimal PE → {out} ({len(data)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
