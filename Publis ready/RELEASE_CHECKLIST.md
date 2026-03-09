# Release Checklist

## Metadata

- [ ] Confirm `CDM KeyPress` is the final public project name.
- [ ] Confirm `Hera` is the final public author name.
- [ ] Keep the release channel as `Beta` for the first public upload.
- [ ] Verify the Retail `## Interface` value before uploading.

## Package Layout

- [ ] Build a clean release folder named `CDMKeyPress`.
- [ ] Include only:
  - `CDMKeyPress.toc`
  - `CDMKeyPress.lua`
  - `Core/`
  - in-game assets actually loaded by the addon
- [ ] Exclude development-only files and folders:
  - `tasks/`
  - `AGENT.md`
  - `CDMKeyPress v1.0.0 working good/`
  - other addon folders from this workspace
  - project page art not used in-game

## CurseForge Page

- [ ] Upload the project logo PNG as page artwork.
- [ ] Use a short summary that mentions BetterCooldownManager, Blizzard default UI, and Retail.
- [ ] Mark the uploaded file as `Beta`.
- [ ] Do not put `(BETA)` in the project title.

## In-Game Validation

- [ ] `/reload` produces no Lua errors.
- [ ] Minimap button appears correctly.
- [ ] Left click opens the quick menu.
- [ ] Right click triggers a scan.
- [ ] Automatic scan finds supported icons.
- [ ] Manual scan works after login.
- [ ] Press and release visuals behave correctly.
- [ ] Bundled `LibCustomGlow-1.0` loads correctly in-game.
- [ ] Glow type switching works for `Button`, `Pixel`, `Autocast`, and `Proc`.
- [ ] Profile switching still works.
- [ ] BetterCooldownManager path is validated in-game.
- [ ] Blizzard default UI path is validated in-game.

## Release Notes

- [ ] Copy the final changelog into the file notes if needed.
- [ ] Keep the first public description conservative and clearly marked as Beta.
- [ ] Announce only the integrations validated in-game.
