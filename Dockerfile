# games:source gibt es nur für amd64
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

ENV DEBIAN_FRONTEND=noninteractive

USER root
RUN set -eux; \
    rm -rf /var/lib/apt/lists/*; mkdir -p /var/lib/apt/lists/partial; \
    apt-get update -o Acquire::Retries=3; \
    apt-get install -y --no-install-recommends \
        git ca-certificates openssh-server gosu passwd; \
    rm -rf /var/lib/apt/lists/*; \
    # sshd Grundkonfiguration
    mkdir -p /var/run/sshd /etc/ssh/sshd_config.d; \
    printf '%s\n' \
      'Port 2225' \
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
    # Persistenz-Verzeichnisse
    mkdir -p /home/container/.vscode-server /home/container/.cache /home/container/.npm

# VS Code Server persistent im Volume
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

COPY boot.sh /usr/local/bin/boot.sh
RUN chmod +x /usr/local/bin/boot.sh

# Doku – in Pterodactyl musst du Host-Port -> Container-Port 2225 mappen
EXPOSE 2225/tcp

# Boot als root, dann Drop zu 'container'
ENTRYPOINT ["/usr/local/bin/boot.sh"]
