#!/usr/bin/env bash
#
# wl.sh - manage whitelist.json with offline UUIDs
#
# WHY
#   Vanilla `whitelist add <name>` looks up the player's ONLINE Mojang UUID
#   and writes that to whitelist.json. With `online-mode=false`, the server
#   identifies players by OFFLINE UUID (deterministic hash of
#   "OfflinePlayer:<name>"). Mismatch -> player kicked as "not whitelisted."
#   This script writes the correct offline UUID instead, then live-reloads
#   the whitelist via the tmux server console.
#
# USAGE
#   wl add <name>       # whitelist a player
#   wl remove <name>    # remove a player from the whitelist
#   wl list             # print current whitelist

set -euo pipefail

SERVER_DIR="${SERVER_DIR:-$HOME/my_server}"
TMUX_SESSION="${TMUX_SESSION:-mc}"
WL="$SERVER_DIR/whitelist.json"

usage() {
    cat <<EOF
Usage:
  wl add <name>       Whitelist a player (uses offline UUID)
  wl remove <name>    Remove a player from the whitelist
  wl list             Show current whitelist
EOF
    exit 1
}

valid_name() {
    [[ "$1" =~ ^[A-Za-z0-9_]{3,16}$ ]]
}

reload_via_tmux() {
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        tmux send-keys -t "$TMUX_SESSION" "whitelist reload" Enter
        echo "Live-reloaded via tmux session '$TMUX_SESSION'."
    else
        echo "tmux session '$TMUX_SESSION' not running -- changes will load on next server start."
    fi
}

cmd="${1:-}"
case "$cmd" in
    add)
        [[ $# -eq 2 ]] || usage
        name="$2"
        valid_name "$name" || { echo "Invalid name: '$name'" >&2; exit 1; }
        mkdir -p "$SERVER_DIR"
        python3 - "$name" "$WL" <<'PY'
import hashlib, json, os, sys, uuid
name, path = sys.argv[1], sys.argv[2]
md5 = hashlib.md5(("OfflinePlayer:" + name).encode()).digest()
b = bytearray(md5)
b[6] = (b[6] & 0x0f) | 0x30
b[8] = (b[8] & 0x3f) | 0x80
u = str(uuid.UUID(bytes=bytes(b)))
data = []
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except json.JSONDecodeError: data = []
data = [e for e in data if e.get("name", "").lower() != name.lower()]
data.append({"uuid": u, "name": name})
with open(path, "w") as f: json.dump(data, f, indent=2)
print(f"Added: {name} -> {u}")
print(f"whitelist.json now has {len(data)} entries")
PY
        reload_via_tmux
        ;;
    remove|rm)
        [[ $# -eq 2 ]] || usage
        name="$2"
        [[ -f "$WL" ]] || { echo "No whitelist.json yet."; exit 0; }
        python3 - "$name" "$WL" <<'PY'
import json, sys
name, path = sys.argv[1], sys.argv[2]
with open(path) as f: data = json.load(f)
before = len(data)
data = [e for e in data if e.get("name", "").lower() != name.lower()]
with open(path, "w") as f: json.dump(data, f, indent=2)
if len(data) == before:
    print(f"'{name}' was not on the whitelist.")
else:
    print(f"Removed: {name}")
    print(f"whitelist.json now has {len(data)} entries")
PY
        reload_via_tmux
        ;;
    list|ls)
        if [[ -f "$WL" ]]; then
            python3 -c "
import json
with open('$WL') as f: data = json.load(f)
if not data: print('(empty)')
else:
    for e in data: print(f\"  {e['name']:<16} {e['uuid']}\")
"
        else
            echo "(no whitelist.json yet)"
        fi
        ;;
    *)
        usage
        ;;
esac
