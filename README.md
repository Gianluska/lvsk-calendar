# lvsk-calendar

Terminal-based calendar application with minimalist design and monochromatic pastel aesthetics.

## Overview

lvsk-calendar is a lightweight, keyboard-driven calendar interface designed for terminal environments. Built with pure bash, it provides month-view navigation with minimal dependencies.

```


                    ╭──────────────────────────────────────╮
                    │            November 2025             │    ◦
                    ╰──────────────────────────────────────╯◦   ·   ◦
              ·   ·                     ˙                    ·     ·
                        mo   tu   we   th   fr   sa   su ◦ ·         · ◦
                        ──   ──   ──   ──   ──   ──   ──     ·     ·
            ∘   ·   ∘   ˙   ˙      ○         ○      ˙   ˙   ◦   ·   ◦
                          ·    ·    ·    ·    ·   1·   2·       ◦

                         3    4    5    6    7    8·   9·

                        10   11   12   13   14   15·  16·
                                                          ˙           ·
                        17   18   19   20   21   22·  23·

                        24   25   26   27   28   29·  30◆
                               ○     ∘     ∘     ○
                            ○           ∘           ○
              ────────────────────────────────────────────────────
                                        ○                   ○
                 hjkl • nav   [] • month   t • today   q • quit ○
                 ∘· · ·∘                ˙                 ˙   ˙
               ∘ ·     · ∘                            ○ ˙       ˙ ○
                 ∘· · ·∘                                  ˙   ˙
                    ∘                                   ○   ˙   ○
                                                            ○
                      ∗                                   ✧
```

## Features

**Interface**
- Monochromatic color scheme
- Month view with complete week rows
- Visual highlighting for current and selected dates
- Minimal resource footprint

**Navigation**
- Arrow keys or vim-style (hjkl) movement
- Quick return to current date
- Month overflow with keyboard shortcuts

**Integration**
- Hyprland floating window support with auto-configuration
- Automatic centering and optimal window sizing (600x500px)

**Dependencies**
- bash
- coreutils

## Installation

### From AUR

```bash
yay -S lvsk-calendar
```

or

```bash
paru -S lvsk-calendar
```

### Manual Build

```bash
git clone https://github.com/Gianluska/lvsk-calendar.git
cd lvsk-calendar
makepkg -si
```

## Usage

Launch the application:

```bash
lvsk-calendar
```

### Keyboard Controls

| Key | Action |
|-----|--------|
| `↑` `↓` `←` `→` | Navigate dates |
| `h` `j` `k` `l` | Navigate dates (vim-style) |
| `t` | Jump to today |
| `q` | Exit application |

## Integration

### Hyprland

When running in Hyprland, the application automatically:
- Enables floating mode for the calendar window
- Centers the window on screen
- Sets optimal dimensions (600x500 pixels)

No additional configuration required.

### Waybar

Add a custom calendar module to your Waybar configuration:

**~/.config/waybar/config**

```json
{
  "modules-center": [
    "clock",
    "custom/calendar",
    "custom/update",
    "custom/screenrecording-indicator"
  ],

  "custom/calendar": {
    "format": "󰃭 ",
    "on-click": "ghostty -e lvsk-calendar",
    "tooltip-format": "Click to open calendar"
  }
}
```

## License

MIT License. See repository for full license text.
