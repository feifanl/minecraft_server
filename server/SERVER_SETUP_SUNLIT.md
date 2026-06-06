# Sunlit Valley Server Setup (Forge 1.20.1)

Setup guide for hosting a **Society: Sunlit Valley** server on the same Oracle Cloud ARM VM described in [`SERVER_SETUP.md`](SERVER_SETUP.md).

Sunlit Valley = Forge 1.20.1 modpack (~100 bundled mods). Setup diverges from the Fabric Vanilla+ workflow at the Java install + launcher steps.

---

## Reuse from `SERVER_SETUP.md`

Steps 1–6 work as-is:

1. Sign up for Oracle Cloud
2. Create the VM (24 GB RAM strongly recommended — Sunlit Valley needs 8+ GB heap)
3. Reserve a public IP
4. Open firewall ports (Oracle VCN layer) — TCP 25565, UDP 24454
5. SSH into the VM
6. Open firewall ports (OS layer)

Pick up here for Sunlit-specific steps.

---

## 7s. Install Java 17 (NOT Java 25)

Forge 1.20.1 needs Java 17. Java 25 will not boot it.

```bash
sudo apt update
sudo apt install -y wget apt-transport-https gpg tmux git unzip
sudo mkdir -p /etc/apt/keyrings
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt update
sudo apt install -y temurin-17-jre
java -version
```

Verify output mentions `Temurin-17` or `17.0.x`.

If Vanilla+ already on this VM with Java 25, keep both — `update-alternatives --config java` or full path in start scripts to pick.

---

## 8s. Clone this repo

```bash
cd ~
git clone https://github.com/feifanl/minecraft_server minecraft-server
mkdir -p ~/sunlit_server && cd ~/sunlit_server
```

---

## 9s. Download + extract Sunlit Valley server pack

CurseForge doesn't allow direct `wget` without an API token. Easiest path: download the zip on your local machine from <https://www.curseforge.com/minecraft/modpacks/society-sunlit-valley/files/all> (filter "Server Pack"), then `scp` it to the VM.

```bash
# From your LOCAL terminal:
scp -i <PATH_TO_KEY> SERVER-PACK-Society-Sunlit-Valley-X.X.X.zip ubuntu@<RESERVED_IP>:~/sunlit_server/
```

Back on the VM:
```bash
cd ~/sunlit_server
unzip SERVER-PACK-Society-Sunlit-Valley-*.zip
rm SERVER-PACK-Society-Sunlit-Valley-*.zip   # save disk
ls
```

Expect: `mods/`, `config/`, `defaultconfigs/`, `forge-1.20.1-XX.X.X.jar`, `startserver.sh`, `user_jvm_args.txt`, etc.

---

## 10s. First boot + accept EULA

The pack ships a `startserver.sh` that runs the Forge launcher. First boot generates `eula.txt`.

```bash
cd ~/sunlit_server
chmod +x startserver.sh
./startserver.sh
# Exits with "You need to agree to the EULA"

sed -i 's/eula=false/eula=true/' eula.txt
```

Tweak heap if needed — edit `user_jvm_args.txt`:
```
-Xms8G
-Xmx12G
```

(12 GB on a 24 GB VM leaves headroom for OS + other servers.)

---

## 11s. Drop in the SVC addon

```bash
cd ~/sunlit_server
unzip -o ~/minecraft-server/server/modpacks/"Sunlit Valley Server Addon.zip" -d mods/
# README.txt also lands in mods/ — harmless but you can rm it:
rm mods/README.txt
```

That installs `voicechat-forge-1.20.1-2.6.4.jar` next to Sunlit Valley's bundled mods.

To refresh later: `cd ~/minecraft-server && git pull && cd ~/sunlit_server && unzip -o ~/minecraft-server/server/modpacks/"Sunlit Valley Server Addon.zip" -d mods/`

---

## 12s. Boot in tmux

Sunlit Valley's `startserver.sh` blocks the terminal. Wrap in tmux so it survives SSH disconnect:

```bash
tmux new -d -s sunlit "cd ~/sunlit_server && ./startserver.sh"
tmux attach -t sunlit
```

`Ctrl-B` then `D` to detach without stopping the server.

First boot generates the world — 2–5 minutes. Done when log shows `Done (X.Xs)! For help, type "help"`.

---

## 13s. server.properties + whitelist

After first boot, `server.properties` exists. Edit:
```bash
nano ~/sunlit_server/server.properties
```

Useful tweaks: `motd`, `max-players`, `view-distance`, `simulation-distance`, `difficulty`.

**Whitelist:** Sunlit Valley uses Forge auth (no EasyAuth). Vanilla whitelist works since `online-mode=true` by default (premium Mojang accounts only).

```bash
# Inside tmux attach session, type at server console (NO leading slash):
whitelist add <PLAYER_NAME>
whitelist on
op <PLAYER_NAME>
```

Players need genuine Microsoft/Mojang accounts to connect. No `/register` flow.

If you want cracked-account support: not recommended on Sunlit Valley — would require swapping in EasyAuth-for-Forge equivalent + config changes that may conflict with bundled mods. Out of scope for this guide.

---

## 14s. Auto-restart on reboot + daily backups

Add to crontab (`crontab -e`):

```cron
@reboot tmux new -d -s sunlit "cd /home/ubuntu/sunlit_server && ./startserver.sh"
0 6 * * * /home/ubuntu/minecraft-server/server/scripts/backup.sh
```

`backup.sh` from this repo works as-is — it tar.gz's `world/`. Set `SERVER_DIR=$HOME/sunlit_server` env var when invoking if needed:
```cron
0 6 * * * SERVER_DIR=/home/ubuntu/sunlit_server /home/ubuntu/minecraft-server/server/scripts/backup.sh
```

---

## Connect from client

Friends use the matching client addon zip: [`client/modpacks/Sunlit Valley Client Addon.zip`](../client/modpacks/Sunlit%20Valley%20Client%20Addon.zip). Install Sunlit Valley client pack normally, drop the addon jars into the instance's `mods/` folder. See [`client/CLIENT_SETUP.md`](../client/CLIENT_SETUP.md).

In-game: **Multiplayer → Add Server**, paste reserved IP. UDP 24454 must be open for voice chat.

---

## Troubleshooting

**`UnsupportedClassVersionError` on boot.** Wrong Java. Need 17, not 25 or 21. `java -version` to check.

**`startserver.sh: No such file or directory`.** Server pack didn't extract right. `ls ~/sunlit_server` — if you see only the zip, re-run `unzip`.

**Server boots but client crashes on join.** Client modpack version ≠ server modpack version. Both must match Sunlit Valley version (e.g. both 4.0.5).

**Voice chat doesn't connect.** UDP 24454 not open on Oracle VCN (step 4) or iptables (step 6). Same as base guide.

**Out of memory crashes.** Heap too small. Bump `-Xmx12G` to `-Xmx16G` in `user_jvm_args.txt`. Don't exceed 80% of VM RAM.
