# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/steamcmd:local
ARG BASE_IMAGE=lancommander/steamcmd:latest
FROM ${BASE_IMAGE}

# SteamCMD settings
ENV STEAM_APP_ID="295230"
ENV START_EXE="srcds_run"
ENV START_ARGS="-game fof -console +maxplayers 20 +map fof_fistful"
ENV INSTALL_SOURCEMOD="true"
ENV SOURCEMOD_MAJOR_VERSION="1.12"
ENV SOURCEMOD_VERSION="1.12.0-git7259"
ENV GAME_MOD="fof"
ENV METAMOD_MAJOR_VERSION="1.12"
ENV METAMOD_VERSION="1.12.0-git1229"
ENV HTTP_FILESERVER_ENABLED="true"
ENV HTTP_FILESERVER_WEB_ROOT="/config/Merged/fof"
ENV HTTP_FILESERVER_FILE_PATTERN="^/(maps|materials|models|sound)/.*\.(bz2|ztmp|bsp|nav|res|mdl|vvd|vtx|phy|ani|vmt|vtf|wav|mp3)$"

# ----------------------------
# Dependencies
# ----------------------------
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    bzip2 \
    tar \
    unzip \
    xz-utils \
    p7zip-full \
    gosu \
  && rm -rf /var/lib/apt/lists/*

# Game traffic and server queries
EXPOSE 27015/udp
# RCON
EXPOSE 27015/tcp
# SourceTV
EXPOSE 27020/udp
# HTTP file server (FastDL)
EXPOSE 80/tcp

# COPY Modules/ "${BASE_MODULES}/"
COPY Hooks/ "${BASE_HOOKS}/"

USER lancommander

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]