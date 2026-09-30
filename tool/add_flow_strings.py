#!/usr/bin/env python3
"""Adds the Phase 4 flow strings to the non-English ARB files.

The English strings live in `app_en.arb`; this copies the same keys into the
other four locales from a translation table, inserting each block next to the
flow strings that are already there. Every key the table lists must already
exist in `app_en.arb` or this fails, so a typo in the table is a hard error
rather than a silently untranslated screen.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / "lib" / "l10n"
LOCALES = ["de", "es", "fr", "it"]
TABLE = Path(
    "/private/tmp/commandcode-501/-Users-abhi-Desktop-FinnAI/"
    "c8d19bc4-e647-43d0-9982-9e9fc0f8cddf/scratchpad/flow_strings.json"
)

table = json.loads(TABLE.read_text())
en = json.loads((L10N / "app_en.arb").read_text())

missing = [k for k in table if k not in en]
if missing:
    sys.exit(f"keys not in app_en.arb: {missing}")

anchor = '"flowsInstructionLabel"'
for locale in LOCALES:
    path = L10N / f"app_{locale}.arb"
    text = path.read_text()
    if '"flowsRunAction"' in text:
        print(f"{locale}: already has the flow-run strings, skipping")
        continue
    idx = text.index(anchor)
    # Close the anchor's own value and its metadata block, then insert.
    end = text.index("},", text.index("@flowsInstructionLabel", idx)) + 2
    block = "\n".join(
        f'  "{key}": {json.dumps(table[key][locale], ensure_ascii=False)},'
        for key in table
    )
    text = text[:end] + "\n" + block + text[end:]
    path.write_text(text)
    # Fail loudly rather than leave a file gen-l10n will choke on.
    json.loads(text)
    print(f"{locale}: inserted {len(table)} keys")
