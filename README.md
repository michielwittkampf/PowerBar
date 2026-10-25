# PowerBar ⚡

Shows your **Mac's total power draw** in the menu bar, calmly, without the number jumping every second. Large changes still show up right away.

```
 7W ⚡
```

- **Calm:** the value is sampled every second and smoothed over about 8 seconds. The number only changes at a difference of at least 1.5 W or 15%.
- **Still alert:** a large jump (≥ 5 W and ≥ 50%) that persists for 3 seconds is shown immediately.
- **Fixed width:** empty digit slots are padded, so the icons to its left stay in place. The bolt sits to the right of the number.
- **Source:** the SMC key `PSTR` (total system power). This is the same value as "System Total" in [Stats](https://github.com/exelban/stats). No sudo needed.

Works on Apple Silicon Macs (M1 and later). There are two ways to run it. Both show the same number and read the same settings file:

| | **PowerBar.app** (native) | **SwiftBar plugin** |
|---|---|---|
| Needs | macOS 13+ | [SwiftBar](https://github.com/swiftbar/SwiftBar) + [macmon](https://github.com/vladkens/macmon) (installed for you) |
| Width | rigid, never moves | can vary by a few pixels |
| Dropdown | smoothed, last, peak | the same, plus CPU/GPU/ANE/RAM |
| Install | build from source (below) | one-line installer |

Use one or the other, not both, or you get two meters.

## PowerBar.app (native)

A small menu bar app that reads `PSTR` straight from the SMC, so it needs neither SwiftBar nor macmon. It needs Xcode or the Command Line Tools (Swift 5.9+).

```bash
git clone https://github.com/michielwittkampf/powerbar.git
cd powerbar
app/build.sh --install   # builds PowerBar.app, copies it to ~/Applications and starts it
```

The dropdown has *Settings…*, *Reload Settings*, *Open at Login*, *Documentation*, *About* and *Quit*. To update, `git pull` and run `app/build.sh --install` again. To remove it, turn off *Open at Login*, quit it, then delete `~/Applications/PowerBar.app`.

## SwiftBar plugin

```bash
curl -fsSL https://raw.githubusercontent.com/michielwittkampf/powerbar/main/install.sh | bash
```

This installs `macmon` and `SwiftBar` with Homebrew (if you don't have them yet), then sets up the plugin and the `powerbar` command. In SwiftBar's settings, enable **Launch at login**. Prefer to read the script first? Download [`install.sh`](install.sh), look it over, then run `bash install.sh`.

```bash
powerbar toggle     # on ↔ off
powerbar on | off
powerbar status
powerbar config     # open settings, then: powerbar restart
powerbar update     # latest version from GitHub
powerbar uninstall
```

You can also turn it off with *Disable* in the dropdown.

**Raycast:** add the `raycast/` folder from this repo via *Raycast → Extensions → Script Commands → Add Directories*. You can then switch with **Toggle powerbar**, or bind a hotkey to it.

## Settings

Your settings live in `~/.config/powerbar/config` (one `KEY = value` per line) and survive an update. See [`config.example`](config.example). After a change, choose *Reload Settings* (app) or run `powerbar restart` (plugin).

| Setting | Default | Allowed | Meaning |
|---|---|---|---|
| `TAU` | 8 | 0.1–3600 | smoothing in seconds (higher = calmer) |
| `STEP_ABS` / `STEP_REL` | 1.5 / 0.15 | 0–1000 / 0–10 | minimum change before the number updates |
| `JUMP_ABS` / `JUMP_REL` | 5 / 0.5 | 0–1000 / 0–10 | what counts as a large jump that is shown immediately |
| `JUMP_N` | 3 | 1–600 | how many samples a jump must persist |
| `INTERVAL_MS` | 1000 | 100–60000 | sampling interval |
| `WIDTH` | 3 | 1–6 | reserved digit slots |
| `MAX_W` | 500 | 1–100000 | readings above this are ignored. The SMC now and then reports a bogus value of thousands of watts, while no Apple Silicon Mac really draws more than about 300 W. |

Unknown keys, values that aren't numbers and values outside the allowed range are ignored; the default is used instead.

> Upgrading from 0.1? The settings were renamed (`STAP_*` → `STEP_*`, `SPRONG_*` → `JUMP_*`, `BREEDTE` → `WIDTH`); update your config file if you had customised them.

## Security and privacy

- **No network, no root.** PowerBar.app reads one SMC key (`PSTR`) through the `AppleSMC` IOKit service, read-only, as a normal user. It doesn't connect to the internet: only *Documentation* and the link under *About* open this page in your browser. The plugin gets the same value from `macmon`.
- **Files it touches:** both read `~/.config/powerbar/config`. The app's *Settings…* creates that file from the example if it doesn't exist; an existing file is never overwritten.
- **What the installer changes:** it installs macmon and SwiftBar with Homebrew if missing, writes the plugin to your SwiftBar plugin folder (and sets that folder to `~/.swiftbar` only if SwiftBar has none yet), writes the `powerbar` command to Homebrew's `bin`, creates the config file if it doesn't exist, and restarts SwiftBar.
- **Signing:** `app/build.sh` signs the app ad hoc, with the hardened runtime. That's fine for an app you build yourself. It has no Developer ID and isn't notarized.
- **Installer:** `install.sh` and `powerbar update` fetch the latest files from the `main` branch of this repo over HTTPS.

Found a security problem? Please report it privately through [GitHub's security advisories](https://github.com/michielwittkampf/powerbar/security/advisories/new) instead of a public issue.

## Known limitation

SwiftBar can't reserve a fixed pixel width. In the system font, digits are not all equally wide (a `1` is narrower than an `8`), so the plugin's width can vary by a few pixels. The native app doesn't have this problem.

## Development

```bash
swift test --package-path app              # unit tests for the logic (no Mac hardware needed)
shellcheck -S warning install.sh bin/powerbar raycast/*.sh app/build.sh
```

`app/Sources/PowerBarCore` holds the logic (settings, smoothing, formatting, the SMC byte layout) and is tested. `app/Sources/PowerBar` is the AppKit layer. [`CLAUDE.md`](CLAUDE.md) has the design notes. The smoothing exists twice, in `powerbar.py` and in `Smoother.swift`, and a test keeps the two in step.

## License

[MIT](LICENSE)
