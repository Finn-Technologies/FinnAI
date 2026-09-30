#!/usr/bin/env python3
"""Adds the one plural key Phase 4 introduced to the non-English ARB files.

`flowsStepCount` uses an ICU plural, so each locale needs its own forms — the
plural categories that matter differ by language (German has one, French has
one, and both differ from English's two). The `arb_parity_test` is what
catches a missing one, and this is the other half of that contract: a table
that must agree with `app_en.arb`, so a typo here fails rather than shipping an
untranslated string.
"""
import json
import sys
from pathlib import Path

L10N = Path(__file__).resolve().parents[1] / "lib" / "l10n"

# One plural form per locale, which is correct for de/es/fr/it: each of these
# languages uses a single form for all counts. Using `other` alone is the
# idiomatic shape and avoids "1 Schritt"/"2 Schritt".
PLURALS = {
    "de": "{count, plural, other{{count} Schritte}}",
    "es": "{count, plural, other{{count} pasos}}",
    "fr": "{count, plural, other{{count} étapes}}",
    "it": "{count, plural, other{{count} passaggi}}",
}

en = json.loads((L10N / "app_en.arb").read_text())
if "flowsStepCount" not in en:
    sys.exit("flowsStepCount is missing from app_en.arb")

for locale, value in PLURALS.items():
    path = L10N / f"app_{locale}.arb"
    text = path.read_text()
    if '"flowsStepCount"' in text:
        print(f"{locale}: already present")
        continue
    anchor = '"flowsScheduleRemove"'
    idx = text.index(anchor)
    end = text.index("\n", idx) + 1
    block = (
        f'  "flowsStepCount": {json.dumps(value, ensure_ascii=False)},\n'
        '  "@flowsStepCount": {\n'
        '    "description": "A flow\'s step count",\n'
        '    "placeholders": {\n'
        '      "count": {\n'
        '        "type": "int"\n'
        '      }\n'
        '    }\n'
        '  },\n'
    )
    text = text[:end] + block + text[end:]
    json.loads(text)
    path.write_text(text)
    print(f"{locale}: added flowsStepCount")
