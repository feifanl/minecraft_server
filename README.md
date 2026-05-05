# Minecraft Server Setup

A collection of server/client modpacks for use by me and my friends, with documentation for people new to modded Minecraft and anyone who wants to host their own server.

---

# Contents

- [Player Quick Start](#player-quick-start) - quickstart to join a server
- [Modpacks](#modpacks) - what's in the server-side and client-side packs
- [Server Config](#server-config) - host your own server end-to-end (Oracle Cloud)
- [Server Scripts](#server-scripts) - scripts to start, backup, and restore servers

---

# Player Quick Start

1. Download a mod launcher, I recommend [Prism Launcher](https://prismlauncher.org/download/windows/).
2. Pick the modpack you want and download the matching `.mrpack` file from the `client/` folder.
3. Create a new instance in your mod launcher.
   ![alt text](images/image.png)
4. Import the downloaded `.mrpack` file.
   ![alt text](images/image1.png)
5. Launch the instance, then connect to the server with the IP from the host.
6. Once you join, do `/register <pw> <pw>` to connect a password to your username. Do `/login <pw>` on future sessions.

---

# Modpacks

For full descriptions of any mod on this list, visit [Modrinth](https://modrinth.com) or Google the mod name.

## Server-side

### Vanilla+
The most basic set of server-side mods for a Vanilla+ Minecraft experience with your friends. This modpack is extremely lightweight, mainly performance/optimization mods plus multiplayer QoL: sitting, sleep speed-up, proximity voice chat, player head drops.

People playing on a Vanilla+ modpack server do **not** *need* to install any mods themselves to connect, though installing Simple Voice Chat is strongly recommended.

**Full mod list:**
- **Performance:** Lithium, Krypton, FerriteCore, ModernFix, Noisium, ScalableLux, C2ME (Concurrent Chunk Management Engine), Alternate Current, ServerCore, spark, View Distance Fix
- **Worldgen / LOD:** Voxy, Voxy Server Side, Voxy WorldGen V2
- **Gameplay:** Sit, Sleep Warp, Let Me Despawn, Get It Together Drops, Clumps, Just Player Heads, Playtime Command
- **Admin / Utility:** LuckPerms, TAB (Fabric Tab List), Placeholder API, Chunky, EasyAuth
- **Voice:** Simple Voice Chat (server side)
- **Networking:** Raknetify (Fabric)
- **Libraries:** Fabric API, Fabric Language Kotlin, Architectury, Cloth Config, Fzzy Config, MidnightLib, TCDCommons API, YetAnotherConfigLib, Config Manager, Almanac, Collective

## Client-side

### Vanilla+
The most basic set of client-side mods — should be used if the server uses Vanilla+, but also works for **a better singleplayer experience**. Mostly client-side counterparts to the Vanilla+ server mods, plus QoL features like FPS display, waypoints, zoom, dynamic lighting, and better shulker boxes.

**Full mod list:**
- **Enables Vanilla+ server features:** **Simple Voice Chat**, AppleSkin, Voxy
- **Performance:** Sodium, Lithium, FerriteCore, ModernFix, ImmediatelyFast, EntityCulling, Cull Fewer Leaves, Dynamic FPS, Particle Core, Fast Noise
- **Visual / QoL:** Iris, LambDynamicLights, Sound Physics Remastered, Zoomify, Fabrishot, Flashback, Fadeless
- **UI tweaks:** Mod Menu, Controlling, Shulker Box Tooltip, Status Effect Bars, Toggle Nametags, FPS-Display, World Play Time, wWaypoints
- **Misc:** No Telemetry, Crash Assistant
- **Libraries:** Fabric API, Fabric Language Kotlin, Architectury, Cloth Config v20, YetAnotherConfigLib, MidnightLib, Fzzy Config, TCDCommons API, Config Manager
- **Optional:** ViaFabricPlus (download this if you want to play on a server that runs a different Minecraft version than your client)

---

# Server Config

Here are the steps to host your own server end-to-end (~30-45 minute set-up).

## 1. Set up server hosting

I recommend [Oracle Cloud](https://www.oracle.com/cloud/free/). Use a Pay As You Go subscription to host a virtual machine (VM) for your server. As long as you stay within the Always Free tier limits (up to 4 OCPUs and 24 GB of RAM total across A1.Flex instances), *you will not be charged*. 

The Free Tier gives more OCPU/RAM hours than there are hours in a month at those specs. You'll still need a credit card to sign up, however, but you won't get charged.

**VM specs:**
- Shape: `VM.Standard.A1.Flex` (ARM Ampere)
- OCPUs: 4
- Memory: 24 GB
- Image: Ubuntu 22.04
- Boot volume: default (50 GB) is more than enough
- Networking: a new VCN with a public subnet - accept the wizard defaults
- SSH keys: paste or generate a new public key

After creating the VM, you can also reserve a public IP in the Networking -> Reserved Public IPs section and attach it to your VM. Reserving one IP is free and means your IP won't change if the VM reboots (though creating a tmux session means it likely won't need to reboot).

## 2. Open the firewall ports

Minecraft uses TCP `25565`. Simple Voice Chat uses UDP `24454`. You must open up these ports on two separate layers:
a) Oracle VCN security list (web console):
Navigate to Networking -> Virtual Cloud Networks -> Your VCN -> The public subnet -> the default security list.
Add ingress rules:
- Source `0.0.0.0/0`, IP Protocol TCP, Destination Port Range `25565`
- Source `0.0.0.0/0`, IP Protocol UDP, Destination Port Range `24454`
b) OS-level firewall (SSH into the VM first, Google if you don't know how to):
```bash
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 25565 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 24454 -j ACCEPT
sudo netfilter-persistent save
```

If `netfilter-persistent` isn't installed, do `sudo apt install -y iptables-persistent`.

## 3. SSH into the VM and install dependencies

```bash
ssh ubuntu@<YOUR IP>
sudo apt update
sudo apt install -y openjdk-21-jre-headless tmux git
java -version
```

The Java version printed should be "OpenJDK 21."

## 4. Clone this repo and set up the server directory

```bash
cd ~
git clone https://github.com/feifanl/minecraft_server minecraft-server
mkdir -p ~/my_server && cd ~/my_server
```

The scripts and instructions below assume `~/my_server` as the server directory. If you choose a different name, **set `SERVER_DIR` when running the scripts below** (e.g. `SERVER_DIR=$HOME/foo ~/my_server/scripts/start.sh`).

## 5. Install the server modpack (Fabric loader + mods)

This repo ships server modpacks as `.mrpack` files (Modrinth format) under `server/modpacks/`. Reinstalls and restores stay reproducible since every mod is pinned to a specific Modrinth version. Unpack with [`mrpack-install`](https://github.com/nothub/mrpack-install).

`mrpack-install` downloads the Fabric server launcher, the matching Minecraft server jar, and every mod all together, so you do **not** need to download Fabric separately.

```bash
# One-time install for mrpack-install
wget https://github.com/nothub/mrpack-install/releases/latest/download/mrpack-install-linux-arm64 -O ~/mrpack-install
chmod +x ~/mrpack-install

# Download server modpack of choice
cd ~/my_server
~/mrpack-install server ~/minecraft-server/server/modpacks/<NAME_OF_MODPACK_TO_INSTALL>
```

`~/my_server/` will now contain `mods/`, the Fabric server launcher jar, and the Minecraft server jar.

## 6. Initialize the server

`mrpack-install` only downloaded files, so no configs exist yet.

Run the launcher once to generate `eula.txt` and the default `config/` tree. It detects `eula=false` and exits before any world generation. This repo also ships a pre-tuned `server.properties` (Vanilla+ defaults: `online-mode=false` for EasyAuth, whitelist enabled, etc.) that you should copy in before first boot, then tweak.

```bash
cd ~/my_server

# 1. Drop in the pre-tuned server.properties (overwrites any default)
cp ~/minecraft-server/server/server.properties ./server.properties

# 2. First boot - generates configs, exits with "You need to agree to the EULA"
# If the launcher jar isn't named fabric-server-launch.jar, rename it or pass JAR=<YOUR_JAR_NAME> when running start.sh later.
java -Xms10G -Xmx10G -jar fabric-server-launch.jar nogui

# 3. Accept Mojang's EULA
sed -i 's/eula=false/eula=true/' eula.txt

# 4. Edit server properties to taste (motd, max-players, difficulty, etc.)
nano server.properties
```

`~/my_server/` should now contain:
```
~/my_server/
├── server.properties      # main server config
├── eula.txt               
├── whitelist.json         # allowed players (created on first /whitelist add)
├── ops.json               # operators (created on first /op)
├── banned-players.json
├── banned-ips.json
├── world/                 # world save (overworld + nether + end)
├── logs/                  
├── mods/                  # mod .jars
├── config/                # per-mod config dirs
│   └── auth/config.json   # EasyAuth config
├── libraries/             # Fabric/Minecraft libs
└── fabric-server-launch.jar
```

Edit `server.properties` based on your desires. Common settings include:
- `motd=<text>` - message shown in server list
- `max-players=<n>`
- `view-distance=<n>` - chunk render distance (default is 10)
- `simulation-distance=<n>` - chunk tick distance (default is 10)
- `difficulty=easy|normal|hard`
- `gamemode=survival|creative` - default mode for new players
- `pvp=true|false`
- `white-list=true` - enable whitelisting so non-whitelisted players can't join
- `enforce-whitelist=true` - kick non-whitelisted players already online if whitelist updates
- `online-mode=false` - **set to `false` if you use EasyAuth** (see below)
- `spawn-protection=<n>`

**Whitelist and perms**: Manage with tmux server console:
```
/whitelist add <username>
/whitelist remove <username>
/whitelist list
/op <username>
/deop <username>
```

You can also directly edit `whitelist.json` / `ops.json` while the server is stopped. Op levels: 1 = bypass spawn protection, 2 = singleplayer cheats, 3 = `/ban` and multiplayer commands, 4 = full access including `/stop`.

**EasyAuth setup**

EasyAuth is a plugin that adds a password and login layer for extra security. This is especially important if your server is `online-mode=false`, since otherwise anyone can pick a whitelisted username and just join.

Setup:
1. Make sure `easyauth-*.jar` is in `~/my_server/mods/` (included in Vanilla+ server pack).
2. Set `online-mode=false` in `server.properties`.
3. Edit `config/auth/config.json`. Recommended values:
   ```json
   {
     "main": {
       "premiumAutologin": true,
       "floodgateAutologin": false,
       "enableGlobalPassword": false,
       "sessionTimeoutTime": 86400,
       "kickTime": 30
     },
     "experimental": {
       "forcedOfflineUuids": false,
       "preventAnotherLocationLog": true,
       "debugMode": false
     },
     "lang": {}
   }
   ```
   - `premiumAutologin: true` - players with actual Mojang accounts skip `/login`
   - `sessionTimeoutTime` - seconds before re-login required (86400 = 24h)
   - `kickTime` - seconds idle before non-logged-in players are kicked

Player commands (run in chat after joining):
```
/register <password> <password>
/login <password>
/changepassword <old> <new>
/logout
/unregister <password>
```

Admin commands (op required):
```
/auth reload
/auth remove <player>
/auth setGlobalPassword <pw>
/auth update <player> <newpassword>
```

Tell each friend on first join to type `/register <pw> <pw>` to claim their username. Until registered or logged in, they can't move, chat, or break blocks.

## 7. Copy over the helper scripts

```bash
mkdir -p ~/my_server/scripts
cp ~/minecraft-server/server/scripts/*.sh ~/my_server/scripts/
chmod +x ~/my_server/scripts/*.sh
```

## 8. Boot up the server (for real)

This time the server will generate the world and stay running.

```bash
~/my_server/scripts/start.sh
tmux attach -t mc
# Detach with Ctrl-B then D — server keeps running while you're disconnected.
```

Connect to the server from Minecraft using the public IP you reserved.

## 9. Schedule daily backups

```bash
crontab -e
```
Add the line:
```
0 6 * * * /home/ubuntu/my_server/scripts/backup.sh >> /home/ubuntu/my_server/backups/backup.log 2>&1
```
Change the schedule of backups by editing the "0 6 * * *" prefix (minute hour day-of-month month day-of-week). Look up cron syntax if this doesn't make sense.

Pick an off-peak hour, since `save-all flush` will stall the server briefly.

# Server Scripts

There are two scripts in `server/scripts/`. Both have comments to explain what is going on. 
1. [`start.sh`](server/scripts/start.sh): Launches the server in a tmux session with 10G of RAM allocated (optimal amount, increasing might be slightly counterproductive).
2. [`backup.sh`](server/scripts/backup.sh): Saves all world directories to `backups/world-<timestamp>.tar.gz`, Keeps the newest `KEEP=N` snapshots (default is 2) and overwrites the rest.

## Restoring from a backup

```bash
tmux attach -t mc
# type: stop
cd ~/my_server
mv world world.broken
tar -xzf backups/world-YYYYMMDD-HHMMSS.tar.gz
~/my_server/scripts/start.sh
```