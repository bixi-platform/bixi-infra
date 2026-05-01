#!/usr/bin/env bash
# Installs the bixi-collector as a systemd service on the Pi.
# Run after setup-pi.sh and after the collector binary is built.
# Usage: bash install-collector-service.sh

set -euo pipefail

BINARY="$HOME/bin/bixi-collector"
CONFIG="$HOME/bixi/bixi-collector/config.yaml"
# Pi runs native PostgreSQL on 5432 — not the nerdctl container (which uses 5433 on dev laptops).
DB_URL="postgres://bixi:bixi@localhost:5432/bixi"
USER=$(whoami)

[[ -f "$BINARY" ]] || { echo "Binary not found at $BINARY. Build it first: cd ~/bixi/bixi-collector && go build -o ~/bin/bixi-collector ./cmd/collector"; exit 1; }

sudo tee /etc/systemd/system/bixi-collector.service > /dev/null <<EOF
[Unit]
Description=BIXI GBFS + Weather Collector
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=$(dirname "$CONFIG")
ExecStart=${BINARY}
Environment=DATABASE_URL=${DB_URL}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bixi-collector

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable bixi-collector
sudo systemctl start bixi-collector

echo "Service status:"
sudo systemctl status bixi-collector --no-pager
echo ""
echo "Logs: sudo journalctl -u bixi-collector -f"
