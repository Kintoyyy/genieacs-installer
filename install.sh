#!/usr/bin/env bash

# Requires: Ubuntu 20.04 / 22.04 / 24.04
# Run as: sudo ./install.sh

# ------------------------
# Color Variables
# ------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'
NC='\033[0m'

# ------------------------
# Root Check
# ------------------------
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script as root (sudo).${NC}"
  exit 1
fi

local_ip=$(hostname -I | awk '{print $1}')

# ------------------------
# Intro
# ------------------------
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}  ______           _      ___   ___________                                ${NC}"
echo -e "${GREEN} / ____/__  ____  (_)__  /   | / ____/ ___/                                ${NC}"
echo -e "${GREEN}/ / __/ _ \/ __ \/ / _ \/ /| |/ /    \__ \                                 ${NC}"
echo -e "${GREEN}/ /_/ /  __/ / / / /  __/ ___ / /___ ___/ /                                 ${NC}"
echo -e "${GREEN}\____/\___/_/ /_/_/\___/_/  |_\____//____/                                  ${NC}"
echo -e "${GREEN}======================= GenieACS Auto Installer ============================${NC}"
echo -e "${GREEN}      By Kintoyyy - https://github.com/Kintoyyy/genieacs-installer          ${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}Do you want to continue? (y/n)${NC}"
read confirmation

if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Installation cancelled. No changes were made.${NC}"
    exit 1
fi


# ------------------------
# Fix Broken Dependencies
# ------------------------
echo -e "${YELLOW}Fixing broken packages and dependencies...${RESET}"
apt-get update
apt-get install -f -y
dpkg --configure -a
apt --fix-broken install -y
apt-get clean

# ------------------------
# Check Installed Services
# ------------------------
NODE_INSTALLED=false
MONGO_RUNNING=false
GENIEACS_RUNNING=false
NGINX_RUNNING=false

if command -v node >/dev/null 2>&1; then
    NODE_INSTALLED=true
fi

if systemctl is-active --quiet mongod; then
    MONGO_RUNNING=true
fi

if systemctl is-active --quiet genieacs-cwmp; then
    GENIEACS_RUNNING=true
fi

if systemctl is-active --quiet nginx; then
    NGINX_RUNNING=true
fi

# ------------------------
# Node.js Installation
# ------------------------
if ! $NODE_INSTALLED; then
    echo -e "${YELLOW}Installing Node.js 20.x...${RESET}"
    curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
    bash nodesource_setup.sh
    apt-get install -y nodejs
    node -v
else
    echo -e "${GREEN}Node.js is already installed.${NC}"
fi

# ------------------------
# MongoDB Installation (Community Edition 8.0)
# ------------------------
if ! $MONGO_RUNNING; then
    echo -e "${YELLOW}Cleaning old MongoDB packages (if any)...${RESET}"
    apt-get purge -y mongodb-org* || true
    rm -f /etc/apt/sources.list.d/mongodb-org-*.list
    rm -f /usr/share/keyrings/mongodb-server-*.gpg
    apt-get update
    apt-get install -y gnupg curl

    # Import MongoDB GPG key
    curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
       gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

    UBUNTU_VERSION=$(lsb_release -cs)

    case "$UBUNTU_VERSION" in
      noble|jammy|focal)
        MONGO_REPO="deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu $UBUNTU_VERSION/mongodb-org/8.0 multiverse"
        ;;
      *)
        echo -e "${RED}Unsupported Ubuntu version: $UBUNTU_VERSION${NC}"
        exit 1
        ;;
    esac

    echo "$MONGO_REPO" | tee /etc/apt/sources.list.d/mongodb-org-8.0.list
    apt-get update
    apt-get install -y mongodb-org
    systemctl enable --now mongod
    mongo --eval 'db.runCommand({ connectionStatus: 1 })' || true
else
    echo -e "${GREEN}MongoDB is already installed and running.${NC}"
fi

# ------------------------
# GenieACS Installation
# ------------------------
if ! $GENIEACS_RUNNING; then
    echo -e "${YELLOW}Installing GenieACS...${RESET}"
    npm install -g genieacs@1.2.13
    useradd --system --no-create-home --user-group genieacs || true

    mkdir -p /opt/genieacs/ext
    mkdir -p /var/log/genieacs
    chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

    cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF

    chown genieacs:genieacs /opt/genieacs/genieacs.env
    chmod 600 /opt/genieacs/genieacs.env

    for svc in cwmp nbi fs ui; do
        cat << EOF > /etc/systemd/system/genieacs-$svc.service
[Unit]
Description=GenieACS $svc
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$svc

[Install]
WantedBy=multi-user.target
EOF
    done

    cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF

    systemctl daemon-reload
    systemctl enable --now genieacs-{cwmp,nbi,fs,ui}
else
    echo -e "${GREEN}GenieACS is already installed and running.${NC}"
fi

# ------------------------
# Nginx Installation
# ------------------------
if ! $NGINX_RUNNING; then
    echo -e "${YELLOW}Installing Nginx...${RESET}"
    apt-get install -y nginx || apt-get install -f -y nginx
    systemctl enable --now nginx || true

    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

    cat << EOF > /etc/nginx/sites-available/genieacs
server {
    listen 80;
    server_name _;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/genieacs /etc/nginx/sites-enabled/genieacs
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx
else
    echo -e "${GREEN}Nginx is already installed and running.${NC}"
fi

# ------------------------
# Firewall Setup
# ------------------------
echo -e "${YELLOW}Configuring UFW firewall...${RESET}"
apt-get install -y ufw
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 7547/tcp
ufw allow 7557/tcp
ufw allow 7567/tcp
ufw --force enable

# ------------------------
# Restart Services
# ------------------------
echo -e "${YELLOW}Restarting all services...${NC}"

services_to_restart=("mongod" "genieacs-cwmp" "genieacs-nbi" "genieacs-fs" "genieacs-ui" "nginx")

for svc in "${services_to_restart[@]}"; do
    if systemctl is-active --quiet "$svc"; then
        systemctl restart "$svc"
        echo -e "${GREEN}$svc restarted successfully.${NC}"
    else
        echo -e "${YELLOW}$svc is not running, skipping restart.${NC}"
    fi
done

echo -e "${GREEN}All services have been restarted.${NC}"

# ------------------------
# Final Info
# ------------------------
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN} GenieACS installation completed successfully!${NC}"
echo -e "${GREEN} UI:     http://$local_ip${NC}"
echo -e "${GREEN} USER:   admin${NC}"
echo -e "${GREEN} PASS:   admin${NC}"
echo -e "${GREEN}                  ${NC}"
echo -e "${GREEN} CWMP:   Port 7547${NC}"
echo -e "${GREEN} NBI:    Port 7557${NC}"
echo -e "${GREEN} FS:     Port 7567${NC}"
echo -e "${GREEN}============================================================================${NC}"