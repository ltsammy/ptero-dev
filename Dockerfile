# Basis: offizielles Source-Engine Yolk
FROM ghcr.io/pterodactyl/games:source

LABEL org.opencontainers.image.source="https://github.com/ltsammy/ptero-dev"
ENV DEBIAN_FRONTEND=noninteractive

# Als root: git installieren, persistente Verzeichnisse vorbereiten
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /home/container/.vscode-server /home/container/.cache /home/container/.npm \
 && chown -R container:container /home/container

# VS Code Server & Caches PERSISTENT nach /home/container legen
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

# Wenn du KEIN eigenes entrypoint brauchst, kommentiere die nächste Zeile einfach aus.
# COPY ./entrypoint.sh /entrypoint.sh

# Zurück zum Pterodactyl-Standarduser
USER container
WORKDIR /home/container

# CMD/ENTRYPOINT kommen aus dem Base-Image (games:source) – nicht überschreiben
