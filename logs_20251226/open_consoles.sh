#!/bin/bash

#############################################################################
# OpenBMC FVP Console Opener Script
# Description: Opens xterm/gnome-terminal windows for FVP consoles
# Author: FWAuto Firmware Development Assistant
# Date: 2024-12-26
#############################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Opening FVP Console Windows               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Check which terminal emulator is available
if command -v xterm &> /dev/null; then
    TERMINAL="xterm"
    echo -e "${BLUE}Using xterm terminal emulator${NC}"
elif command -v gnome-terminal &> /dev/null; then
    TERMINAL="gnome-terminal"
    echo -e "${BLUE}Using gnome-terminal emulator${NC}"
else
    echo -e "${YELLOW}Warning: Neither xterm nor gnome-terminal found${NC}"
    echo "Please install xterm: sudo apt install xterm"
    exit 1
fi

# Open console windows based on available terminal
if [ "$TERMINAL" = "xterm" ]; then
    echo "Opening console windows with xterm..."

    xterm -T "BMC Console (Port 5065)" -e "telnet localhost 5065" &
    sleep 0.5

    xterm -T "Host Console (Port 5064)" -e "telnet localhost 5064" &
    sleep 0.5

    xterm -T "Console 2 (Port 5066)" -e "telnet localhost 5066" &
    sleep 0.5

    xterm -T "Console 3 (Port 5067)" -e "telnet localhost 5067" &

elif [ "$TERMINAL" = "gnome-terminal" ]; then
    echo "Opening console windows with gnome-terminal..."

    gnome-terminal --title="BMC Console (Port 5065)" -- telnet localhost 5065 &
    sleep 0.5

    gnome-terminal --title="Host Console (Port 5064)" -- telnet localhost 5064 &
    sleep 0.5

    gnome-terminal --title="Console 2 (Port 5066)" -- telnet localhost 5066 &
    sleep 0.5

    gnome-terminal --title="Console 3 (Port 5067)" -- telnet localhost 5067 &
fi

sleep 1
echo ""
echo -e "${GREEN}✅ Console windows opened!${NC}"
echo ""
echo -e "${BLUE}Console Information:${NC}"
echo "  • Port 5065: BMC Console (main BMC serial output)"
echo "  • Port 5064: Host Console (host CPU serial output)"
echo "  • Port 5066: Additional Console 2"
echo "  • Port 5067: Additional Console 3"
echo ""
echo -e "${YELLOW}Note:${NC} To close all consoles, close the terminal windows or press Ctrl+] then 'quit'"
echo ""
