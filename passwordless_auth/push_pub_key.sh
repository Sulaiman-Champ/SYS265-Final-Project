#!/bin/bash
# push_pubkey.sh
# Run from the CONTROLLER (172.16.1.X) after setup_deployer.sh has been run on the target.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
CONTROLLER_PUBKEY="${HOME}/.ssh/id_ed25519.pub"   # change if your key differs
TARGET_HOST=""                                     # e.g. 172.16.1.50
TARGET_USER="deployer"
REMOTE_AUTH_KEYS="/home/${TARGET_USER}/.ssh/authorized_keys"
# ─────────────────────────────────────────────────────────────────────────────

# Allow TARGET_HOST to be passed as the first argument
if [[ -n "${1:-}" ]]; then
    TARGET_HOST="$1"
fi

if [[ -z "${TARGET_HOST}" ]]; then
    echo "Usage: $0 <target-server-ip>"
    echo "  e.g. $0 172.16.1.50"
    exit 1
fi

if [[ ! -f "${CONTROLLER_PUBKEY}" ]]; then
    echo "[!] Public key not found at ${CONTROLLER_PUBKEY}"
    echo "    Generate one with:  ssh-keygen -t ed25519"
    exit 1
fi

echo "[*] Copying public key to ${TARGET_USER}@${TARGET_HOST}"
# ssh-copy-id handles deduplication and correct permissions automatically.
# It will prompt once for the root/deployer password if key auth isn't yet set up.
ssh-copy-id -i "${CONTROLLER_PUBKEY}" "${TARGET_USER}@${TARGET_HOST}"

echo ""
echo "[*] Verifying connection..."
ssh -o BatchMode=yes "${TARGET_USER}@${TARGET_HOST}" "echo '[+] Passwordless SSH is working as: \$(whoami)@\$(hostname)'"
echo ""
echo "============================================================"
echo " Done. ${TARGET_USER}@${TARGET_HOST} is ready for"
echo " passwordless, key-based SSH access."
echo "============================================================"
