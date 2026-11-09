# Fistful of Frags Server (Docker)

This repository provides a Dockerized **Fistful of Frags** game server suitable for running a FoF server in a clean, reproducible way.  
The image is designed for **headless operation**, automatically downloads and updates the game server via SteamCMD (anonymous login, app `295230`), supports file overlaying using OverlayFS, and includes optional SourceMod/MetaMod support.

---

## Features

- Fistful of Frags game server support (Shootout, Teamplay/Objectives, Break Bad, Elimination, Versus, Co-op)
- Runs the 32-bit Source SDK 2013 dedicated server (`srcds_linux`)
- Automatically downloads and updates the game server via SteamCMD, including the first install on a fresh SteamCMD
- Optional SourceMod/MetaMod installation
- Supports file overlaying using OverlayFS (no file copying required)
- Updates the game server on every start, with optional file validation

## Docker Compose Example

```yaml
services:
  fof-server:
    image: lancommander/fistfuloffrags:latest
    container_name: my-fof-server

    # Expose game server ports
    ports:
      - "27015:27015/udp"  # Game server port
      - "27015:27015/tcp"  # RCON
      - "27020:27020/udp"  # SourceTV port (optional)

    # Bind mounts
    volumes:
      - ./config:/config      # Game server configuration and overlay directory

    environment:
      START_ARGS: "-game fof -console +maxplayers 20 +map fof_fistful"
      INSTALL_SOURCEMOD: "true"              # SourceMod/MetaMod (default: true)

    user: root

    # For overlayfs support
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Game files downloaded by SteamCMD (auto-created, about 3.3 GB)
    │   └── fof/           # Fistful of Frags game directory
    ├── Overlay/           # Files to overlay on game directory (optional)
    │   └── fof/           # Fistful of Frags overlay directory
    │       ├── addons/    # SourceMod/MetaMod installation location
    │       │   ├── sourcemod/
    │       │   │   ├── plugins/     # Place your .smx plugin files here
    │       │   │   ├── configs/     # SourceMod configuration files
    │       │   │   └── ...
    │       │   └── metamod/
    │       ├── maps/      # Custom maps
    │       ├── cfg/       # Server configuration files (server.cfg, etc.)
    │       └── ...        # Any other files you want to overlay
    ├── Merged/            # Overlayfs merged view (auto-created, if overlayfs enabled)
    ├── .overlay-work/     # Overlayfs work directory (auto-created)
    ├── Scripts/
    │   └── Hooks/         # Script files in this directory get automatically executed if registered to a hook
    └── ...                # Your game server configuration files
```

The `config` directory **must be writable** by Docker. The `Server` directory is automatically created and populated by SteamCMD on first startup.

---

## Configuration

### Custom Scripts

You can create custom scripts in the `/config/Scripts/Hooks/{HookName}` directory to execute at various points in the container's startup. This is useful for:
- Installing additional dependencies
- Setting up environment variables
- Downloading additional files
- Modifying configuration before the game server starts

All scripts should be PowerShell scripts.

### File Overlaying

The overlay directory (`/config/Overlay`) allows you to overlay files on top of the game directory without copying files. This is useful for:
- Replacing game files (maps, scripts, assets)
- Adding custom content
- Modifying game files without touching the base installation

**How it works:**
- Files in `/config/Overlay` will appear in the merged view at `/config/Merged`
- If a file exists in both `/config/Server` and `/config/Overlay`, the version in `/config/Overlay` takes precedence
- The game server runs from the merged directory

**Requirements:**
- Container must run with `--cap-add SYS_ADMIN` or `--privileged` flag

**Example overlay structure:**
```text
/config/Overlay/
└── fof/
    ├── cfg/
    │   └── server.cfg
    ├── maps/
    │   └── fof_custom.bsp
    └── mapcycle.txt
```

### `server.cfg` and RCON

The stock `fof/cfg/server.cfg` runs on every map load and sets `rcon_password ""`, `sv_lan 0`, the game mode and the bot settings. Because it runs after the command line, it overrides `+rcon_password` and `+sv_lan` in `START_ARGS`. Put your own `server.cfg` in `/config/Overlay/fof/cfg/` (start from a copy of the stock one) and set those cvars there.

### Game modes and maps

`fof_sv_currentmode` in `server.cfg` selects the game mode: `1` Shootout (default), `2` Teamplay/Objectives, `3` Break Bad, `4` Elimination, `5` Versus, `6` Co-op. `mp_teamplay` and `fof_sv_maxteams` (2-4) set the teams. The game ships one map rotation per kind of map (`mapcycle.txt` for the `fof_` Shootout maps, `mapcycle_tp.txt`, `mapcycle_vs.txt` and others); set `mapcyclefile` or overlay your own `fof/mapcycle.txt` to change it. Bots are built in and controlled by the `fof_sv_bot_*` cvars. See [Documentation/Docker.md](Documentation/Docker.md) for the full list.

---

## SourceMod Installation

This image includes support for automatically installing SourceMod and MetaMod:Source. SourceMod is a powerful administration plugin framework for Source engine games.

### Enabling SourceMod

SourceMod installation is enabled by default (`INSTALL_SOURCEMOD="true"`). Set it to `"false"` to skip it:

```yaml
environment:
  INSTALL_SOURCEMOD: "false"
```

When enabled, the container will automatically:
- Install MetaMod:Source (required dependency for SourceMod)
- Install SourceMod
- Place all files in the overlay directory (`/config/Overlay/fof/addons/`)

Fistful of Frags loads the generic Source SDK 2013 builds (`metamod.2.sdk2013.so`, `sourcemod.2.sdk2013.so`).

### Installing Plugins

Once SourceMod is installed, you can add custom plugins by placing `.smx` files in:

```
/config/Overlay/fof/addons/sourcemod/plugins/
```

**Example:**
```bash
# Place your plugin file
cp my_plugin.smx ./config/Overlay/fof/addons/sourcemod/plugins/

# Restart the container to load the plugin
docker restart my-fof-server
```

### SourceMod Configuration

SourceMod configuration files should be placed in:

```
/config/Overlay/fof/addons/sourcemod/configs/
```

Common configuration files:
- `admins_simple.ini` - Admin user configuration
- `core.cfg` - Core SourceMod settings
- `database.cfg` - Database configuration (if using database features)

## Match Statistics

The server can report the matches played on it to LANCommander, with the
[LANCommander match statistics plugin](https://github.com/LANCommander/LANCommander.MatchStatistics.SourceMod).
The plugin is built into the image and needs SourceMod (`INSTALL_SOURCEMOD`). It is turned on when
`MATCH_STATS_SERVER_URL` and `MATCH_STATS_TOKEN` are set, and is then copied into `fof/addons/sourcemod/` on every
start. The core plugin loads the Fistful of Frags module itself. Turned off, the plugin's files are removed again.

| Variable | Description | Default |
|----------|-------------|---------|
| `MATCH_STATS_ENABLED` | `auto`: on when `MATCH_STATS_SERVER_URL` and `MATCH_STATS_TOKEN` are set. `true` or `false` | `auto` |
| `MATCH_STATS_SERVER_URL` | The LANCommander server, e.g. `http://lancommander.lan:1337`. Only `http://` works on Linux | *(empty)* |
| `MATCH_STATS_TOKEN` | A LANCommander access token with the **Report matches** scope (Profile → Access Tokens). It isn't written to any file | *(empty)* |
| `MATCH_STATS_GAME_ID` | The game's id in LANCommander | *(empty)* |
| `MATCH_STATS_SERVER_ID` | This server's id in LANCommander, if LANCommander manages it | *(empty)* |
| `MATCH_STATS_REPORTER_NAME` | How the server is named in LANCommander | *(hostname)* |
| `MATCH_STATS_MIN_PLAYERS` | Human players needed before a match is recorded | *(1)* |
| `MATCH_STATS_MODE` | The mode reported. Empty lets the game module decide | *(empty)* |
| `MATCH_STATS_RECORD_BOTS` | Record bots as players (`true`/`false`) | *(true)* |
| `MATCH_STATS_RECORD_CHAT` | Record chat messages (`true`/`false`) | *(false)* |
| `MATCH_STATS_ATTACH_DEMOS` | Upload SourceTV demos recorded with `tv_record` (`true`/`false`) | *(true)* |

The settings are written to `fof/cfg/sourcemod/lancommander.cfg` as `lc_*` cvars on every start. Settings left
empty aren't written, so they and the plugin's other `lc_*` cvars (see its README) can be set in
`fof/cfg/sourcemod/sourcemod.cfg` instead. A `lancommander.cfg` you put in `Overlay/fof/cfg/sourcemod/` yourself
is left alone.

`sm_lc_status` on the server console or over RCON shows the match being recorded and how delivery is going. Reports
that couldn't be delivered yet are kept in `Overlay/fof/addons/sourcemod/extensions/.interposer/Matches/` and sent
once LANCommander can be reached.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STEAM_APP_ID` | Steam app id of the dedicated server | `295230` |
| `STEAM_VALIDATE` | Validate the game files when SteamCMD updates on startup (`true`/`false`) | `true` |
| `START_EXE` | Server executable (relative to the game directory) | `srcds_run` |
| `START_ARGS` | Arguments used to start the game server | `"-game fof -console +maxplayers 20 +map fof_fistful"` |
| `GAME_MOD` | Game directory that SourceMod/MetaMod are installed into | `fof` |
| `INSTALL_SOURCEMOD` | Enable SourceMod/MetaMod installation (`true`/`false`) | `true` |
| `SOURCEMOD_MAJOR_VERSION` | SourceMod release branch | `1.12` |
| `SOURCEMOD_VERSION` | SourceMod version to install | `1.12.0-git7259` |
| `SOURCEMOD_URL` | Override the SourceMod download URL | *(unset)* |
| `METAMOD_MAJOR_VERSION` | MetaMod:Source release branch | `1.12` |
| `METAMOD_VERSION` | MetaMod version to install | `1.12.0-git1229` |
| `METAMOD_URL` | Override the MetaMod download URL | *(unset)* |
| `HTTP_FILESERVER_ENABLED` | Serve custom content over HTTP (FastDL) on port 80 | `true` |
| `HTTP_FILESERVER_WEB_ROOT` | Directory served by the HTTP file server | `/config/Merged/fof` |
| `HTTP_FILESERVER_FILE_PATTERN` | Regex of request paths the file server allows | maps, materials, models and sound files |

### `STEAM_VALIDATE`

SteamCMD updates the game server on every container start. With `STEAM_VALIDATE` set to `true` (the default) it also checks every game file, which takes longer; set it to `false` for faster restarts.

### `START_ARGS`

Arguments passed to the game server executable at startup. Default example:

```bash
START_ARGS="-game fof -console +maxplayers 20 +map fof_fistful"
```

You can customize this with additional server parameters:

```bash
START_ARGS="-game fof -console +maxplayers 16 +map tp_station +mapcyclefile mapcycle_tp.txt"
```

---

## Running the Server

### Basic run (with automatic updates)

```bash
mkdir -p config

docker run --rm -it \
  --user root \
  --cap-add SYS_ADMIN \
  --security-opt apparmor:unconfined \
  -p 27015:27015/udp \
  -p 27015:27015/tcp \
  -v "$(pwd)/config:/config" \
  -e START_ARGS="-game fof -console +maxplayers 20 +map fof_fistful" \
  lancommander/fistfuloffrags:latest
```

### Without SourceMod

```bash
docker run --rm -it \
  --user root \
  --cap-add SYS_ADMIN \
  --security-opt apparmor:unconfined \
  -p 27015:27015/udp \
  -v "$(pwd)/config:/config" \
  -e INSTALL_SOURCEMOD="false" \
  lancommander/fistfuloffrags:latest
```

### Skip file validation on startup

```bash
docker run --rm -it \
  --user root \
  --cap-add SYS_ADMIN \
  --security-opt apparmor:unconfined \
  -p 27015:27015/udp \
  -v "$(pwd)/config:/config" \
  -e STEAM_VALIDATE="false" \
  lancommander/fistfuloffrags:latest
```

---

## OverlayFS Details

The container uses Linux OverlayFS to merge the server directory (`/config/Server`) with the overlay directory (`/config/Overlay`) into a merged view (`/config/Merged`). This allows you to:

1. **Replace files** without modifying the base game installation
2. **Add files** that don't exist in the base game
3. **Avoid copying** large files - OverlayFS is a union filesystem

**Technical details:**
- **Lower layer**: `/config/Server` (base game files from SteamCMD)
- **Upper layer**: `/config/Overlay` (your custom files)
- **Merged view**: `/config/Merged` (where the game server runs from)
- **Work directory**: `/config/.overlay-work` (required by OverlayFS)

If OverlayFS cannot be mounted (e.g., missing privileges), the container will fall back to using `/config/Server` directly and log a warning.

---

## Troubleshooting

### OverlayFS not working

If you see warnings about OverlayFS, ensure your container has the required privileges:

```bash
# Option 1: Add SYS_ADMIN capability (recommended)
docker run --cap-add SYS_ADMIN --security-opt apparmor:unconfined ...

# Option 2: Use privileged mode (less secure)
docker run --privileged ...
```

### Game server not starting

1. Verify `START_ARGS` contains the correct arguments for Fistful of Frags
2. Check container logs: `docker logs <container-name>`
3. Ensure the server directory was downloaded: check `/config/Server/fof` in the container
4. Verify the server configuration files are correct (e.g., `server.cfg`)

### RCON rejects the password, or `+sv_lan 1` has no effect

The stock `fof/cfg/server.cfg` sets `rcon_password ""` and `sv_lan 0` on every map load, after the command line. Set them in your own `/config/Overlay/fof/cfg/server.cfg`. RCON listens on the container's IP address, not on `127.0.0.1`.

### Clients can't join: version mismatch

The image always installs the newest server build from Steam (the `public` branch is the only one). A client running an older or newer build than the server (compare `PatchVersion` in `fof/steam.inf`) may be rejected or fail to load the map. Update the client to the same build.

### SourceMod not loading

1. Ensure `INSTALL_SOURCEMOD` is set to `"true"` (not just `true` without quotes in YAML)
2. Check that SourceMod was installed: verify `/config/Overlay/fof/addons/sourcemod` exists
3. Verify MetaMod is installed: check for `/config/Overlay/fof/addons/metamod.vdf`
4. Run `meta list` and `sm plugins list` over RCON
5. Ensure plugins are compiled `.smx` files (not `.sp` source files)

### `ERROR! Failed to install app '295230' (Missing configuration)`

A fresh SteamCMD can fail the first install with this error until it has refreshed the app info. The `PreSteamInstallGame/10-BootstrapInstall.ps1` hook runs `app_info_update 1` and the install in one SteamCMD session when `Server/steamapps/appmanifest_295230.acf` doesn't exist yet. If the first install was interrupted, delete that file and restart the container.

### Harmless startup messages

`dlopen failed trying to load: .../.steam/sdk32/steamclient.so` and the `CApplicationManager::GetMountVolume: invalid index` assertions appear on every start; the server then loads its local `steamclient.so` and runs normally.

### Permission errors

If you encounter permission errors:

1. Ensure mounted volumes are writable
2. Check file ownership in the container
3. Review logs for specific permission error messages

---

## License

SteamCMD and game servers are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
