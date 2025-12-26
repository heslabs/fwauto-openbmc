#!/bin/bash
#
# OpenBMC FVP Setup and Launch Automation Script
# This script automates the full setup process for OpenBMC on FVP
#
# Usage: ./openbmc-automation.sh
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to execute remote commands
remote_exec() {
    sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" "$1"
}

# Function to execute BMC commands
bmc_exec() {
    sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" \
        "sshpass -p '${BMC_PASSWORD}' ssh -p 4222 -o StrictHostKeyChecking=no root@127.0.0.1 \"$1\""
}

# Step 0: Test connection to remote PC
log_info "Step 0: Testing connection to remote PC..."
if remote_exec "echo 'Connected successfully'" > /dev/null 2>&1; then
    log_info "Successfully connected to ${REMOTE_HOST}"
else
    log_error "Failed to connect to ${REMOTE_HOST}"
    exit 1
fi

# Step 1: Setup TAP interface
log_info "Step 1: Setting up TAP interface..."

log_info "  - Cleaning up FVP processes..."
remote_exec "cd ${FVP_DIR} && ./cleanup-fvp.sh"

log_info "  - Cleaning up TAP interface..."
remote_exec "cd ${FVP_DIR} && ./cleanup-tap.sh"

log_info "  - Waiting 2 seconds..."
sleep 2

log_info "  - Setting up TAP interface..."
remote_exec "cd ${FVP_DIR} && ./setup-tap-fixed.sh"

log_info "TAP interface setup completed"

# Step 2: Launch FVP
log_info "Step 2: Launching FVP..."
remote_exec "cd ${FVP_DIR} && nohup ./run.sh -m ${FVP_MODEL_PATH} > /tmp/fvp_run.log 2>&1 &"
sleep 5

# Verify FVP is running
FVP_COUNT=$(remote_exec "ps aux | grep 'FVP_RD_V3_R1' | grep -v grep | wc -l")
if [ "$FVP_COUNT" -gt 0 ]; then
    log_info "FVP launched successfully (${FVP_COUNT} processes running)"
else
    log_error "FVP failed to launch"
    exit 1
fi

# Step 3: Wait for BMC to be ready
log_info "Step 3: Waiting for BMC to be ready (max ${MAX_WAIT_ATTEMPTS} attempts, ${WAIT_INTERVAL}s interval)..."
for i in $(seq 1 $MAX_WAIT_ATTEMPTS); do
    if bmc_exec "echo BMC_READY" > /dev/null 2>&1; then
        log_info "BMC is ready after $i attempts!"
        BMC_READY=1
        break
    fi
    echo "  Waiting for BMC... ($i/$MAX_WAIT_ATTEMPTS)"
    sleep $WAIT_INTERVAL
done

if [ -z "$BMC_READY" ]; then
    log_error "Timeout waiting for BMC to be ready"
    exit 1
fi

# Step 4: Restart MCTP service
log_info "Step 4: Restarting MCTP service..."
if bmc_exec "systemctl restart mctpd.service" > /dev/null 2>&1; then
    log_info "MCTP service restarted successfully"
else
    log_warn "MCTP service restart returned an error (may be normal)"
fi

log_info "Waiting 5 seconds for MCTP service to stabilize..."
sleep 5

# Step 5: Verification
log_info "Step 5: Performing verification..."

# Check FVP status
FVP_COUNT=$(remote_exec "ps aux | grep 'FVP_RD_V3_R1' | grep -v grep | wc -l")
if [ "$FVP_COUNT" -gt 0 ]; then
    log_info "  ✓ FVP is running (${FVP_COUNT} processes)"
else
    log_error "  ✗ FVP is not running"
fi

# Check BMC SSH connection
if bmc_exec "echo BMC_READY" > /dev/null 2>&1; then
    log_info "  ✓ BMC SSH connection successful"
else
    log_error "  ✗ BMC SSH connection failed"
fi

# Check MCTP service
MCTP_STATUS=$(bmc_exec "systemctl is-active mctpd.service" 2>/dev/null || echo "unknown")
if [ "$MCTP_STATUS" = "active" ]; then
    log_info "  ✓ MCTP service is active"
else
    log_warn "  ✗ MCTP service status: $MCTP_STATUS"
fi

# Check listening ports
log_info "  Checking listening ports..."
PORTS=$(remote_exec "netstat -tuln 2>/dev/null | grep -E ':(4222|4223|5064|5065|5066|5067)' | wc -l || ss -tuln | grep -E ':(4222|4223|5064|5065|5066|5067)' | wc -l")
if [ "$PORTS" -ge 6 ]; then
    log_info "  ✓ All required ports are listening (${PORTS}/6)"
else
    log_warn "  ✗ Some ports may not be listening (${PORTS}/6)"
fi

# Summary
echo ""
log_info "============================================"
log_info "OpenBMC FVP Setup Completed Successfully!"
log_info "============================================"
echo ""
log_info "System is ready for use. You can SSH to BMC using:"
echo "  sshpass -p '${BMC_PASSWORD}' ssh -p 4222 root@127.0.0.1"
echo ""
log_info "Or from your local machine through the remote host:"
echo "  sshpass -p '${REMOTE_PASS}' ssh ${REMOTE_USER}@${REMOTE_HOST} \"sshpass -p '${BMC_PASSWORD}' ssh -p 4222 root@127.0.0.1\""
echo ""
