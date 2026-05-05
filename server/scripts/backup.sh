#!/usr/bin/env bash
#
# backup.sh - safe, regular backup of Minecraft world data

# Creates a tar.gz snapshot of every world directory and overwrites old ones,
# keeping only the N newest. If the server is running, it pauses autosave,
# forces a flush to disk, snapshots, then re-enables autosave (so you don't 
# tar a half-written chunk).

set -euo pipefail

# Override via env vars when calling.

# Server directory.
SERVER_DIR="${SERVER_DIR:-$HOME/my_server}"

# Where backups are saved to, keep default.
BACKUP_DIR="${BACKUP_DIR:-$SERVER_DIR/backups}"

# The tmux session name, must match name in start.sh if you change from default.
TMUX_SESSION="${TMUX_SESSION:-mc}"

# How many world backups to retain at any given moment. 2 is enough for daily backups 
# for playing on a server with friends. Old backups will be overwritten every time
# a new backup is generated.
KEEP="${KEEP:-2}"

# World directory names, Fabric uses these three.
WORLDS=("world" "world_nether" "world_the_end")

mkdir -p "$BACKUP_DIR"
cd "$SERVER_DIR"

# Timestamped name for backup, auto-sorts by date
TS="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BACKUP_DIR/world-$TS.tar.gz"

# Check if server is live, if not can just backup immediately
server_running=0
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    server_running=1
fi

mc_cmd() {
    tmux send-keys -t "$TMUX_SESSION" "$1" Enter
}

cleanup() {
    if [[ $server_running -eq 1 ]]; then
        mc_cmd "save-on" || true
        mc_cmd "say Backup complete." || true
    fi
}
trap cleanup EXIT

if [[ $server_running -eq 1 ]]; then
    mc_cmd "say Backup starting — autosave paused."
    mc_cmd "save-off"
    mc_cmd "save-all flush"
    
    sleep 10
else
    echo "tmux session '$TMUX_SESSION' not running — taking cold backup."
fi

# Only tar world dirs that actually exist (the Nether and End may not have been
# explored yet).
EXISTING_WORLDS=()
for w in "${WORLDS[@]}"; do
    [[ -d "$SERVER_DIR/$w" ]] && EXISTING_WORLDS+=("$w")
done

if [[ ${#EXISTING_WORLDS[@]} -eq 0 ]]; then
    echo "No world directories found in $SERVER_DIR — nothing to back up." >&2
    exit 1
fi

tar -czf "$ARCHIVE" -C "$SERVER_DIR" "${EXISTING_WORLDS[@]}"

echo "Backup written: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

# Delete old snapshots
mapfile -t old < <(ls -1t "$BACKUP_DIR"/world-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)))
for f in "${old[@]}"; do
    rm -f -- "$f"
    echo "Pruned: $f"
done