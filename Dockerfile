# games:source gibt es nur für amd64
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

ENV DEBIAN_FRONTEND=noninteractive

# Als root arbeiten
USER root

# APT robust + Git + OpenSSH-Server installieren, Verzeichnisse vorbereiten
RUN set -eux; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /var/lib/apt/lists/partial; \
    apt-get update -o Acquire::Retries=3; \
    apt-get install -y --no-install-recommends git ca-certificates openssh-server; \
    rm -rf /var/lib/apt/lists/*; \
    # SSHD vorbereiten
    mkdir -p /var/run/sshd /etc/ssh/sshd_config.d; \
    # Minimal-konfig: Port 2222, kein Root-Login, nur User 'container'
    printf '%s\n' \
      'Port 2222' \
      'Protocol 2' \
      'PermitRootLogin no' \
      'PasswordAuthentication no' \
      'ChallengeResponseAuthentication no' \
      'UsePAM yes' \
      'X11Forwarding no' \
      'AllowUsers container' \
      'ClientAliveInterval 120' \
      'ClientAliveCountMax 2' \
    > /etc/ssh/sshd_config; \
    # Hostkeys (werden bei Bedarf generiert)
    ssh-keygen -A; \
    # VS Code Server & Caches im persistenten Volume ablegen
    mkdir -p /home/container/.vscode-server /home/container/.cache /home/container/.npm; \
    chown -R container:container /home/container

# VS Code Server persistent
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

# Boot-Wrapper: startet sshd, setzt optional Passwort, dann Original-EntryPoint
COPY boot.sh /usr/local/bin/boot.sh
RUN chmod +x /usr/local/bin/boot.sh

# Expose für Doku (Port muss im Panel zugewiesen werden)
EXPOSE 2225/tcp

# Boot als root -> startet sshd -> chain zum Base-EntryPoint
ENTRYPOINT ["/usr/local/bin/boot.sh"]
