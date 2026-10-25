# powerbar ⚡

Shows your **Mac's total power draw** in the menu bar, calmly, without the number jumping every second. Large changes still show up right away.

```
 7W ⚡
```

- **Source:** the SMC key `PSTR` (total system power). This is the same value as "System Total" in Stats. Read with [macmon](https://github.com/vladkens/macmon), no sudo needed.
- **Calm:** the value is sampled every second and smoothed over about 8 seconds. The number only changes at a difference of at least 1.5 W or 15%.
- **Still alert:** a large jump (≥ 5 W and ≥ 50%) that persists for 3 seconds is shown immediately.
- **Fixed width:** empty digit slots are padded with figure spaces, so the icons to its left stay in place. The bolt icon sits to the right of the number.
- **Dropdown:** smoothed value, last reading, peak and CPU/GPU/ANE/RAM, plus *Settings…* and *Disable*.

Works on Apple Silicon (M1–M5) and runs on [SwiftBar](https://github.com/swiftbar/SwiftBar).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/michielwittkampf/powerbar/main/install.sh | bash
```

This installs `macmon` and `SwiftBar` via Homebrew (if you don't have them yet), then sets up the plugin and the `powerbar` command. In SwiftBar's settings, enable **Launch at login**.

## On/off and management

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

Your settings live in `~/.config/powerbar/config` and survive an update. See [`config.example`](config.example).

| Setting | Default | Meaning |
|---|---|---|
| `TAU` | 8 | smoothing in seconds (higher = calmer) |
| `STEP_ABS` / `STEP_REL` | 1.5 / 0.15 | minimum change before the number updates |
| `JUMP_ABS` / `JUMP_REL` / `JUMP_N` | 5 / 0.5 / 3 | what counts as a large jump that is shown immediately |
| `INTERVAL_MS` | 1000 | sampling interval |
| `WIDTH` | 3 | reserved digit slots |
| `MAX_W` | 500 | readings above this are ignored. The SMC now and then reports a bogus value of thousands of watts, while no Apple Silicon Mac really draws more than about 300 W. |

> Upgrading from an earlier version? The settings were renamed (`STAP_*` → `STEP_*`, `SPRONG_*` → `JUMP_*`, `BREEDTE` → `WIDTH`); update your config file if you had customised them.

## Native app (experimental)

[`app/`](app) contains a standalone menu bar app, so you no longer need SwiftBar. It shows the same number with the same smoothing, reads the same `~/.config/powerbar/config`, and still uses `macmon` as its data source. Because it uses a fixed status item width and tabular digits, the width never changes, not even by a pixel.

```bash
app/build.sh --install   # builds PowerBar.app, copies it to ~/Applications and starts it
```

This needs Xcode or the Command Line Tools (Swift 5.9+) and macOS 13 or later. The dropdown has *Settings…*, *Reload Settings*, *Open at Login* and *Quit*. Turn off the SwiftBar plugin (`powerbar off`) so you don't get two meters.

## Known limitation

SwiftBar can't reserve a fixed pixel width. In the system font, digits are not all equally wide (a `1` is narrower than an `8`), so the width can vary by a few pixels.

## License

MIT
