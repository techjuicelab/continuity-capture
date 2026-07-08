<p align="center">
  <img src="icon.png" width="180" alt="ContinuityCapture icon">
</p>

<h1 align="center">ContinuityCapture</h1>

<p align="center">
  Fire iPhone/iPad <b>Continuity Camera</b> from a hotkey and save photos &amp; scans straight into a folder.<br>
  <i>No Preview window · no iCloud delay · no resident process · no UI scripting</i>
</p>

<p align="center"><a href="README.ko.md">한국어</a></p>

---

Press a hotkey on your Mac → your iPhone's camera opens → shoot → the JPEG lands
in your macOS screenshot folder (or `~/Desktop`) about a second later,
transferred directly over Apple's peer-to-peer Wi-Fi (AWDL — the same
transport AirDrop uses).

- **Photo** → `IMG_yyyyMMdd_HHmmss.jpg`, **Scan** → `Scan_yyyyMMdd_HHmmss.pdf`
  (multi-page → one PDF), saved into your **macOS screenshot folder** by
  default (`com.apple.screencapture location`, falling back to `~/Desktop`) —
  configurable without rebuilding, see below
- The capture is **also copied to the clipboard** — ⌘V pastes it straight into
  Slack/Notes/KakaoTalk (as image or file attachment) or Finder (as a file).
  One pasteboard item carries both the file reference and raw image/PDF data.
- **Auto-paste into the app you fired the hotkey from**: AI apps and browsers
  (Claude, ChatGPT, Codex, Gemini, Safari, Chrome) get the image pasted via ⌘V;
  terminals and IDEs (Ghostty, Terminal, iTerm2, VS Code, Cursor, …) get the
  escaped *file path* — exactly what CLI agents like Claude Code want. Unknown
  apps get clipboard-only, no keystroke injection. Same behavior as
  [AIShot](https://github.com/techjuicelab/aishot); disable with `--no-paste`.
- Runs **only while invoked** — exits immediately after saving, cancelling, or timing out
- Capturing itself needs **no permissions** (no camera/microphone, no UI
  scripting). The optional auto-paste asks once for Accessibility, and saving
  to a TCC-protected folder (Desktop/Documents/iCloud Drive) may show one
  Files-and-Folders prompt — both degrade gracefully if declined
- Plays *Glass* on save, *Basso* when no device is available

## Install

**Option A — prebuilt app.** Download `ContinuityCapture.app.zip` from
[Releases](https://github.com/techjuicelab/continuity-capture/releases), unzip
into `~/Applications`. Universal binary (Apple Silicon + Intel), macOS 14+
(the headless trigger is verified on macOS 26; on 14/15 run `--self-test`
first and check the log). Browser downloads are quarantined — the app is
ad-hoc signed, so on macOS 14 use right-click → Open once; on macOS 15+
attempt a launch, then approve it under System Settings → Privacy & Security
→ "Open Anyway", or simply:

```sh
xattr -d com.apple.quarantine ~/Applications/ContinuityCapture.app
```

Heads-up: launching the app with no arguments immediately starts a **photo
capture** (there is no window) — your iPhone's camera opening means it works;
a *Basso* beep means no device was found (see Requirements; log:
`/tmp/continuitycapture.log`). That first launch also registers the app with
LaunchServices, which the `open -na ContinuityCapture` command below relies
on. Option B does both automatically.

**Option B — build from source** (requires Xcode Command Line Tools):

```sh
git clone https://github.com/techjuicelab/continuity-capture.git
cd continuity-capture && ./build.sh   # builds, signs, installs to ~/Applications
```

Clone it anywhere — nothing depends on the path or username.

## Usage

```sh
open -na ContinuityCapture --args photo
open -na ContinuityCapture --args scan
```

| Flag | Description | Default |
|---|---|---|
| `photo` / `scan` | take a photo / scan documents | `photo` |
| `--out DIR` | destination folder | screenshot folder → `~/Desktop` |
| `--device HINT` | preferred device name substring (falls back to first available) | `iPhone` |
| `--timeout SEC` | how long to wait for the capture | `300` |
| `--no-clipboard` | save to folder only, don't touch the clipboard | off |
| `--no-paste` | copy to clipboard but never synthesize ⌘V | off |
| `--mode auto\|path\|image` | force what gets pasted (path text vs image data) | `auto` |
| `--self-test` | print the detected device list and exit (fires nothing) | — |

Auto-paste needs a one-time **Accessibility** grant (System Settings → Privacy
& Security → Accessibility → ContinuityCapture); until granted the app prompts
once and gracefully falls back to clipboard-only. Add your own paste targets
without rebuilding:

```sh
defaults write com.techjuicelab.continuitycapture extraPathApps  -array-add "com.example.terminal"
defaults write com.techjuicelab.continuitycapture extraImageApps -array-add "com.example.chatapp"
```

Set a permanent destination folder without rebuilding (survives updates;
priority: `--out` flag > this setting > screenshot folder > `~/Desktop`):

```sh
defaults write com.techjuicelab.continuitycapture outDir "~/Documents/Scans"
```

Log: `/tmp/continuitycapture.log`

## Hotkey

Pick whichever launcher you already use — both point at the same
`open -na ContinuityCapture` command, so latency is dominated by Continuity
Camera's own device handshake (~1–2 s), not the launcher.

### Alfred (lowest latency — requires the paid Powerpack)

A prebuilt workflow lives in [`alfred/ContinuityCapture.alfredworkflow`](alfred/ContinuityCapture.alfredworkflow).
No Powerpack? Use Shortcuts or Raycast below instead.

1. **Double-click** the `.alfredworkflow` file → **Import**.
2. Alfred strips hotkeys on import (to avoid clashes). Double-click the top
   **Hotkey** node, click its field, and press your combo — e.g. **⌥⌘P**. Do
   the same for the lower Hotkey node if you want scan (e.g. **⌥⌘S**).
3. Done. Press the hotkey from any app; your iPhone's camera opens.

No hotkey needed to try it: open Alfred and type `photo` (or `scan`) — the
keyword triggers are already wired.

### Shortcuts.app

Import the two signed shortcuts in [`shortcuts/`](shortcuts/) (double-click →
Add), enable *Settings → Advanced → Allow Running Scripts* in the Shortcuts
app, then assign a keyboard shortcut in each shortcut's info panel. Also
runnable from Spotlight/Siri by name. (Slightly higher key-to-launch latency
than Alfred, since it routes through the Shortcuts runtime.)

### Karabiner-Elements

If you already run [Karabiner-Elements](https://karabiner-elements.pqrs.org),
[`karabiner/continuitycapture.json`](karabiner/continuitycapture.json) provides
two ready-made rules (⌥⌘P photo, ⌥⌘S scan). Copy it into
`~/.config/karabiner/assets/complex_modifications/`, then enable the rules in
Karabiner-Elements → Complex Modifications → **Add predefined rule**. Karabiner
grabs the key at the HID level, so it works even when no launcher is running.

### Raycast / others

Bind a *Run Shell Script* command to `open -na ContinuityCapture --args photo`.

## How it works

Apple documents a magic menu item, [`NSMenuItem.importFromDeviceIdentifier`](https://developer.apple.com/documentation/appkit/supporting-continuity-camera-in-your-mac-app):
put it in your app's main menu and the system attaches the per-device
Take Photo / Scan Documents submenu. ContinuityCapture discovered that on
modern macOS this submenu can be populated **headlessly** — `submenu.update()`
fills in the devices without the menu ever being displayed — after which
`performActionForItem` fires the system action (`importFromDevice:` on
`SidecarMenuController`). The capture arrives as an attachment in a hidden
NSTextView and is written to disk as-is (JPEG passthrough; HEIC converted to
JPEG; scans arrive as PDF).

Notes for fellow tinkerers, measured on macOS 26:
- The context-menu plugin route (`allowsContextMenuPlugIns`, used by older
  menu-bar utilities) no longer injects Continuity Camera items for
  third-party apps — the main-menu identifier route is the one that works.
- Custom App Shortcuts (`NSUserKeyEquivalents`) can't trigger these items:
  they're created lazily when the menu opens, so the key equivalent never fires.
- Requirements are the standard Continuity Camera ones: same Apple ID on both
  devices, Bluetooth + Wi-Fi on, iPhone unlocked and nearby.

## License

[MIT](LICENSE)

