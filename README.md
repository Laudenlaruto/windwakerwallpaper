# Wind Waker time wallpaper for macOS

A macOS port of [JayexDesigns/time-changing-wallpaper](https://github.com/JayexDesigns/time-changing-wallpaper), a set of 200 images that follow the time of day. The images are Matt Vince's Wind Waker landscape.

It installs two pieces:

- **Wallpaper:** `timewall`, a small background tool (LaunchAgent `local.timechangingwallpaper`). It sets the image for the current time on every display. It re-applies when you switch Space, connect or remove a display, or wake the Mac, and checks once a minute.
- **Screen saver:** "Wind Waker Time", which shows the same image and fades to the next one as time passes.

The original's sea-sparks animation and audio visualizer are not included.

## Install

Needs the Xcode command line tools (`swiftc`).

```bash
./install.sh
```

The script downloads the images from the upstream repo, or reuses ones already installed. You can also pass an `imgs` folder: `./install.sh path/to/imgs`. Then choose **Wind Waker Time** under *Other* in System Settings › Screen Saver.

Installed files:

- `~/Library/Application Support/TimeChangingWallpaper`: images, `timewall`, `timewall.log`, and a copy of these scripts
- `~/Library/LaunchAgents/local.timechangingwallpaper.plist`
- `~/Library/Screen Savers/Wind Waker Time.saver`

## Uninstall

```bash
~/Library/Application\ Support/TimeChangingWallpaper/uninstall.sh
```

Then pick a new wallpaper and screen saver in System Settings.

## Debugging

```bash
timewall --print            # which image is due now
timewall --at 05:01 --print # 40.jpg (sunrise)
timewall --get              # what each screen currently shows
```

The schedule in `Schedule.swift` matches upstream `script.js`. It uses 199 time slots over the day, image 40 lands at 05:01, and the numbering wraps around midnight.

## Files

| File | What |
| --- | --- |
| `Schedule.swift` | time → image number, shared by both pieces |
| `main.swift` | `timewall` tool and `--watch` mode |
| `Saver.swift` | screen saver view |
| `assets/` | screen saver thumbnails |
| `install.sh` / `uninstall.sh` | install and remove |
