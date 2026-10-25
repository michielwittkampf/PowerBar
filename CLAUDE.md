# PowerBar — project context for Claude Code

A native macOS menu bar app that calmly shows the total system power draw of an Apple Silicon Mac. Public repo; UI text and docs are in English. User docs: `README.md`; changes: `CHANGELOG.md`.

## Layout
- A Swift package at the repo root. `swift test` runs the tests; `scripts/build.sh [--install]` makes `build/PowerBar.app` (and with `--install` copies it to `~/Applications` and starts it).
- `Sources/PowerBarCore` holds everything that needs neither AppKit nor IOKit, and is unit tested: `Settings` (config keys, ranges, parsing), `Smoother` (the calm number), `Format` (menu bar title, dropdown texts, the `Project` URLs) and `SMC` (the byte layout of the AppleSMC call and decoding of the value).
- `Sources/PowerBar` is the AppKit layer, one concern per file: `AppDelegate` only wires reader → smoother → UI and restarts on wake/reload; `StatusItemController` (title, bolt, fixed width); `MenuController` (dropdown rows and actions); `ConfigFile` (open/create the settings file); `LoginItem` (`SMAppService`); `SMCReader` (the IOKit calls).
- `Resources/` holds `AppIcon.icns` and `config.example`; `build.sh` copies both into the bundle.

## How it works
- **No helper tools, no root.** `SMCReader` reads the SMC key `PSTR` through the `AppleSMC` user client (`IOConnectCallStructMethod`, selector 2: key info = 9, read = 5), as a normal user, once per `INTERVAL_MS`. On Apple Silicon `PSTR` is `flt `: a little-endian float32. Verified on an M5 Pro / macOS 27: identical to macmon's `sys_power` and Stats' "System Total".
- SMC only gives the total, so there are no CPU/GPU/ANE/RAM rows. Getting those would mean the private IOReport API.
- `Smoother`: an EMA with time constant `TAU`. The shown number only changes at `max(STEP_ABS, STEP_REL*shown)`. A large jump (`JUMP_*`) that persists `JUMP_N` samples is shown immediately; during a possible jump the normal updates are suppressed. `MAX_W` drops the occasional bogus PSTR value (thousands of W) before it reaches the smoother.
- Settings live in `~/.config/powerbar/config` (`KEY = value`). `Settings.keys` is the single table of keys, ranges and setters. Out-of-range values are ignored because e.g. `JUMP_N=0` divided by zero and `WIDTH=1e30` crashed on `Int(_:)`. Hex and other non-decimal notations are rejected too. **The settings table in the README mirrors `Settings.keys`**; keep them in step.

## Hard requirements from the user
- **No other font.** The number uses the menu bar font, with tabular digits (`monospacedDigitSystemFont`), so it is the same typeface.
- **Fixed width** so the icons to the left don't shift: `fixWidth()` measures the widest title (`999W` plus the bolt) once and sets that as the status item `length`; empty digit slots are padded with U+2007 FIGURE SPACE.
- **Bolt to the right of the number** (`imagePosition = .imageTrailing`).
- The number must be calm, but substantial changes must show up quickly.

## Pitfalls
- In `restart()`, show `?` **before** `reader.start()`: `start()` delivers its first reading synchronously, and a `show(nil)` after it wiped that number until the next large change.
- After an SMC error, `restart()` schedules one retry after 60 s as a `DispatchWorkItem`; every `restart()` cancels the pending one, so retries don't pile up.
- Open at Login uses `SMAppService.mainApp`, which only works from the `.app` bundle, not from `swift run`.
- `build.sh` signs ad hoc with the hardened runtime (`--options runtime`); SMC reading works under it. There is no Developer ID, so Gatekeeper stops a downloaded copy on first launch. Tested end to end on macOS 27 with a quarantined copy: the normal *"PowerBar" Not Opened* dialog (not "damaged"), then *Privacy & Security ▸ Open Anyway*, after which the app runs (translocated until it is moved to Applications). The README's install steps rely on that.
- The app icon (`Resources/AppIcon.icns`, committed) comes from `swift scripts/make-icon.swift`: the SF Symbol `bolt.fill` on a rounded square, drawn through AppKit because the SF fonts have no bolt glyph. The icon matters: PowerBar is a login item and must be recognisable in Login Items.

## Releases and CI
- `build.sh` sets `CFBundleVersion` to the commit count (it must be numeric) and the custom key `PowerBarCommit` to the short hash, with `+` for uncommitted changes; About shows that hash. The release workflow checks out with `fetch-depth: 0` so the count is right.
- The version lives in `scripts/build.sh` (`VERSION`). To release: bump it, give the `CHANGELOG.md` entry its date (heading `## X.Y.Z — YYYY-MM-DD`), let CI pass, move `main`, then push tag `vX.Y.Z`. `.github/workflows/release.yml` checks the version, builds, zips, attests and creates the GitHub Release with `PowerBar.zip`, its `.sha256` and the changelog entry as notes. Don't create the release by hand.
- CI (`.github/workflows/ci.yml`) runs on every push: `swift test`, the app build and shellcheck. `main` is only moved (fast-forward) to a commit whose CI run is green; no PRs needed for solo work.

## Possible next steps
- Notarize the download (needs a paid Apple Developer ID), so the Open Anyway step disappears; then a Homebrew cask is possible too.
