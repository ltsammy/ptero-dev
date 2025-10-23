# games:source gibt es nur für amd64
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

ENV DEBIAN_FRONTEND=noninteractive

# --- Als root arbeiten ---
USER root

# --- APT & Basis ---
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

# --- Wrapper (POSIX sh) ---
RUN set -eux; \
  cat > /usr/local/bin/with-sshd << 'EOF'
#!/bin/sh
set -eu

echo "[with-sshd] starting…"

# Port (muss exakt der Pterodactyl-Allocation entsprechen)
SSHD_PORT="${SSHD_PORT:-30022}"

# Hostkeys erzeugen, falls fehlend
if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
  echo "[with-sshd] generating host keys"
  ssh-keygen -A
fi

# sshd auf gewünschtem Port starten (Wings mappt 1:1)
mkdir -p /var/run/sshd
echo "[with-sshd] launching sshd on port ${SSHD_PORT}"
/usr/sbin/sshd -e -o "Port=${SSHD_PORT}" &

# Diagnose
echo "[with-sshd] user: $(id -u -n) (uid=$(id -u)), cwd: $(pwd)"
echo "[with-sshd] invoking yolk entrypoint…"

# WICHTIG: Yolks wollen /entrypoint.sh via bash, nicht direkt als exec.
if [ -x /entrypoint.sh ]; then
  exec /bin/bash /entrypoint.sh "$@"
elif [ -x /start.sh ]; then
  exec /bin/bash /start.sh "$@"
else
  # Fallback: wenn Pterodactyl ein CMD übergibt
  if [ $# -gt 0 ]; then
    echo "[with-sshd] exec CMD: $*"
    exec "$@"
  else
    echo "[with-sshd] no entrypoint and no CMD provided — sleeping to avoid crash"
    tail -f /dev/null
  fi
fi
EOF
# sicherstellen: LF-Zeilenenden + ausführbar
RUN sed -i 's/\r$//' /usr/local/bin/with-sshd && chmod 0755 /usr/local/bin/with-sshd

# --- SSH-Verzeichnis für den container-User ---
RUN mkdir -p /home/container/.ssh \
    && chown -R container:container /home/container/.ssh \
    && chmod 700 /home/container/.ssh

# --- VS Code Server persistieren ---
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

# --- ENTRYPOINT: unser Wrapper ---
ENTRYPOINT ["/usr/local/bin/with-sshd"]

# --- zurück zu Standard-User/Arbeitsverzeichnis ---
USER container
WORKDIR /home/container
