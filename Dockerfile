# games:source gibt es nur für amd64
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

ENV DEBIAN_FRONTEND=noninteractive

# --- Als root arbeiten ---
USER root

# --- APT robust machen + Git installieren + Persistenz vorbereiten ---
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

# --- OpenSSH-Server installieren & absichern ---
RUN set -eux; \
    apt-get update -o Acquire::Retries=3; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-server; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /var/run/sshd; \
    # sshd absichern: nur Keys, kein root, kein Challenge, kein X11
    sed -i 's/#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -i 's/#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config; \
    sed -i 's/#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config; \
    sed -i 's/#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config; \
    sed -i 's@#\?AuthorizedKeysFile .*@AuthorizedKeysFile .ssh/authorized_keys@' /etc/ssh/sshd_config; \
    sed -i 's/#\?X11Forwarding .*/X11Forwarding no/' /etc/ssh/sshd_config

# --- Wrapper: startet sshd auf dem Pterodactyl-Allocation-Port und übergibt an den Yolk ---
RUN bash -lc 'cat >/usr/local/bin/with-sshd << "EOF"\n\
#!/usr/bin/env bash\n\
set -Eeuo pipefail\n\
# Port aus ENV (muss dem Pterodactyl-Allocation-Port entsprechen)\n\
SSHD_PORT=\"${SSHD_PORT:-30022}\"\n\
# Hostkeys generieren, falls nicht vorhanden\n\
if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then\n\
  ssh-keygen -A\n\
fi\n\
# sshd auf dem gewünschten Port starten (Vorsicht: Wings mappt 1:1, also Port muss identisch sein)\n\
mkdir -p /var/run/sshd\n\
/usr/sbin/sshd -e -o Port=\"${SSHD_PORT}\" &\n\
# An den Pterodactyl-EntryPoint übergeben, falls vorhanden, sonst CMD\n\
if [ -x /entrypoint.sh ]; then\n\
  exec /entrypoint.sh \"$@\"\n\
elif [ -x /start.sh ]; then\n\
  exec /start.sh \"$@\"\n\
else\n\
  exec \"$@\"\n\
fi\n\
EOF\n\
'; chmod +x /usr/local/bin/with-sshd

# --- SSH-Verzeichnis für den container-User vorbereiten ---
RUN mkdir -p /home/container/.ssh \
 && chown -R container:container /home/container/.ssh \
 && chmod 700 /home/container/.ssh


# --- VS Code Server persistieren (wie bei dir) ---
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

# --- ENTRYPOINT auf Wrapper setzen, damit sshd + Yolk starten ---
ENTRYPOINT ["/usr/local/bin/with-sshd"]

# --- zurück zu Standard-User/Arbeitsverzeichnis des Yolks ---
USER container
WORKDIR /home/container
# ENTRYPOINT/CMD kommen weiterhin aus dem Base-Image; unser Wrapper ruft sie auf
