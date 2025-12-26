#!/bin/bash
#
# Complete OpenBMC FVP Setup Script
# This script performs the full setup: remote FVP launch + local SSH tunnels + console windows
#
# Usage: ./full-setup.sh [--skip-tunnels] [--skip-consoles]
#

set -e

# Configuration
REMOTE_HOST="192.168.52.91"
REMOTE_USER="auto"
REMOTE_PASS="demo123@"
BMC_PASSWORD="0penBmc"
FVP_MODEL_PATH="/home/auto/openbmc/FVP_RD_V3_R1/models/Linux64_GCC-9.3/FVP_RD_V3_R1"
FVP_DIR="~/openbmc/fvp"
MAX_WAIT_ATTEMPTS=60
WAIT_INTERVAL=5

# Parse arguments
SKIP_TUNNELS=0
SKIP_CONSOLES=0

for arg in "$@"; do
    case $arg in
        --skip-tunnels)
            SKIP_TUNNELS=1
            ;;
        --skip-consoles)
            SKIP_CONSOLES=1
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-tunnels   Skip SSH tunnel setup"
            echo "  --skip-consoles  Skip console window opening"
            echo "  --help           Show this help message"
            exit 0
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

remote_exec() {
    sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" "$1"
}

bmc_exec() {
    sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" \
        "sshpass -p '${BMC_PASSWORD}' ssh -p 4222 -o StrictHostKeyChecking=no root@127.0.0.1 \"$1\""
}

# Main execution
echo ""
log_info "=================================================="
log_info "  OpenBMC FVP Complete Setup Script"
log_info "=================================================="
echo ""

# PART 1: Remote FVP Setup
log_step "PART 1: Remote FVP Setup"

# Step 0: Test connection
log_info "Step 0: Testing connection to remote PC..."
if remote_exec "echo 'Connected successfully'" > /dev/null 2>&1; then
    log_info "✓ Connected to ${REMOTE_HOST}"
else
    log_error "✗ Failed to connect to ${REMOTE_HOST}"
    exit 1
fi

# Step 1: Setup TAP interface
log_info "Step 1: Setting up TAP interface..."
remote_exec "cd ${FVP_DIR} && ./cleanup-fvp.sh" > /dev/null 2>&1
log_info "  - FVP processes cleaned up"

remote_exec "cd ${FVP_DIR} && ./cleanup-tap.sh" > /dev/null 2>&1
log_info "  - TAP interfaces cleaned up"

sleep 2

remote_exec "cd ${FVP_DIR} && ./setup-tap-fixed.sh" > /dev/null 2>&1
log_info "  - TAP interfaces configured"

log_info "✓ TAP interface setup complete"

# Step 2: Launch FVP
log_info "Step 2: Launching FVP..."
remote_exec "cd ${FVP_DIR} && nohup ./run.sh -m ${FVP_MODEL_PATH} > /tmp/fvp_run.log 2>&1 &"
sleep 5

FVP_COUNT=$(remote_exec "ps aux | grep 'FVP_RD_V3_R1' | grep -v grep | wc -l")
if [ "$FVP_COUNT" -gt 0 ]; then
    log_info "✓ FVP launched successfully (${FVP_COUNT} processes)"
else
    log_error "✗ FVP failed to launch"
    exit 1
fi

# Step 3: Wait for BMC
log_info "Step 3: Waiting for BMC to be ready..."
BMC_READY=0
for i in $(seq 1 $MAX_WAIT_ATTEMPTS); do
    if bmc_exec "echo BMC_READY" > /dev/null 2>&1; then
        log_info "✓ BMC ready after $i attempts"
        BMC_READY=1
        break
    fi
    echo -n "."
    sleep $WAIT_INTERVAL
done
echo ""

if [ $BMC_READY -eq 0 ]; then
    log_error "✗ Timeout waiting for BMC"
    exit 1
fi

# Step 4: Restart MCTP
log_info "Step 4: Restarting MCTP service..."
bmc_exec "systemctl restart mctpd.service" > /dev/null 2>&1
sleep 5
log_info "✓ MCTP service restarted"

# Step 5: Verification
log_info "Step 5: Verifying remote setup..."

FVP_COUNT=$(remote_exec "ps aux | grep 'FVP_RD_V3_R1' | grep -v grep | wc -l")
log_info "  ✓ FVP running (${FVP_COUNT} processes)"

if bmc_exec "echo BMC_READY" > /dev/null 2>&1; then
    log_info "  ✓ BMC SSH accessible"
fi

MCTP_STATUS=$(bmc_exec "systemctl is-active mctpd.service" 2>/dev/null || echo "unknown")
if [ "$MCTP_STATUS" = "active" ]; then
    log_info "  ✓ MCTP service active"
fi

PORTS=$(remote_exec "netstat -tuln 2>/dev/null | grep -E ':(4222|4223|5064|5065|5066|5067)' | wc -l || ss -tuln | grep -E ':(4222|4223|5064|5065|5066|5067)' | wc -l")
log_info "  ✓ Ports listening (${PORTS}/6)"

log_info "✓ Remote FVP setup complete"

# PART 2: Local SSH Tunnels
if [ $SKIP_TUNNELS -eq 0 ]; then
    log_step "PART 2: Setting up SSH Tunnels"

    log_info "Establishing SSH tunnels from local machine to remote FVP..."

    # Kill existing tunnels
    pkill -f "ssh.*${REMOTE_HOST}.*-L" 2>/dev/null || true
    sleep 1

    # Create tunnels
    TUNNEL_ARGS="-L 4222:127.0.0.1:4222 -L 4223:127.0.0.1:4223 -L 5064:127.0.0.1:5064 -L 5065:127.0.0.1:5065 -L 5066:127.0.0.1:5066 -L 5067:127.0.0.1:5067"

    sshpass -p "${REMOTE_PASS}" ssh -N -f \
        -o StrictHostKeyChecking=no \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        ${TUNNEL_ARGS} \
        ${REMOTE_USER}@${REMOTE_HOST}

    sleep 2

    # Verify tunnels
    TUNNEL_COUNT=0
    for port in 4222 4223 5064 5065 5066 5067; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
            ((TUNNEL_COUNT++))
        fi
    done

    log_info "✓ SSH tunnels established (${TUNNEL_COUNT}/6 ports)"
    log_info "  You can now access BMC locally: ssh -p 4222 root@localhost"
else
    log_warn "Skipping SSH tunnel setup (--skip-tunnels)"
fi

# PART 3: Console Windows
if [ $SKIP_CONSOLES -eq 0 ]; then
    log_step "PART 3: Opening Console Windows"

    log_info "Launching console windows..."

    # Check if we have a terminal emulator
    if command -v gnome-terminal &> /dev/null || command -v konsole &> /dev/null || \
       command -v xfce4-terminal &> /dev/null || command -v xterm &> /dev/null; then

        # Run the console window script
        bash "$(dirname "$0")/open-console-windows.sh" > /dev/null 2>&1 &

        sleep 2
        log_info "✓ Console windows opened"
        log_info "  Check your desktop for new terminal windows"
    else
        log_warn "No terminal emulator found - skipping console windows"
        log_info "  You can manually connect to:"
        log_info "  - BMC SSH: ssh -p 4222 root@localhost (password: ${BMC_PASSWORD})"
        log_info "  - FVP Serial (BMC): telnet ${REMOTE_HOST} 5000"
        log_info "  - FVP Serial (Host): telnet ${REMOTE_HOST} 5001"
    fi
else
    log_warn "Skipping console window opening (--skip-consoles)"
fi

# Final summary
echo ""
log_info "=================================================="
log_info "  Setup Complete!"
log_info "=================================================="
echo ""
log_info "Access Methods:"
echo ""
log_info "  Via SSH Tunnel (Local):"
echo "    ssh -p 4222 root@localhost"
echo "    Password: ${BMC_PASSWORD}"
echo ""
log_info "  Via Remote Host:"
echo "    sshpass -p '${REMOTE_PASS}' ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo "    Then: ssh -p 4222 root@127.0.0.1"
echo ""
log_info "  Redfish API:"
echo "    https://localhost:5064/redfish/v1"
echo ""
log_info "  Serial Consoles:"
echo "    telnet ${REMOTE_HOST} 5000  # BMC"
echo "    telnet ${REMOTE_HOST} 5001  # Host"
echo ""
log_info "To stop FVP:"
echo "  sshpass -p '${REMOTE_PASS}' ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${FVP_DIR} && ./cleanup-fvp.sh'"
echo ""
log_info "To close SSH tunnels:"
echo "  pkill -f 'ssh.*${REMOTE_HOST}.*-L'"
echo ""
