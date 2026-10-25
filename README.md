# PowerBar ⚡

Want to know how much power your Mac draws with what you're doing right now? For example, to see how fast you're draining your battery?

Seeing it on screen while you work gives you that insight, as long as it doesn't distract you with graphs or settings.

PowerBar shows your **Mac's total power draw** in the menu bar, calmly, without the number jumping every second. Large changes still show up right away.

```
 7W ⚡
```

- **Calm:** the value is sampled every second and smoothed over about 8 seconds. The number only changes at a difference of at least 1.5 W or 15%.
- **Still alert:** a large jump (≥ 5 W and ≥ 50%) that persists for 3 seconds is shown immediately.
- **Fixed width:** the number uses tabular digits in a fixed-width slot, so the icons to its left never shift. The bolt sits to the right of the number.
- **Source:** the SMC key `PSTR` (total system power). This is the same value as "System Total" in [Stats](https://github.com/exelban/stats). PowerBar reads it directly, with no helper tools and no sudo.

The dropdown shows the smoothed value, the last reading and the peak since start, plus *Settings…*, *Reload Settings*, *Open at Login*, *Documentation*, *About* and *Quit*.

Works on Apple Silicon Macs (M1 and later) with macOS 13 or later.

## Install

PowerBar is built from source. You need Xcode or the Command Line Tools (Swift 5.9+; run `xcode-select --install` if `swift` is missing).

```bash
git clone https://github.com/michielwittkampf/powerbar.git
cd powerbar
scripts/build.sh --install   # builds PowerBar.app, copies it to ~/Applications and starts it
```

Then choose *Open at Login* in the PowerBar menu if you want it to start with your Mac.

- **Update:** `git pull`, then `scripts/build.sh --install` again. Your settings stay.
- **Remove:** turn off *Open at Login*, quit PowerBar, then delete `~/Applications/PowerBar.app` (and `~/.config/powerbar` if you want your settings gone).

There is no ready-made download: an app without a paid, notarized Apple Developer ID signature is blocked by Gatekeeper.

### Coming from the SwiftBar plugin?

Up to version 0.4.0, PowerBar was also a [SwiftBar](https://github.com/swiftbar/SwiftBar) plugin that used [macmon](https://github.com/vladkens/macmon). That plugin is retired. Run `powerbar uninstall` to remove it; your settings file is shared, so it carries over. `brew uninstall macmon` and `brew uninstall --cask swiftbar` remove the tools it used, if nothing else needs them. The plugin's last version is still available under the [v0.4.0 tag](https://github.com/michielwittkampf/powerbar/tree/v0.4.0).

## Settings

Choose *Settings…* in the menu. That opens `~/.config/powerbar/config` (one `KEY = value` per line) and creates it from [`config.example`](Resources/config.example) the first time. After a change, choose *Reload Settings*.

| Setting | Default | Allowed | Meaning |
|---|---|---|---|
| `TAU` | 8 | 0.1–3600 | smoothing in seconds (higher = calmer) |
| `STEP_ABS` / `STEP_REL` | 1.5 / 0.15 | 0–1000 / 0–10 | minimum change before the number updates |
| `JUMP_ABS` / `JUMP_REL` | 5 / 0.5 | 0–1000 / 0–10 | what counts as a large jump that is shown immediately |
| `JUMP_N` | 3 | 1–600 | how many samples a jump must persist |
| `INTERVAL_MS` | 1000 | 100–60000 | sampling interval |
| `WIDTH` | 3 | 1–6 | reserved digit slots |
| `MAX_W` | 500 | 1–100000 | readings above this are ignored. The SMC now and then reports a bogus value of thousands of watts, while no Apple Silicon Mac really draws more than about 300 W. |

Unknown keys, values that aren't plain numbers and values outside the allowed range are ignored; the default is used instead.

## Security and privacy

- **No network, no root.** PowerBar reads one SMC key (`PSTR`) through the `AppleSMC` IOKit service, read-only, as a normal user. It doesn't connect to the internet: only *Documentation* and the link under *About* open this page in your browser.
- **Files it touches:** it reads `~/.config/powerbar/config`. *Settings…* creates that file from the example if it doesn't exist; an existing file is never overwritten. *Open at Login* registers the app with macOS (`SMAppService`); nothing else is installed.
- **Signing:** `scripts/build.sh` signs the app ad hoc, with the hardened runtime. That's fine for an app you build yourself. It has no Developer ID and isn't notarized.

Found a security problem? Please report it privately through [GitHub's security advisories](https://github.com/michielwittkampf/powerbar/security/advisories/new) instead of a public issue.

## Development

```bash
swift test                 # unit tests for the logic (no SMC access needed)
scripts/build.sh           # build/PowerBar.app
swift scripts/make-icon.swift   # regenerate Resources/AppIcon.icns (committed)
```

`Sources/PowerBarCore` holds the logic: settings, smoothing, formatting and the SMC byte layout. It has no AppKit and is unit tested. `Sources/PowerBar` is the AppKit layer, one concern per file. [`CLAUDE.md`](CLAUDE.md) has the design notes and pitfalls; [`CHANGELOG.md`](CHANGELOG.md) lists the changes.

## License

[MIT](LICENSE)
