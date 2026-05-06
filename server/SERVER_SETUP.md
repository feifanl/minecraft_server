# Minecraft Server Setup

This is an end-to-end guide to host a Fabric Minecraft server on a free Oracle Cloud ARM VM. It should take about ~45–60 minutes once your account is approved (can take multiple days). 

This guide assumes zero prior cloud or Linux experience.

---

## Contents

1. [Sign up for Oracle Cloud](#1-sign-up-for-oracle-cloud)
2. [Create the VM](#2-create-the-vm)
3. [Reserve a public IP](#3-reserve-a-public-ip)
4. [Open the firewall ports (Oracle VCN layer)](#4-open-the-firewall-ports-oracle-vcn-layer)
5. [SSH into the VM](#5-ssh-into-the-vm)
6. [Open the firewall ports (OS layer)](#6-open-the-firewall-ports-os-layer)
7. [Install dependencies (Java 25 + tools)](#7-install-dependencies-java-25--tools)
8. [Clone this repo and create the server directory](#8-clone-this-repo-and-create-the-server-directory)
9. [Install the server modpack](#9-install-the-server-modpack)
10. [Drop in pre-tuned configs and accept the EULA](#10-drop-in-pre-tuned-configs-and-accept-the-eula)
11. [Install the helper scripts](#11-install-the-helper-scripts)
12. [Boot the server for real](#12-boot-the-server-for-real)
13. [Whitelist players, EasyAuth, op management](#13-whitelist-players-easyauth-op-management)
14. [Schedule daily backups](#14-schedule-daily-backups)
15. [Restoring from a backup](#15-restoring-from-a-backup)
16. [Server scripts reference](#16-server-scripts-reference)
17. [Troubleshooting](#17-troubleshooting)

---

## 1. Sign up for Oracle Cloud

Goal: a Pay-As-You-Go account so you can use the **Always Free** A1.Flex ARM VM. You will *not be charged as long* as you stay under Always Free quotas of 4 OCPUs / 24 GB RAM.

1. Go to <https://www.oracle.com/cloud/free/>.
2. Click **Start for free** -> fill in personal info, email, country.
3. **Home region**: pick the geographically closest one to you. **This cannot be changed later**. If your closest region shows "out of capacity" for ARM later, you'll need a new account.
4. Verify email -> set password -> enter address -> enter mobile number (real one since you'll need to verify with SMS).
5. **Payment**: enter a real credit card. Oracle charges $0 to verify it. They will never auto-charge you unless you explicitly upgrade to PAYG and exceed free limits.
6. Sign agreement -> submit.

**Wait for approval.** Oracle reviews each new account. Approval can take anywhere from instant (rare) to 5–7 days (common, especially for trial -> PAYG upgrade). If it stalls past 3 days, open a chat with Oracle support from the My Oracle Support page; mention you want to be moved to PAYG and they'll usually unblock within 24h. Always Free works on PAYG accounts; the trial credits are separate.

You're done with this step when you can log into <https://cloud.oracle.com> and see the dashboard with no "trial expired" or "pending" banners.

---

## 2. Create the VM

1. In the OCI console, top-left **hamburger menu (☰)** -> **Compute** -> **Instances**.
2. Click **Create instance**.
3. **Name**: `mc-server` (or whatever you want).
4. **Compartment**: leave default (root compartment).
5. **Placement**: pick any availability domain. If one fails with "out of host capacity," try a different one.
6. **Image and shape**:
   - Click **Edit** -> **Change image** -> select **Canonical Ubuntu** -> version **22.04** -> **Select image**.
   - Click **Change shape** -> **Ampere** tab -> select **VM.Standard.A1.Flex** -> set **OCPUs = 4**, **Memory (GB) = 24** -> **Select shape**. (Default is 1/6, you must manually change later).
7. **Networking**:
   - Leave **Create new virtual cloud network** selected. Wizard auto-fills sane names.
   - **Public IPv4 address**: leave **Assign a public IPv4 address** checked.
8. **Add SSH keys**:
   - Recommended: **Generate a key pair for me** -> click **Save private key** AND **Save public key**. Both will download (`ssh-key-YYYY-MM-DD.key` and `ssh-key-YYYY-MM-DD.key.pub`).
   - Save them somewhere stable (e.g. `~/.ssh/oracle/` on Mac/Linux or `C:\Users\<you>\.ssh\oracle\` on Windows). You'll need the **private** key file for SSH.
   - If you already have an SSH key, choose **Upload public key files** or **Paste public keys** instead.
9. **Boot volume**: leave defaults (50 GB).
10. **Initialization script** (cloud-init): leave blank. We do everything manually.
11. **Block volumes**: skip.
12. Click **Create**. Wait ~1 minute for the instance state to go **Provisioning** -> **Running**.

Note the auto-assigned **Public IPv4 address** in the instance details - you'll use it in step 5. We'll swap it for a stable reserved IP next.

---

## 3. Reserve a public IP

The default public IP is **ephemeral** - it gets thrown away whenever you stop the VM. Reserve a permanent one (free under Always Free) so friends don't have to update the server entry every time you reboot.

1. ☰ -> **Networking** -> **IP Management** -> **Reserved Public IPs**.
2. Click **Reserve Public IP Address** -> name it `mc-server-ip` -> make sure region matches your VM's region -> **Reserve**.
3. Open your VM in **Compute -> Instances -> mc-server**.
4. Scroll to **Attached VNICs** -> click the VNIC name (a hyperlink).
5. **Resources** sidebar -> **IPv4 Addresses** -> click `⋮` (kebab menu) on the **Primary IP** row -> **Edit**.
6. **Public IP Type**: switch from **Ephemeral public IP** to **Reserved Public IP**. (If "Reserved" doesn't appear, first switch to **No public IP** -> **Update**, re-open the dialog, then it'll show.)
7. Pick the reserved IP you just made -> **Update**.

The new IP is now permanent. Use it for everything below.

---

## 4. Open the firewall ports (Oracle VCN layer)

Minecraft = TCP `25565`. Simple Voice Chat = UDP `24454`. Oracle blocks both by default at the network layer.

1. ☰ -> **Networking** -> **Virtual Cloud Networks**.
2. Click your VCN (named like `vcn-YYYYMMDD-HHMM`).
3. **Resources** sidebar -> **Security Lists** -> click the **Default Security List**.
4. Click **Add Ingress Rules**, fill in:

   | Field | Value |
   |---|---|
   | Source CIDR | `0.0.0.0/0` |
   | IP Protocol | **TCP** |
   | Destination Port Range | `25565` |
   | Description | `Minecraft` |

5. Click **+ Another Ingress Rule**, add a second:

   | Field | Value |
   |---|---|
   | Source CIDR | `0.0.0.0/0` |
   | IP Protocol | **UDP** |
   | Destination Port Range | `24454` |
   | Description | `Simple Voice Chat` |

6. **Add Ingress Rules** to save.

---

## 5. SSH into the VM

Open a terminal on your **local computer** (Windows PowerShell, macOS Terminal, or Linux shell - all have `ssh` built-in on modern OSes).

```bash
ssh -i <PATH_TO_PRIVATE_KEY> ubuntu@<YOUR_RESERVED_IP>
```

Example (Windows): `ssh -i C:\Users\you\.ssh\oracle\ssh-key-2026-05-04.key ubuntu@123.45.67.89`
Example (macOS/Linux): `ssh -i ~/.ssh/oracle/ssh-key-2026-05-04.key ubuntu@123.45.67.89`

First connect: type `yes` to add the host fingerprint.

**Windows "permissions too open" error:** lock down the key file ACL:
```powershell
icacls C:\Users\you\.ssh\oracle\ssh-key-2026-05-04.key /inheritance:r /grant:r "$($env:USERNAME):R"
```

**macOS/Linux equivalent:**
```bash
chmod 400 ~/.ssh/oracle/ssh-key-2026-05-04.key
```

Once connected your prompt looks like `ubuntu@mc-server:~$`. Everything below runs there.

---

## 6. Open the firewall ports (OS layer)

Oracle's default Ubuntu image ships with an iptables `REJECT all` rule on the INPUT chain. Order matters — first match wins — so ACCEPT rules **must sit above** the REJECT rule. Inserting at position 1 always lands above REJECT regardless of how default rules shift after reboot/persistence.

```bash
sudo apt update
sudo apt install -y iptables-persistent
sudo iptables -I INPUT 1 -m state --state NEW -p tcp --dport 25565 -j ACCEPT
sudo iptables -I INPUT 1 -m state --state NEW -p udp --dport 24454 -j ACCEPT
sudo netfilter-persistent save
```

Verify:
```bash
sudo iptables -L INPUT -nv --line-numbers
```

Expected: ACCEPT rows for `udp dpt:24454` and `tcp dpt:25565` appear **before** the `REJECT all reject-with icmp-host-prohibited` row. If REJECT comes first, the ACCEPT rules are dead code — re-run the inserts above.

Test from the VM that local public IP is reachable on the port (loopback works regardless, public IP test catches firewall ordering bugs):
```bash
sudo apt install -y netcat-openbsd
nc -vz $(curl -s ifconfig.me) 25565   # only meaningful AFTER step 12 when server is running
```

---

## 7. Install dependencies (Java 25 + tools)

Minecraft 1.21+ needs Java 21+. Some Vanilla+ mods (e.g. C2ME's natives-math submodule) need Java 22+. Easiest path: Eclipse Temurin 25 (current LTS) via Adoptium's apt repo.

```bash
sudo apt install -y wget apt-transport-https gpg tmux git
sudo mkdir -p /etc/apt/keyrings
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt update
sudo apt install -y temurin-25-jre
java -version
```

`java -version` output should mention `Temurin-25` or similar `25.0.x`.

---

## 8. Clone this repo and create the server directory

```bash
cd ~
git clone https://github.com/feifanl/minecraft_server minecraft-server
mkdir -p ~/my_server && cd ~/my_server
```

The rest of this guide assumes the server directory is `~/my_server`. If you pick a different name, prefix scripts with `SERVER_DIR=$HOME/your_name` (e.g. `SERVER_DIR=$HOME/foo ~/foo/scripts/start.sh`).

---

## 9. Install the server modpack

This repo ships server modpacks as `.mrpack` files (Modrinth format) under `server/modpacks/`. Every mod is pinned to a Modrinth version + SHA, so reinstalls are reproducible. Unpack with [`mrpack-install`](https://github.com/nothub/mrpack-install) - it pulls the Fabric server launcher, the Minecraft server jar, and every mod in one go.

```bash
# Install mrpack-install (one-time)
wget https://github.com/nothub/mrpack-install/releases/latest/download/mrpack-install-linux-arm64 -O ~/mrpack-install
chmod +x ~/mrpack-install

# Install the server modpack into ~/my_server (note quotes - pack filename has spaces and parens)
cd ~/my_server
~/mrpack-install "$HOME/minecraft-server/server/modpacks/<MODPACK_OF_CHOICE_NAME>.mrpack" --server-dir .
```

`--server-dir .` installs into the current directory; without it, mrpack-install creates a `mc/` subdirectory.

After this step, `~/my_server/` contains `mods/`, `libraries/`, `versions/`, `modpack.json`, and a launcher jar named `fabric-server-mc.<MC_VER>-loader.<LOADER_VER>-launcher.<INSTALLER_VER>.jar`.

---

## 10. Drop in pre-tuned configs and accept the EULA

`mrpack-install` only downloaded files - no `eula.txt` or `world/` exist yet. You need to:
1. Copy in this repo's pre-tuned `server.properties` and EasyAuth config.
2. Boot the launcher once to generate `eula.txt`.
3. Accept the EULA.

```bash
cd ~/my_server

# 1. Pre-tuned configs (online-mode=false for EasyAuth, whitelist enforced, etc.)
cp ~/minecraft-server/server/server.properties ./server.properties
mkdir -p ./config/auth
cp ~/minecraft-server/server/config/auth/config.json ./config/auth/config.json

# 2. First boot - generates eula.txt then exits with "You need to agree to the EULA"
java -Xms10G -Xmx10G -jar fabric-server*.jar nogui

# 3. Accept Mojang's EULA
sed -i 's/eula=false/eula=true/' eula.txt

# 4. (Optional) Edit server properties - motd, max-players, view-distance, difficulty, etc.
nano server.properties
```

Common `server.properties` settings worth tweaking:
- `motd=<text>` - message shown in the multiplayer server list
- `max-players=<n>` - default 10
- `view-distance=<n>` - chunk render distance, default 12
- `simulation-distance=<n>` - chunk tick distance, default 10
- `difficulty=easy|normal|hard`
- `gamemode=survival|creative` - default mode for new players
- `pvp=true|false`
- `spawn-protection=<n>` - radius around spawn ops can build in but normal players can't

**Do not change** `online-mode=false`, `white-list=true`, or `enforce-whitelist=true`. All three required:
- `online-mode=false` - EasyAuth needs this so it can manage auth itself
- `white-list=true` + `enforce-whitelist=true` - gates **who** can connect at all (without it, anyone with the IP can join, run `/register`, and grief inside EasyAuth's protections)

EasyAuth alone isn't enough: it gates actions **after** connection, but doesn't block registration. Whitelist gates connection itself. You need both layers.

**Whitelist + offline-mode UUID gotcha**: see step 13 — `whitelist add <name>` writes online (Mojang) UUIDs, but the server connects players with **offline** UUIDs computed from name. Mismatch -> kicked. Workaround documented in step 13.

After this step, `~/my_server/` looks like:

```
~/my_server/
├── server.properties                                  # main server config
├── eula.txt
├── modpack.json                                       # mrpack-install metadata
├── fabric-server-mc.<MC>-loader.<L>-launcher.<I>.jar  # Fabric launcher
├── EasyAuth/                                          # EasyAuth runtime data (player auth state)
├── config/                                            # per-mod config dirs
│   └── auth/config.json                               # EasyAuth config
├── mods/                                              # mod .jars
├── libraries/                                         # Fabric/Minecraft libs
├── versions/                                          # Minecraft server jar lives here
└── logs/
```

`whitelist.json`, `ops.json`, `banned-*.json`, and `world/` will appear after step 12.

---

## 11. Install the helper scripts

One-shot installer. Copies all helper scripts into `~/my_server/scripts/`, makes them executable, and appends short aliases to `~/.bashrc` so common operations have simple commands.

```bash
bash ~/minecraft-server/server/scripts/install.sh
source ~/.bashrc
```

Aliases now available from any shell:

| Alias | Does |
|---|---|
| `wl add\|remove\|list <name>` | Manage whitelist (offline UUID-aware - see step 13) |
| `op add\|remove\|list <name> [level]` | Manage ops (offline UUID-aware) |
| `mc-attach` | Attach to the server's tmux session (`Ctrl-B D` to detach) |
| `mc-start` | Launch the server in tmux (no-op if already running) |
| `mc-backup` | Take a backup right now |
| `mc-stop` | Send `stop` to the server console |

---

## 12. Boot the server for real

```bash
mc-start
```

The server boots inside a detached tmux session called `mc`. The first run takes 1–3 minutes to generate the world, then logs go quiet. You're done when you see something like `Done (X.Xs)! For help, type "help"`.

**Detach from tmux without killing the server**: press `Ctrl-B` then `D`. 
*The server will keep running even while you're disconnected from SSH*.

**Re-attach later**: `mc-attach`.

**Connect from Minecraft**: in the client, **Multiplayer -> Add Server**, paste your reserved IP. Default port `25565` is fine.

---

## 13. Whitelist players, EasyAuth, op management

**Offline-mode UUID gotcha (applies to both whitelist + ops)**

Vanilla `whitelist add <name>` and `op <name>` look up the player's **online** Mojang UUID and write it to `whitelist.json` / `ops.json`. With `online-mode=false`, the server identifies players by **offline** UUID (deterministic hash of `OfflinePlayer:<name>`). Mismatch -> vanilla command writes the wrong UUID -> player gets kicked or ops don't apply.

Fix: use the `wl` and `op` shell aliases (set up by `install.sh` in step 11). They compute the correct offline UUID, edit the JSON, and live-reload via tmux. Works for both premium and cracked accounts.

```bash
# Whitelist
wl add <PLAYER_NAME>       # add player (offline UUID)
wl remove <PLAYER_NAME     # remove
wl list                    # show all whitelisted

# Ops
op add <PLAYER_NAME>       # op at level 4 (full)
op add <PLAYER_NAME> 2     # op at level 2 (singleplayer cheats only)
op remove <PLAYER_NAME     # deop
op list                    # show all ops
```

Op levels: 1 = bypass spawn protection, 2 = singleplayer cheats, 3 = ban + multiplayer cmds, 4 = full access incl. `stop`. For trusted friends, use 4 (default).

Both commands are live — no server restart needed. The player can connect / use op powers immediately.

**Other server console commands** (run inside `mc-attach`, **no leading slash**):
```
stop                       # gracefully shuts the server down
auth reload                # re-load EasyAuth config after editing it
auth update <player> <pw>  # admin override password
```

**EasyAuth (`/register` and `/login` flow)**

EasyAuth adds a password layer so people can't impersonate whitelisted usernames on `online-mode=false`. Setup is automatic if you followed step 10:
- `easyauth-*.jar` ships in `mods/`
- `online-mode=false` is set in `server.properties`
- `config/auth/config.json` ships with sane defaults:
  - `premiumAutologin: true` - players with real Mojang accounts skip `/login` after registering once
  - `sessionTimeoutTime: 86400` - re-login required every 24 hours
  - `kickTime: 30` - idle non-logged-in players kicked after 30 seconds
  - `enableGlobalPassword: false` - each player picks their own password

Tweak any of these by editing `config/auth/config.json` and running `auth reload` in the server console.

**Player commands** (typed in **chat** in-game, slash required):
```
/register <password> <password>     # claim username, first time only
/login <password>                   # subsequent sessions
/changepassword <old> <new>
/logout
/unregister <password>              # release the username
```

Tell each friend on first join: type `/register <pw> <pw>`. Until they register or log in, they can't move, chat, or break blocks.

---

## 14. Schedule daily backups and reboot on crash

```bash
crontab -e
```

(Pick `nano` if it asks which editor. Add this line, then `Ctrl-O`, `Enter`, `Ctrl-X` to save:)

```
0 6 * * * /home/ubuntu/my_server/scripts/backup.sh >> /home/ubuntu/my_server/backups/backup.log 2>&1
@reboot /home/ubuntu/my_server/scripts/start.sh
```

This runs `backup.sh` at 06:00 UTC every day and reboots the server if the tmux/VM crashes. Adjust the `0 6 * * *` prefix for a different time (`minute hour day-of-month month day-of-week`). Pick an off-peak hour for your group - `save-all flush` stalls the tick loop briefly while writing chunks.

`backup.sh` keeps the newest `KEEP=2` snapshots by default and overwrites older ones. Override with `KEEP=N` env var in the cron line if you want more.

---

## 15. Restoring from a backup

```bash
tmux attach -t mc
# At the server console prompt, type:
stop
# Wait for "Stopping the server", then Ctrl-B then D.

cd ~/my_server
mv world world.broken           # keep the bad world around in case
tar -xzf backups/world-YYYYMMDD-HHMMSS.tar.gz
~/my_server/scripts/start.sh
```

If the Nether or End existed in the backup, the tarball restores `world_nether/` and `world_the_end/` too - rename those out the same way before extracting.

---

## 16. Server scripts reference

Both scripts live in `~/my_server/scripts/` after step 11. Source: [`server/scripts/`](scripts/). Both have inline comments.

| Script | Alias | Purpose |
|---|---|---|
| [`install.sh`](scripts/install.sh) | -- | One-time installer: copies the other scripts into `~/my_server/scripts/`, makes them executable, appends shell aliases to `~/.bashrc`. Idempotent (re-running won't double-append). |
| [`start.sh`](scripts/start.sh) | `mc-start` | Launches the server in a detached tmux session named `mc`, with Aikar's G1GC flags and 10G heap. Auto-detects the Fabric launcher jar (`fabric-server*.jar`). Override `SERVER_DIR`, `JAR`, `HEAP`, `JAVA_BIN`, `TMUX_SESSION` via env vars if needed. |
| [`backup.sh`](scripts/backup.sh) | `mc-backup` | Pauses autosave, flushes chunks, tar.gz's `world/` + `world_nether/` + `world_the_end/`, re-enables autosave, prunes old snapshots beyond `KEEP=N`. Safe to run while the server is live. |
| [`wl.sh`](scripts/wl.sh) | `wl` | `wl add\|remove\|list <name>` — manages `whitelist.json` with offline UUIDs (required on `online-mode=false`). Live-reloads via tmux. |
| [`op.sh`](scripts/op.sh) | `op` | `op add\|remove\|list <name> [level]` — manages `ops.json` with offline UUIDs. Live-reloads via tmux. |
| (tmux) | `mc-attach` | Attach to the server tmux session — equivalent to `tmux attach -t mc`. |
| (tmux) | `mc-stop` | Send `stop` to the server console — equivalent to `tmux send-keys -t mc "stop" Enter`. |

---

## 17. Troubleshooting

**`Out of host capacity` when creating or restarting the VM.** Common for ARM A1.Flex shapes. Wait 10 minutes and retry, or pick a different availability domain in the create wizard.

**`Permissions for ssh-key.key are too open`.** Tighten ACL - see step 5.

**`Connection timed out` on first SSH.** Check the Oracle VCN security list (step 4) and OS-level iptables (step 6). Also confirm you used the **reserved** IP, not the old ephemeral one.

**Server boots but Minecraft client times out.** TCP `25565` not open on one of the two firewall layers. Re-run step 4 and step 6.

**Most common variant: iptables ordering bug.** Run `sudo iptables -L INPUT -nv --line-numbers` on the VM. If a `REJECT all reject-with icmp-host-prohibited` row appears **above** your `ACCEPT tcp dpt:25565` row, traffic hits REJECT first and the ACCEPT is dead. Confirm with a self-test on the VM: `nc -vz $(curl -s ifconfig.me) 25565` returns `No route to host`. Fix:
```bash
# Find the line numbers of your stale ACCEPT rules and delete them
sudo iptables -L INPUT -nv --line-numbers
sudo iptables -D INPUT <line_number_of_old_25565_ACCEPT>
sudo iptables -D INPUT <line_number_of_old_24454_ACCEPT>
# Re-insert at position 1 (always above REJECT)
sudo iptables -I INPUT 1 -m state --state NEW -p tcp --dport 25565 -j ACCEPT
sudo iptables -I INPUT 1 -m state --state NEW -p udp --dport 24454 -j ACCEPT
sudo netfilter-persistent save
```

**Voice chat doesn't connect.** UDP `24454` not open. Same fix.

**`Mod resolution failed: requires version X of sodium / java N`.** A mod has a dependency the server can't satisfy. Sodium is client-only and should not be on the server. Java version mismatches mean step 7 was skipped or pinned an older JDK. Check `java -version` shows 22+.

**Fabric launcher jar not found by `start.sh`.** `start.sh` looks for `fabric-server*.jar` in `$SERVER_DIR`. If you renamed the jar or installed the modpack to a different directory, set `JAR=<filename>` and `SERVER_DIR=<dir>` env vars when invoking the script.

**Daily backup didn't run.** Check `~/my_server/backups/backup.log`. Cron uses UTC by default - confirm your time is in UTC. `crontab -l` shows the current schedule.

**Server lags / TPS drops.** Pre-generate chunks with the [Chunky](https://modrinth.com/plugin/chunky) mod's console commands (`chunky radius 1000`, `chunky start`). spark profiler is also installed (`spark profiler --timeout 60`).

**Forgot a player's EasyAuth password.** From the server console: `auth update <username> <newpassword>`.
