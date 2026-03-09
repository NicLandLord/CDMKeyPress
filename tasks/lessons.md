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

## 2026-03-07

### 30) Option UIs need width-aware typography before adding richer copy
- Fixed-size rows and cards break quickly once subtitles/descriptions become sentence-length, especially in narrow sidebars and two-column panels.
- Rule: constrain text width, enable wrapping, reduce font sizes for secondary copy, and size control containers around actual text height instead of assuming one-line labels.

## 2026-03-08

### 31) When a settings panel starts accumulating sections, switch to scroll early
- Packing preview, controls, and style selectors into a fixed-height pane forces cramped layouts and pushes users toward icon-heavy grids.
- Rule: once a settings page needs more than one dense column, move it into a right-edge scroll container and simplify selectors into readable vertical rows before adding more visual chrome.

### 32) Shared slider templates need width overrides in narrow panels
- Reusing one fixed slider width across the whole menu caused the Glow panel sliders to bleed past the panel padding even though the surrounding layout was correct.
- Rule: shared controls should accept a local width override whenever they are reused inside narrower containers.

### 33) Removing a tab means removing its whole lifecycle, not only the button
- Hiding a nav entry alone leaves dead page builders and refresh paths behind, which can still fault when the menu refreshes.
- Rule: when deleting a menu tab, remove the nav definition, page construction, refresh references, and stale UI copy in the same pass.

### 34) Menu open state should be explicit, not accidental
- After iterating on tabs, relying on the last selected page or constructor defaults made the menu feel inconsistent on open and hid layout bugs until after a click.
- Rule: if a menu is expected to open on a specific page, reset that page explicitly in the open flow instead of assuming prior state.

### 35) When summary UIs get simpler, delete the stale data path too
- Removing a visible summary field but keeping its refresh assignment leaves dead state plumbing that makes later layout passes harder to reason about.
- Rule: when you remove a visible field from a panel, remove both the widget creation and the refresh/update write in the same patch.

### 36) Tooltip affordances must stay aligned with real click behavior
- Replacing plain click text with custom icons made the minimap tooltip less explicit, and once the labels changed there was a risk of tooltip and click behavior diverging.
- Rule: for action tooltips, prefer explicit text first, and if you change the wording of click hints, verify the click handlers match in the same patch.

### 37) File renames in WoW addons are usually loader changes, not code changes
- Renaming a module file often needs only the physical move plus the `.toc` loader update; missing the `.toc` change is what actually breaks runtime loading.
- Rule: when renaming an addon source file, update the on-disk filename and the `.toc` entry together before looking for deeper code edits.

### 38) When the user corrects an input mapping, update both semantics and labels exactly
- Tooltip copy about left/right click is easy to “fix” in the wrong direction if you focus only on wording instead of the actual action mapping.
- Rule: when the user corrects a button mapping, re-check the real click handler first, then make the tooltip text mirror that exact mapping in the same edit.

### 39) If copy is removed from a header, remove the widget too
- Leaving an empty subtitle region preserves old spacing and makes the header feel oddly padded even though the text is gone.
- Rule: when removing header copy, delete or stop creating the subtitle widget and then re-anchor the remaining title intentionally.

### 40) If a summary section is removed, its refresh writes must disappear too
- Overview-style dashboard sections often look self-contained, but their values are still hydrated centrally during refresh; deleting only the visuals leaves hidden nil references behind.
- Rule: when removing a dashboard block, delete both the widget creation and every refresh assignment that targeted it.

### 41) When simplifying navigation, move the controls before deleting the tab
- Dropping an `Advanced` tab without migrating its controls would hide important tuning options and force a second round of UI work.
- Rule: if a settings tab is being removed, first decide where each control block lands, then switch refresh/navigation once the new host page can fully own those controls.

### 42) If a preview must stay stable, anchor it outside the scroll container
- Keeping a live preview inside the same scroll child as the controls makes it drift away as soon as the settings page gets longer.
- Rule: when a preview should stay visible while options scroll, parent it to the root window and toggle it with page visibility instead of anchoring it inside the scrollable content.
