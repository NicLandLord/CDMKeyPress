# CDMKeyPress - Current Task

## Goal
- Keep scan/reload behavior untouched and improve only the keypress push animation on CDM icons.

## Plan
- [x] Add a stronger pressed visual stack (warm tint + internal shade + icon darken + slight scale-down).
- [x] Keep release logic strict (`alpha=0`, scale/icon restore) to avoid persistent glow artifacts.
- [x] Update preset values (`default` and `blizzard`) so quick menu toggles still work.
- [x] Keep scan/matching/event architecture unchanged.

## Verification
- [ ] `/reload` loads with no Lua error. (to validate in-game)
- [ ] Auto-scan still tracks CDM icons as before. (to validate in-game)
- [ ] Hold a key bound to a tracked spell: icon looks visibly pressed while held. (to validate in-game)
- [ ] Release key (or cast ends): pressed effect disappears immediately with no stuck glow. (to validate in-game)
- [ ] `/cdmkp preset blizzard` noticeably increases pressed feedback versus `default`. (to validate in-game)

## Review
- Added pressed-shade overlay config and runtime application:
- `PressedShadeTexturePath`, `PressedShadeBlendMode`, `PressedShadeVertexColor`, `PressedShadeAlpha`.
- Added icon darken-on-press config and runtime handling:
- `PressedIconVertexColor` with safe capture/restore of icon vertex color.
- Extended `EnsurePressAnimation()` to build and cache:
- warm pressed overlay, dark shade overlay, and icon texture object reference.
- Updated `ShowPressedTint()` / `HidePressedTint()`:
- apply pressed tint + shade + icon darken + scale while pressed.
- hard restore all pressed visuals on release to prevent sticky state.
- Updated `RefreshTrackedVisuals()`:
- live-refresh shade/icon tint settings when changing presets.
- Updated `blizzard` preset:
- stronger press alpha/shade and deeper scale to feel closer to default action button keypress feedback.
- Follow-up bugfix (animation not visible despite mapping hit):
- Added explicit top draw layers for press textures (`OVERLAY` sublevels `6/7`) to stay visible on CDM/BCDM icon stacks.
- Added short guaranteed hold (`PressedMinHoldSeconds`) so SENT->SUCCEEDED instant casts remain perceptible.
- Added pressed activation path on `SUCCEEDED` matches too, so visual works when mode is `succeeded`.
- User preference lock:
- Locked runtime behavior to `mode=sent` and `preset=default`.
- Updated slash/menu so alternative modes/presets are refused with a clear lock message.

## Release Freeze 1.0
- [x] Set addon version to `1.0` in `.toc`.
- [x] Initialize local git repository.
- [x] Create initial snapshot commit.
- [x] Tag snapshot as `v1.0`.
