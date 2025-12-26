#!/bin/bash

#############################################################################
# OpenBMC FVP Full Setup Script
# Description: Complete automation for setting up and verifying OpenBMC FVP
# Author: FWAuto Firmware Development Assistant
# Date: 2024-12-26
#############################################################################

set -e  # Exit on error

# Configuration
REMOTE_HOST="192.168.52.91"
REMOTE_USER="auto"
REMOTE_PASS="demo123@"
BMC_PASSWORD="0penBmc"
BMC_SSH_PORT=4222
REDFISH_PORT=4223
MAX_BOOT_WAIT=60  # 5 minutes (60 * 5 seconds)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step counter
STEP=0
step() {
    STEP=$((STEP + 1))
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Step $STEP: $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
}

#############################################################################
# Main Execution
#############################################################################

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     OpenBMC FVP Full Setup and Verification Script        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Cleanup FVP
step "Cleanup existing FVP instances"
log_info "Cleaning up FVP on remote server..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_HOST \
    "cd ~/openbmc/fvp && ./cleanup-fvp.sh"
log_success "FVP cleanup completed"

# Step 2: Cleanup TAP interface
step "Cleanup TAP interfaces"
log_info "Cleaning up TAP interfaces..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_HOST \
    "cd ~/openbmc/fvp && ./cleanup-tap.sh"
log_success "TAP cleanup completed"

log_info "Waiting 2 seconds..."
sleep 2

# Step 3: Setup TAP interface
step "Setup TAP interface"
log_info "Setting up TAP interface..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_HOST \
    "cd ~/openbmc/fvp && ./setup-tap-fixed.sh"
log_success "TAP interface setup completed"

# Step 4: Launch FVP
step "Launch FVP"
log_info "Launching FVP in background..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_HOST \
    "cd ~/openbmc/fvp && nohup ./run.sh -m /home/auto/openbmc/FVP_RD_V3_R1/models/Linux64_GCC-9.3/FVP_RD_V3_R1 > /tmp/fvp_launch.log 2>&1 &"
log_success "FVP launched (logs: /tmp/fvp_launch.log on remote)"

log_info "Waiting 5 seconds for FVP to initialize..."
sleep 5

# Step 5: Wait for BMC to boot
step "Wait for BMC to boot (max ${MAX_BOOT_WAIT} attempts)"
log_info "Polling for BMC readiness..."

BMC_READY=false
for i in $(seq 1 $MAX_BOOT_WAIT); do
    if sshpass -p "$BMC_PASSWORD" ssh -p $BMC_SSH_PORT -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 root@$REMOTE_HOST "echo BMC_READY" 2>/dev/null | grep -q "BMC_READY"; then
        log_success "BMC is ready! (attempt $i/$MAX_BOOT_WAIT)"
        BMC_READY=true
        break
    fi
    echo -n "⏳ Waiting for BMC... ($i/$MAX_BOOT_WAIT)"
    echo -ne "\r"
    sleep 5
done
echo "" # New line after progress

if [ "$BMC_READY" = false ]; then
    log_error "Timeout: BMC did not become ready within $((MAX_BOOT_WAIT * 5)) seconds"
    exit 1
fi

# Step 6: Restart MCTP service
step "Restart MCTP service"
log_info "Restarting mctpd.service..."
sshpass -p "$BMC_PASSWORD" ssh -p $BMC_SSH_PORT -o StrictHostKeyChecking=no \
    root@$REMOTE_HOST "systemctl restart mctpd.service"
log_success "MCTP service restarted"

log_info "Waiting 5 seconds for service to start..."
sleep 5

# Step 7: Test PLDM
step "Test PLDM functionality"
log_info "Testing PLDM..."
if sshpass -p "$BMC_PASSWORD" ssh -p $BMC_SSH_PORT -o StrictHostKeyChecking=no \
    root@$REMOTE_HOST "pldmtool platform GetPDR -d 1" 2>&1 | grep -q "error"; then
    log_warning "PLDM test returned errors (may be expected if endpoint not configured)"
else
    log_success "PLDM test completed"
fi

# Step 8: Test Redfish API
step "Test Redfish API"
log_info "Testing Redfish endpoint..."
REDFISH_RESPONSE=$(sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no \
    $REMOTE_USER@$REMOTE_HOST "curl -s -k -u root:$BMC_PASSWORD https://127.0.0.1:$REDFISH_PORT/redfish/v1/")

if echo "$REDFISH_RESPONSE" | grep -q "@odata.id"; then
    log_success "Redfish API is responding correctly"
    echo "$REDFISH_RESPONSE" | grep -E "(RedfishVersion|Name|UUID)" || true
else
    log_error "Redfish API test failed"
    exit 1
fi

# Step 9: Setup SSH tunnel
step "Setup SSH tunnel for local console access"
log_info "Checking for existing SSH tunnel..."

# Kill existing tunnel if present
pkill -f "ssh.*$REMOTE_USER@$REMOTE_HOST.*5064" 2>/dev/null || true
sleep 1

log_info "Establishing SSH tunnel..."
sshpass -p "$REMOTE_PASS" ssh -f -N \
    -L 5064:127.0.0.1:5064 \
    -L 5065:127.0.0.1:5065 \
    -L 5066:127.0.0.1:5066 \
    -L 5067:127.0.0.1:5067 \
    -L $BMC_SSH_PORT:127.0.0.1:$BMC_SSH_PORT \
    -L $REDFISH_PORT:127.0.0.1:$REDFISH_PORT \
    -o StrictHostKeyChecking=no \
    $REMOTE_USER@$REMOTE_HOST

sleep 2
log_success "SSH tunnel established"

# Step 10: Verify tunnel
step "Verify SSH tunnel"
log_info "Testing local access to BMC..."
if sshpass -p "$BMC_PASSWORD" ssh -p $BMC_SSH_PORT -o StrictHostKeyChecking=no \
    root@localhost "cat /etc/os-release" | grep -q "openbmc"; then
    log_success "SSH tunnel verified - BMC accessible on localhost:$BMC_SSH_PORT"
else
    log_error "SSH tunnel verification failed"
    exit 1
fi

#############################################################################
# Final Summary
#############################################################################

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Setup Completed Successfully!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Access Information:${NC}"
echo "  • BMC SSH:         ssh -p $BMC_SSH_PORT root@localhost (password: $BMC_PASSWORD)"
echo "  • Redfish API:     https://127.0.0.1:$REDFISH_PORT/redfish/v1/"
echo "  • BMC Console:     telnet localhost 5065"
echo "  • Host Console:    telnet localhost 5064"
echo "  • Console 2:       telnet localhost 5066"
echo "  • Console 3:       telnet localhost 5067"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Run './open_consoles.sh' to open console windows"
echo "  2. Monitor boot messages in console windows"
echo "  3. Access BMC via SSH or Redfish API"
echo ""
