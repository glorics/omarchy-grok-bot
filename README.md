# Grok Bot for Omarchy

A bar widget for the **official** Grok Bot Linux client.

This is **not** Grok Bot, and it is **not** an xAI or Cursor product. The
AppImage is the remote control. This plugin is desktop chrome around it:
running state and launch-or-focus.

The unofficial Windows-to-Linux port at
[glorics/grok-bot-linux](https://github.com/glorics/grok-bot-linux) is
retired. Cursor publishes Linux packages on `downloads.cursor.com`.

Plugin id: `glorics.grok-bot`

## What it does

- Bar icon: the real [x.ai/bot](https://x.ai/bot) `IconMark` (head path + 25 eye rings from production JS). Head fill is the Omarchy icon color; eyes use the theme background. The face cycles official moods (idle, curious, thinking, listening, happy, drowsy, …) instead of looping one look.
- Left click: panel · right click: launch or focus · middle click: check Cursor's CDN for a newer Linux AppImage
- Panel shows connected / window closed, whether you are signed in, and that the cloud computer stays on
- Check for updates reads Cursor's official feed (same version as macOS/Windows). If a newer Linux AppImage is on the CDN, **Update now** downloads it. A desktop notification fires once per new version (also on the six-hour background check)
- While the client is open, the subtitle rotates through product facts: cloud computer, remote control, AI teammates, always on

It does **not** list bots, open chats, or read Electron state beyond the
session marker the client already writes.

## Install

Review this repository, then:

```bash
omarchy plugin add https://github.com/glorics/omarchy-grok-bot.git --enable
```

The widget defaults to the right side of the bar. Move it with:

```bash
omarchy bar move glorics.grok-bot --section right
```

You also need the official Linux client:

```bash
curl -fLO https://downloads.cursor.com/grokbot/stable/2385d097738b3719cc5ecd9281a107aa106215f1/linux/x64/Grok_Bot_0.30.0.AppImage
chmod +x Grok_Bot_0.30.0.AppImage
mkdir -p ~/Applications
mv Grok_Bot_0.30.0.AppImage ~/Applications/
ln -sfn ~/Applications/Grok_Bot_0.30.0.AppImage ~/Applications/GrokBot-current.AppImage
```

On Omarchy / Hyprland, launch with `--ozone-platform-hint=auto` if the window
does not appear.

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
| `GrokBotIcon.qml` | Theme-colored round mark |
| `status.py` | Reads `~/.grokbot/installed`, the session marker, and Hyprland clients |

## License

MIT for this plugin. Grok Bot belongs to xAI / Cursor.
