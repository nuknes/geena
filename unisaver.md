# UniMatrix Pseudo-Screensaver for Caelestia

A Matrix digital rain screensaver that **dynamically matches your wallpaper's color scheme**. Works as an automatic idle screensaver and a manual toggle keybind on Arch Linux + Caelestia (Hyprland + Quickshell).

## What You'll Get

- Matrix rain in a floating, semi-transparent foot terminal window
- Colors that shift with your Caelestia dynamic scheme (Material You extraction)
- Auto-triggers on idle, auto-closes on unlock
- Manual toggle via `SUPER + U`
- No focus stealing, no bar reveals, no visual clutter

## Prerequisites

- Arch Linux with Caelestia dots installed and working
- Hyprland as your compositor
- An AUR helper (paru, yay, etc.)

### Default Terminal & Shell

Caelestia ships with **foot** as the default terminal and **fish** as the default shell. The commands in this guide assume you're using foot. If you've changed your terminal to something else (kitty, alacritty, wezterm, etc.), you'll need to:

- Replace `foot --app-id=unimatrix-screen` with your terminal's equivalent flag for setting a custom app-id/class:
  - **Kitty:** `kitty --class unimatrix-screen`
  - **Alacritty:** `alacritty -o window.class=unimatrix-screen`
  - **WezTerm:** `wezterm start --config-overrides 'window_class="unimatrix-screen"'`
- Replace `pkill -f 'foot --app-id=unimatrix-screen'` with a matching pattern for your terminal

The `sh -c '...'` wrapper (rather than relying on fish) is intentional, it works regardless of which shell you've set as your default, since we're invoking a POSIX shell explicitly.

## Step 1: Install UniMatrix

```bash
paru -S unimatrix-git
```

That's it. It's a single Python script, no extra dependencies beyond Python (which you already have).

## Step 2: Override Caelestia's Default Foot Opaque Rule

Caelestia's default Hyprland rules force foot windows to be fully opaque. This means our `opacity = "0.75 override"` on the unimatrix window rule would be ignored and the window stays solid regardless.

To fix this, add the following to `~/.config/caelestia/hypr-user.lua`:

```lua
hl.window_rule({
    match = { class = "^unimatrix-screen$" },
    opaque = 0,
})
```

**Why this is needed:** Caelestia's rules apply an `opaque` rule to all foot-class windows, which forces the compositor to treat them as fully opaque thus overriding any `opacity` value you set on a more specific rule. The `opaque = 0` in `hypr-user.lua` (which loads *after* the default rules) un-forces this, allowing the `opacity` on our `unimatrix-screen` rule to take effect.

**Why scoped to `unimatrix-screen` only:** This targets just the screensaver window, leaving your regular foot terminals fully opaque and unaffected.

## Step 3: Add the Hyprland Window Rule

In `~/.config/caelestia/hypr-user.lua` (same file as Step 2), add:

```lua
hl.window_rule({
    name = "unimatrix-fullscreen",
    match = {
        class = "^unimatrix-screen$"
    },
    float = true,
    center = true,
    fullscreen = false,
    border_size = 0,
    rounding = false,
    size = "1920 1080",
    opacity = "0.75 override 0.75 override",
    xray = false,
    stay_focused = true
})
```

**Why these values:**

| Field | Purpose |
|-------|---------|
| `float = true` + `size = "1920 1080"` + `center = true` | Pseudo-fullscreen without entering actual fullscreen mode (avoids triggering "show on fullscreen" bar behavior) |
| `opacity = "0.75 override 0.75 override"` | The `override` flag forces the opacity even if the window requests otherwise. Tweak to taste. |
| `stay_focused = true` | Prevents the window from stealing focus or triggering bar reveals on hover |
| `border_size = 0` + `rounding = false` | Clean edges for a screensaver look |

> **Note:** Adjust `size` to match your actual resolution. The `class` field in Hyprland corresponds to the `--app-id` you passed to foot.

## Step 4: Add a Manual Toggle Keybind

In `~/.config/caelestia/hypr-user.lua`:

```lua
hl.bind("SUPER + U", hl.dsp.exec_cmd(
    "sh -c 'hyprctl clients | grep -q \"unimatrix-screen\" && pkill -f \"foot --app-id=unimatrix-screen\" || foot --app-id=unimatrix-screen sh -c \"cat ~/.local/state/caelestia/sequences.txt; exec unimatrix\"'"
))
```

This is a true toggle:
- First press launches unimatrix
- Second press kills it

The same window rule from Step 3 applies automatically since we use the same `--app-id`.

## Step 5: Configure the Idle Timeouts

Edit `~/.config/quickshell/caelestia/shell.json`. Replace your `idle.timeouts` array with:

```json
"timeouts": [
    {
        "timeout": 120,
        "idleAction": ["sh", "-c", "hyprctl clients | grep -q 'unimatrix-screen' || { setsid foot --app-id=unimatrix-screen sh -c 'cat ~/.local/state/caelestia/sequences.txt; exec unimatrix' >/dev/null 2>&1 & sleep 1; }"]
    },
    {
        "timeout": 180,
        "idleAction": "lock",
        "returnAction": ["sh", "-c", "pkill -f 'foot --app-id=unimatrix-screen' 2>/dev/null; true"],
        "inhibitWhenAudio": false,
        "respectInhibitors": true
    },
    {
        "timeout": 240,
        "idleAction": "dpms off",
        "returnAction": "dpms on"
    }
]
```

**Three entries, one purpose each:**

| Entry | Purpose |
|-------|---------|
| 120s | Launch unimatrix in a floating foot terminal, themed via `sequences.txt` |
| 180s | Lock the screen (unimatrix runs invisibly underneath); on unlock, `returnAction` kills unimatrix |
| 240s | Turn off display; on activity, turn it back on |

**Why the lock entry handles cleanup:**

Each entry in the `timeouts` array gets its own independent `IdleMonitor` instance. The lock entry's monitor only transitions when *its* 180s timeout elapses (false→true) and when the user interacts to unlock (true→false). The unimatrix launch at 120s happens *before* this entry's timeout, so it doesn't cause a spurious transition on this monitor. The `returnAction` fires cleanly on unlock — no flicker, no race conditions, no flag files.

**Why `inhibitWhenAudio: false` on the lock entry:**

The top-level `"inhibitWhenAudio": true` would disable the lock during audio playback. We override it per-entry so the screen still locks at 180s even if music/video is playing — a privacy/security choice. The unimatrix entry intentionally inherits the top-level setting so it *won't* start if audio is playing.

**Why `"lock"` as a string (not a shell command):**

Caelestia intercepts the string `"lock"` in QML and sets `lock.lock.locked = true` directly, no shell, no IPC, no CLI. This is the only reliable way to trigger the full Caelestia lock experience (theming, animations, etc.) from an idle action.

**What `sequences.txt` does:**

Caelestia regenerates `~/.local/state/caelestia/sequences.txt` every time your wallpaper or scheme changes. It contains SGR escape codes that remap `term0`–`term15`. By `cat`-ing it into the terminal *before* unimatrix runs, the rain inherits your wallpaper's accent colors instead of the default green.

## How It All Fits Together

```
┌─────────────────────────────────────────────────────────────┐
│  Caelestia Shell (Quickshell)                               │
│                                                             │
│  shell.json idle timeouts (each = independent IdleMonitor)  │
│       │                                                     │
│       ├── 120s: launch foot (app-id=unimatrix-screen)       │
│       │         └── cat sequences.txt → theme terminal      │
│       │         └── exec unimatrix → draw rain              │
│       │                                                     │
│       ├── 180s: "lock" → hyprlock covers the terminal       │
│       │         returnAction: pkill foot → rain gone        │
│       │         (fires on unlock, not on launch)            │
│       │                                                     │
│       └── 240s: dpms off / dpms on                          │
├─────────────────────────────────────────────────────────────┤
│  Hyprland (hypr-user.lua)                                   │
│                                                             │
│  window_rule: opaque=0 (override Caelestia default)         │
│  window_rule: float, center, 1920x1080, 0.75 opacity        │
│  keybind:     SUPER+U  toggle                              │
└─────────────────────────────────────────────────────────────┘
```

## Tips & Tweaks

- **Different opacity:** Change `0.75` in the window rule. Lower = more see-through.
- **Full screen coverage:** Set `size` to your exact resolution, or use `fullscreen = true` if you don't care about bar behavior.
- **Unimatrix flags:** Pass them through: `exec unimatrix -c blue`, `exec unimatrix -w` (single wave), `exec unimatrix -s 95` (speed).
- **No dynamic colors:** Remove the `cat` line if you prefer the classic green rain regardless of wallpaper.
- **Multiple monitors:** The window rule targets one window. For per-monitor rain, you'd need a more complex setup (one foot per output).
- **Adjust timing:** The 120/180/240 values are a sensible default. Bump the lock to 300+ if you want longer unimatrix visibility before the screen locks.

## Uninstall

```bash
pkill -f unimatrix 2>/dev/null
# Remove the three timeout entries from shell.json
# Remove the window rules and keybind from hypr-user.lua
paru -Rns unimatrix-git
```
