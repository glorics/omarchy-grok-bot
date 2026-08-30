# Grok Bot for Omarchy

[![Release](https://img.shields.io/github/v/release/glorics/omarchy-grok-bot)](https://github.com/glorics/omarchy-grok-bot/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

The [x.ai/bot](https://x.ai/bot) face on your Omarchy bar. Launch or focus the **official** Linux client, see whether the window is open, and install a newer AppImage from Cursor's CDN when one lands.

<p align="center">
  <img src="preview.png" alt="Grok Bot panel on Omarchy" width="420">
</p>

<p align="center">
  <img src="docs/bar.png" alt="Grok Bot icon on the Omarchy bar, next to bluetooth and volume" width="280">
</p>

This plugin is desktop chrome around the official client. It is **not** Grok Bot, and it is **not** an xAI or Cursor product.

Plugin id: `glorics.grok-bot`

## Install

Read this repository first. Plugins run unsandboxed inside `omarchy-shell`.

```bash
omarchy plugin add https://github.com/glorics/omarchy-grok-bot.git --enable
```

The widget defaults to the right side of the bar, next to the other system icons. Move it with:

```bash
omarchy bar move glorics.grok-bot --section right
```

You also need the official Linux AppImage (Grok Bot 0.30.0 on the Cursor CDN):

```bash
curl -fLO https://downloads.cursor.com/grokbot/stable/2385d097738b3719cc5ecd9281a107aa106215f1/linux/x64/Grok_Bot_0.30.0.AppImage
chmod +x Grok_Bot_0.30.0.AppImage
mkdir -p ~/Applications
mv Grok_Bot_0.30.0.AppImage ~/Applications/
ln -sfn ~/Applications/Grok_Bot_0.30.0.AppImage ~/Applications/GrokBot-current.AppImage
```

On Omarchy / Hyprland, launch with `--ozone-platform-hint=auto` if the window does not appear.

## What it does

- **Face:** the real x.ai/bot `IconMark` (head path + 25 eye rings from production JS). Head fill is the Omarchy icon color; eyes use the theme background. Moods cycle from the official table — idle, curious, thinking, listening, happy, drowsy, and the rest — instead of looping one glance
- **Orbit:** the official five-bead 3D ellipse from x.ai/bot (radius 52, y-squash 0.42, 0.0017 rad/ms). Bead colors come from the active Omarchy theme (Tokyo Night red/blue/green/yellow/magenta, and the matching keys on every other theme) instead of the x.ai brand palette
- **Clicks:** left opens the panel, right launches or focuses Grok Bot, middle checks Cursor's CDN for a newer Linux AppImage
- **Panel:** connected / window closed, signed in, cloud computer stays on
- **Updates:** same version feed as macOS/Windows. **Update now** downloads the Linux AppImage when a newer one is on the CDN. A desktop notification fires once per new version (also on a six-hour background check)
- **Copy:** while the client is open, the subtitle rotates through product facts — cloud computer, remote control, AI teammates, always on

It does **not** list bots, open chats, or read Electron state beyond the session marker the client already writes.

The unofficial Windows-to-Linux port at [glorics/grok-bot-linux](https://github.com/glorics/grok-bot-linux) is retired.

## Use

| Input | Action |
|---|---|
| Left click / Enter | Open the selected row (Open / Focus by default) |
| Right click | Launch or focus Grok Bot |
| Middle click / `u` | Check Cursor's CDN for a newer Linux AppImage |
| `U` | Download that AppImage when one is newer |
| `r` | Refresh local status |
| `g` | Open [x.ai/bot](https://x.ai/bot) |
| `j` / `k` or arrows | Move between actions |
| Esc | Close |

IPC:

```bash
omarchy-shell glorics.grok-bot toggle
omarchy-shell glorics.grok-bot launch
omarchy-shell glorics.grok-bot refresh
```

## Remove

```bash
omarchy plugin remove glorics.grok-bot
```

That disables the widget and deletes the checkout. Your Grok Bot AppImage in `~/Applications` is left alone.

## Validate from source

```bash
omarchy plugin validate .
python3 status.py | python3 -m json.tool
```

## Layout

| File | Role |
|---|---|
| `manifest.json` | Plugin id, bar-widget, default section right |
| `Panel.qml` | Bar button and keyboard panel |
| `Service.qml` | Status poll and launch |
| `GrokBotIcon.qml` | Theme-colored official mark |
| `status.py` | Reads `~/.grokbot/installed`, the session marker, and Hyprland clients |

## License

MIT for this plugin. Grok Bot belongs to xAI / Cursor.
