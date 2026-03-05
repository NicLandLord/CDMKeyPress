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

## Ayije-CDM Sync Patch
- [x] Reuse Ayije-style viewer lifecycle hooks (`itemFramePool Acquire/Release`) for scan refresh.
- [x] Reuse Ayije-style mixin hooks (`OnCooldownIDSet`/`OnActiveStateChanged`) for Essential/Utility recache.
- [x] Extend spell extraction candidates with `overrideTooltipSpellID` and `linkedSpellIDs`.
- [x] Keep visual behavior unchanged.

## ElvUI Pattern Integration (press + anti-stuck + glow backend)

### Goal
- Reuse ElvUI patterns without touching scan/matching behavior:
- Pattern 1: flat additive yellow pressed tint while keypress is active.
- Pattern 2: strict release/hide cleanup to prevent stuck pressed/glow artifacts.
- Pattern 3: use `LibCustomGlow` backend when available, with current overlay fallback.

### Plan
- [x] Switch pressed overlay defaults/presets to `WHITE8X8` + additive yellow tint.
- [x] Add hard cleanup on icon `OnHide` to stop press visuals and glow safely.
- [x] Add `LibCustomGlow` detection and runtime `ButtonGlow_Start/Stop` integration.
- [x] Preserve glow options (`alpha`, `brightness`, `color`) and apply them to both backends.
- [x] Keep scan/reload/mapping flow unchanged.

### Verification
- [ ] `/reload` has no Lua error.
- [ ] Auto-scan still reaches tracked CDM frames as before.
- [ ] Press visual no longer shows the center yellow triangle artifact.
- [ ] No stuck pressed/glow after cast, frame recycle, or icon hide/show.
- [ ] With ElvUI loaded, `/cdmkp status` shows `backend=libcustomglow`; without it, `backend=overlay`.

### Review
- Pressed visual now matches ElvUI style (`WHITE8X8`, `ADD`, yellow tint) via config + presets.
- Added `GetCustomGlowLib()` runtime discovery (`LibStub` / global fallback).
- Added `ApplyGlowState(frame)` that routes glow to `LibCustomGlow` when available and otherwise to existing overlay.
- Updated menu/status outputs to show active glow backend.
- Added frame `OnHide` hard-reset path to stop press anim and clear glow state.

## Secret String Taint Fix

### Goal
- Fix the two Lua crashes caused by direct comparisons against WoW "secret string" texture keys.
- Keep scan, mapping, and visuals unchanged.

### Plan
- [x] Identify unsafe texture-key compare path in `IndexFrameTexture`.
- [x] Sanitize texture/name keys into plain Lua strings before storage/indexing.
- [x] Replace direct equality checks with guarded comparisons.
- [ ] Validate in-game that Essential/Utility viewer updates no longer throw.

### Review
- Added `ToPlainString`, `ToNormalizedString`, and `SafeValuesEqual` helpers.
- `NormalizeTextureKey` now strips secret string wrappers before indexing.
- `NormalizeSpellName` and string `ToSpellID` parsing now use the same safe conversion path.
- `IndexFrameTexture` and `IndexFrameName` no longer compare raw runtime values directly.

## Combat Performance Pass

### Goal
- Remove combat stutter without changing scan/mapping/animation behavior.

### Plan
- [x] Compare current rescan flow against lighter patterns used by sibling addons.
- [x] Replace repeated delayed full rescans with a debounced queue.
- [x] Restrict queued rescans to the impacted viewer root when possible.
- [x] Skip redundant reindexing when a frame's spell/name/texture signature is unchanged.
- [ ] Validate in-game that combat smoothness improves and mapping still updates correctly.

### Review
- Added debounced viewer rescan batching instead of one `C_Timer.After + ScanForCDMIcons()` per hook fire.
- Added `RunScanForRoot(root, budget)` so viewer lifecycle hooks rescan only their own root instead of all configured roots.
- `OnCooldownIDSet` / `OnActiveStateChanged` now prefer direct `TrackIconFrame(frame)` updates and only queue a viewer rescan when direct tracking fails.
- Pool `Release` now untracks the released frame directly instead of triggering another scan.
- `TrackIconFrame` now exits early when spellID, spell-name key, and texture key are unchanged.

## Profile Persistence

### Goal
- Save user-adjustable addon settings in a profile-backed SavedVariables store.
- Keep all current scan/animation behavior unchanged.

### Plan
- [x] Add SavedVariables entry in the `.toc`.
- [x] Implement account-wide profile DB with per-character profile mapping.
- [x] Load/apply active profile on addon startup.
- [x] Persist runtime changes from menu/slash setters automatically.
- [x] Add minimal slash commands for profile status/set/reset.
- [ ] Validate in-game that settings persist across `/reload` and relog.

### Review
- Added `CDMKeyPressDB` with `profileKeys` and `profiles`.
- Persisted only runtime user settings (`mode`, `preset`, visual/glow config), not detection internals.
- Added `profile status`, `profile set <name>`, and `profile reset` slash support.
- Status output now includes the active profile name.
- New profiles are initialized from the current live settings, not hard-reset defaults.
- Character/profile binding is refreshed again on `PLAYER_LOGIN` to avoid early-load identity edge cases.
