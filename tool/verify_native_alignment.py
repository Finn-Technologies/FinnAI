#!/usr/bin/env python3
"""Verify that every 64-bit ELF shared library is 16 KB page compatible."""

from __future__ import annotations

import argparse
import struct
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Optional


MIN_ALIGNMENT = 0x4000
PT_LOAD = 1


def load_alignments(path: Path) -> Optional[list[int]]:
    with path.open("rb") as stream:
        header = stream.read(64)
        if len(header) < 64 or header[:4] != b"\x7fELF":
            raise ValueError("not an ELF file")
        if header[5] != 1:
            raise ValueError("expected a little-endian ELF file")
        if header[4] == 1:
            return None
        if header[4] != 2:
            raise ValueError(f"unsupported ELF class {header[4]}")

        program_offset = struct.unpack_from("<Q", header, 32)[0]
        entry_size = struct.unpack_from("<H", header, 54)[0]
        entry_count = struct.unpack_from("<H", header, 56)[0]
        if entry_size < 56:
            raise ValueError(f"invalid program-header size {entry_size}")

        alignments: list[int] = []
        stream.seek(program_offset)
        for _ in range(entry_count):
            entry = stream.read(entry_size)
            if len(entry) != entry_size:
                raise ValueError("truncated program-header table")
            if struct.unpack_from("<I", entry, 0)[0] == PT_LOAD:
                alignments.append(struct.unpack_from("<Q", entry, 48)[0])
        return alignments


def verify(root: Path) -> int:
    libraries = sorted(root.rglob("*.so"))
    if not libraries:
        print(f"FAIL: no shared libraries found under {root}")
        return 1

    failed = False
    for library in libraries:
        try:
            alignments = load_alignments(library)
        except ValueError as error:
            print(f"FAIL: {library.name}: {error}")
            failed = True
            continue

        if alignments is None:
            print(f"SKIP: {library.name}: 32-bit ELF")
            continue

        if not alignments:
            print(f"FAIL: {library.name}: no PT_LOAD segments")
            failed = True
            continue

        minimum = min(alignments)
        status = "OK" if minimum >= MIN_ALIGNMENT else "BLOCKER"
        rendered = ", ".join(f"0x{alignment:x}" for alignment in alignments)
        print(
            f"{status}: {library.name}: "
            f"PT_LOAD alignments [{rendered}], minimum 0x{minimum:x}"
        )
        failed |= minimum < MIN_ALIGNMENT

    return int(failed)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify 16 KB PT_LOAD alignment in a directory, APK, AAB, or AAR."
    )
    parser.add_argument("artifact", type=Path)
    args = parser.parse_args()

    artifact = args.artifact.expanduser().resolve()
    if not artifact.exists():
        parser.error(f"{artifact} does not exist")

    if artifact.is_dir():
        return verify(artifact)

    if artifact.suffix.lower() not in {".aar", ".aab", ".apk", ".zip"}:
        parser.error("artifact must be a directory, .aar, .aab, .apk, or .zip")

    with tempfile.TemporaryDirectory(prefix="finn-native-alignment-") as temp_dir:
        try:
            with zipfile.ZipFile(artifact) as archive:
                archive.extractall(temp_dir)
        except zipfile.BadZipFile:
            print(f"FAIL: {artifact} is not a valid ZIP archive")
            return 1
        return verify(Path(temp_dir))


if __name__ == "__main__":
    sys.exit(main())
