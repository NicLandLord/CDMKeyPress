# CDMKeyPress Lessons

## 2026-03-05

### 1) WoW texture sublevel limits are strict
- `Frame:CreateTexture()` sublevel must stay between `-8` and `7`.
- Do not use arbitrary large sublevels (e.g. `20`) even for overlays.
- Rule: prefer `CreateTexture(nil, "OVERLAY")` without explicit sublevel unless absolutely needed.

### 2) Do not suppress SUCCEEDED unless SENT actually matched
- If `SENT` has zero matched icons, suppressing `SUCCEEDED` hides valid fallback behavior.
- Rule: only suppress `SUCCEEDED` when `SENT` animated at least one frame.

### 3) Slash diagnostics must execute synchronously for reliability
- Deferred slash scan callbacks can hide errors and confuse runtime debugging.
- Rule: run manual scan via direct call + `pcall`, always print tracked count or explicit error.

### 4) Preserve stable base before visual iterations
- Once matching/scan is stable, visual work should layer on top without touching core detection flow.
- Rule: isolate visual presets (`default`/`blizzard`) and apply them via runtime refresh helpers.

### 5) "Feels too light" needs tactile cues, not only alpha
- Increasing alpha alone is often insufficient for "keypress feel".
- Rule: combine brighter pressed tint with a small temporary scale-down on press, then release with short fade-out.

### 6) Texture fallback can leak to unrelated UI elements
- Matching by icon texture may hit non-target frames (e.g., achievement toasts) when textures overlap.
- Rule: keep texture fallback disabled by default; use spellID/name first for precise targeting.

### 7) Press overlay texture choice affects icon shape artifacts
- `UI-Quickslot2` can produce a visible center motif/triangle when used as a persistent pressed tint.
- Rule: for pure pressed tint, use a flat texture (`Interface\\Buttons\\WHITE8X8`) and color it with vertex color.

### 8) Continuous scan loops should be opt-in
- Ticker/event rescans can create noisy logs and unnecessary CPU usage once frame mapping is stable.
- Rule: run startup scan on reload/login, then keep rescans manual unless dynamic icon churn explicitly requires periodic scanning.

### 9) Secret tainted numbers cannot be compared directly
- Some frame-derived numeric values can be "secret tainted" and throw on direct comparisons (`value > 0`).
- Rule: wrap numeric positivity checks in `pcall` before comparing or converting to spell IDs.

### 10) Press release must target the exact pressed frame set
- Recomputing frame matches on release can miss frames and leave a stuck pressed overlay.
- Rule: capture the exact frame set at press time and release those same frames later.

### 11) Table indexing can fail on "secret" keys in WoW runtime
- Accessing Lua tables with some protected/secret values as keys can throw (`table index is secret`).
- Rule: wrap table get/set for runtime-derived keys with `pcall` and skip unsafe key writes instead of crashing.

### 12) Avoid spellID-keyed state for pressed lifecycle
- Using event-derived spell IDs as table keys can fail under protected/secret values and leave stale visual state.
- Rule: keep a single active pressed state object (`activePressedState`) and release by state reference/timeouts.

### 13) For sticky overlay issues, prefer hard reset over fade-out
- Alpha fade-out animations can leave visual residue when event order/frame remap is imperfect.
- Rule: on release, stop animations and force `alpha=0` + scale restore; add global pressed-visual cleanup as safety.

### 14) Startup scan should expose success/failure explicitly
- Silent `pcall` startup scans can fail without user-visible signal and look like "scan not running".
- Rule: startup scan path must print either tracked-count summary or explicit error.

### 15) Delayed addon UIs need finite startup retries
- A single reload scan can happen before dynamic icon pools exist, yielding 0 tracked frames.
- Rule: run a short finite retry window at startup and stop automatically once frames are detected.

### 16) Restore matching first, then constrain false positives
- Disabling fallback matching can break legitimate icon hits when upstream IDs differ.
- Rule: re-enable fallback where needed, then constrain scope with explicit frame-name exclusions.

### 17) CDM-like addons are best scanned by known viewer roots + lifecycle hooks
- Global enumerate scans are brittle when icon pools initialize late or are recycled.
- Rule: prioritize explicit viewer roots and hook viewer lifecycle (`RefreshLayout`, `OnShow`, queue methods) for reliable recache/reindex timing.

### 18) "ActionButton pressed feel" needs layered depress cues
- A single yellow additive overlay feels like glow, not a physical keypress.
- Rule: combine warm pressed tint with inner dark shade and temporary icon darkening, then hard-restore on release.

### 19) SENT->SUCCEEDED instant chains can hide the press effect
- If `PressedMinHoldSeconds` is zero, instant casts can set+release in the same visual frame and look like "no animation".
- Rule: keep a short minimum hold and ensure pressed visual can also activate from `SUCCEEDED` mode.

### 20) CDM/BCDM stacks may hide overlays without explicit top draw layer
- Some icon/frame hierarchies place cooldown/text layers above naive overlays.
- Rule: set pressed overlays to high `OVERLAY` sublevels within allowed range (<=7).

### 21) Lock preferred UX in code when user asks for "only this"
- Leaving optional toggles available after a strong preference request causes accidental regressions.
- Rule: enforce fixed mode/preset in defaults and reject incompatible slash/menu actions explicitly.

### 22) For CDM item recycling, hook mixins + pool events, not only frame scans
- Viewer-only scans miss some identity updates when Blizzard recycles item frames.
- Rule: hook `itemFramePool Acquire/Release` and item mixins (`OnCooldownIDSet`, `OnActiveStateChanged`) to keep frame->spell mapping fresh.

### 23) Separate "pressed tint" from "glow ring" for Blizzard-like keypress feel
- Reusing `UI-Quickslot2` for persistent press tint can introduce center-shape artifacts and weak tactile feedback.
- Rule: use a flat texture (`Interface\\Buttons\\WHITE8X8`) in additive yellow for pressed state, and keep outer glow as a separate backend (`LibCustomGlow` preferred, overlay fallback).

### 24) Secret strings must be normalized before compare or index reuse
- Blizzard viewer data can surface texture identifiers as "secret string" values; direct `==` / `~=` on them can throw.
- Rule: convert runtime strings through a guarded `tostring` normalization step before storing them on frames or comparing them later.

### 25) Helper validation on secret strings must avoid direct empty-string checks
- Even after wrapping `tostring`, the resulting value can still behave as a secret string inside WoW and crash on `value == ""`.
- Rule: validate string presence with guarded operations such as `pcall(string.len, value)` instead of direct string comparisons.

### 26) Parse secret numbers through a plain-string round-trip before numeric checks
- `tonumber(secretValue)` can still leave you with a protected/secret-flavored number that crashes on `> 0`.
- Rule: convert runtime values to a plain string first, then `tonumber` that plain string and only compare the resulting plain Lua number.

### 27) Prefer positive-integer string canonicalization on Blizzard IDs/fileIDs
- Texture fileIDs and spellIDs often end up as numeric identifiers where only "positive integer or nil" matters.
- Rule: canonicalize them to a plain positive integer string first, then convert back only if needed; this avoids fragile direct numeric comparisons on runtime-derived values.

### 28) Viewer lifecycle hooks must batch work in combat
- `OnActiveStateChanged`, `OnCooldownIDSet`, and pool acquire/release can fire in bursts during combat; scheduling a full rescan per callback causes visible stutter.
- Rule: update the touched frame directly first, batch follow-up rescans with a debounce, and scope them to the affected viewer root instead of all roots.

### 29) Persist only user-facing runtime settings, not technical detection config
- Saving the whole addon config makes future refactors brittle and can freeze obsolete detection heuristics into old profiles.
- Rule: profile storage should target user-adjustable runtime options only, while structural scan/detection defaults stay in code.
