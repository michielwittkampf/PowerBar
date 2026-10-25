# PowerBar ⚡

Want to know how much power your Mac draws with what you're doing right now? For example, to see how fast you're draining your battery?

Seeing it on screen while you work gives you that insight, as long as it doesn't distract you with graphs or settings.

PowerBar shows your **Mac's total power draw** in the menu bar, calmly, without the number jumping every second. Large changes still show up right away.

```
 7W ⚡
```

- **Calm:** the value is sampled every second and smoothed over about 8 seconds. The number only changes once the difference is at least 1.5 W and at least 15%.
- **Still alert:** a large jump (≥ 5 W and ≥ 50%) that persists for 3 seconds is shown immediately.
- **Fixed width:** the number uses tabular digits in a fixed-width slot, so the icons to its left never shift. The bolt sits to the right of the number.
- **Source:** the SMC key `PSTR` (total system power). This is the same value as "System Total" in [Stats](https://github.com/exelban/stats). PowerBar reads it directly, with no helper tools and no sudo.

The dropdown keeps it short:

```
Smoothed: 11.8 W
Last reading: 12.1 W
Peak since start: 34.0 W
─────────────
Settings  ▸   Edit Settings…  ⌘,  ·  Open at Login  ·  (source and current settings)
Help      ▸   Documentation (README on GitHub)  ·  About PowerBar
─────────────
Quit PowerBar  ⌘Q
```

If the power can't be read, an error row appears under the readings.

Works on Apple Silicon Macs (M1 and later) with macOS 13 or later.

## Install

1. Download [**PowerBar.zip**](https://github.com/michielwittkampf/powerbar/releases/latest/download/PowerBar.zip) from the [latest release](https://github.com/michielwittkampf/powerbar/releases/latest), open it, and drag **PowerBar** to your Applications folder.
2. Open PowerBar. macOS says *"PowerBar" Not Opened*, because the app isn't notarized by Apple (that needs a paid developer account). Click **Done**.
3. Open **System Settings ▸ Privacy & Security**, scroll down to *"PowerBar" was blocked…* and click **Open Anyway**, then confirm with your password or Touch ID.
4. Open PowerBar again and confirm. From then on it starts like any other app.

Choose *Settings ▸ Open at Login* in the PowerBar menu if you want it to start with your Mac.

- **Update:** download the new release and replace the app. Your settings stay.
- **Remove:** turn off *Settings ▸ Open at Login*, quit PowerBar, then delete PowerBar from Applications (and `~/.config/powerbar` if you want your settings gone).

**Is the download really built from this code?** GitHub Actions builds it from the release tag, and signs a build provenance record. With the [GitHub CLI](https://cli.github.com) you can check that: `gh attestation verify PowerBar.zip -R michielwittkampf/powerbar`. Each release also lists the zip's SHA-256 checksum.

### Build it yourself

If you'd rather not run a downloaded app, build it from source. You need Xcode or the Command Line Tools (Swift 5.9+; run `xcode-select --install` if `swift` is missing). No Gatekeeper steps are needed for an app you build yourself.

```bash
git clone https://github.com/michielwittkampf/powerbar.git
cd powerbar
scripts/build.sh --install   # builds PowerBar.app, copies it to ~/Applications and starts it
```

To update, `git pull` and run `scripts/build.sh --install` again.

## Settings

Choose *Settings ▸ Edit Settings…* in the menu. That opens `~/.config/powerbar/config` (one `KEY = value` per line) and creates it from [`config.example`](Resources/config.example) the first time. PowerBar picks up your changes as soon as you save the file.

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

- **No network, no root.** PowerBar reads one SMC key (`PSTR`) through the `AppleSMC` IOKit service, read-only, as a normal user. It doesn't connect to the internet: only *Help ▸ Documentation* and the link in *Help ▸ About PowerBar* open this page in your browser.
- **Files it touches:** it reads and watches `~/.config/powerbar/config`, and creates the empty folder `~/.config/powerbar` at startup if it doesn't exist. *Edit Settings…* creates that file from the example if it doesn't exist; an existing file is never overwritten. *Open at Login* registers the app with macOS (`SMAppService`); nothing else is installed.
- **Signing:** the app is signed ad hoc, with the hardened runtime. It has no Apple Developer ID and isn't notarized, which is why macOS asks you to allow it once (see *Install*).

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
