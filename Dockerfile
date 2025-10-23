# games:source gibt es nur für amd64
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

ENV DEBIAN_FRONTEND=noninteractive

# --- Root für Installation ---
USER root

# --- Pakete & Persistenz ---
RUN set -eux; \
    rm -rf /var/lib/apt/lists/*; mkdir -p /var/lib/apt/lists/partial; \
    apt-get update -o Acquire::Retries=3; \
    apt-get install -y --no-install-recommends ca-certificates git openssh-server; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /home/container/.vscode-server /home/container/.cache /home/container/.npm /home/container/.ssh; \
    chown -R container:container /home/container; \
    chmod 700 /home/container/.ssh

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

# --- Wrapper: root startet sshd, danach $STARTUP als "container" ---
RUN set -eux; \
  cat > /usr/local/bin/with-sshd << 'EOF'
#!/bin/sh
set -eu

echo "[with-sshd] starting…"

SSHD_PORT="${SSHD_PORT:-30022}"

# Hostkeys (Root-Kontext)
if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
  echo "[with-sshd] generating host keys"
  ssh-keygen -A
fi

# sshd als root starten (Wings mappt 1:1)
mkdir -p /var/run/sshd
echo "[with-sshd] launching sshd on port ${SSHD_PORT}"
/usr/sbin/sshd -e -o "Port=${SSHD_PORT}" &

# Ziel-User ermitteln (default: container)
RUN_AS="container"
if ! getent passwd "${RUN_AS}" >/dev/null 2>&1; then
  echo "[with-sshd] WARNING: user '${RUN_AS}' not found, staying root"
  RUN_AS="root"
fi

# Pterodactyl-STARTUP ausführen, falls vorhanden
if [ -n "${STARTUP:-}" ]; then
  echo "[with-sshd] exec as ${RUN_AS}: \$STARTUP"
  if [ "${RUN_AS}" = "root" ]; then
    exec /bin/bash -lc "${STARTUP}"
  else
    exec su -p -s /bin/bash "${RUN_AS}" -c "${STARTUP}"
  fi
fi

# Fallback: entrypoint/start.sh, sonst wach bleiben
if [ -x /entrypoint.sh ]; then
  echo "[with-sshd] exec /entrypoint.sh as ${RUN_AS}"
  if [ "${RUN_AS}" = "root" ]; then exec /bin/bash /entrypoint.sh "$@"; else exec su -p -s /bin/bash "${RUN_AS}" -c "/entrypoint.sh \"$@\""; fi
elif [ -x /start.sh ]; then
  echo "[with-sshd] exec /start.sh as ${RUN_AS}"
  if [ "${RUN_AS}" = "root" ]; then exec /bin/bash /start.sh "$@"; else exec su -p -s /bin/bash "${RUN_AS}" -c "/start.sh \"$@\""; fi
else
  echo "[with-sshd] no STARTUP/entrypoint provided — sleeping"
  exec tail -f /dev/null
fi
EOF
RUN sed -i 's/\r$//' /usr/local/bin/with-sshd && chmod 0755 /usr/local/bin/with-sshd

# --- VS Code Server-Dirs (deine ENV wie gehabt) ---
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

# --- ENTRYPOINT bleibt root (damit sshd Keys/Port öffnen darf) ---
ENTRYPOINT ["/usr/local/bin/with-sshd"]

# --- KEIN "USER container" am Ende! ---
# Wir wechseln im Wrapper (su) auf "container", damit sshd Root bleibt.
WORKDIR /home/container
