# Joining the server with Prism Launcher

Step-by-step setup for friends to launch and join server (~10 mins + download time).

## Requirements
- The server's public IP
- ~5 GB free disk space for the instance + mod jars

## 1. Install Prism Launcher

Download the installer from <https://prismlauncher.org/download/>. Run it once and it auto-downloads Java for you. Don't install Java separately.

## 2. Add your Microsoft account (or continue in offline mode)

In Prism: **Accounts** menu (top-right, person icon) -> **Manage Accounts** -> **Add Microsoft** -> sign in.

## 3. Download the modpack

Download the modpack of your choice from this repo's `client/modpacks/` folder.

## 4. Create a new instance

Click **Add Instance** in the top-left toolbar.

![Prism instance list](../images/image.png)

## 5. Import the .mrpack

1. Pick **Import** in the left sidebar
2. Click **Browse** and select the `.mrpack` file you downloaded
3. Click **OK**

![Import .mrpack](../images/image1.png)

Prism will resolve all mods, download every jar from Modrinth, and set up the Fabric loader.

## 6. Launch

Double-click the new instance and wait while Prism unpacks mods and launches.

## 7. Connect to the server

In the Minecraft main menu:
1. **Multiplayer** -> **Add Server**
2. Server Name: whatever you want to call the server, just for you to see
3. Server Address: the public IP your host gave you (e.g. `123.45.67.89`)
4. **Done** -> double-click the server entry to join
5. Do `/register <pw> <pw>` to connect a password to your username. Use `/login <pw>` on future sessions.

Voice chat (Simple Voice Chat) auto-activates when you join. Press **V** to mute/unmute, **Y** to switch between proximity/group/global voice. Setup audio devices in the in-game menu (Esc -> Voice Chat Settings).

## Miscellaneous
There are some pre-downloaded shader packs and resource packs. Feel free to play around with these and see what you like!

To enable: **Options -> Video Settings -> Shader Packs / Resource Packs -> click one -> Done**.