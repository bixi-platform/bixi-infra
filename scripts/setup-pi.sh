#!/usr/bin/env bash
# Pi setup script for the BIXI collector stack.
# Run once as your regular user (not root) after first SSH login.
# Usage: bash setup-pi.sh

set -euo pipefail

GO_VERSION="1.25.0"
PG_VERSION="16"
DB_NAME="bixi"
DB_USER="bixi"
DB_PASS="bixi"          # change this in production
DATA_DIR="/data"        # SSD mount point (or /var/lib if no SSD)

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }
die() { echo -e "\033[1;31mERROR:\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 0. Sanity check
# ---------------------------------------------------------------------------
[[ $(uname -m) == "aarch64" ]] || die "This script is for ARM64 (Pi 4/5). Got: $(uname -m)"
[[ $EUID -ne 0 ]] || die "Run as your regular user, not root."

# ---------------------------------------------------------------------------
# 1. System update
# ---------------------------------------------------------------------------
log "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# ---------------------------------------------------------------------------
# 2. Essential tools
# ---------------------------------------------------------------------------
log "Installing essential tools..."
sudo apt-get install -y -qq \
    git curl wget vim htop \
    build-essential \
    python3 python3-pip python3-venv \
    postgresql-common apt-transport-https \
    gnupg lsb-release

# ---------------------------------------------------------------------------
# 3. Mount SSD at /data (skip if no external drive)
# ---------------------------------------------------------------------------
if lsblk | grep -q "sda"; then
    log "External drive detected. Checking /data mount..."
    if ! mountpoint -q "$DATA_DIR"; then
        DRIVE=$(lsblk -J -o NAME,TYPE | python3 -c "
import json, sys
d = json.load(sys.stdin)
for b in d['blockdevices']:
    if b['type'] == 'disk' and b['name'].startswith('sd'):
        print('/dev/' + b['name'])
        break
")
        if [[ -n "$DRIVE" ]]; then
            log "Formatting $DRIVE as ext4 and mounting at $DATA_DIR..."
            echo "WARNING: This will erase $DRIVE. Press Ctrl+C to abort, Enter to continue."
            read -r
            sudo mkfs.ext4 -F "$DRIVE"
            sudo mkdir -p "$DATA_DIR"
            sudo mount "$DRIVE" "$DATA_DIR"
            DRIVE_UUID=$(sudo blkid -s UUID -o value "$DRIVE")
            echo "UUID=$DRIVE_UUID  $DATA_DIR  ext4  defaults,noatime  0  2" | sudo tee -a /etc/fstab
            log "SSD mounted at $DATA_DIR and added to /etc/fstab."
        fi
    else
        log "$DATA_DIR already mounted."
    fi
else
    log "No external drive found. Using default filesystem paths."
    DATA_DIR="/var/lib"
fi

# ---------------------------------------------------------------------------
# 4. PostgreSQL + TimescaleDB
# ---------------------------------------------------------------------------
log "Adding TimescaleDB repository..."
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/timescaledb.list
curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
    | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg

sudo apt-get update -qq
sudo apt-get install -y -qq "timescaledb-2-postgresql-${PG_VERSION}"

# Move data directory to SSD if applicable
PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
if [[ "$DATA_DIR" == "/data" ]]; then
    SSD_PG="$DATA_DIR/postgresql/${PG_VERSION}/main"
    if [[ ! -d "$SSD_PG" ]]; then
        log "Moving PostgreSQL data directory to SSD..."
        sudo systemctl stop postgresql
        sudo mkdir -p "$(dirname "$SSD_PG")"
        sudo rsync -av "$PG_DATA/" "$SSD_PG/"
        sudo sed -i "s|data_directory = '.*'|data_directory = '$SSD_PG'|" \
            "/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
        sudo systemctl start postgresql
    fi
fi

log "Tuning PostgreSQL for TimescaleDB..."
sudo timescaledb-tune --quiet --yes --pg-config "/usr/lib/postgresql/${PG_VERSION}/bin/pg_config"

log "Creating database and user..."
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" 2>/dev/null || true

sudo systemctl enable postgresql
log "PostgreSQL ready. DATABASE_URL=postgres://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}"

# ---------------------------------------------------------------------------
# 5. Go
# ---------------------------------------------------------------------------
log "Installing Go ${GO_VERSION}..."
GO_TAR="go${GO_VERSION}.linux-arm64.tar.gz"
wget -q "https://go.dev/dl/${GO_TAR}" -O "/tmp/${GO_TAR}"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "/tmp/${GO_TAR}"
rm "/tmp/${GO_TAR}"

PROFILE_LINE='export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin'
grep -qF "$PROFILE_LINE" ~/.profile || echo "$PROFILE_LINE" >> ~/.profile
export PATH=$PATH:/usr/local/go/bin
log "Go $(go version) installed."

# ---------------------------------------------------------------------------
# 6. Python virtual environment for ML pipeline
# ---------------------------------------------------------------------------
log "Setting up Python virtual environment at ~/bixi-venv..."
python3 -m venv ~/bixi-venv
~/bixi-venv/bin/pip install --quiet --upgrade pip

ACTIVATE_LINE='source ~/bixi-venv/bin/activate'
grep -qF "$ACTIVATE_LINE" ~/.profile || echo "$ACTIVATE_LINE" >> ~/.profile
log "Python venv ready. Activate with: source ~/bixi-venv/bin/activate"

# ---------------------------------------------------------------------------
# 7. Clone repos and run migrations
# ---------------------------------------------------------------------------
log "Creating project directory at ~/bixi..."
mkdir -p ~/bixi

cat <<'EOF'

Next steps (run manually):

  1. Copy your code to the Pi:
       rsync -av bixi-infra/ pi@<PI_IP>:~/bixi/bixi-infra/
       rsync -av bixi-collector/ pi@<PI_IP>:~/bixi/bixi-collector/

  2. Run DB migrations (Pi uses native PostgreSQL on port 5432, not the nerdctl container):
       psql postgres://bixi:bixi@localhost:5432/bixi -f ~/bixi/bixi-infra/migrations/001_initial_schema.sql
       psql postgres://bixi:bixi@localhost:5432/bixi -f ~/bixi/bixi-infra/migrations/002_add_hypertables.sql
       psql postgres://bixi:bixi@localhost:5432/bixi -f ~/bixi/bixi-infra/migrations/003_schema_fixes.sql

  3. Build and install the collector:
       cd ~/bixi/bixi-collector
       go build -o ~/bin/bixi-collector ./cmd/collector
       # Then install the systemd service (see bixi-infra/scripts/install-collector-service.sh)

EOF

log "Pi setup complete! Log out and back in for PATH changes to take effect."
