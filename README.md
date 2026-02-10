# Ubuntu Server Post-Installation Script

A comprehensive bash script to automate the setup of essential services and tools on a fresh Ubuntu Server installation.

## What Gets Installed

### Core Services
- **Tailscale** - VPN mesh network from official repository
- **Docker Engine** - Container platform with Docker Compose plugin from official repository
- **Webmin** - Web-based system administration interface from official repository
- **NFS Server** - Network File System for sharing directories
- **Samba Server** - SMB/CIFS file sharing for Windows compatibility

### System Utilities
- **git** - Version control system
- **htop** - Interactive process viewer
- **ncdu** - NCurses disk usage analyzer
- **screen** - Terminal multiplexer for persistent sessions
- **rsync** - Fast incremental file transfer
- **smartmontools** - Hard drive health monitoring
- **net-tools** - Classic networking tools (ifconfig, netstat, etc.)
- **dnsutils** - DNS troubleshooting (dig, nslookup)
- **iperf3** - Network performance testing

### Security & Updates
- **UFW** - Uncomplicated Firewall for easy firewall management
- **unattended-upgrades** - Automatic security updates

## Prerequisites

- Fresh Ubuntu Server installation (22.04 LTS or newer recommended)
- Root or sudo access
- Internet connection

## Usage

1. Download the script:
```bash
wget https://raw.githubusercontent.com/yourusername/ubuntu-server/main/post-install.sh
# or
curl -O https://raw.githubusercontent.com/yourusername/ubuntu-server/main/post-install.sh
```

2. Make it executable:
```bash
chmod +x post-install.sh
```

3. Run the script with sudo:
```bash
sudo bash post-install.sh
```

## Post-Installation Steps

After the script completes, follow these steps:

### 1. Configure Firewall
```bash
# Allow SSH first (important!)
sudo ufw allow 22/tcp

# Allow Webmin
sudo ufw allow 10000/tcp

# Allow Tailscale (optional, if not using exit nodes)
sudo ufw allow 41641/udp

# Enable firewall
sudo ufw enable
```

### 2. Connect to Tailscale
```bash
sudo tailscale up
```
Follow the authentication link provided in the output.

### 3. Access Webmin
Open your browser and navigate to:
```
https://<your-server-ip>:10000
```
Login with your system username and password.

### 4. Test Docker
```bash
docker run hello-world
```
If you were added to the docker group, log out and back in first.

### 5. Configure NFS Exports

Edit `/etc/exports` to add your NFS shares:
```bash
sudo nano /etc/exports
```

Example configuration:
```
/srv/nfs/share    192.168.1.0/24(rw,sync,no_subtree_check)
```

Apply changes:
```bash
sudo exportfs -ra
```

### 6. Configure Samba Shares

Edit `/etc/samba/smb.conf`:
```bash
sudo nano /etc/samba/smb.conf
```

Example share configuration:
```ini
[shared]
   path = /srv/samba/share
   browseable = yes
   read only = no
   guest ok = no
   valid users = @sambashare
   create mask = 0660
   directory mask = 2770
```

Add a Samba user:
```bash
# Create system user if needed
sudo useradd -M -s /sbin/nologin sambauser

# Add to sambashare group
sudo usermod -aG sambashare sambauser

# Set Samba password
sudo smbpasswd -a sambauser
```

Restart Samba:
```bash
sudo systemctl restart smbd nmbd
```

## Default Directories

The script creates the following directories:

- `/srv/nfs/share` - Default NFS export directory (nobody:nogroup, 755)
- `/srv/samba/share` - Default Samba share directory (2775)

## Configuration Files

Backup copies are created for:
- `/etc/exports.backup` - Original NFS exports file
- `/etc/samba/smb.conf.backup` - Original Samba configuration

## Useful Commands

### Docker
```bash
# Check Docker status
sudo systemctl status docker

# View running containers
docker ps

# Remove unused images/containers
docker system prune
```

### Tailscale
```bash
# Check status
tailscale status

# Show IP addresses
tailscale ip

# Disconnect
sudo tailscale down
```

### NFS
```bash
# Show active exports
sudo exportfs -v

# Restart NFS server
sudo systemctl restart nfs-kernel-server
```

### Samba
```bash
# List Samba users
sudo pdbedit -L

# Test configuration
testparm

# Restart Samba
sudo systemctl restart smbd nmbd
```

### System Monitoring
```bash
# Interactive process viewer
htop

# Disk usage analyzer
ncdu /

# Check disk health
sudo smartctl -a /dev/sda

# Network performance test (server side)
iperf3 -s
```

## Troubleshooting

### Webmin Not Accessible
```bash
# Check if Webmin is running
sudo systemctl status webmin

# Check firewall
sudo ufw status

# Restart Webmin
sudo systemctl restart webmin
```

### Docker Permission Denied
```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then verify
groups
```

### NFS Exports Not Working
```bash
# Check exports syntax
sudo exportfs -v

# Check NFS server status
sudo systemctl status nfs-kernel-server

# View NFS logs
sudo journalctl -u nfs-kernel-server
```

### Samba Share Not Accessible
```bash
# Check Samba status
sudo systemctl status smbd nmbd

# Test configuration
testparm

# Check Samba logs
sudo tail -f /var/log/samba/log.smbd
```

## Security Considerations

1. **Change default passwords** - Especially for Webmin
2. **Configure UFW properly** - Only open necessary ports
3. **Use Tailscale** - For secure remote access instead of exposing services publicly
4. **Keep system updated** - Unattended-upgrades is configured for security updates
5. **Monitor logs** - Regularly check system and service logs
6. **Backup configuration** - Before making major changes

## Uninstalling

If you need to remove any component:

```bash
# Docker
sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker /var/lib/containerd

# Tailscale
sudo apt-get purge tailscale

# Webmin
sudo apt-get purge webmin

# NFS Server
sudo apt-get purge nfs-kernel-server

# Samba
sudo apt-get purge samba samba-common-bin
```

## License

This script is provided as-is for personal and educational use.

## Contributing

Feel free to submit issues and enhancement requests!

## Author

Created for simplified Ubuntu Server setup and maintenance.
