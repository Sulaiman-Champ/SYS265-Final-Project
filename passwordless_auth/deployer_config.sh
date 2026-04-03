#!/bin/bash
# setup_deployer.sh
# Run as root on the target Ubuntu server

set -euo pipefail

DEPLOYER_USER="deployer"
SSH_DIR="/home/${DEPLOYER_USER}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

echo "[*] Creating user: ${DEPLOYER_USER}"
if id "${DEPLOYER_USER}" &>/dev/null; then
    echo "    User already exists, skipping creation."
else
    useradd -m -s /bin/bash "${DEPLOYER_USER}"
    echo "    User created."
fi

echo "[*] Adding ${DEPLOYER_USER} to sudo group"
usermod -aG sudo "${DEPLOYER_USER}"

echo "[*] Adding sudoers entry (NOPASSWD)"
SUDOERS_FILE="/etc/sudoers.d/${DEPLOYER_USER}"
echo "${DEPLOYER_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_FILE}"
chmod 0440 "${SUDOERS_FILE}"
visudo -cf "${SUDOERS_FILE}"  # Validate before leaving it in place
echo "    Sudoers entry written and validated: ${SUDOERS_FILE}"

echo "[*] Setting up .ssh directory"
mkdir -p "${SSH_DIR}"
touch "${AUTH_KEYS}"
chmod 700 "${SSH_DIR}"
chmod 600 "${AUTH_KEYS}"
chown -R "${DEPLOYER_USER}:${DEPLOYER_USER}" "${SSH_DIR}"
echo "    .ssh directory ready at ${SSH_DIR}"

echo " Setup complete."
