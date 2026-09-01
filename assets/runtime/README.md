# Runtime assets — Figma export hygiene

`assets/runtime/*.svg` are raw **Figma** exports. They are not all used at runtime.

## Canonical icon contract

- **App chrome, nav, composer, dialogs**: use `FluxIcons` from `lib/src/widgets/flux_controls.dart` (HugeIcons). This is the canonical set — vector, theme-aware, no asset load.
- **Figma-origin visuals** (welcome arrow, back chevron, privacy/magic illustrations, sidebar tiles, send states, no-history): use `FigmaSvg` + `FigmaAssets` (filtered `assets/runtime/*.svg`). Only `FigmaSvg` should load SVGs; never `SvgPicture.asset` directly in feature code.

## Orphan inventory (generated)

76 SVGs are tracked in `assets/runtime/`. 19 are wired via `FigmaAssets`:

- `icon_144_180.svg` (back), `icon_144_170.svg` (welcomeArrow), `icon_144_195.svg` (privacy), `icon_144_243.svg` (magic), `icon_149_193.svg` (security), `icon_144_238.svg` (download), `icon_59_31.svg` (menu), `icon_59_32.svg` (modelChevron), `icon_59_14.svg` (send), `icon_59_65.svg` (activeSend), `icon_59_19.svg` (add), `icon_98_197.svg` (sidebarActions), `icon_98_202.svg` (sidebarCreations), `icon_101_181.svg` (sidebarYou), `icon_101_193.svg` (sidebarSkills), `icon_114_151.svg` (noHistory), `icon_178_212.svg` (creationBack), `icon_178_220.svg` (creationSend), `icon_178_228.svg` (creationAdd)

57 are currently **orphan** (not referenced in `lib/`). They are kept because they are cheap (~1 KB each) and may be re-wired for future Figma iterations, but they should not be loaded. Do not add new `FigmaAssets` entries without removing or replacing an orphan.

Orphan list:

- `icon_101_205.svg`, `icon_120_155.svg`, `icon_120_159.svg`, `icon_120_163.svg`, `icon_120_174.svg`, `icon_120_181.svg`, `icon_120_183.svg`, `icon_144_209.svg`, `icon_145_316.svg`, `icon_145_323.svg`, `icon_149_153.svg`, `icon_149_203.svg`, `icon_149_208.svg`, `icon_178_392.svg`, `icon_178_404.svg`, `icon_178_415.svg`, `icon_178_426.svg`, `icon_178_437.svg`, `icon_182_207.svg`, `icon_182_211.svg`, `icon_182_226.svg`, `icon_59_100.svg`, `icon_59_105.svg`, `icon_59_112.svg`, `icon_59_123.svg`, `icon_59_127.svg`, `icon_59_131.svg`, `icon_59_139.svg`, `icon_59_146.svg`, `icon_59_15.svg`, `icon_59_205.svg`, `icon_59_209.svg`, `icon_59_213.svg`, `icon_59_224.svg`, `icon_59_231.svg`, `icon_59_69.svg`, `icon_59_73.svg`, `icon_59_78.svg`, `icon_59_85.svg`, `icon_59_92.svg`, `icon_59_96.svg`, `icon_63_261.svg`, `icon_64_263.svg`, `icon_64_265.svg`, `icon_73_11.svg`, `icon_73_15.svg`, `icon_73_20.svg`, `icon_73_27.svg`, `icon_73_7.svg`, `icon_98_197.svg` (actually used — see above), `icon_I73_1137_52515_33125.svg`, `icon_I73_1137_52515_33150.svg`, `icon_I73_1137_52515_33158.svg`, `icon_I73_1137_52515_33166.svg`, `icon_I73_1137_52515_33168.svg`, `icon_I73_1137_52515_33171.svg`, `icon_I73_1137_52555_25530.svg`, `icon_I73_1137_52555_25711.svg`

> To regenerate: `ls assets/runtime/*.svg | xargs -n1 basename | sort > /tmp/all; grep -rh "icon_" lib/ --include="*.dart" | grep -o "icon_[^\"]*\.svg" | sort -u > /tmp/used; comm -23 /tmp/all /tmp/used`

## Adding a new asset

1. Export from Figma into `assets/runtime/` with the `icon_<frame>_<node>.svg` naming.
2. Add a named constant to `FigmaAssets` (one line).
3. Use it only through `FigmaSvg` so dark-mode tinting stays consistent.
4. Update the orphan list above.

## Removal

Orphans can be deleted in a single cleanup PR once design locks — no code references to update.
