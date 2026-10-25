# powerbar — project context for Claude Code

Calmly shows the total system power draw of an Apple Silicon Mac in the menu bar, as a SwiftBar plugin (`powerbar.py`) and as a native app (`app/`). Public repo; UI text and docs are in English. User docs: `README.md`; changes: `CHANGELOG.md`.

## How it works
- `powerbar.py` is a **streamable** SwiftBar plugin (`<swiftbar.type>streamable</swiftbar.type>`). It starts `macmon pipe -i 1000` and reads JSON lines. The source is `sys_power` (SMC key `PSTR`), with `all_power` as fallback.
- Each update is written as `~~~\n` + lines, in a single write with a flush. SwiftBar uses the block after the last `~~~` by default.
- The number is smoothed with an EMA (`TAU`). The number in the menu bar only changes at `max(STEP_ABS, STEP_REL*shown)`. A persistent large jump (`JUMP_*`) is shown immediately. During a possible jump we suppress the normal updates.
- User settings live in `~/.config/powerbar/config` (`KEY=value`). They are read by `load_config()` and only override the keys in `LIMITS`, and only with a value inside that key's range. **`LIMITS` and `Settings.limits` (Swift) must stay identical**, and so must the table in the README. The ranges exist because e.g. `JUMP_N=0` divided by zero and `WIDTH=1e30` crashed the app on `Int(_:)`.

## Hard requirements from the user
- **No other font.** The number uses the default menu bar font, so no `font=` or `size=`.
- **Fixed width** so the icons to the left don't shift. We do this with U+2007 FIGURE SPACE padding up to `WIDTH` digits, plus `trim=false`.
- **Bolt to the right of the number**, inline as `:bolt.fill:` in the title. `sfimage=` always puts the icon on the left (`imagePosition = .imageLeft` in SwiftBar).
- The number must be calm, but substantial changes must show up quickly.

## Pitfalls
- The plugin runs with `/usr/bin/python3` (Python 3.9 on macOS). Use **no backslashes inside f-string expressions** and no 3.10+ syntax.
- SwiftBar splits the title at the first `|` and trims by default. Put `|` directly after the text (`7W :bolt.fill:|`), otherwise the space becomes part of the title.
- SwiftBar may start the plugin without a locale. That's why `sys.stdout.reconfigure(encoding="utf-8")` is there.
- Homebrew may live in `~/.homebrew` (not only `/opt/homebrew`). See `MACMON_CANDIDATES` and use `brew --prefix`.
- On/off goes through the URL scheme: `swiftbar://enableplugin|disableplugin|toggleplugin?name=powerbar`. The state is in `defaults read com.ameba.SwiftBar DisabledPlugins` (id = `powerbar.py`).
- `install.sh` must work from a clone and via `curl | bash`. It must not overwrite an existing SwiftBar `PluginDirectory`.

## Testing
- Plugin: make a fake `macmon` that prints JSON lines with `sys_power`, and point `MACMON_CANDIDATES` at it (on a Mac with Homebrew the real one in `/opt/homebrew` wins over `PATH`). Run the plugin and compare the title lines (`grep "W :" | uniq`).
- Shell scripts: `shellcheck -S warning`. CI (`.github/workflows/ci.yml`) runs the Swift tests, shellcheck and a Python syntax check.

## Native app (`app/`)
- A Swift package. `PowerBarCore` holds everything that doesn't need AppKit or IOKit, and is unit tested: `Settings`, `Sample`, `Smoother` (a 1:1 port of `powerbar.py`), `Format` (title, dropdown texts, the `Project` URLs) and `SMC` (the byte layout of the AppleSMC call and decoding of the value).
- `PowerBar` is the AppKit layer, one concern per file: `AppDelegate` only wires reader → smoother → UI and restarts on wake/reload; `StatusItemController` (title, bolt, fixed width); `MenuController` (dropdown rows and actions); `ConfigFile` (open/create the settings file); `LoginItem` (`SMAppService`); `SMCReader` (the IOKit calls).
- In `restart()`, show `?` **before** `reader.start()`: `start()` delivers its first reading synchronously, and a `show(nil)` after it wiped that number until the next large change.
- **No macmon.** `SMCReader` reads `PSTR` itself through the `AppleSMC` user client (`IOConnectCallStructMethod`, selector 2: key info = 9, read = 5), as a normal user, once per `INTERVAL_MS`. On Apple Silicon `PSTR` is `flt `: a little-endian float32. Verified on an M5 Pro / macOS 27: identical to macmon's `sys_power`. `MAX_W` still filters the occasional bogus PSTR value.
- SMC only gives the total, so the dropdown has no CPU/GPU/ANE/RAM rows (those came from macmon's IOReport reading). Getting them back natively would mean the private IOReport API.
- **Keep the two in sync:** if you change the smoothing logic in `powerbar.py`, port it and update `testMatchesPythonPlugin`. That test replays a fake macmon sequence whose expected titles come from the Python plugin.
- Fixed width: `fixWidth()` measures the widest title (`999W` plus the bolt) once and sets that as the `length`. The font is the menu bar font with tabular digits (`monospacedDigitSystemFont`), so there is no other typeface.
- `swift test --package-path app` runs the tests. `app/build.sh [--install]` makes `app/build/PowerBar.app`: ad-hoc signed with the hardened runtime (SMC reading works under it), `LSUIElement`, `config.example` as a resource. Open at Login uses `SMAppService.mainApp`, which only works from the `.app` bundle.
- The version lives in `app/build.sh` (`VERSION`) and in the `xbar.version` line of `powerbar.py`. Bump both, add a `CHANGELOG.md` entry, and tag `vX.Y.Z`.
- The app icon (`app/Resources/AppIcon.icns`, committed) comes from `swift app/make-icon.swift`: the SF Symbol `bolt.fill` on a rounded square. A font-glyph icon script can't do this, because the SF fonts have no bolt glyph. The icon matters: PowerBar is a login item and must be recognisable in Login Items.

## Known limitation and possible next steps
- In the plugin, digits are proportional in the system font (a `1` is narrower than an `8`), so a few pixels of variation remain. The native app solves this.
- Options for later: a downloadable, notarized PowerBar.app (needs a paid Apple Developer ID), a Homebrew cask for it, or a tap for the plugin.
