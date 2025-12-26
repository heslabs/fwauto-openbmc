#!/bin/bash
#
# SSH Tunnel Setup Script for OpenBMC FVP
# This script establishes SSH tunnels from local machine to remote FVP services
#
# Usage: ./setup-ssh-tunnels.sh
#

# Configuration
REMOTE_HOST="192.168.52.91"
REMOTE_USER="auto"
REMOTE_PASS="demo123@"

# Tunnel configuration: local_port:remote_host:remote_port
TUNNELS=(
    "4222:127.0.0.1:4222"  # BMC SSH
    "4223:127.0.0.1:4223"  # Host SSH
    "5064:127.0.0.1:5064"  # Redfish BMC
    "5065:127.0.0.1:5065"  # Redfish Secondary
    "5066:127.0.0.1:5066"  # Redfish Tertiary
    "5067:127.0.0.1:5067"  # Redfish Quaternary
)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    log_error "sshpass is not installed. Please install it first:"
    echo "  sudo apt-get install sshpass  # Debian/Ubuntu"
    echo "  sudo yum install sshpass      # RHEL/CentOS"
    exit 1
fi

# Kill existing SSH tunnels
log_info "Cleaning up existing SSH tunnels..."
pkill -f "ssh.*${REMOTE_HOST}.*-L" || true
sleep 1

# Build tunnel arguments
TUNNEL_ARGS=""
for tunnel in "${TUNNELS[@]}"; do
    TUNNEL_ARGS="${TUNNEL_ARGS} -L ${tunnel}"
done

# Start SSH tunnel in background
log_info "Establishing SSH tunnels to ${REMOTE_HOST}..."
log_info "Tunneling ports: 4222, 4223, 5064-5067"

sshpass -p "${REMOTE_PASS}" ssh -N -f \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    ${TUNNEL_ARGS} \
    ${REMOTE_USER}@${REMOTE_HOST}

if [ $? -eq 0 ]; then
    log_info "SSH tunnels established successfully!"
    echo ""
    log_info "You can now access services locally:"
    echo "  - BMC SSH:        ssh -p 4222 root@localhost (password: 0penBmc)"
    echo "  - Host SSH:       ssh -p 4223 root@localhost"
    echo "  - Redfish API:    https://localhost:5064/redfish/v1"
    echo ""
    log_info "To view tunnel status:"
    echo "  ps aux | grep 'ssh.*${REMOTE_HOST}.*-L'"
    echo ""
    log_info "To close tunnels:"
    echo "  pkill -f 'ssh.*${REMOTE_HOST}.*-L'"
else
    log_error "Failed to establish SSH tunnels"
    exit 1
fi

# Verify tunnels
sleep 2
log_info "Verifying tunnels..."
for tunnel in "${TUNNELS[@]}"; do
    local_port=$(echo $tunnel | cut -d: -f1)
    if netstat -tuln 2>/dev/null | grep -q ":${local_port} " || ss -tuln 2>/dev/null | grep -q ":${local_port} "; then
        log_info "  ✓ Port ${local_port} is listening"
    else
        log_warn "  ✗ Port ${local_port} may not be listening"
    fi
done

echo ""
log_info "SSH tunnel setup complete!"
