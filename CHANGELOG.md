# Changelog

## Unreleased

- `Resources/` is now `resources/`: only the folders SwiftPM expects (`Sources/`, `Tests/`) are capitalised.
- The dropdown is shorter: the readings, then a *Settings* submenu (Edit Settings…, Reload Settings, Open at Login, the source and settings row) and a *Help* submenu (Documentation (README on GitHub), About PowerBar), then Quit. An error shows as its own row under the readings.
- Settings are picked up as soon as you save the file; *Reload Settings* is gone. PowerBar creates `~/.config/powerbar` at startup so it can watch it.
- About shows the commit the app was built from, e.g. *Version 0.5.0 (e972f45)*; `CFBundleVersion` is the commit count.

## 0.5.0 — 2026-10-25

- PowerBar is now only the native app. The SwiftBar plugin, its installer, the `powerbar` command and the Raycast script are removed; the last version is under the `v0.4.0` tag.
- The Swift package moved to the repo root (`swift test`, `scripts/build.sh`); `config.example` moved to `Resources/`.
- Every release has a ready-made `PowerBar.zip`, built by GitHub Actions from the tag, with checksum and build provenance.
- About shows the version once, without the build number in parentheses.
- Settings keys, ranges and parsing live in one table (`Settings.keys`); the `Sample` type from the multi-source days is gone.

## 0.4.0 — 2026-10-25

- App: the number now shows right after launch, wake and *Reload Settings*. Before, it stayed at `?W` until the power changed a lot.
- App and plugin: settings outside a sane range are ignored. Before, e.g. `JUMP_N = 0` or a huge `WIDTH` could crash the app.
- App: *Documentation* and *About PowerBar* in the dropdown. The plugin has *Documentation* too.
- App: signed with the hardened runtime.
- App: code split into one concern per file, with the menu texts in the tested core.
- Docs: README rewritten (app vs. plugin, security and privacy), CI added.

## 0.3.0 — 2026-10-25

- App reads `PSTR` straight from the SMC; no macmon needed.

## 0.2.0 — 2026-10-25

- Native menu bar app (PowerBar.app), bolt icon, `MAX_W` filter for bogus readings.

## 0.1.0 — 2026-10-18

- SwiftBar plugin, installer and the `powerbar` command.
