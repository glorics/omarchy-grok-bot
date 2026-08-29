# Grok Bot for Omarchy

A bar widget for the [unofficial Grok Bot Linux client](https://github.com/glorics/grok-bot-linux).

This is **not** Grok Bot, and it is **not** an xAI or Cursor product. The
AppImage is the remote control. This plugin is desktop chrome around it:
running state, GitHub updates, and launch-or-focus.

Cursor's in-app updater cannot work on Linux. The Linux launcher checks
GitHub. This widget is the place that fact belongs on Omarchy.

Plugin id: `glorics.grok-bot`

Want a jar of sand instead of the orb? That is
[glorics/omarchy-grok-sand](https://github.com/glorics/omarchy-grok-sand).
Same panel, different face. Enable one:

```bash
omarchy plugin disable glorics.grok-bot
omarchy plugin add https://github.com/glorics/omarchy-grok-sand.git --enable
```

## What it does

- Bar icon for the unofficial Linux client — glossy orb, official-style eyes that glance around and blink while the box is running
- Left click: panel · right click: launch or focus · middle click: check GitHub
- Panel shows running / idle / crashed, installed version, and whether GitHub has a newer AppImage
- **Update now** only appears for the unofficial AppImage (`~/.local/bin/grok-bot --update-only`)
- If Omarchy's own `grok-bot` 0.24.0 package is what you have, the panel says so and points at the newer unofficial build instead of trying to `pacman -S` over it

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

You also need the Linux client:

```bash
# from a grok-bot-linux release
./scripts/install-linux.sh Grok_Bot_0.30.0_x86_64.AppImage
```

## Use

| Input | Action |
|---|---|
| Left click / Enter | Open the selected row (Open / Focus by default) |
| Right click | Launch or focus Grok Bot |
| Middle click / `u` | Check GitHub for a newer AppImage |
| `U` | Run `grok-bot --update-only` (AppImage only) |
| `r` | Refresh status |
| `g` | Open the Linux client repo |
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
| `Service.qml` | Status poll, launch, update |
| `GrokBotIcon.qml` | Theme-colored round mark |
| `status.py` | Reads `~/.grokbot/installed`, the session marker, and Hyprland clients |

## License

MIT for this plugin. Grok Bot belongs to xAI / Cursor.
