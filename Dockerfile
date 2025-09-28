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
    mkdir -p /var/run/sshd /etc/ssh/sshd_config.d; \
    # Basis-sshd_config (Root-Login aus, Port 2222; Passwort-Login per ENV togglebar)
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
    > /etc/ssh/sshd_config

# VS Code Server & Caches PERSISTENT nach /home/container
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

# Boot-Wrapper: startet sshd (als root), setzt optional Passwort, dann chain zum Base-EntryPoint
COPY boot.sh /usr/local/bin/boot.sh
RUN chmod +x /usr/local/bin/boot.sh

# Expose (Dokumentation) – den Host-Port weist du im Panel zu
EXPOSE 2222/tcp

# ***WICHTIG: Als ROOT bleiben, damit boot.sh root-Rechte hat***
ENTRYPOINT ["/usr/local/bin/boot.sh"]
