#!/bin/bash
# push_pubkey.sh
# Run from the CONTROLLER (172.16.1.X) after setup_deployer.sh has been run on the targets.
# Usage:
#   ./push_pubkey.sh hosts.txt          # file of newline-separated IPs
#   ./push_pubkey.sh 172.16.1.50        # single IP (original behaviour)

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
CONTROLLER_PUBKEY="deployer/.ssh/id_ed25519.pub"   # change if your key differs
TARGET_USER="deployer"
# ─────────────────────────────────────────────────────────────────────────────

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <hosts-file.txt | ip-address>"
    exit 1
fi

# Build the list of targets: file → read lines; plain string → treat as single host
TARGETS=()
if [[ -f "$1" ]]; then
    echo "[*] Reading hosts from file: $1"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip whitespace and skip blank lines / comments
        line="${line//[[:space:]]/}"
        [[ -z "$line" || "$line" == \#* ]] && continue
        TARGETS+=("$line")
    done < "$1"
else
    TARGETS=("$1")
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "[!] No valid hosts found. Exiting."
    exit 1
fi

if [[ ! -f "${CONTROLLER_PUBKEY}" ]]; then
    echo "[!] Public key not found at ${CONTROLLER_PUBKEY}"
    echo "    Generate one with:  ssh-keygen -t ed25519"
    exit 1
fi

# ── Per-host tracking ────────────────────────────────────────────────────────
SUCCEEDED=()
FAILED=()

echo ""
echo "[*] Pushing public key to ${#TARGETS[@]} host(s)..."
echo "============================================================"

for HOST in "${TARGETS[@]}"; do
    echo ""
    echo "[*] → ${TARGET_USER}@${HOST}"

    if ssh-copy-id -i "${CONTROLLER_PUBKEY}" "${TARGET_USER}@${HOST}"; then
        # Verify the key actually works
        if ssh -o BatchMode=yes -o ConnectTimeout=10 "${TARGET_USER}@${HOST}" \
               "echo '[+] OK: \$(whoami)@\$(hostname)'"; then
            SUCCEEDED+=("${HOST}")
        else
            echo "    [!] Key copied but verification failed for ${HOST}"
            FAILED+=("${HOST}")
        fi
    else
        echo "    [!] ssh-copy-id failed for ${HOST}"
        FAILED+=("${HOST}")
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Summary"
echo "============================================================"
echo " Succeeded (${#SUCCEEDED[@]}): ${SUCCEEDED[*]:-none}"
echo " Failed    (${#FAILED[@]}):    ${FAILED[*]:-none}"
echo "============================================================"

# Exit non-zero if any host failed
[[ ${#FAILED[@]} -eq 0 ]]
