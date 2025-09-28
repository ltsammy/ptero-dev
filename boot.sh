#!/bin/bash
set -euo pipefail

# 0) Hostkeys sicherstellen (falls nicht vorhanden)
ssh-keygen -A

# 1) UID/GID des gemounteten Volumes ermitteln (z. B. 999:999)
VOL_UID="$(stat -c %u /home/container || echo 1000)"
VOL_GID="$(stat -c %g /home/container || echo 1000)"

# 1a) Gruppe anpassen/erstellen
if getent group "${VOL_GID}" >/dev/null 2>&1; then
  TARGET_GRP="$(getent group "${VOL_GID}" | cut -d: -f1)"
else
  if getent group container >/dev/null 2>&1; then
    groupmod -o -g "${VOL_GID}" container
    TARGET_GRP="container"
  else
    groupadd -o -g "${VOL_GID}" container
    TARGET_GRP="container"
  fi
fi

# 1b) User 'container' auf korrekte UID/GID bringen oder anlegen
if getent passwd container >/dev/null 2>&1; then
  usermod -o -u "${VOL_UID}" -g "${VOL_GID}" container
else
  useradd -m -d /home/container -o -u "${VOL_UID}" -g "${VOL_GID}" container
fi

# 2) Persistente Verzeichnisse (mit Besitz)
install -d -m 700 -o "${VOL_UID}" -g "${VOL_GID}" /home/container/.ssh || true
install -d -m 755 -o "${VOL_UID}" -g "${VOL_GID}" "${VSCODE_SERVER_DIR:-/home/container/.vscode-server}" || true
install -d -m 755 -o "${VOL_UID}" -g "${VOL_GID}" "${XDG_CACHE_HOME:-/home/container/.cache}" || true
install -d -m 755 -o "${VOL_UID}" -g "${VOL_GID}" "${NPM_CONFIG_CACHE:-/home/container/.npm}" || true

# authorized_keys härten, falls vorhanden
if [ -f /home/container/.ssh/authorized_keys ]; then
  chown "${VOL_UID}:${VOL_GID}" /home/container/.ssh/authorized_keys || true
  chmod 600 /home/container/.ssh/authorized_keys || true
fi

# 3) Optional: Passwort-Login per ENV aktivieren (Key-Auth bleibt empfohlen)
if [ -n "${CONTAINER_PASSWORD:-}" ]; then
  echo "container:${CONTAINER_PASSWORD}" | chpasswd
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
fi

# 4) sshd starten (Port 2225 – in /etc/ssh/sshd_config gesetzt)
mkdir -p /var/run/sshd
/usr/sbin/sshd

# 5) Privilege-Drop & Original-Entrypoint starten
cd /home/container
exec gosu container /bin/bash /entrypoint.sh
