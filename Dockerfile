# games:source gibt es nur für amd64
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

ENV DEBIAN_FRONTEND=noninteractive

# Als root arbeiten
USER root

# APT robust machen + Git installieren + Persistenz vorbereiten
RUN set -eux; \
    # APT säubern / Verzeichnisse sicherstellen (fix für "exit 100")
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /var/lib/apt/lists/partial; \
    apt-get update -o Acquire::Retries=3; \
    apt-get install -y --no-install-recommends git ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    # VS Code Server & Caches im persistenten Volume ablegen
    mkdir -p /home/container/.vscode-server /home/container/.cache /home/container/.npm; \
    chown -R container:container /home/container

# VS Code Server persistieren
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

# zurück zu Standard-User/Arbeitsverzeichnis des Yolks
USER container
WORKDIR /home/container
# ENTRYPOINT/CMD kommen aus dem Base-Image
