#!/bin/bash
set -euo pipefail

# Persistente Verzeichnisse sicherstellen
mkdir -p "${VSCODE_SERVER_DIR:-/home/container/.vscode-server}" \
         "${XDG_CACHE_HOME:-/home/container/.cache}" \
         "${NPM_CONFIG_CACHE:-/home/container/.npm}"

# SSH authorized_keys aus persistenter Home-Partition
# -> Lege deinen PUBLIC KEY in /home/container/.ssh/authorized_keys ab (siehe Schritte unten)
if [ ! -d /home/container/.ssh ]; then
  mkdir -p /home/container/.ssh
  chown -R container:container /home/container/.ssh
  chmod 700 /home/container/.ssh
fi
if [ -f /home/container/.ssh/authorized_keys ]; then
  chown container:container /home/container/.ssh/authorized_keys
  chmod 600 /home/container/.ssh/authorized_keys
fi

# Optional: Passwort-Login aktivieren, wenn ENV gesetzt ist
# (Standard ist 'PasswordAuthentication no' – wird hier temporär auf yes gesetzt, falls gewünscht)
if [ -n "${CONTAINER_PASSWORD:-}" ]; then
  echo "container:${CONTAINER_PASSWORD}" | chpasswd
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
fi

# SSHD starten (daemonisiert sich selbst)
mkdir -p /var/run/sshd
/usr/sbin/sshd

# An das originale EntryPoint vom Base-Image chainen
# (games:source setzt /entrypoint.sh)
exec /bin/bash /entrypoint.sh
