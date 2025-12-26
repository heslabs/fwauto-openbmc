#!/bin/bash

#############################################################################
# OpenBMC FVP Quick Verification Script
# Description: Quick checks to verify FVP and BMC are running correctly
# Author: FWAuto Firmware Development Assistant
# Date: 2024-12-26
#############################################################################

# Configuration
REMOTE_HOST="192.168.52.91"
BMC_PASSWORD="0penBmc"
BMC_SSH_PORT=4222
REDFISH_PORT=4223

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       OpenBMC FVP Quick Verification              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Test 1: Check if FVP process is running
echo -n "1. FVP Process:         "
if ps aux | grep -q "[F]VP_RD_V3_R1"; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${RED}❌ Not running${NC}"
fi

# Test 2: Check SSH tunnel
echo -n "2. SSH Tunnel:          "
if lsof -i :$BMC_SSH_PORT -i :5064 -i :5065 | grep -q LISTEN; then
    echo -e "${GREEN}✅ Active${NC}"
else
    echo -e "${RED}❌ Not active${NC}"
fi

# Test 3: BMC SSH access
echo -n "3. BMC SSH Access:      "
if timeout 5 sshpass -p "$BMC_PASSWORD" ssh -p $BMC_SSH_PORT -o StrictHostKeyChecking=no \
    root@localhost "echo OK" 2>/dev/null | grep -q "OK"; then
    echo -e "${GREEN}✅ Accessible${NC}"
else
    echo -e "${RED}❌ Not accessible${NC}"
fi

# Test 4: Redfish API
echo -n "4. Redfish API:         "
if curl -s -k -u root:$BMC_PASSWORD https://127.0.0.1:$REDFISH_PORT/redfish/v1/ \
    2>/dev/null | grep -q "@odata.id"; then
    echo -e "${GREEN}✅ Responding${NC}"
else
    echo -e "${RED}❌ Not responding${NC}"
fi

# Test 5: Console ports
echo -n "5. Console Ports:       "
if lsof -i :5064 -i :5065 -i :5066 -i :5067 | grep -q LISTEN; then
    echo -e "${GREEN}✅ Available${NC}"
else
    echo -e "${YELLOW}⚠️  Not all available${NC}"
fi

echo ""
echo -e "${BLUE}Detailed Information:${NC}"

# Get BMC version
echo -n "  BMC Version: "
sshpass -p "$BMC_PASSWORD" ssh -p $BMC_SSH_PORT -o StrictHostKeyChecking=no \
    root@localhost "cat /etc/os-release | grep VERSION_ID" 2>/dev/null | cut -d= -f2 || echo "N/A"

# Get Redfish version
echo -n "  Redfish Version: "
curl -s -k -u root:$BMC_PASSWORD https://127.0.0.1:$REDFISH_PORT/redfish/v1/ 2>/dev/null | \
    grep -o '"RedfishVersion":"[^"]*"' | cut -d'"' -f4 || echo "N/A"

# Check MCTP service
echo -n "  MCTP Service: "
sshpass -p "$BMC_PASSWORD" ssh -p $BMC_SSH_PORT -o StrictHostKeyChecking=no \
    root@localhost "systemctl is-active mctpd.service" 2>/dev/null || echo "N/A"

echo ""
