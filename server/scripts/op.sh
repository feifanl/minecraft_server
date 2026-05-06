#!/usr/bin/env bash
#
# op.sh - manage ops.json with offline UUIDs
#
# WHY
#   Same offline-UUID issue as the whitelist: vanilla `op <name>` looks up
#   the online Mojang UUID, which never matches the offline UUID the server
#   uses on `online-mode=false`. This script writes the correct offline UUID
#   into ops.json, then live-reloads via the tmux console.
#
# USAGE
#   op add <name> [level]   # default level 4 (full op)
#   op remove <name>
#   op list
#
# Op levels:
#   1 = bypass spawn protection
#   2 = singleplayer cheats
#   3 = ban + multiplayer commands
#   4 = full access including 'stop'

set -euo pipefail

SERVER_DIR="${SERVER_DIR:-$HOME/my_server}"
TMUX_SESSION="${TMUX_SESSION:-mc}"
OPS="$SERVER_DIR/ops.json"

usage() {
    cat <<EOF
Usage:
  op add <name> [level]    Op a player (default level 4)
  op remove <name>         Deop a player
  op list                  Show current ops
EOF
    exit 1
}

valid_name() {
    [[ "$1" =~ ^[A-Za-z0-9_]{3,16}$ ]]
}

reload_via_tmux() {
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        tmux send-keys -t "$TMUX_SESSION" "reload" Enter
        echo "Sent 'reload' to tmux session '$TMUX_SESSION'."
    else
        echo "tmux session '$TMUX_SESSION' not running -- changes will load on next server start."
    fi
}

cmd="${1:-}"
case "$cmd" in
    add)
        [[ $# -ge 2 && $# -le 3 ]] || usage
        name="$2"
        level="${3:-4}"
        valid_name "$name" || { echo "Invalid name: '$name'" >&2; exit 1; }
        [[ "$level" =~ ^[1-4]$ ]] || { echo "Invalid op level: '$level' (must be 1-4)" >&2; exit 1; }
        mkdir -p "$SERVER_DIR"
        python3 - "$name" "$level" "$OPS" <<'PY'
import hashlib, json, os, sys, uuid
name, level, path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
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
data.append({
    "uuid": u, "name": name, "level": level, "bypassesPlayerLimit": False
})
with open(path, "w") as f: json.dump(data, f, indent=2)
print(f"Op'd: {name} (level {level}) -> {u}")
print(f"ops.json now has {len(data)} entries")
PY
        reload_via_tmux
        ;;
    remove|rm|deop)
        [[ $# -eq 2 ]] || usage
        name="$2"
        [[ -f "$OPS" ]] || { echo "No ops.json yet."; exit 0; }
        python3 - "$name" "$OPS" <<'PY'
import json, sys
name, path = sys.argv[1], sys.argv[2]
with open(path) as f: data = json.load(f)
before = len(data)
data = [e for e in data if e.get("name", "").lower() != name.lower()]
with open(path, "w") as f: json.dump(data, f, indent=2)
if len(data) == before:
    print(f"'{name}' was not an op.")
else:
    print(f"Deopped: {name}")
    print(f"ops.json now has {len(data)} entries")
PY
        reload_via_tmux
        ;;
    list|ls)
        if [[ -f "$OPS" ]]; then
            python3 -c "
import json
with open('$OPS') as f: data = json.load(f)
if not data: print('(empty)')
else:
    for e in data: print(f\"  {e['name']:<16} level={e.get('level',4)}  {e['uuid']}\")
"
        else
            echo "(no ops.json yet)"
        fi
        ;;
    *)
        usage
        ;;
esac
