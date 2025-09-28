# games:source gibt es nur für amd64
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

ENV DEBIAN_FRONTEND=noninteractive

USER root
RUN set -eux; \
    rm -rf /var/lib/apt/lists/*; mkdir -p /var/lib/apt/lists/partial; \
    apt-get update -o Acquire::Retries=3; \
    apt-get install -y --no-install-recommends \
        git ca-certificates openssh-server sudo; \
    rm -rf /var/lib/apt/lists/*; \
    # SSHD Grundkonfig (Port 2225, Root-Login aus, PW-Login standardmäßig aus)
    mkdir -p /var/run/sshd /etc/ssh/sshd_config.d; \
    printf '%s\n' \
      'Port 2225' \
      'Protocol 2' \
      'PermitRootLogin no' \
      'PasswordAuthentication no' \
      'ChallengeResponseAuthentication no' \
      'UsePAM yes' \
      'X11Forwarding no' \
      'ClientAliveInterval 120' \
      'ClientAliveCountMax 2' \
    > /etc/ssh/sshd_config; \
    # VS Code Server/Caches (persistente Pfade anlegen – Ownership übernimmt Wings/Volume)
    mkdir -p /home/container/.vscode-server /home/container/.cache /home/container/.npm; \
    # --- UID/GID 999 vorbereiten, damit "No user exists for uid 999" NIE auftritt ---
    # Gruppe 999 (falls nicht vorhanden) + User ptero:999 mit Home /home/container
    (getent group 999 || groupadd -g 999 ptero) && \
    (getent passwd 999 || useradd -M -u 999 -g 999 -s /bin/bash -d /home/container ptero); \
    # sudo erlauben: ptero darf sshd & ssh-keygen ohne Passwort
    printf 'ptero ALL=(root) NOPASSWD: /usr/sbin/sshd, /usr/bin/ssh-keygen\n' > /etc/sudoers.d/ptero-sshd; \
    chmod 440 /etc/sudoers.d/ptero-sshd

# VS Code Server persistent im Volume
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container

# Boot-Wrapper (macht SSH + startet danach Original-Entrypoint)
COPY boot.sh /usr/local/bin/boot.sh
RUN chmod +x /usr/local/bin/boot.sh

# Container-Port (im Panel Host-Port -> 2225 mappen)
EXPOSE 2225/tcp

# Wichtig: Wir bleiben beim "originalen Entrypoint" semantisch:
# boot.sh führt am Ende /entrypoint.sh der Base aus.
ENTRYPOINT ["/usr/local/bin/boot.sh"]
