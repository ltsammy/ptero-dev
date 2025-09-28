#!/bin/bash
set -euo pipefail

# Verzeichnisse, ohne aggressive chown-Aktionen
mkdir -p "$VSCODE_SERVER_DIR" "${XDG_CACHE_HOME:-/home/container/.cache}" "${NPM_CONFIG_CACHE:-/home/container/.npm}" /home/container/.ssh || true
chmod 700 /home/container/.ssh || true
[ -f /home/container/.ssh/authorized_keys ] && chmod 600 /home/container/.ssh/authorized_keys || true

start_sshd_as_root() {
  # Hostkeys sicherstellen & sshd starten
  ssh-keygen -A
  mkdir -p /var/run/sshd
  /usr/sbin/sshd
}

start_sshd_as_user() {
  # Falls wir nicht root sind (z. B. UID 999), nutzen wir sudo (NOPASSWD)
  sudo /usr/bin/ssh-keygen -A
  sudo mkdir -p /var/run/sshd
  sudo /usr/sbin/sshd
}

# Optional Passwort-Login erlauben: CONTAINER_PASSWORD setzen
if [ -n "${CONTAINER_PASSWORD:-}" ]; then
  # Nur als Root sauber möglich: wenn wir User sind, lockern wir sshd_config und lassen PW-Auth zu;
  # das eigentliche Passwort-Setzen in /etc/shadow geht nur als Root -> daher Hinweis:
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  echo "WARN: Passwort-Login aktiviert. Bitte Key-Auth bevorzugen."
fi

if [ "$(id -u)" -eq 0 ]; then
  start_sshd_as_root
else
  # sicherstellen, dass sudo ohne TTY läuft
  export SUDO_ASKPASS=/bin/true
  start_sshd_as_user
fi

# Zum Original-Entrypoint der Base (Source) – hier NICHT als root nötig
cd /home/container
exec /bin/bash /entrypoint.sh
