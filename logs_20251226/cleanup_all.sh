#!/bin/bash

#############################################################################
# OpenBMC FVP Cleanup Script
# Description: Stops FVP, closes tunnels, and cleans up all resources
# Author: FWAuto Firmware Development Assistant
# Date: 2024-12-26
#############################################################################

# Configuration
REMOTE_HOST="192.168.52.91"
REMOTE_USER="auto"
REMOTE_PASS="demo123@"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║          OpenBMC FVP Cleanup Script               ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Kill local SSH tunnel
echo -e "${BLUE}[1/4]${NC} Closing SSH tunnel..."
if pkill -f "ssh.*$REMOTE_USER@$REMOTE_HOST.*5064"; then
    echo -e "${GREEN}✅ SSH tunnel closed${NC}"
else
    echo -e "${YELLOW}⚠️  No SSH tunnel found${NC}"
fi

# Step 2: Close console windows
echo -e "${BLUE}[2/4]${NC} Closing console windows..."
pkill -f "telnet localhost 506" 2>/dev/null && echo -e "${GREEN}✅ Console windows closed${NC}" || \
    echo -e "${YELLOW}⚠️  No console windows found${NC}"

# Step 3: Stop FVP on remote
echo -e "${BLUE}[3/4]${NC} Stopping FVP on remote server..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_HOST \
    "cd ~/openbmc/fvp && ./cleanup-fvp.sh" && \
    echo -e "${GREEN}✅ FVP stopped${NC}" || \
    echo -e "${RED}❌ Failed to stop FVP${NC}"

# Step 4: Cleanup TAP interfaces
echo -e "${BLUE}[4/4]${NC} Cleaning up TAP interfaces..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_HOST \
    "cd ~/openbmc/fvp && ./cleanup-tap.sh" && \
    echo -e "${GREEN}✅ TAP interfaces cleaned${NC}" || \
    echo -e "${RED}❌ Failed to clean TAP interfaces${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Cleanup Completed!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo "You can now run './full_setup.sh' to start fresh."
echo ""
