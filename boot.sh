#!/bin/bash
set -euo pipefail

# 1) Hostkeys sicherstellen (manche Images haben keine)
ssh-keygen -A

# 2) persistente Verzeichnisse anlegen (mit korrekten Besitz/Rechten)
#    keine blanket-chown auf /home/container (Pterodactyl managt Ownership selbst)
install -d -m 700 -o container -g container /home/container/.ssh || true
install -d -m 755 -o container -g container "${VSCODE_SERVER_DIR:-/home/container/.vscode-server}"
install -d -m 755 -o container -g container "${XDG_CACHE_HOME:-/home/container/.cache}"
install -d -m 755 -o container -g container "${NPM_CONFIG_CACHE:-/home/container/.npm}"

# 3) authorized_keys (falls vorhanden) korrekt setzen
if [ -f /home/container/.ssh/authorized_keys ]; then
  chown container:container /home/container/.ssh/authorized_keys || true
  chmod 600 /home/container/.ssh/authorized_keys || true
fi

# 4) Optional: Passwort-Login über ENV aktivieren (default: aus)
#    Setze im Panel CONTAINER_PASSWORD, wenn du Passwortlogin willst
if [ -n "${CONTAINER_PASSWORD:-}" ]; then
  echo "container:${CONTAINER_PASSWORD}" | chpasswd
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
fi

# 5) sshd starten (als root)
mkdir -p /var/run/sshd
/usr/sbin/sshd

# 6) zum Base-EntryPoint chainen (games:source liefert /entrypoint.sh)
#    Dieses Script wechselt selbst auf den 'container'-User und startet deinen Server.
exec /bin/bash /entrypoint.sh
