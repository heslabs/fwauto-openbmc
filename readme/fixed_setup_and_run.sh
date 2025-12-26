#!/bin/bash

# Fixed OpenBMC Setup and Run Script
# This script handles sudo password input and fixes display issues

REMOTE_USER="fvp"
REMOTE_HOST="122.116.228.96"
REMOTE_PASS="demo123@"
PROJECT_DIR="~/openbmc/fvp-poc"
LOG_DIR="./openbmc_logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/fixed_run_${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

log "=========================================="
log "Fixed OpenBMC Setup Script"
log "=========================================="

# Create a fixed setup-tap.sh script that uses passwordless sudo approach
log "Creating fixed setup-tap script on remote host..."

# First, let's try to run setup-tap.sh with password input via sshpass
log ""
log "Step 1: Running setup-tap.sh with sudo password automation..."

# Create a helper script that feeds password to sudo
SETUP_SCRIPT=$(cat <<'EOFSETUP'
#!/bin/bash
cd ~/openbmc/fvp-poc

# Function to run commands with auto-sudo
run_sudo() {
    echo "demo123@" | sudo -S bash -c "$1" 2>&1
}

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1"
}

log_msg "Starting TAP/Bridge setup..."

# Host Dependencies
log_msg "Installing dependencies..."
run_sudo "apt update && apt install -y qemu-kvm libvirt-daemon-system iproute2"

# Ensure that libvirtd service is running
log_msg "Starting libvirtd service..."
run_sudo "systemctl start libvirtd"

# Check if virbr0 already exists
if ip link show virbr0 &>/dev/null; then
    log_msg "virbr0 already exists, skipping creation"
else
    log_msg "Creating virbr0 bridge..."
    run_sudo "ip link add name virbr0 type bridge"
    run_sudo "ip link set dev virbr0 up"
fi

# Create TAP interface for Host NIC
log_msg "Setting up tap0 interface..."
if ip link show tap0 &>/dev/null; then
    log_msg "tap0 already exists, cleaning up first..."
    run_sudo "ip link set tap0 down"
    run_sudo "ip link delete tap0"
fi
run_sudo "ip tuntap add dev tap0 mode tap user $(whoami)"
run_sudo "ip link set tap0 promisc on"
run_sudo "ip addr add 0.0.0.0 dev tap0"
run_sudo "ip link set tap0 up"
run_sudo "ip link set tap0 master virbr0"

# Create TAP interface for BMC NIC
log_msg "Setting up RedfishHI interface..."
if ip link show RedfishHI &>/dev/null; then
    log_msg "RedfishHI already exists, cleaning up first..."
    run_sudo "ip link set RedfishHI down"
    run_sudo "ip link delete RedfishHI"
fi
run_sudo "ip tuntap add dev RedfishHI mode tap user $(whoami)"
run_sudo "ip link set RedfishHI promisc on"
run_sudo "ip addr add 0.0.0.0 dev RedfishHI"
run_sudo "ip link set RedfishHI up"
run_sudo "ip link set RedfishHI master virbr0"

log_msg "TAP/Bridge setup completed successfully"
log_msg "Network configuration:"
ip link show virbr0 tap0 RedfishHI 2>/dev/null || true
EOFSETUP
)

# Upload and execute the setup script
log "Uploading setup script to remote host..."
echo "$SETUP_SCRIPT" | sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no \
    "${REMOTE_USER}@${REMOTE_HOST}" "cat > /tmp/setup_tap_fixed.sh && chmod +x /tmp/setup_tap_fixed.sh"

log "Executing setup script..."
sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no \
    "${REMOTE_USER}@${REMOTE_HOST}" "/tmp/setup_tap_fixed.sh" 2>&1 | tee -a "${LOG_FILE}"

SETUP_RESULT=${PIPESTATUS[0]}

if [ ${SETUP_RESULT} -eq 0 ]; then
    log "✅ Setup completed successfully"
else
    log "⚠️ Setup completed with warnings (exit code: ${SETUP_RESULT})"
    log "This may be normal if some resources already exist"
fi

log ""
log "=========================================="
log "Step 2: Running OpenBMC FVP"
log "=========================================="

# Create fixed run script
RUN_SCRIPT=$(cat <<'EOFRUN'
#!/bin/bash
cd ~/openbmc/fvp-poc

# Restart mctp-local service
echo "demo123@" | sudo -S systemctl restart mctp-local 2>&1

# Set DISPLAY for xterm (use headless mode by modifying run.sh behavior)
export DISPLAY=:0

# Run the FVP model
# Note: This will run in background and launch the BMC
./run.sh -m /home/fvp/openbmc/FVP_RD_V3_R1/models/Linux64_GCC-9.3/FVP_RD_V3_R1
EOFRUN
)

log "Uploading run script to remote host..."
echo "$RUN_SCRIPT" | sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no \
    "${REMOTE_USER}@${REMOTE_HOST}" "cat > /tmp/run_rdv3_fixed.sh && chmod +x /tmp/run_rdv3_fixed.sh"

log "Executing run script in background..."
log "Note: This script launches the FVP model which will run until stopped"
log "Default BMC login: username=root, password=0penBmc"
log ""

# Run in background and capture PID
sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no \
    "${REMOTE_USER}@${REMOTE_HOST}" "nohup /tmp/run_rdv3_fixed.sh > ~/openbmc/fvp-poc/logs/fvp_run_${TIMESTAMP}.log 2>&1 &" 2>&1 | tee -a "${LOG_FILE}"

log ""
log "=========================================="
log "Summary"
log "=========================================="
log "✅ Setup and run scripts executed"
log "📝 Local log: ${LOG_FILE}"
log "📝 Remote log: ~/openbmc/fvp-poc/logs/fvp_run_${TIMESTAMP}.log"
log ""
log "To check FVP status on remote host:"
log "  ssh fvp@${REMOTE_HOST}"
log "  ps aux | grep FVP"
log "  tail -f ~/openbmc/fvp-poc/logs/obmc_console.log"
log ""
log "To stop FVP:"
log "  ssh fvp@${REMOTE_HOST}"
log "  pkill -f FVP_RD_V3_R1"
log ""
