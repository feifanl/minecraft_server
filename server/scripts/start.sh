#!/usr/bin/env bash
#
# start.sh - launch Fabric Minecraft server inside tmux session

# Boots up a Fabric Minecraft server in a detached tmux session so it keeps
# running even when not ssh-ed or terminal crashes.

set -euo pipefail

# Override via env vars when calling.

# Server directory.
SERVER_DIR="${SERVER_DIR:-$HOME/my_server}"

# The Fabric launcher jar produced by the Fabric installer. Filename varies, so
# either change the jar's filename or set JAR=<YOUR_JAR_FILENAME> when running.
JAR="${JAR:-fabric-server-launch.jar}"

# tmux session name. Must match that of backup.sh so I recommend keeping "mc."
TMUX_SESSION="${TMUX_SESSION:-mc}"

# JVM RAM allocation. I would recommend using half of available RAM and capping
# at 10-12G. Allocating more actually might decrease performance, and even 
# large servers like Hermitcraft with massive farms only need ~10 GB.
HEAP="${HEAP:-10G}"

# Path to Java binary. Override if you have multiple JDKs installed
JAVA_BIN="${JAVA_BIN:-java}"

cd "$SERVER_DIR"

# Check if the jar is there, if not output an error message
if [[ ! -f "$JAR" ]]; then
    echo "Server jar not found: $SERVER_DIR/$JAR" >&2
    echo "Run the Fabric installer first, or set JAR=<filename>." >&2
    exit 1
fi

# Don't create a new tmux if there's already one running
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "tmux session '$TMUX_SESSION' already running."
    echo "Attach with: tmux attach -t $TMUX_SESSION"
    exit 0
fi

# Aikar's JVM flags

# "Aikar's flags" are a G1GC tuning profile maintained by the Paper community.
# Don't tweak -- optimizes to Minecraft performance.
# Reference: https://mcflags.emc.gs 
JVM_FLAGS=(
    "-Xms${HEAP}"
    "-Xmx${HEAP}"
    "-XX:+UseG1GC"
    "-XX:+ParallelRefProcEnabled"
    "-XX:MaxGCPauseMillis=200"
    "-XX:+UnlockExperimentalVMOptions"
    "-XX:+DisableExplicitGC"
    "-XX:+AlwaysPreTouch"
    "-XX:G1NewSizePercent=40"
    "-XX:G1MaxNewSizePercent=50"
    "-XX:G1HeapRegionSize=16M"
    "-XX:G1ReservePercent=15"
    "-XX:G1HeapWastePercent=5"
    "-XX:G1MixedGCCountTarget=4"
    "-XX:InitiatingHeapOccupancyPercent=20"
    "-XX:G1MixedGCLiveThresholdPercent=90"
    "-XX:G1RSetUpdatingPauseTimePercent=5"
    "-XX:SurvivorRatio=32"
    "-XX:+PerfDisableSharedMem"
    "-XX:MaxTenuringThreshold=1"
    "-Dusing.aikars.flags=https://mcflags.emc.gs"
    "-Daikars.new.flags=true"
)

CMD=("$JAVA_BIN" "${JVM_FLAGS[@]}" -jar "$JAR" nogui)

# Launch the tmux
tmux new-session -d -s "$TMUX_SESSION" -c "$SERVER_DIR" "${CMD[@]}"

echo "Server started in tmux session '$TMUX_SESSION'."
echo "Attach: tmux attach -t $TMUX_SESSION    Detach: Ctrl-b then d"