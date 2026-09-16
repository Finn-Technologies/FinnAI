# Runtime assets — Figma export hygiene

`assets/runtime/*.svg` are raw **Figma** exports. This doc lives outside the
assets directory so it is never bundled into the shipped app.

## Canonical icon contract

- **App chrome, nav, composer, dialogs**: use `FluxIcons` from `lib/src/widgets/flux_controls.dart` (HugeIcons). This is the canonical set — vector, theme-aware, no asset load.
- **Figma-origin visuals** (welcome arrow, back chevron, privacy/magic illustrations, sidebar tiles, send states, no-history): use `FigmaSvg` + `FigmaAssets` (filtered `assets/runtime/*.svg`). Only `FigmaSvg` should load SVGs; never `SvgPicture.asset` directly in feature code.

## Wired inventory

19 SVGs are tracked in `assets/runtime/`, all wired via `FigmaAssets` (the set
is asserted by `test/asset_verification_test.dart`):

- `icon_144_180.svg` (back), `icon_144_170.svg` (welcomeArrow), `icon_144_195.svg` (privacy), `icon_144_243.svg` (magic), `icon_149_193.svg` (security), `icon_144_238.svg` (download), `icon_59_31.svg` (menu), `icon_59_32.svg` (modelChevron), `icon_59_14.svg` (send), `icon_59_65.svg` (activeSend), `icon_59_19.svg` (add), `icon_98_197.svg` (sidebarActions), `icon_98_202.svg` (sidebarCreations), `icon_101_181.svg` (sidebarYou), `icon_101_193.svg` (sidebarSkills), `icon_114_151.svg` (noHistory), `icon_178_212.svg` (creationBack), `icon_178_220.svg` (creationSend), `icon_178_228.svg` (creationAdd)

The former 57 orphans (not referenced in `lib/`) were deleted in the asset
cleanup so the bundled assets directory only ships what the UI loads.

> To re-verify: `ls assets/runtime/*.svg | xargs -n1 basename | sort > /tmp/all; grep -rh "icon_" lib/ --include="*.dart" | grep -o "icon_[^\"]*\.svg" | sort -u > /tmp/used; comm -23 /tmp/all /tmp/used` must print nothing.

## Adding a new asset

1. Export from Figma into `assets/runtime/` with the `icon_<frame>_<node>.svg` naming.
2. Add a named constant to `FigmaAssets` (one line).
3. Use it only through `FigmaSvg` so dark-mode tinting stays consistent.
4. Update the wired inventory above and `test/asset_verification_test.dart`.
