# Repository Maintenance Checklist

Use this checklist before merging substantial engine or release work.

## Architecture

- [ ] Keep llama.cpp-specific imports behind the engine backend boundary.
- [ ] Prefer small extractions from `FinnAccelerator` over a large rewrite.
- [ ] Keep architecture docs explicit about what is implemented, partial, or planned.
- [ ] Update issue #13 when backend abstraction or accelerator decomposition materially progresses.

## Validation

- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run the engine seam verification script.
- [ ] Run release verification for release-facing changes.
- [ ] For Android native changes, verify ARM64 packaging and 16 KB alignment.
- [ ] For performance changes, record reproducible device/model/configuration details.

## Pull requests

- [ ] Keep each PR focused on one concern.
- [ ] Link the relevant issue.
- [ ] Include behavior, test, and migration notes when applicable.
- [ ] Do not merge based only on documentation claims when the behavior has not been independently validated.

## Documentation

- [ ] Update the README when repository structure or developer workflow changes.
- [ ] Update architecture docs when implementation diverges from the roadmap.
- [ ] Keep benchmark claims traceable to recorded validation data.
