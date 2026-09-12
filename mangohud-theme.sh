#!/bin/bash
# ~/.local/bin/mangohud-theme.sh
# Sources MangoHud colors from Caelestia dynamic scheme

SCHEME=~/.local/state/caelestia/scheme.json
MANGOHUD=~/.var/app/com.usebottles.bottles/config/MangoHud/MangoHud.conf

# Extract colors
TEXT=$(jq -r '.colours.text' "$SCHEME")
MAUVE=$(jq -r '.colours.mauve' "$SCHEME")
GREEN=$(jq -r '.colours.green' "$SCHEME")
PINK=$(jq -r '.colours.pink' "$SCHEME")
SKY=$(jq -r '.colours.sky' "$SCHEME")
OUTLINE=$(jq -r '.colours.outline' "$SCHEME")
BACKGROUND=$(jq -r '.colours.background' "$SCHEME")
RED=$(jq -r '.colours.red' "$SCHEME")
YELLOW=$(jq -r '.colours.yellow' "$SCHEME")
TEAL=$(jq -r '.colours.teal' "$SCHEME")

# Fallbacks
TEXT=${TEXT:-FFFFFF}
MAUVE=${MAUVE:-EB5B85}
GREEN=${GREEN:-39F900}
PINK=${PINK:-FFFFFF}
SKY=${SKY:-FFFFFF}
OUTLINE=${OUTLINE:-EB5B85}
BACKGROUND=${BACKGROUND:-0e0e0e}
RED=${RED:-FF0000}
YELLOW=${YELLOW:-FFFF00}
TEAL=${TEAL:-39F900}

# Strip from text_color= to EOF (the color block)
sed -i '/^text_color=/,$d' "$MANGOHUD" 2>/dev/null

# Append new color block
cat >> "$MANGOHUD" <<EOF
text_color=${TEXT}
gpu_color=${MAUVE}
cpu_color=${MAUVE}
vram_color=${PINK}
ram_color=${PINK}
frametime_color=${GREEN}
wine_color=${MAUVE}
engine_color=${MAUVE}
horizontal_separator_color=${OUTLINE}
fps_color=${RED},${YELLOW},${TEAL}
EOF
