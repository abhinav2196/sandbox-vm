#!/usr/bin/env python3
"""
Ethereum Transaction Signing Demo
Signs a transfer transaction using a private key from the encrypted secrets mount.

Usage:
  eth-sign.py                           # Interactive mode
  eth-sign.py --to 0x... --value 0.01   # Direct mode
  eth-sign.py --dry-run                 # Show signed tx, don't broadcast
"""

import os
import sys
import json
import argparse
from pathlib import Path

try:
    from web3 import Web3
    from eth_account import Account
except ImportError:
    print("Error: web3 not installed. Run: pip3 install web3")
    sys.exit(1)

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SECRETS_MOUNT = os.environ.get("SECRETS_MOUNT", "/mnt/secrets")
DEFAULT_KEY_FILE = "eth-signing-key.json"  # Expected format: {"private_key": "0x..."}

# Public testnet RPCs (Sepolia is recommended for testing)
NETWORKS = {
    "sepolia": {
        "rpc": "https://rpc.sepolia.org",
        "chain_id": 11155111,
        "explorer": "https://sepolia.etherscan.io/tx/",
    },
    "goerli": {
        "rpc": "https://rpc.ankr.com/eth_goerli",
        "chain_id": 5,
        "explorer": "https://goerli.etherscan.io/tx/",
    },
    "mainnet": {
        "rpc": "https://eth.llamarpc.com",
        "chain_id": 1,
        "explorer": "https://etherscan.io/tx/",
    },
}

# Colors
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
CYAN = "\033[0;36m"
NC = "\033[0m"


def info(msg):
    print(f"{GREEN}==> {msg}{NC}")


def warn(msg):
    print(f"{YELLOW}==> {msg}{NC}")


def error(msg):
    print(f"{RED}Error: {msg}{NC}")
    sys.exit(1)


# ─────────────────────────────────────────────────────────────────────────────
# Core Functions
# ─────────────────────────────────────────────────────────────────────────────


def load_private_key(key_file: str = None) -> str:
    """Load private key from encrypted secrets mount."""
    
    # Try multiple locations
    search_paths = []
    
    if key_file:
        search_paths.append(Path(key_file))
    
    search_paths.extend([
        Path(SECRETS_MOUNT) / DEFAULT_KEY_FILE,
        Path(SECRETS_MOUNT) / "private-key.json",
        Path(SECRETS_MOUNT) / "wallet.json",
    ])
    
    # Also check for any .json file with private_key field
    secrets_dir = Path(SECRETS_MOUNT)
    if secrets_dir.exists():
        for f in secrets_dir.glob("*.json"):
            if f not in search_paths:
                search_paths.append(f)
    
    for path in search_paths:
        if path.exists():
            try:
                data = json.loads(path.read_text())
                # Support multiple key formats
                key = data.get("private_key") or data.get("privateKey") or data.get("key")
                if key:
                    info(f"Loaded key from: {path}")
                    # Ensure 0x prefix
                    if not key.startswith("0x"):
                        key = "0x" + key
                    return key
            except (json.JSONDecodeError, KeyError):
                continue
    
    # If no file found, check if there's a raw key in env (for testing)
    if os.environ.get("ETH_PRIVATE_KEY"):
        warn("Using ETH_PRIVATE_KEY from environment (testing only)")
        return os.environ["ETH_PRIVATE_KEY"]
    
    error(f"No private key found in {SECRETS_MOUNT}. Expected JSON with 'private_key' field.")


def create_and_sign_transaction(
    private_key: str,
    to_address: str,
    value_eth: float,
    network: str = "sepolia",
    gas_limit: int = 21000,
) -> dict:
    """Create and sign an Ethereum transaction."""
    
    if network not in NETWORKS:
        error(f"Unknown network: {network}. Available: {list(NETWORKS.keys())}")
    
    net_config = NETWORKS[network]
    w3 = Web3(Web3.HTTPProvider(net_config["rpc"]))
    
    if not w3.is_connected():
        error(f"Cannot connect to {network} RPC: {net_config['rpc']}")
    
    # Derive address from private key
    account = Account.from_key(private_key)
    from_address = account.address
    
    info(f"From address: {from_address}")
    info(f"Network: {network} (chain_id: {net_config['chain_id']})")
    
    # Get nonce
    nonce = w3.eth.get_transaction_count(from_address)
    info(f"Nonce: {nonce}")
    
    # Get current gas price
    gas_price = w3.eth.gas_price
    info(f"Gas price: {Web3.from_wei(gas_price, 'gwei'):.2f} Gwei")
    
    # Check balance
    balance = w3.eth.get_balance(from_address)
    balance_eth = Web3.from_wei(balance, "ether")
    info(f"Balance: {balance_eth:.6f} ETH")
    
    value_wei = Web3.to_wei(value_eth, "ether")
    total_cost = value_wei + (gas_limit * gas_price)
    
    if balance < total_cost:
        warn(f"Insufficient balance! Need {Web3.from_wei(total_cost, 'ether'):.6f} ETH")
        warn("Transaction will be signed but will fail if broadcast")
    
    # Build transaction
    tx = {
        "nonce": nonce,
        "to": Web3.to_checksum_address(to_address),
        "value": value_wei,
        "gas": gas_limit,
        "gasPrice": gas_price,
        "chainId": net_config["chain_id"],
    }
    
    info("Transaction built:")
    print(f"  To:       {tx['to']}")
    print(f"  Value:    {value_eth} ETH ({value_wei} wei)")
    print(f"  Gas:      {gas_limit}")
    print(f"  Gas Cost: ~{Web3.from_wei(gas_limit * gas_price, 'ether'):.6f} ETH")
    
    # Sign transaction
    signed = Account.sign_transaction(tx, private_key)
    
    info("Transaction signed!")
    print(f"  Tx Hash:  {signed.hash.hex()}")
    print(f"  Raw Tx:   {signed.raw_transaction.hex()[:80]}...")
    
    return {
        "tx": tx,
        "signed": signed,
        "from": from_address,
        "network": network,
        "explorer": net_config["explorer"],
        "w3": w3,
    }


def broadcast_transaction(result: dict) -> str:
    """Broadcast a signed transaction to the network."""
    
    w3 = result["w3"]
    signed = result["signed"]
    
    info("Broadcasting transaction...")
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    
    explorer_url = result["explorer"] + tx_hash.hex()
    info(f"Transaction broadcast!")
    print(f"  Tx Hash: {tx_hash.hex()}")
    print(f"  Explorer: {explorer_url}")
    
    return tx_hash.hex()


# ─────────────────────────────────────────────────────────────────────────────
# Demo Mode
# ─────────────────────────────────────────────────────────────────────────────


def demo_mode():
    """Interactive demo showing the signing flow."""
    
    print(f"\n{CYAN}╔════════════════════════════════════════════════════════════╗{NC}")
    print(f"{CYAN}║     Ethereum Transaction Signing Demo (Secure Sandbox)     ║{NC}")
    print(f"{CYAN}╚════════════════════════════════════════════════════════════╝{NC}\n")
    
    # Step 1: Show we're in encrypted environment
    info("Step 1: Verify encrypted secrets mount")
    if os.path.ismount(SECRETS_MOUNT):
        print(f"  ✓ {SECRETS_MOUNT} is mounted")
    else:
        warn(f"  {SECRETS_MOUNT} not mounted (demo mode, using test key)")
    
    print()
    
    # Step 2: Load key
    info("Step 2: Load private key from encrypted storage")
    
    # For demo, create a test key if none exists
    if not any(Path(SECRETS_MOUNT).glob("*.json")) if Path(SECRETS_MOUNT).exists() else True:
        warn("No key file found - generating ephemeral test key for demo")
        test_account = Account.create()
        private_key = test_account.key.hex()
        print(f"  Test address: {test_account.address}")
        print(f"  (This is an unfunded test wallet)")
    else:
        private_key = load_private_key()
    
    print()
    
    # Step 3: Build demo transaction
    info("Step 3: Build transfer transaction")
    
    # Demo recipient (Ethereum burn address - commonly used for demos)
    demo_to = "0x000000000000000000000000000000000000dEaD"
    demo_value = 0.001  # Small amount for demo
    
    print(f"  Recipient: {demo_to}")
    print(f"  Amount: {demo_value} ETH")
    print()
    
    # Step 4: Sign
    info("Step 4: Sign transaction (key never leaves encrypted mount)")
    
    try:
        result = create_and_sign_transaction(
            private_key=private_key,
            to_address=demo_to,
            value_eth=demo_value,
            network="sepolia",
        )
        
        print()
        info("Step 5: Transaction ready")
        print(f"  The signed transaction can now be broadcast to Sepolia testnet.")
        print(f"  In production, you would call broadcast_transaction() here.")
        print()
        
        print(f"{CYAN}═══════════════════════════════════════════════════════════════{NC}")
        print(f"{GREEN}Demo complete! Key material remains only in encrypted mount.{NC}")
        print(f"{CYAN}═══════════════════════════════════════════════════════════════{NC}")
        
    except Exception as e:
        warn(f"Network error (expected if no internet): {e}")
        
        # Offline signing demo
        print()
        info("Offline signing demo (no network required):")
        account = Account.from_key(private_key)
        
        tx = {
            "nonce": 0,
            "to": Web3.to_checksum_address(demo_to),
            "value": Web3.to_wei(demo_value, "ether"),
            "gas": 21000,
            "gasPrice": Web3.to_wei(20, "gwei"),
            "chainId": 11155111,  # Sepolia
        }
        
        signed = Account.sign_transaction(tx, private_key)
        print(f"  From: {account.address}")
        print(f"  Signed tx hash: {signed.hash.hex()}")
        print(f"  Raw transaction: {signed.raw_transaction.hex()[:60]}...")
        print()
        print(f"{GREEN}✓ Transaction signed offline successfully{NC}")


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(
        description="Sign Ethereum transactions from encrypted secrets mount"
    )
    parser.add_argument("--to", help="Recipient address")
    parser.add_argument("--value", type=float, help="Amount in ETH")
    parser.add_argument(
        "--network",
        default="sepolia",
        choices=list(NETWORKS.keys()),
        help="Network to use",
    )
    parser.add_argument("--key-file", help="Path to key JSON file")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Sign but don't broadcast",
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Run interactive demo",
    )
    
    args = parser.parse_args()
    
    # Demo mode
    if args.demo or (not args.to and not args.value):
        demo_mode()
        return
    
    # Direct mode
    if not args.to or args.value is None:
        error("Both --to and --value required for direct mode")
    
    private_key = load_private_key(args.key_file)
    
    result = create_and_sign_transaction(
        private_key=private_key,
        to_address=args.to,
        value_eth=args.value,
        network=args.network,
    )
    
    if args.dry_run:
        print()
        info("Dry run - transaction NOT broadcast")
        print(f"  Raw tx (for manual broadcast): {result['signed'].raw_transaction.hex()}")
    else:
        print()
        confirm = input(f"{YELLOW}Broadcast transaction? [y/N]: {NC}").strip().lower()
        if confirm == "y":
            broadcast_transaction(result)
        else:
            info("Transaction not broadcast")


if __name__ == "__main__":
    main()

