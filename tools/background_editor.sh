#!/bin/sh
# Starts the Godot editor with no desktop session, so the godot-mcp plugin
# can drive it from a terminal or over SSH.
#
# It runs sway as a headless Wayland compositor and opens the editor inside
# it. Without a login session there's no access to the GPU's render node, so
# rendering falls back to llvmpipe (software Vulkan): fine for menus and UI
# checks, slow for the 3D dungeon. Screenshots work.
#
# Usage: tools/background_editor.sh [path to godot binary]
# Stop it by killing the two PIDs it prints.

set -e
GODOT="${1:-${GODOT:-godot}}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/godot-headless"
mkdir -p "$WORK"

cat > "$WORK/sway.conf" <<'CONF'
output HEADLESS-1 resolution 1920x1080
xwayland disable
CONF

before="$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$' || true)"
WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WAYLAND_DISPLAY= \
	nohup sway -c "$WORK/sway.conf" > "$WORK/sway.log" 2>&1 &
SWAY_PID=$!

socket=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
	sleep 0.5
	for s in $(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$'); do
		echo "$before" | grep -qx "$s" || socket="$s"
	done
	[ -n "$socket" ] && break
done
if [ -z "$socket" ]; then
	echo "sway didn't come up; see $WORK/sway.log" >&2
	exit 1
fi

WAYLAND_DISPLAY="$socket" DISPLAY= \
	nohup "$GODOT" --editor --path "$PROJECT" --display-driver wayland > "$WORK/editor.log" 2>&1 &
echo "sway PID $SWAY_PID on $socket, editor PID $!. Logs in $WORK."
