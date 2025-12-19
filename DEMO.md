# Demo Runbook (2–5 minutes)

## Goal

Show:
- VM boot
- “VM access ≠ gcloud access”
- Secrets retrieved only inside encrypted session
- Secrets not visible from other sessions
- Browser profile stored inside encrypted mount
- Cleanup (secrets destroyed)

## Pre-req (host)

- Fill `config.yaml` with **project ID** + secret label.

## Demo Steps

### 1) Fast boot

```bash
cd /Users/abhinavtaneja/Developer/sandbox-scripts
./deploy.sh
```

### 2) Hardening (1-time per VM)

```bash
vagrant ssh -c "sudo /vagrant_config/scripts/harden.sh"
```

### 3) Prove “VM access ≠ gcloud access”

```bash
vagrant ssh -c "sudo -u security gcloud version || echo 'OK: security cannot run gcloud'"
```

### 4) Start secrets session (encrypted + gcloud tokens inside mount)

```bash
vagrant ssh
sudo /usr/local/sbin/secrets.sh /vagrant_config/config.yaml
```

Inside that session:

```bash
whoami                         # security
ls -la /mnt/secrets
ls -la /mnt/secrets/*.json
```

### 5) Prove other sessions cannot see decrypted secrets

On host (separate terminal) while the secrets session is still open:

```bash
vagrant ssh -c "mount | grep /mnt/secrets || echo 'OK: no /mnt/secrets mount visible here'"
vagrant ssh -c "ls -la /mnt/secrets"
vagrant ssh -c "ls -la /mnt/secrets/*.json || echo 'OK: no secret files visible here'"
```

### 6) Ethereum Transaction Signing Demo

Inside the secrets session, sign a transaction:

```bash
# Run interactive demo (creates test key if none exists)
eth-sign --demo
```

**With your own key** (store in encrypted mount first):

```bash
# Create key file in encrypted mount
cat > /mnt/secrets/eth-signing-key.json << 'EOF'
{
  "private_key": "0xYOUR_PRIVATE_KEY_HERE"
}
EOF
chmod 600 /mnt/secrets/eth-signing-key.json

# Sign a transfer (dry run - doesn't broadcast)
eth-sign --to 0xRECIPIENT_ADDRESS --value 0.01 --network sepolia --dry-run

# Sign and broadcast (will prompt for confirmation)
eth-sign --to 0xRECIPIENT_ADDRESS --value 0.01 --network sepolia
```

**Key points demonstrated:**
- Private key loaded from encrypted RAM-backed volume
- Key never written to disk
- Transaction signed inside isolated environment
- Signed raw transaction can be broadcast externally

### 7) Browser workflow (seed + extension data inside encrypted mount)

Inside the secrets session:

```bash
secure-browser
```

### 8) Cleanup proof

Inside the secrets session:

```bash
exit
```

Then:

```bash
vagrant ssh -c "mount | grep /mnt/secrets || echo 'OK: not mounted after exit'"
vagrant ssh -c "cat /mnt/secrets/eth-signing-key.json 2>&1 || echo 'OK: key file destroyed'"
```

## After demo

```bash
./cleanup.sh vm
```


