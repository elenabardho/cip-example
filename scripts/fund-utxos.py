#!/usr/bin/env python3
"""
Scans unspent UTXOs for a fund address and prints a table of those
whose transaction metadata contains event = "fund".

Usage:
  python3 scripts/fund-utxos.py
"""

import json
import urllib.request

KOIOS_BASE   = "https://api.koios.rest/api/v1"
FUND_ADDRESS = "addr1x84sdxt6jjennmstphgdu7l7c2scf5d02a6cve2dgn5s2k8tq6vh499n88hqkrwsmealas4psng674m4sej5638fq4vqmxs59w"
BATCH_SIZE   = 50


def post_json(url: str, payload: dict) -> list:
    data = json.dumps(payload).encode()
    req  = urllib.request.Request(
        url, data=data,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def fetch_utxos(address: str) -> list:
    return post_json(f"{KOIOS_BASE}/address_utxos", {"_addresses": [address]})


def fetch_tx_info(tx_hashes: list) -> dict:
    result = {}
    for i in range(0, len(tx_hashes), BATCH_SIZE):
        chunk = tx_hashes[i : i + BATCH_SIZE]
        print(f"  fetching tx_info batch {i + 1}–{i + len(chunk)} of {len(tx_hashes)} …", flush=True)
        rows = post_json(f"{KOIOS_BASE}/tx_info", {
            "_tx_hashes": chunk,
            "_metadata": True,
        })
        for row in rows:
            result[row["tx_hash"]] = row
    return result


def _str(val) -> str:
    if isinstance(val, list):
        return "".join(str(v) for v in val)
    return str(val) if val is not None else "—"


def _fmt_assets(asset_list) -> str:
    if not asset_list:
        return "—"
    parts = []
    for a in asset_list:
        hex_name = a.get("asset_name") or ""
        try:
            name = bytes.fromhex(hex_name).decode("utf-8")
        except Exception:
            name = hex_name or a.get("policy_id", "")[:8]
        qty = int(a.get("quantity", 0))
        parts.append(f"{name}: {qty:,}")
    return "  |  ".join(parts)


def main():
    print("Fetching UTXOs for address …")
    utxos = fetch_utxos(FUND_ADDRESS)
    print(f"  ✓ {len(utxos)} UTXOs found")

    unique_hashes = list({u["tx_hash"] for u in utxos})
    print(f"Fetching tx_info for {len(unique_hashes)} unique transaction(s) …")
    tx_map = fetch_tx_info(unique_hashes)
    print(f"  ✓ tx_info fetched\n")

    # Build fund_map: tx_hash → {label, identifier} for txs with event=fund
    # Metadata format: {"1694": {"body": {"event": "fund", "label": "...", "identifier": "..."}}}
    fund_map = {}
    for tx_hash, tx in tx_map.items():
        for label_val in (tx.get("metadata") or {}).values():
            if not isinstance(label_val, dict):
                continue
            body = label_val.get("body", {})
            if body.get("event") == "fund":
                fund_map[tx_hash] = {
                    "label":      _str(body.get("label", "—")),
                    "identifier": _str(body.get("identifier", "—")),
                }
                break

    results = [
        {
            "tx_hash":    u["tx_hash"],
            "amount":     u["value"],
            "assets":     _fmt_assets(u.get("asset_list")),
            "label":      fund_map[u["tx_hash"]]["label"],
            "identifier": fund_map[u["tx_hash"]]["identifier"],
        }
        for u in utxos
        if u["tx_hash"] in fund_map
    ]

    # Table
    SEP = "─" * 140
    print(f"{'TX Hash':<66}  {'Amount (ADA)':>15}  {'Identifier':<15}  {'Assets':<20}  Label")
    print(SEP)
    if not results:
        print("  No fund UTXOs found.")
    else:
        for row in results:
            ada = int(row["amount"]) // 1_000_000
            print(
                f"{row['tx_hash']:<66}  "
                f"{ada:>15,}  "
                f"{row['identifier']:<15}  "
                f"{row['assets']:<20}  "
                f"{row['label']}"
            )
    print(SEP)
    print(f"Total fund UTXOs: {len(results)}")


if __name__ == "__main__":
    main()
