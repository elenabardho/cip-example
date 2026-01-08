#!/bin/bash
##################################################

# Default configuration values

##################################################

# Exit immediately if a command exits with a non-zero status, 
# treat unset variables as an error, and fail if any command in a pipeline fails
set -euo pipefail

# Colors
#BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BRIGHTWHITE='\033[0;37;1m'
NC='\033[0m'

# Check if cardano-cli is installed
if ! command -v cardano-cli >/dev/null 2>&1; then
  echo "Error: cardano-cli is not installed or not in your PATH." >&2
  exit 1
fi

# Usage message

usage() {
    echo "Usage: $0 <payment address> [--metadata-file <jsonld-file>]"
    echo "Options:"
    echo "  <payment address>                   (Required Cardano payment address in Bech32)"
    echo "  <payment details list file>         (Path to the CSV file with payment details: address, amount in lovelace)"
    echo "  --metadata-file <jsonld-file>       (Path to the JSON metadata file)"
    echo "  -h, --help                           Show this help message and exit"
    exit 1
}

# Initialize variables with defaults
payment_address_input=""
payment_details_list_file=""

# Optional variables
metadata_file_input=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --metadata-file)
            if [ -n "${2:-}" ]; then
                metadata_file_input="$2"
                echo -e "${BLUE}Using metadata file: ${NC}$metadata_file_input"
                shift 2
            else
                echo -e "${RED}Error: --metadata-file requires a value${NC}" >&2
                usage
            fi
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$payment_address_input" ]; then
                payment_address_input="$1"
                echo -e "${BLUE}Using payment address:${NC} $payment_address_input"
            else
                echo -e "${RED}Error: Payment address already specified. Unexpected argument: $1${NC}" >&2
                usage
            fi
            shift
            ;;
    esac
done

# If no payment address provided, show usage
if [ -z "$payment_address_input" ]; then
    echo -e "${RED}Error: No payment address specified${NC}" >&2
    usage
fi

# Check if input file exists
if [ "$metadata_file_input" != "" ] && [ ! -f "$metadata_file_input" ]; then
    echo -e "${RED}Error: Input file not found: $metadata_file_input${NC}" >&2
    exit 1
fi


# export PAYMENT_ADDR='addr1qx93k28kzzu4fng49cfcj8w7m8px36wf9z8j94638lu8cw574gazl7xgwlxg4uxe4ytwnttj8qw489waumt82gx5jdtqwh8hn0'

# utxo_list=$(cardano-cli conway query utxo \
#   --mainnet \
#   --socket-path "$CARDANO_NODE_SOCKET_PATH" \
#   --address "$PAYMENT_ADDR" )

# echo "UTxO list for address $PAYMENT_ADDR:"
# # Extract wallet address (column 1) and lovelace amount (column 2)
# # Clean invisible characters (carriage returns, tabs, etc.)
# export TX_OUT=$(tail -n +3 './payment-test.csv' | tr -d '\r\t' | awk -F',' '{print "--tx-out " $1 "+" $2}' | tr '\n' ' ' | sed 's/^ *//;s/ *$//')

# # Display what will be sent
# echo "Transaction outputs:"
# echo "$TX_OUT"

# # Build and execute the transaction
# cardano-cli conway transaction build \
#   --socket-path "$CARDANO_NODE_SOCKET_PATH" \
#   --mainnet \
#   --tx-in "b9e7830b6291bbdafbb371bd9f79ba07f717a0a59e1054db92f7681645f5c35f#1" \
#   $TX_OUT \
#   --change-address "$PAYMENT_ADDR" \
#   --out-file ./bulk-payment.tx 