#!/bin/bash

################################################################################
# Ubuntu Server Post-Installation Script
#
# This script installs:
# - Tailscale (from official repo)
# - Webmin (from official repo)
# - Docker Engine (from official repo)
# - Docker Compose plugin
# - NFS Server
# - Samba Server
# - Essential system utilities and tools
#
# Usage: sudo bash post-install.sh
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}"
   exit 1
fi

echo -e "${GREEN}Starting Ubuntu Server post-installation...${NC}\n"

################################################################################
# System Update
################################################################################
echo -e "${YELLOW}[1/7] Updating system packages...${NC}"
apt-get update
apt-get upgrade -y
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common

################################################################################
# Install Essential System Utilities
################################################################################
echo -e "\n${YELLOW}[2/7] Installing essential system utilities...${NC}"

apt-get install -y \
    git \
    htop \
    ncdu \
    screen \
    rsync \
    smartmontools \
    net-tools \
    dnsutils \
    iperf3 \
    ufw \
    unattended-upgrades

# Configure unattended-upgrades for automatic security updates
dpkg-reconfigure -plow unattended-upgrades

echo -e "${GREEN}Essential utilities installed successfully!${NC}"

################################################################################
# Install Tailscale
################################################################################
echo -e "\n${YELLOW}[3/7] Installing Tailscale...${NC}"

# Add Tailscale GPG key
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# Add Tailscale repository
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

# Install Tailscale
apt-get update
apt-get install -y tailscale

# Enable and start Tailscale
systemctl enable --now tailscaled

echo -e "${GREEN}Tailscale installed successfully!${NC}"
echo -e "Run 'sudo tailscale up' to authenticate and connect to your network"

################################################################################
# Install Docker
################################################################################
echo -e "\n${YELLOW}[4/7] Installing Docker...${NC}"

# Remove old Docker versions if they exist
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository using DEB822 format
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(lsb_release -cs)
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
systemctl enable --now docker

# Add current user to docker group if not root
if [[ -n "$SUDO_USER" ]]; then
    usermod -aG docker "$SUDO_USER"
    echo -e "${GREEN}Added $SUDO_USER to docker group${NC}"
    echo -e "Log out and back in for group changes to take effect"
fi

echo -e "${GREEN}Docker installed successfully!${NC}"

################################################################################
# Install Webmin
################################################################################
echo -e "\n${YELLOW}[5/7] Installing Webmin...${NC}"

# Download and run official Webmin repository setup script
curl -o /tmp/webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
sh /tmp/webmin-setup-repo.sh

# Install Webmin
apt-get install -y webmin --install-recommends
rm -f /tmp/webmin-setup-repo.sh

echo -e "${GREEN}Webmin installed successfully!${NC}"
echo -e "Access Webmin at: https://$(hostname -I | awk '{print $1}'):10000"

################################################################################
# Install NFS Server
################################################################################
echo -e "\n${YELLOW}[6/7] Installing NFS Server...${NC}"

# Install NFS kernel server
apt-get install -y nfs-kernel-server

# Create default NFS export directory
mkdir -p /srv/nfs/share
chown nobody:nogroup /srv/nfs/share
chmod 755 /srv/nfs/share

# Backup existing exports file if it exists
if [ -f /etc/exports ]; then
    cp /etc/exports /etc/exports.backup
fi

# Add example export configuration (commented out)
cat >> /etc/exports <<EOF

# Example NFS exports - uncomment and modify as needed:
# /srv/nfs/share    192.168.1.0/24(rw,sync,no_subtree_check)
# /srv/nfs/share    *(ro,sync,no_subtree_check)
EOF

# Enable and start NFS server
systemctl enable --now nfs-kernel-server

echo -e "${GREEN}NFS Server installed successfully!${NC}"
echo -e "Default share directory created at: /srv/nfs/share"
echo -e "Configure exports in: /etc/exports"

################################################################################
# Install Samba Server
################################################################################
echo -e "\n${YELLOW}[7/7] Installing Samba Server...${NC}"

# Install Samba
apt-get install -y samba samba-common-bin

# Backup existing smb.conf if it exists
if [ -f /etc/samba/smb.conf ]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
fi

# Create default Samba share directory
mkdir -p /srv/samba/share
chmod 2775 /srv/samba/share

# Add example share configuration to smb.conf
cat >> /etc/samba/smb.conf <<EOF

# Example Samba share - uncomment and modify as needed:
#[shared]
#   path = /srv/samba/share
#   browseable = yes
#   read only = no
#   guest ok = no
#   valid users = @sambashare
#   create mask = 0660
#   directory mask = 2770
EOF

# Create sambashare group
groupadd -f sambashare

# Enable and start Samba services
systemctl enable --now smbd
systemctl enable --now nmbd

echo -e "${GREEN}Samba Server installed successfully!${NC}"
echo -e "Default share directory created at: /srv/samba/share"
echo -e "Configure shares in: /etc/samba/smb.conf"
echo -e "Add users with: ${YELLOW}sudo smbpasswd -a username${NC}"

################################################################################
# Cleanup
################################################################################
echo -e "\n${YELLOW}Cleaning up...${NC}"
apt-get autoremove -y
apt-get autoclean

################################################################################
# Summary
################################################################################
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}\n"

echo -e "Installed components:"
echo -e "  ${GREEN}✓${NC} System utilities (git, htop, ncdu, screen, rsync, smartmontools, etc.)"
echo -e "  ${GREEN}✓${NC} UFW firewall"
echo -e "  ${GREEN}✓${NC} Unattended upgrades (automatic security updates)"
echo -e "  ${GREEN}✓${NC} Tailscale $(tailscale version 2>/dev/null | head -n1 || echo 'installed')"
echo -e "  ${GREEN}✓${NC} Docker $(docker --version)"
echo -e "  ${GREEN}✓${NC} Docker Compose $(docker compose version)"
echo -e "  ${GREEN}✓${NC} Webmin"
echo -e "  ${GREEN}✓${NC} NFS Server"
echo -e "  ${GREEN}✓${NC} Samba Server"

echo -e "\nNext steps:"
echo -e "  1. Configure UFW firewall: ${YELLOW}sudo ufw allow 22/tcp && sudo ufw enable${NC}"
echo -e "  2. Connect to Tailscale: ${YELLOW}sudo tailscale up${NC}"
echo -e "  3. Access Webmin at: ${YELLOW}https://$(hostname -I | awk '{print $1}'):10000${NC}"
echo -e "  4. Test Docker: ${YELLOW}docker run hello-world${NC}"
echo -e "  5. Configure NFS exports in: ${YELLOW}/etc/exports${NC}"
echo -e "  6. Configure Samba shares in: ${YELLOW}/etc/samba/smb.conf${NC}"
echo -e "  7. Add Samba users: ${YELLOW}sudo smbpasswd -a username${NC}"
echo -e "  8. If you were added to the docker group, log out and back in\n"

echo -e "${GREEN}Script completed successfully!${NC}\n"
