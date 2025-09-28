# Wichtig: Plattform festnageln
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /home/container/.vscode-server /home/container/.cache /home/container/.npm \
 && chown -R container:container /home/container

# VS Code Server persistent im Volume
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

USER container
WORKDIR /home/container
