#!/bin/bash

#################################################
# Default configuration values
#################################################

treasury_address='addr1xxzc8pt7fgf0lc0x7eq6z7z6puhsxmzktna7dluahrj6g6v9swzhujsjlls7dajp59u95re0qdk9vh8mumlemw89535s4ecqxj'
vendor_address='addr1xxyzewehw7dh78ea62mkgdnzmcdlcxqt4u39a7pqc0v0at5g9janwaum0u0nm54hvsmx9hsmlsvqhteztmuzps7cl6hq7d35th'

#!/usr/bin/env bash

KOIOS_BASE="https://api.koios.rest/api/v1"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

koios_post() {
  local endpoint="$1"
  local body="$2"
  curl -s -X POST \
    "${KOIOS_BASE}${endpoint}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$body"
}

get_tx_info() {
  local tx_hash="$1"
  koios_post "/tx_info" "{\"_tx_hashes\":[\"${tx_hash}\"]}"
}

get_address_txs() {
  local address="$1"
  local after_block="${2:-0}"
  koios_post "/address_txs" \
    "{\"_addresses\":[\"${address}\"],\"_after_block_height\":${after_block}}"
}

# ---------------------------------------------------------------------------
# Main chain tracer
# ---------------------------------------------------------------------------

trace_utxo_chain() {
  local start_tx="$1"
  local wallet_addr="$2"
  local max_hops="${3:-50}"

  local current_tx="$start_tx"
  local hop=0
  local visited=""

  echo "=== Tracing UTxO chain for ${wallet_addr} ==="
  echo "    Starting tx: ${start_tx}"
  echo ""

  while [ "$hop" -lt "$max_hops" ]; do

    # Loop detection
    if echo "$visited" | grep -qF "$current_tx"; then
      echo "[!] Loop detected at ${current_tx}, stopping."
      break
    fi
    visited="${visited} ${current_tx}"

    echo "--- Hop ${hop}: ${current_tx}"

    # Step 1: get tx info
    local tx_data
    tx_data=$(get_tx_info "$current_tx")

    local block_height
    block_height=$(echo "$tx_data" | jq -r '.[0].block_height // empty')

    if [ -z "$block_height" ]; then
      echo "[!] No tx data returned. Hash may be invalid or unconfirmed."
      break
    fi

    echo "    Block: ${block_height}"

    # Step 2: find outputs belonging to our wallet
    local wallet_outputs
    wallet_outputs=$(echo "$tx_data" | jq -c \
      "[.[0].outputs[] | select(.payment_addr.bech32 == \"${wallet_addr}\")]")

    local output_count
    output_count=$(echo "$wallet_outputs" | jq 'length')

    if [ "$output_count" -eq 0 ]; then
      echo "[!] No outputs to wallet in this tx. Stopping."
      break
    fi

    # Print what the wallet received
    echo "    Wallet outputs (${output_count}):"
    echo "$wallet_outputs" | jq -r '.[] | "      #\(.tx_index)  \(.value) lovelace"'

    # Build UTxO ref set for spending check
    local utxo_refs
    utxo_refs=$(echo "$wallet_outputs" | jq -r \
      ".[] | \"${current_tx}#\(.tx_index)\"")

    # Step 3: get subsequent txs for this wallet after this block
    local addr_txs
    addr_txs=$(get_address_txs "$wallet_addr" "$block_height")

    local next_tx=""

    # Step 4: walk candidates and find the one that spends our UTxO
    while IFS= read -r candidate_hash; do
      [ "$candidate_hash" = "$current_tx" ] && continue
      [ -z "$candidate_hash" ] && continue

      local candidate_data
      candidate_data=$(get_tx_info "$candidate_hash")

      # Check if any input matches one of our UTxO refs
      local match
      match=$(echo "$candidate_data" | jq -r \
        --arg curtx "$current_tx" \
        '.[0].inputs[] | "\(.tx_hash)#\(.tx_index)"' 2>/dev/null \
        | grep -Ff <(echo "$utxo_refs") | head -1)

      if [ -n "$match" ]; then
        echo "    Spent by: ${candidate_hash} (input: ${match})"
        next_tx="$candidate_hash"
        break
      fi
    done < <(echo "$addr_txs" | jq -r '.[].tx_hash')

    if [ -z "$next_tx" ]; then
      echo ""
      echo "=== Chain tip reached — UTxO is unspent ==="
      break
    fi

    current_tx="$next_tx"
    hop=$((hop + 1))
    echo ""
  done
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

TX_HASH="${1:?Usage: $0 <tx_hash> <wallet_address> [max_hops]}"
WALLET_ADDR="${2:?Usage: $0 <tx_hash> <wallet_address> [max_hops]}"
MAX_HOPS="${3:-50}"

trace_utxo_chain "$TX_HASH" "$WALLET_ADDR" "$MAX_HOPS"