#!/usr/bin/env bash
#
# install.sh - one-time install of helper scripts + shell aliases
#
# Copies scripts/ into $SERVER_DIR/scripts/, makes them executable, and
# appends short aliases to ~/.bashrc so common ops feel native:
#
#   wl add|remove|list <name>    - manage whitelist (offline UUID-aware)
#   op add|remove|list <name>    - manage ops (offline UUID-aware)
#   mc-attach                    - attach to the running server's tmux session
#   mc-start                     - launch the server (no-op if already running)
#   mc-backup                    - take a backup right now
#   mc-stop                      - send 'stop' to the running server console
#
# Idempotent: re-running won't double-append aliases.
#
# USAGE
#   bash <path-to-this-repo>/server/scripts/install.sh
#   # then: source ~/.bashrc   (or open a new shell)

set -euo pipefail

# Override via env vars when calling.
SERVER_DIR="${SERVER_DIR:-$HOME/my_server}"
TMUX_SESSION="${TMUX_SESSION:-mc}"

# Locate this script's directory so we can copy siblings.
SCRIPT_SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

mkdir -p "$SERVER_DIR/scripts"
cp "$SCRIPT_SRC_DIR"/*.sh "$SERVER_DIR/scripts/"
chmod +x "$SERVER_DIR/scripts/"*.sh
echo "Copied scripts -> $SERVER_DIR/scripts/"

MARKER_BEGIN="# >>> minecraft-server aliases >>>"
MARKER_END="# <<< minecraft-server aliases <<<"
BASHRC="$HOME/.bashrc"

# Strip any prior install block so re-running is safe.
if grep -qF "$MARKER_BEGIN" "$BASHRC" 2>/dev/null; then
    sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$BASHRC"
fi

cat >> "$BASHRC" <<EOF
$MARKER_BEGIN
export MC_SERVER_DIR="$SERVER_DIR"
export MC_TMUX_SESSION="$TMUX_SESSION"
alias wl='\$MC_SERVER_DIR/scripts/wl.sh'
alias op='\$MC_SERVER_DIR/scripts/op.sh'
alias mc-attach='tmux attach -t \$MC_TMUX_SESSION'
alias mc-start='\$MC_SERVER_DIR/scripts/start.sh'
alias mc-backup='\$MC_SERVER_DIR/scripts/backup.sh'
alias mc-stop='tmux send-keys -t \$MC_TMUX_SESSION "stop" Enter'
$MARKER_END
EOF

echo "Appended aliases to $BASHRC."
echo
echo "Aliases now available (after 'source ~/.bashrc' or new shell):"
echo "  wl add|remove|list <name>    - manage whitelist"
echo "  op add|remove|list <name>    - manage ops"
echo "  mc-attach                    - attach to server tmux"
echo "  mc-start                     - launch the server"
echo "  mc-backup                    - take a backup now"
echo "  mc-stop                      - send 'stop' to the server console"
