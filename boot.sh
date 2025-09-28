#!/bin/bash
set -euo pipefail

# 1) Hostkeys sicherstellen
ssh-keygen -A

# 2) Persistente Verzeichnisse anlegen (Ownership gezielt setzen; Fehler nicht fatal)
install -d -m 700 -o container -g container /home/container/.ssh || true
install -d -m 755 -o container -g container "${VSCODE_SERVER_DIR:-/home/container/.vscode-server}" || true
install -d -m 755 -o container -g container "${XDG_CACHE_HOME:-/home/container/.cache}" || true
install -d -m 755 -o container -g container "${NPM_CONFIG_CACHE:-/home/container/.npm}" || true

# 3) authorized_keys (falls vorhanden) härten
if [ -f /home/container/.ssh/authorized_keys ]; then
  chown container:container /home/container/.ssh/authorized_keys || true
  chmod 600 /home/container/.ssh/authorized_keys || true
fi

# 4) Optional: Passwort-Login via ENV aktivieren
#    (Standard: Passwort-Login aus; Key-Auth empfohlen!)
if [ -n "${CONTAINER_PASSWORD:-}" ]; then
  echo "container:${CONTAINER_PASSWORD}" | chpasswd
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
fi

# 5) sshd starten
mkdir -p /var/run/sshd
/usr/sbin/sshd

# 6) zum Original-Entrypoint droppen – als 'container'
cd /home/container
exec gosu container /bin/bash /entrypoint.sh
