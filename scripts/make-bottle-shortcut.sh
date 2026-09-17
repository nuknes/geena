#!/usr/bin/env bash

# 18 September 2026 - Bottles Shortcut Manager v.9.4
# Updated to launch games directly via Bottles (no Gamescope).
# Fullscreen handled by Hyprland hypr-user.lua window rules.
# v.9.1: Added option to remove stale game shortcut & icon.
# v.9.2: Confirmation before delete, batch progress counter, input trimming.
# v.9.3: Sync check option, menu reordered (exit last), note reworded.
# v.9.4: Added list all current games option.

LIB_FILE="$HOME/.var/app/com.usebottles.bottles/data/bottles/library.yml"

if [ ! -f "$LIB_FILE" ]; then
    echo "Error: Bottles library.yml not found at expected path: $LIB_FILE"
    exit 1
fi

# Helper: trim leading/trailing whitespace
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Interactive menu if no arguments are provided
if [ -z "$1" ]; then
    echo ""
    echo "========================================================"
    echo "   Bottles Shortcut Manager (Direct Launch)   v.9.4    "
    echo "========================================================"
    echo ""
    echo "1) List all current games from library.yml"
    echo "2) Refresh / Update all games from library.yml"
    echo "3) Create a single game shortcut"
    echo "4) Remove a game shortcut & icon"
    echo "5) Sync check, find missing or stale shortcuts"
    echo "6) Exit without changes"
    echo ""
    echo "Note: For 3 and 4, type the exact game name including space(s), no quotes"
    echo ""
    read -p "Choose an option [1-6]: " CHOICE

    case "$CHOICE" in
        1)
            echo ""
            mapfile -t GAME_LIST < <(python3 -c '
import os
path = os.path.expanduser("~/.var/app/com.usebottles.bottles/data/bottles/library.yml")
games = set()
with open(path, "r") as f:
    for line in f:
        if line.startswith("  name:") and not line.startswith("    "):
            game_name = line.split(":", 1)[1].strip().strip("\"'\''")
            if game_name and game_name != "Play":
                games.add(game_name)
for game in sorted(games):
    print(game)
')
            echo "  ${#GAME_LIST[@]} games found:"
            echo ""
            for game in "${GAME_LIST[@]}"; do
                echo "   • $game"
            done
            echo ""
            exit 0
            ;;
        2)
            echo "Scanning library.yml..."

            mapfile -t GAME_LIST < <(python3 -c '
import os
path = os.path.expanduser("~/.var/app/com.usebottles.bottles/data/bottles/library.yml")
games = set()
with open(path, "r") as f:
    for line in f:
        if line.startswith("  name:") and not line.startswith("    "):
            game_name = line.split(":", 1)[1].strip().strip("\"'\''")
            if game_name and game_name != "Play":
                games.add(game_name)
for game in sorted(games):
    print(game)
')

            TOTAL_GAMES=${#GAME_LIST[@]}

            read -p "Found $TOTAL_GAMES unique games to refresh. Proceed? [Y/n]: " CONFIRM
            CONFIRM="${CONFIRM:-Y}"

            case "$CONFIRM" in
                [Yy]* | [Yy][Ee][Ss])
                    echo -e "\nRefreshing all games..."
                    i=0
                    for game in "${GAME_LIST[@]}"; do
                        i=$((i + 1))
                        echo -e "\n--- [$i/$TOTAL_GAMES] $game ---"
                        "$0" "$game" "Play"
                    done

                    update-desktop-database ~/.local/share/applications/
                    echo -e "\n✔ All $TOTAL_GAMES shortcuts and icon caches successfully refreshed."
                    exit 0
                    ;;
                *)
                    echo "Exiting... No changes were made."
                    exit 0
                    ;;
            esac
            ;;
        3)
            read -p "Enter the exact game name: " GAME_NAME
            GAME_NAME="$(trim "$GAME_NAME")"
            if [ -z "$GAME_NAME" ]; then
                echo "Error: No game name provided."
                exit 1
            fi
            read -p "Enter bottle name [default: Play]: " BOTTLE_INPUT
            BOTTLE_NAME="$(trim "$BOTTLE_INPUT")"
            BOTTLE_NAME="${BOTTLE_NAME:-Play}"
            ;;
        4)
            read -p "Enter the exact game name to remove: " GAME_NAME
            GAME_NAME="$(trim "$GAME_NAME")"
            if [ -z "$GAME_NAME" ]; then
                echo "Error: No game name provided."
                exit 1
            fi

            DESKTOP_HASH=""
            for f in "$HOME"/.local/share/applications/com.usebottles.bottles.App_*.desktop; do
                [ -f "$f" ] || continue
                if grep -q "^Name=🎮 / $GAME_NAME$" "$f"; then
                    DESKTOP_HASH=$(basename "$f" .desktop)
                    break
                fi
            done

            if [ -z "$DESKTOP_HASH" ]; then
                echo "⚠ No shortcut found for '$GAME_NAME'."
                exit 0
            fi

            DESKTOP_FILE="$HOME/.local/share/applications/${DESKTOP_HASH}.desktop"
            ICON_FILE="$HOME/.local/share/xdg-desktop-portal/icons/256x256/${DESKTOP_HASH}.png"

            echo ""
            echo "  Shortcut: $DESKTOP_FILE"
            echo "  Icon:     $ICON_FILE"
            echo ""
            read -p "Remove? [Y/n]: " CONFIRM
            CONFIRM="${CONFIRM:-Y}"
            case "$CONFIRM" in
                [Yy]*)
                    rm -f "$DESKTOP_FILE"
                    echo "✔ Removed shortcut: $DESKTOP_FILE"
                    if [ -f "$ICON_FILE" ]; then
                        rm -f "$ICON_FILE"
                        echo "✔ Removed icon: $ICON_FILE"
                    fi
                    update-desktop-database "$HOME/.local/share/applications/"
                    echo "✔ Desktop database refreshed."
                    ;;
                *)
                    echo "Cancelled. No changes made."
                    ;;
            esac
            exit 0
            ;;
        5)
            echo ""
            echo "Scanning..."

            mapfile -t LIB_GAMES < <(python3 -c '
import os
path = os.path.expanduser("~/.var/app/com.usebottles.bottles/data/bottles/library.yml")
with open(path, "r") as f:
    for line in f:
        if line.startswith("  name:") and not line.startswith("    "):
            n = line.split(":", 1)[1].strip().strip("\"'\''")
            if n and n != "Play":
                print(n)
')

            mapfile -t DESKTOP_GAMES < <(
                for f in "$HOME"/.local/share/applications/com.usebottles.bottles.App_*.desktop; do
                    [ -f "$f" ] || continue
                    name=$(grep "^Name=" "$f" | head -1 | sed 's/^Name=🎮 \/ //')
                    [ -n "$name" ] && echo "$name"
                done
            )

            MISSING=()
            for game in "${LIB_GAMES[@]}"; do
                found=0
                for d in "${DESKTOP_GAMES[@]}"; do
                    [ "$game" = "$d" ] && found=1 && break
                done
                [ $found -eq 0 ] && MISSING+=("$game")
            done

            STALE=()
            for d in "${DESKTOP_GAMES[@]}"; do
                found=0
                for g in "${LIB_GAMES[@]}"; do
                    [ "$d" = "$g" ] && found=1 && break
                done
                [ $found -eq 0 ] && STALE+=("$d")
            done

            if [ ${#MISSING[@]} -eq 0 ] && [ ${#STALE[@]} -eq 0 ]; then
                echo "✔ All shortcuts are in sync. Nothing to do."
                exit 0
            fi

            if [ ${#MISSING[@]} -gt 0 ]; then
                echo ""
                echo "⚠ Missing shortcuts (in library, no .desktop):"
                for g in "${MISSING[@]}"; do
                    echo "   • $g"
                done
            fi

            if [ ${#STALE[@]} -gt 0 ]; then
                echo ""
                echo "⚠ Stale shortcuts (no longer in library):"
                for g in "${STALE[@]}"; do
                    echo "   • $g"
                done
            fi

            echo ""
            if [ ${#MISSING[@]} -gt 0 ]; then
                read -p "Add ${#MISSING[@]} missing shortcut(s)? [Y/n]: " CONFIRM_ADD
                CONFIRM_ADD="${CONFIRM_ADD:-Y}"
                case "$CONFIRM_ADD" in
                    [Yy]*)
                        for g in "${MISSING[@]}"; do
                            "$0" "$g" "Play"
                        done
                        ;;
                esac
            fi

            if [ ${#STALE[@]} -gt 0 ]; then
                read -p "Remove ${#STALE[@]} stale shortcut(s)? [Y/n]: " CONFIRM_DEL
                CONFIRM_DEL="${CONFIRM_DEL:-Y}"
                case "$CONFIRM_DEL" in
                    [Yy]*)
                        for g in "${STALE[@]}"; do
                            for f in "$HOME"/.local/share/applications/com.usebottles.bottles.App_*.desktop; do
                                [ -f "$f" ] || continue
                                if grep -q "^Name=🎮 / $g$" "$f"; then
                                    hash=$(basename "$f" .desktop)
                                    rm -f "$f"
                                    rm -f "$HOME/.local/share/xdg-desktop-portal/icons/256x256/${hash}.png"
                                    echo "  ✔ Removed: $g"
                                fi
                            done
                        done
                        update-desktop-database "$HOME/.local/share/applications/"
                        ;;
                esac
            fi

            echo ""
            echo "✔ Sync check complete."
            exit 0
            ;;
        6)
            echo "Exiting... No changes were made."
            exit 0
            ;;
        *)
            echo "Exiting... No changes were made."
            exit 0
            ;;
    esac
else
    GAME_NAME="$1"
    BOTTLE_NAME="${2:-Play}"
fi   

# Safely extract both the UUID and the explicit icon path from library.yml using Python
PARSED_DATA=$(python3 -c '
import sys, re
try:
    with open(sys.argv[1], "r") as f:
        content = f.read()
    target = sys.argv[2]
    blocks = re.split(r"\n(?=[0-9a-fA-F-]+:)", content)
    for block in blocks:
        if f"name: {target}" in block or f"name: \"{target}\"" in block or f"name: '\''{target}'\''" in block:
            id_m = re.search(r"id:\s*([0-9a-fA-F\-]{36})", block)
            icon_m = re.search(r"icon:\s+(.+?)(?=\n\s+[a-z]+:|\Z)", block, re.DOTALL)

            game_id = id_m.group(1) if id_m else ""
            icon_path = ""
            if icon_m:
                raw_icon = icon_m.group(1)
                icon_path = re.sub(r"\s+", " ", raw_icon).strip().strip("\"'\''")

            if game_id:
                print(f"{game_id}|{icon_path}")
                break
except Exception as e:
    sys.stderr.write(f"Error parsing library file: {e}\n")
' "$LIB_FILE" "$GAME_NAME")

GAME_ID=$(echo "$PARSED_DATA" | cut -d'|' -f1)
EXPLICIT_ICON=$(echo "$PARSED_DATA" | cut -d'|' -f2-)

if [ -z "$GAME_ID" ]; then
    echo "Error: Could not find '$GAME_NAME' in Bottles library.yml."
    exit 1
fi

# Format hash and paths
CLEAN_ID=$(echo "$GAME_ID" | tr -d '-')
DESKTOP_HASH="com.usebottles.bottles.App_${CLEAN_ID}"
APPS_DIR="$HOME/.local/share/applications"
PORTAL_ICON_DIR="$HOME/.local/share/xdg-desktop-portal/icons/256x256"
BOTTLE_ICONS_DIR="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/$BOTTLE_NAME/icons"

mkdir -p "$APPS_DIR"
mkdir -p "$PORTAL_ICON_DIR"

ICON_DEST="$PORTAL_ICON_DIR/${DESKTOP_HASH}.png"

# Use the exact icon path from library.yml if it exists, otherwise fall back gracefully
if [ -n "$EXPLICIT_ICON" ] && [ -f "$EXPLICIT_ICON" ]; then
    cp "$EXPLICIT_ICON" "$ICON_DEST"
    echo "✔ Copied explicit icon from library.yml: $(basename "$EXPLICIT_ICON")"
else
    FALLBACK_ICON="$BOTTLE_ICONS_DIR/Space Invaders Extreme.png"
    if [ -f "$FALLBACK_ICON" ]; then
        cp "$FALLBACK_ICON" "$ICON_DEST"
        echo "✔ No icon found in YAML, Space Invaders icon used as fallback for '$GAME_NAME'."
    else
        touch "$ICON_DEST"
        echo "⚠ Warning: No icon found for '$GAME_NAME' (used empty fallback)."
    fi
fi

# Determine StartupWMClass (lowercased without spaces, appended with .exe)
LOWER_WM_CLASS=$(echo "$GAME_NAME" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

# Generate .desktop file (v.9: Direct Bottles launch, no Gamescope)
DESKTOP_FILE="$APPS_DIR/${DESKTOP_HASH}.desktop"

cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Exec=flatpak run --command=bottles-cli com.usebottles.bottles run -p "$GAME_NAME" -b "$BOTTLE_NAME"
Type=Application
Terminal=false
Categories=Game;
Comment=Launch $GAME_NAME using Bottles
StartupWMClass=${LOWER_WM_CLASS}.exe
Name=🎮 / $GAME_NAME
Icon=$ICON_DEST
TryExec=/var/lib/flatpak/exports/bin/com.usebottles.bottles
X-Flatpak=com.usebottles.bottles
EOF

# Explicitly update the desktop database cache
update-desktop-database "$APPS_DIR"

echo "✔ Successfully generated desktop entry for '$GAME_NAME'."
echo "-> $DESKTOP_FILE"
