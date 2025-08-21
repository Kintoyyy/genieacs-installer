#!/usr/bin/env bash

# Requires: Ubuntu 20.04 / 22.04 / 24.04
# Run as: sudo ./uninstall.sh

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

# ------------------------
# Intro
# ------------------------
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}   GenieACS Auto Uninstaller${NC}"
echo -e "${GREEN}   This will REMOVE GenieACS, MongoDB, Node.js, and Nginx completely.${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${YELLOW}Do you really want to continue? (y/n)${NC}"
read confirmation

if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Uninstallation cancelled. No changes were made.${NC}"
    exit 1
fi

# ------------------------
# Drop GenieACS MongoDB Database
# ------------------------
echo -e "${YELLOW}Dropping GenieACS MongoDB database...${NC}"
if command -v mongo >/dev/null 2>&1; then
    mongo genieacs --eval "db.dropDatabase()" || true
elif command -v mongosh >/dev/null 2>&1; then
    mongosh genieacs --eval "db.dropDatabase()" || true
else
    echo -e "${RED}Mongo client not found, skipping DB drop.${NC}"
fi

# ------------------------
# Stop and Disable Services
# ------------------------
echo -e "${YELLOW}Stopping services...${NC}"
systemctl stop genieacs-{cwmp,nbi,fs,ui} mongod nginx 2>/dev/null || true
systemctl disable genieacs-{cwmp,nbi,fs,ui} mongod nginx 2>/dev/null || true

# ------------------------
# Remove Packages
# ------------------------
echo -e "${YELLOW}Removing packages...${NC}"
apt-get purge -y mongodb-org* nginx nodejs
npm uninstall -g genieacs || true
apt-get autoremove -y
apt-get clean

# ------------------------
# Remove Config Files and Logs
# ------------------------
echo -e "${YELLOW}Removing GenieACS files and configs...${NC}"
rm -rf /opt/genieacs \
       /var/log/genieacs \
       /etc/systemd/system/genieacs-*.service \
       /etc/logrotate.d/genieacs

echo -e "${YELLOW}Removing Nginx configs...${NC}"
rm -f /etc/nginx/sites-available/genieacs \
      /etc/nginx/sites-enabled/genieacs

echo -e "${YELLOW}Removing MongoDB configs...${NC}"
rm -f /etc/apt/sources.list.d/mongodb-org-*.list \
      /usr/share/keyrings/mongodb-server-*.gpg

# Reload systemd
systemctl daemon-reload

# ------------------------
# Final Message
# ------------------------
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN} GenieACS, MongoDB (DB dropped), Node.js, and Nginx have been completely removed.${NC}"
echo -e "${GREEN}============================================================================${NC}"
