#!/bin/bash
#
# Console Window Launcher for OpenBMC FVP
# This script opens terminal windows showing BMC and Host console output
#
# Usage: ./open-console-windows.sh
#

# Configuration
REMOTE_HOST="192.168.52.91"
REMOTE_USER="auto"
REMOTE_PASS="demo123@"
BMC_PASSWORD="0penBmc"

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

# Detect available terminal emulator
detect_terminal() {
    if command -v gnome-terminal &> /dev/null; then
        echo "gnome-terminal"
    elif command -v konsole &> /dev/null; then
        echo "konsole"
    elif command -v xfce4-terminal &> /dev/null; then
        echo "xfce4-terminal"
    elif command -v xterm &> /dev/null; then
        echo "xterm"
    else
        echo ""
    fi
}

TERMINAL=$(detect_terminal)

if [ -z "$TERMINAL" ]; then
    log_error "No terminal emulator found. Please install one of:"
    echo "  - gnome-terminal"
    echo "  - konsole"
    echo "  - xfce4-terminal"
    echo "  - xterm"
    exit 1
fi

log_info "Using terminal: $TERMINAL"

# Check if tunnels are established
if ! netstat -tuln 2>/dev/null | grep -q ":4222 " && ! ss -tuln 2>/dev/null | grep -q ":4222 "; then
    log_warn "SSH tunnels may not be established. Run ./setup-ssh-tunnels.sh first"
    log_info "Attempting to use remote connection instead..."
    USE_REMOTE=1
fi

# Function to open console window
open_console() {
    local title="$1"
    local command="$2"

    case "$TERMINAL" in
        gnome-terminal)
            gnome-terminal --title="$title" -- bash -c "$command; exec bash" &
            ;;
        konsole)
            konsole --title "$title" -e bash -c "$command; exec bash" &
            ;;
        xfce4-terminal)
            xfce4-terminal --title="$title" -e "bash -c '$command; exec bash'" &
            ;;
        xterm)
            xterm -T "$title" -e bash -c "$command; exec bash" &
            ;;
    esac
}

log_info "Opening console windows..."

# BMC Console Window
if [ -z "$USE_REMOTE" ]; then
    # Use local tunnel
    BMC_CMD="echo 'Connecting to BMC Console via SSH tunnel...'; sshpass -p '${BMC_PASSWORD}' ssh -p 4222 -o StrictHostKeyChecking=no root@localhost"
else
    # Use remote connection
    BMC_CMD="echo 'Connecting to BMC Console via remote host...'; sshpass -p '${REMOTE_PASS}' ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} \"sshpass -p '${BMC_PASSWORD}' ssh -p 4222 -o StrictHostKeyChecking=no root@127.0.0.1\""
fi

log_info "Opening BMC Console window..."
open_console "BMC Console (OpenBMC FVP)" "$BMC_CMD"

sleep 1

# Host Console Window (if available)
if [ -z "$USE_REMOTE" ]; then
    # Check if host SSH is available
    if timeout 2 bash -c "echo | nc localhost 4223" 2>/dev/null; then
        HOST_CMD="echo 'Connecting to Host Console via SSH tunnel...'; ssh -p 4223 -o StrictHostKeyChecking=no root@localhost"
        log_info "Opening Host Console window..."
        open_console "Host Console (FVP)" "$HOST_CMD"
    else
        log_warn "Host SSH (port 4223) not responding - skipping Host Console"
    fi
fi

# BMC Serial Console via FVP (if running on remote)
log_info "Opening FVP Serial Console window (BMC)..."
FVP_BMC_CMD="echo 'Connecting to FVP BMC Serial Console...'; sshpass -p '${REMOTE_PASS}' ssh -t -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} 'telnet localhost 5000'"
open_console "FVP Serial Console - BMC" "$FVP_BMC_CMD"

sleep 1

# Host Serial Console via FVP (if running on remote)
log_info "Opening FVP Serial Console window (Host)..."
FVP_HOST_CMD="echo 'Connecting to FVP Host Serial Console...'; sshpass -p '${REMOTE_PASS}' ssh -t -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} 'telnet localhost 5001'"
open_console "FVP Serial Console - Host" "$FVP_HOST_CMD"

echo ""
log_info "Console windows opened successfully!"
log_info "You should see 2-4 terminal windows with console access"
echo ""
log_info "Console types:"
echo "  1. BMC Console (SSH) - Interactive BMC shell"
echo "  2. Host Console (SSH) - Interactive Host shell (if available)"
echo "  3. FVP Serial Console (BMC) - Serial output via telnet port 5000"
echo "  4. FVP Serial Console (Host) - Serial output via telnet port 5001"
echo ""
log_info "To close all consoles, simply close the terminal windows"
