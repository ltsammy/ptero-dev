# games:source gibt es nur für amd64
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

ENV DEBIAN_FRONTEND=noninteractive

# --- Als root arbeiten ---
USER root

# --- APT & Persistenz vorbereiten (wie gehabt) ---
RUN set -eux; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /var/lib/apt/lists/partial; \
    apt-get update -o Acquire::Retries=3; \
    apt-get install -y --no-install-recommends ca-certificates git openssh-server; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /home/container/.vscode-server /home/container/.cache /home/container/.npm; \
    chown -R container:container /home/container

# --- sshd absichern ---
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -i 's/#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -i 's/#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config; \
    sed -i 's/#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config; \
    sed -i 's/#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config; \
    sed -i 's@#\?AuthorizedKeysFile .*@AuthorizedKeysFile .ssh/authorized_keys@' /etc/ssh/sshd_config; \
    sed -i 's/#\?X11Forwarding .*/X11Forwarding no/' /etc/ssh/sshd_config; \
    if grep -q '^UsePAM' /etc/ssh/sshd_config; then sed -i 's/^UsePAM.*/UsePAM no/' /etc/ssh/sshd_config; else echo 'UsePAM no' >> /etc/ssh/sshd_config; fi

# --- Wrapper (POSIX sh): startet sshd auf dem Pterodactyl-Allocation-Port und übergibt an den Yolk ---
RUN set -eux; \
  cat > /usr/local/bin/with-sshd << 'EOF'
#!/bin/sh
set -eu

# Port (muss exakt der Pterodactyl-Allocation entsprechen)
SSHD_PORT="${SSHD_PORT:-30022}"

# Hostkeys erzeugen, falls fehlend
if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
  ssh-keygen -A
fi

# sshd auf gewünschtem Port starten (Wings mappt 1:1)
mkdir -p /var/run/sshd
/usr/sbin/sshd -e -o "Port=${SSHD_PORT}" &

# An den Yolk-Entrypoint übergeben, falls vorhanden; sonst CMD
if [ -x /entrypoint.sh ]; then
  exec /entrypoint.sh "$@"
elif [ -x /start.sh ]; then
  exec /start.sh "$@"
else
  exec "$@"
fi
EOF
# sicherstellen: LF-Zeilenenden + ausführbar
RUN sed -i 's/\r$//' /usr/local/bin/with-sshd && chmod 0755 /usr/local/bin/with-sshd

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

# --- ENTRYPOINT: über /bin/sh aufrufen (vermeidet exec-format-Fehler) ---
ENTRYPOINT ["/bin/sh","-c","exec /usr/local/bin/with-sshd \"$@\"","--"]

# --- zurück zu Standard-User/Arbeitsverzeichnis des Yolks ---
USER container
WORKDIR /home/container
