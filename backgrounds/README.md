# lvsk-calendar Backgrounds

This directory contains the builtin background illustrations for lvsk-calendar.

**Note:** These files are automatically copied to `~/.config/lvsk-calendar/backgrounds/` on first run. Users should edit the files in their config directory, not these source files.

## Available Backgrounds

- **orbital.sh** - Cosmic/orbital design with stars and circles (default)
- **minimal.sh** - Simple dots pattern for a clean look
- **stars.sh** - Starry night design
- **none.sh** - No background decoration

## Creating Custom Backgrounds

You can create your own background illustrations!

### Quick Start

All backgrounds are in your config directory after first run.

1. Copy an existing background:
```bash
cp ~/.config/lvsk-calendar/backgrounds/orbital.sh ~/.config/lvsk-calendar/backgrounds/custom.sh
```

2. Edit your background:
```bash
nano ~/.config/lvsk-calendar/backgrounds/custom.sh
```

3. Configure lvsk-calendar to use it:
```bash
# In ~/.config/lvsk-calendar/config.sh
BACKGROUND_STYLE="custom"
```

### Background File Structure

Every background file must define a `draw_custom_background()` function:

```bash
#!/bin/bash

# Your Background Name
# Description of your background

draw_custom_background() {
    printf "${COLORS[SUBTLE]}${COLORS[DIM]}%s${COLORS[RESET]}" \
"
Your ASCII art goes here
Line by line
"
}
```

### Tips

1. **Use available colors**:
   - `${COLORS[SUBTLE]}` - For subtle elements
   - `${COLORS[DIM]}` - For dimmed elements
   - `${COLORS[RESET]}` - Always end with this!
   - Backgrounds should adapt to the user's color scheme

2. **Unicode characters you can use**:
   - Stars: `✧ ✦ ★ ☆ ∗`
   - Circles: `○ ◦ ● ◉ ∘`
   - Dots: `· ˙ ‧ ∙`
   - Others: `◆ ◇ ▪ ▫ ■ □`

3. **Dimensions**:
   - Keep height around 30 lines
   - Width can vary but ~70-80 characters works well
   - Remember: calendar UI renders on top

4. **Testing**:
   - Test with different terminal sizes
   - Test with different color schemes
   - Run `lvsk-calendar` to see your changes

### Examples

**Simple gradient of dots:**
```bash
draw_custom_background() {
    printf "${COLORS[SUBTLE]}${COLORS[DIM]}%s${COLORS[RESET]}" \
"
         ·  ·  ·

           ·    ·    ·

              ·     ·     ·

                 ·      ·      ·
"
}
```

**Geometric pattern:**
```bash
draw_custom_background() {
    printf "${COLORS[SUBTLE]}${COLORS[DIM]}%s${COLORS[RESET]}" \
"
      ◆           ◆           ◆

         ◇     ◇     ◇     ◇

            ◆     ◆     ◆

         ◇     ◇     ◇     ◇

      ◆           ◆           ◆
"
}
```

## Contributing

If you create a beautiful background that you think others would enjoy, consider contributing it to the project!

1. Fork the repository
2. Add your background to this directory
3. Update this README
4. Submit a pull request

## License

All backgrounds in this directory are part of lvsk-calendar and share the same MIT license.
