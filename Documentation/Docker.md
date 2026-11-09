# Fistful of Frags Docker Container

This Docker container provides a fully configured Fistful of Frags game server that automatically downloads and updates the game via SteamCMD, supports file overlaying using OverlayFS, and includes optional SourceMod/MetaMod support.

## Quick Start

```yaml
services:
  fof-shootout:
    image: lancommander/fistfuloffrags:latest
    container_name: fof-shootout

    ports:
      - 27015:27015/udp
      - 27015:27015/tcp
      - 27080:80 # For FastDL support

    volumes:
      - "/data/Servers/Fistful of Frags/Shootout:/config"

    environment:
      START_ARGS: "-game fof -console +maxplayers 20 +map fof_fistful"
      INSTALL_SOURCEMOD: "true"

    user: root

    cap_add:
      - SYS_ADMIN

    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

## Configuration Options

### Ports

The container exposes the following ports:

- **27015/udp** - Main game server port (default). Clients connect to this port to join the server, and server browser queries (A2S) are answered on it.
- **27015/tcp** - RCON (remote console). The server listens on the container's IP address, not on `127.0.0.1`.
- **27020/udp** - SourceTV port (optional). Used for game broadcasting and recording.
- **80/tcp** - HTTP file server port (optional). Used for serving game files to clients (See [FastDL](https://developer.valvesoftware.com/wiki/FastDL)).

**Port Mapping:**
In the example configuration, ports are mapped as:
- `27015:27015/udp` - Maps host port 27015 to container port 27015
- `27015:27015/tcp` - Maps host port 27015 to container port 27015 (RCON)
- `27080:80` - Maps host port 27080 to container port 80

You can customize these mappings based on your network requirements. If you're running multiple servers, use different host ports for each instance.

### Volumes

The container requires a volume mount for the `/config` directory, which stores:

- **Server/** - Game files downloaded by SteamCMD (auto-created, about 3.3 GB)
- **Overlay/** - Custom files that overlay on top of the game directory
- **Merged/** - OverlayFS merged view (auto-created)
- **Scripts/** - Custom PowerShell scripts for hooks

**Example:**
```yaml
volumes:
  - "/data/Servers/Fistful of Frags/Shootout:/config"
```

The host path can be:
- An absolute path (Windows: `C:\data\...`, Linux: `/data/...`)
- A relative path (e.g., `./config:/config`)
- A named volume (e.g., `fof-server-data:/config`)

**Important:** The mounted directory must be writable by the container.

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `STEAM_APP_ID` | Steam app id of the dedicated server | `295230` | No |
| `STEAM_VALIDATE` | Validate the game files when SteamCMD updates on startup (`true`/`false`) | `true` | No |
| `START_EXE` | Server executable (relative to the game directory) | `srcds_run` | No |
| `START_ARGS` | Arguments used to start the game server | `"-game fof -console +maxplayers 20 +map fof_fistful"` | No |
| `GAME_MOD` | Game directory that SourceMod/MetaMod are installed into | `fof` | No |
| `INSTALL_SOURCEMOD` | Enable SourceMod/MetaMod installation (`true`/`false`) | `true` | No |
| `SOURCEMOD_MAJOR_VERSION` | SourceMod release branch | `1.12` | No |
| `SOURCEMOD_VERSION` | SourceMod version to install | `1.12.0-git7259` | No |
| `SOURCEMOD_URL` | Override the SourceMod download URL | *(unset)* | No |
| `METAMOD_MAJOR_VERSION` | MetaMod:Source release branch | `1.12` | No |
| `METAMOD_VERSION` | MetaMod version to install | `1.12.0-git1229` | No |
| `METAMOD_URL` | Override the MetaMod download URL | *(unset)* | No |
| `HTTP_FILESERVER_ENABLED` | Serve custom content over HTTP (FastDL) on port 80 | `true` | No |
| `HTTP_FILESERVER_WEB_ROOT` | Directory served by the HTTP file server | `/config/Merged/fof` | No |
| `HTTP_FILESERVER_FILE_PATTERN` | Regex of request paths the file server allows | maps, materials, models and sound files | No |

#### `STEAM_VALIDATE`

SteamCMD updates the game server on every container start. With `STEAM_VALIDATE` set to `"true"` (the default) it also checks every game file, which takes longer; set it to `"false"` for faster restarts.

**Example:**
```yaml
environment:
  STEAM_VALIDATE: "false"
```

#### `START_ARGS`

Arguments passed to the game server executable at startup.

**Default:**
```yaml
START_ARGS: "-game fof -console +maxplayers 20 +map fof_fistful"
```

**Customization Examples:**

Teamplay map rotation (set `fof_sv_currentmode 2` in `server.cfg`):
```yaml
START_ARGS: "-game fof -console +maxplayers 16 +map tp_station +mapcyclefile mapcycle_tp.txt"
```

Versus map rotation (set `fof_sv_currentmode 5` in `server.cfg`):
```yaml
START_ARGS: "-game fof -console +maxplayers 16 +map vs_desert +mapcyclefile mapcycle_vs.txt"
```

**Common Server Parameters:**
- `+map <mapname>` - Set the starting map
- `+maxplayers <n>` - Player slots. The stock `server.cfg` notes that the official maps support up to 20 players in 3-4 team Shootout, 24 in 2-team Shootout and 16 in free-for-all
- `+mapcyclefile <file>` - Map rotation file in `fof/` (see [Game modes and maps](#game-modes-and-maps))
- `+ip <address>` - Server IP address (use `0.0.0.0` for all interfaces)
- `+port <port>` - Server port (default: 27015)
- `+hostname "<name>"` - Server name displayed in server browser

`rcon_password`, `sv_lan`, `hostname` and the game mode cvars are also set by the stock `server.cfg` on every map load, which overrides the command line. Set them in your own `server.cfg` (see [Server Configuration](#server-configuration)).

#### `INSTALL_SOURCEMOD`

Enables automatic installation of SourceMod and MetaMod:Source, which provide plugin support and enhanced server administration.

- `"true"` - Install SourceMod and MetaMod
- `"false"` - Skip SourceMod installation

Default: `"true"`.

When enabled, the container will:
1. Download and install MetaMod:Source (required dependency)
2. Download and install SourceMod
3. Place all files in `/config/Overlay/fof/addons/`
4. Remove the 64-bit `metamod_x64.vdf` loader (the server is 32-bit; `metamod.vdf` loads MetaMod)

**Example:**
```yaml
environment:
  INSTALL_SOURCEMOD: "true"
```

### Security Options

The container requires elevated privileges to use OverlayFS for file overlaying.

#### `cap_add: SYS_ADMIN`

Adds the `SYS_ADMIN` capability, which is required for mounting OverlayFS. This is the recommended approach as it provides minimal necessary privileges.

```yaml
cap_add:
  - SYS_ADMIN
```

#### `security_opt: apparmor:unconfined`

On Ubuntu hosts with AppArmor enabled, you may need to disable AppArmor restrictions for the container. This is often necessary for OverlayFS to function properly.

```yaml
security_opt:
  - apparmor:unconfined
```

**Alternative Options:**

If you prefer less security but simpler configuration, you can use privileged mode:

```yaml
privileged: true
```

**Note:** Privileged mode grants the container extensive access to the host system and is less secure than using `cap_add: SYS_ADMIN`.

### Restart Policy

```yaml
restart: unless-stopped
```

This ensures the container automatically restarts if it stops unexpectedly, but won't restart if you manually stop it.

**Other options:**
- `no` - Never restart
- `always` - Always restart, even after manual stop
- `on-failure` - Restart only on failure

## Directory Structure

The `/config` directory contains the following structure:

```
/config/
├── Server/              # Game files from SteamCMD (auto-created)
│   └── fof/             # Fistful of Frags game directory
├── Overlay/             # Custom files overlay (your modifications)
│   └── fof/
│       ├── addons/      # SourceMod/MetaMod installation location
│       │   ├── sourcemod/
│       │   │   ├── plugins/     # Place .smx plugin files here
│       │   │   ├── configs/     # SourceMod configuration files
│       │   │   └── ...
│       │   └── metamod/
│       ├── maps/        # Custom maps
│       ├── cfg/         # Server configuration files (server.cfg, etc.)
│       ├── mapcycle.txt # Map rotation
│       └── ...
├── Merged/              # OverlayFS merged view (auto-created)
├── .overlay-work/       # OverlayFS work directory (auto-created)
└── Scripts/
    └── Hooks/           # Custom PowerShell scripts for hooks
```

## Game Configuration

### Server Configuration

Place server configuration files in:

```
/config/Overlay/fof/cfg/
```

The stock `fof/cfg/server.cfg` runs on every map load and sets `hostname`, `rcon_password ""`, `sv_lan 0`, the game mode, teams, bots, rates and logging. An `Overlay/fof/cfg/server.cfg` replaces it; start from a copy of the stock file (`/config/Server/fof/cfg/server.cfg`, documented line by line) and change what you need. Per-map overrides go in `fof/cfg/mapcfg/<map>.cfg`.

**Example changes:**
```
hostname "My FoF Server"
rcon_password "your_rcon_password"
sv_lan 1
fof_sv_currentmode 1
mp_teamplay 1
fof_sv_maxteams 4
mp_timelimit 15
```

### Game modes and maps

`fof_sv_currentmode` selects the game mode:

| Value | Game mode |
|-------|-----------|
| `1` | Shootout (default) |
| `2` | Teamplay/Objectives |
| `3` | Break Bad |
| `4` | Elimination |
| `5` | Versus |
| `6` | Co-op |

`mp_teamplay 0/1` turns teams off or on, and `fof_sv_maxteams` sets 2, 3 or 4 teams. The stock config runs 4-team Shootout.

The game ships these map rotations in `fof/` (select one with `mapcyclefile`, or overlay your own `fof/mapcycle.txt`):

| File | Maps |
|------|------|
| `mapcycle.txt` (default) | `fof_cripplecreek`, `fof_fistful`, `fof_nest`, `fof_desperados`, `fof_robertlee`, `fof_trampled`, `fof_revenge`, `fof_depot`, `fof_winterlong`, `fof_sweetwater`, `fof_overtop`, `fof_impact` |
| `mapcycle_12.txt` | `fof_sawmill_12`, `fof_tortuga_12`, `fof_tramonto_12`, `fof_sweetwater_12`, `fof_robertlee_12`, `fof_nest_12` |
| `mapcycle_32.txt` | `fof_cripplecreek`, `fof_fistful`, `fof_nest`, `fof_desperados`, `fof_winterlong`, `fof_sweetwater`, `fof_robertlee`, `fof_overtop`, `fof_trampled` |
| `mapcycle_tp.txt` | `tp_snowy`, `tp_yosemite`, `tp_eliminator`, `tp_loothill`, `tp_abandoned` |
| `mapcycle_vs.txt` | `vs_desert`, `vs_forest`, `vs_river` |
| `mapcycle_cm.txt` | `tp_station`, `tp_forest`, `tp_coastal`, `fof_fistful`, `cm_forest` |
| `mapcycle_gt.txt` | `gt_desperados`, `gt_overtop`, `gt_nest`, `gt_creepycreek` |
| `mapcycle_hr.txt` | `fofhr_monumentvalley`, `fofhr_tramonto`, `fofhr_coldblood` |

### Bots

Bots are built into the game. The stock `server.cfg` sets `fof_sv_bot_dynamicjoin 1` (bots join and leave to fill a share of the slots until humans join), `fof_sv_bot_slotpct 0.2` (the share of slots, 1 = 100%) and `fof_bot_skill 5` (random skill; 0-4 sets a fixed skill).

## SourceMod Configuration

### Installing Plugins

Once SourceMod is installed, add plugins by placing compiled `.smx` files in:

```
/config/Overlay/fof/addons/sourcemod/plugins/
```

**Example:**
```bash
# Copy plugin to the overlay directory
cp my_plugin.smx "/data/Servers/Fistful of Frags/Shootout/Overlay/fof/addons/sourcemod/plugins/"

# Restart the container to load the plugin
docker restart fof-shootout
```

### SourceMod Configuration Files

Place SourceMod configuration files in:

```
/config/Overlay/fof/addons/sourcemod/configs/
```

**Common configuration files:**
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

## OverlayFS

The container uses Linux OverlayFS to merge the base game files with your custom files:

- **Lower layer**: `/config/Server` (base game files from SteamCMD)
- **Upper layer**: `/config/Overlay` (your custom files)
- **Merged view**: `/config/Merged` (where the game server runs from)

**Benefits:**
- Replace files without modifying the base installation
- Add custom content (maps, plugins, configs)
- No file copying required - OverlayFS is a union filesystem
- Easy updates - base game files can be updated without losing customizations

If OverlayFS cannot be mounted (e.g., missing privileges), the container will fall back to using `/config/Server` directly and log a warning.

## Troubleshooting

### Container Won't Start

1. **Check logs:**
   ```bash
   docker logs fof-shootout
   ```

2. **Verify permissions:**
   Ensure the mounted volume is writable:
   ```bash
   # Linux
   chmod -R 755 "/data/Servers/Fistful of Frags/Shootout"

   # Windows
   # Ensure the directory has proper permissions in Windows
   ```

3. **Check security options:**
   Ensure `cap_add: SYS_ADMIN` is set, or use `privileged: true`

### Game Server Not Starting

1. **Verify START_ARGS:**
   Check that `START_ARGS` contains valid server arguments:
   ```yaml
   START_ARGS: "-game fof -console +maxplayers 20 +map fof_fistful"
   ```

2. **Check server directory:**
   Verify that game files were downloaded:
   ```bash
   docker exec fof-shootout ls -la /config/Server/fof
   ```

3. **Review server logs:**
   Check container logs for server startup messages and errors

### RCON Rejects the Password

The stock `server.cfg` sets `rcon_password ""` on every map load, which overrides `+rcon_password` in `START_ARGS` and disables RCON. Set `rcon_password` in `/config/Overlay/fof/cfg/server.cfg`. The same applies to `sv_lan` and `hostname`. RCON listens on the container's IP address, so connect to that (or the published host port), not to `127.0.0.1` inside the container.

### Clients Can't Join: Version Mismatch

The dedicated server app has only the `public` branch, so the image always installs the newest build. Clients need the same build as the server: compare `PatchVersion` in `fof/steam.inf` on both sides (the `status` command shows the server's as `version : <PatchVersion>/24`). An older client may be rejected or fail to load the map; update it.

### SourceMod Not Loading

1. **Verify installation:**
   Ensure `INSTALL_SOURCEMOD: "true"` is set (with quotes in YAML)

2. **Check installation directory:**
   ```bash
   docker exec fof-shootout ls -la /config/Overlay/fof/addons/sourcemod
   ```

3. **Verify MetaMod:**
   Check that MetaMod's 32-bit loader is installed:
   ```bash
   docker exec fof-shootout ls -la /config/Overlay/fof/addons/metamod.vdf
   ```

4. **Check over RCON:**
   `meta list` should list SourceMod and SDK Tools, and `sm plugins list` the default plugins. Fistful of Frags uses the generic Source SDK 2013 builds (`metamod.2.sdk2013.so`, `sourcemod.2.sdk2013.so`).

### `ERROR! Failed to install app '295230' (Missing configuration)`

A fresh SteamCMD (no cached app info) can fail to install the dedicated server with this error. The image handles this in the `PreSteamInstallGame/10-BootstrapInstall.ps1` hook: when `Server/steamapps/appmanifest_295230.acf` doesn't exist yet, it refreshes the app info (`app_info_update 1`) and installs in the same SteamCMD session. Later updates work as usual. If the first install was interrupted, delete `Server/steamapps/appmanifest_295230.acf` and restart the container to run the bootstrap again.

### Harmless Startup Messages

`dlopen failed trying to load: /home/lancommander/.steam/sdk32/steamclient.so`, `CApplicationManager::GetMountVolume: invalid index` assertions, `/tmp/dumps is not owned by us` and `ConVarRef mat_dxlevel doesn't point to an existing ConVar` appear on every start. The server then loads its own `steamclient.so` and runs normally.

### Port Already in Use

If you get port binding errors:

1. **Check for existing containers:**
   ```bash
   docker ps -a
   ```

2. **Use different ports:**
   Change the port mapping in docker-compose.yml:
   ```yaml
   ports:
     - 27016:27015/udp  # Use a different host port
   ```

3. **Stop conflicting containers:**
   ```bash
   docker stop <container-name>
   ```

### Permission Errors

The container runs as a non-root user. If you encounter permission errors:

1. **Check file ownership:**
   ```bash
   docker exec fof-shootout ls -la /config
   ```

2. **Verify volume mount:**
   Ensure the host directory is accessible and writable

3. **Review logs:**
   Check container logs for specific permission error messages

## Advanced Usage

### Custom Hooks

You can create custom PowerShell scripts that execute at various points in the container's lifecycle. Place scripts in:

```
/config/Scripts/Hooks/{HookName}/
```

**Available hooks:**
- `PreSteamInstallGame` - Before SteamCMD runs
- `PostSteamInstallGame` - After SteamCMD completes
- `PreInstallSourceMod` - Before SourceMod installation
- `PostInstallSourceMod` - After SourceMod installation

**Example hook script** (`/config/Scripts/Hooks/PostSteamInstallGame/10-CustomSetup.ps1`):
```powershell
Write-Host "Running custom setup..."
# Your custom commands here
```

### HTTP File Server

The container includes an optional HTTP file server (port 80) for serving game files to clients. This is useful for fast downloads of custom maps and content. Point `sv_downloadurl` in `server.cfg` at it (the stock config sets a placeholder URL).

The file server is configured via environment variables:
- `HTTP_FILESERVER_ENABLED` - Enable/disable the file server
- `HTTP_FILESERVER_WEB_ROOT` - Root directory for file serving
- `HTTP_FILESERVER_FILE_PATTERN` - Pattern for files to serve

### Multiple Server Instances

To run multiple Fistful of Frags servers on the same host:

1. **Use different container names:**
   ```yaml
   container_name: fof-server1
   ```

2. **Use different ports:**
   ```yaml
   ports:
     - 27016:27015/udp
     - 27016:27015/tcp
   ```

3. **Use different volume mounts:**
   ```yaml
   volumes:
     - "/data/Servers/Fistful of Frags/Server1:/config"
   ```

4. **Use different maps/names:**
   ```yaml
   environment:
     START_ARGS: "-game fof -console +maxplayers 16 +map tp_station +mapcyclefile mapcycle_tp.txt"
   ```

## Additional Resources

- [Source Dedicated Server Documentation](https://developer.valvesoftware.com/wiki/Source_Dedicated_Server)
- [SourceMod Documentation](https://wiki.alliedmods.net/Category:SourceMod_Documentation)
- [MetaMod:Source Documentation](https://wiki.alliedmods.net/Metamod:Source)
