#!/usr/bin/env sh
# Install bit-by-bit as a systemd service. Run as root from the repo root after
# `ecko build main.ecko -o bit-by-bit`. Never overwrites an existing config and
# never enables or starts the service.
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "error: run as root (sudo ./deploy/install.sh)" >&2
    exit 1
fi
if [ ! -x ./bit-by-bit ]; then
    echo "error: ./bit-by-bit not found - run: ecko build main.ecko -o bit-by-bit" >&2
    exit 1
fi

install -m 0755 ./bit-by-bit /usr/local/bin/bit-by-bit
install -d -m 0700 /etc/bit-by-bit /var/lib/bit-by-bit /var/log/bit-by-bit

if [ -e /etc/bit-by-bit/config.json ]; then
    echo "kept existing /etc/bit-by-bit/config.json"
else
    install -m 0600 deploy/config.example.json /etc/bit-by-bit/config.json
    echo "installed /etc/bit-by-bit/config.json - edit it before starting the service"
fi

install -m 0644 deploy/bit-by-bit.service /etc/systemd/system/bit-by-bit.service
install -m 0644 deploy/logrotate.conf /etc/logrotate.d/bit-by-bit
systemctl daemon-reload

cat <<'NEXT'

Next:
  1. Edit /etc/bit-by-bit/config.json and write credentials files (chmod 600).
  2. bit-by-bit check-config
  3. bit-by-bit run --dry-run
  4. systemctl enable --now bit-by-bit
  5. bit-by-bit status    (and: journalctl -u bit-by-bit -p warning)
NEXT
