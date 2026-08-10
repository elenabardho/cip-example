#!/usr/bin/env python3
"""
Enriches a drep comparison CSV with:
  - name        (resolved from the DRep's metadata URL)
  - voting_power_ada  (from Koios /drep_info, correct lovelace→ADA)

Usage:
  python3 scripts/enrich-drep-csv.py <input.csv> [output.csv]

If output.csv is omitted the enriched file is written next to the input
with "_enriched" appended before the extension.
"""

import csv
import json
import sys
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

KOIOS_URL  = "https://api.koios.rest/api/v1/drep_info"
META_TIMEOUT = 8   # seconds per metadata fetch
BATCH_SIZE   = 50


def post_json(url: str, payload: dict) -> list:
    data = json.dumps(payload).encode()
    req  = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def fetch_drep_info(drep_ids):
    """Batch-fetch drep_info; returns dict keyed by drep_id."""
    result = {}
    for i in range(0, len(drep_ids), BATCH_SIZE):
        chunk = drep_ids[i : i + BATCH_SIZE]
        rows  = post_json(KOIOS_URL, {"_drep_ids": chunk})
        for row in rows:
            result[row["drep_id"]] = row
    return result


def fetch_name(meta_url) -> str:
    if not meta_url:
        return ""
    try:
        req = urllib.request.Request(
            meta_url,
            headers={"Accept": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=META_TIMEOUT) as r:
            meta = json.loads(r.read())
        body = meta.get("body", {})
        raw = body.get("dRepName") or body.get("givenName") or ""
        # JSON-LD typed value: {"@value": "Name", "@language": "en"}
        if isinstance(raw, dict):
            raw = raw.get("@value", "")
        return raw or ""
    except Exception:
        return ""


def resolve_names(info_map):
    """Resolve names in parallel; returns dict keyed by drep_id."""
    names: dict[str, str] = {}
    tasks = {
        drep_id: info.get("meta_url")
        for drep_id, info in info_map.items()
    }
    with ThreadPoolExecutor(max_workers=20) as pool:
        futures = {pool.submit(fetch_name, url): drep_id for drep_id, url in tasks.items()}
        done = 0
        total = len(futures)
        for future in as_completed(futures):
            drep_id = futures[future]
            names[drep_id] = future.result()
            done += 1
            print(f"  ↳ resolving names {done}/{total} …", end="\r", flush=True)
    print()
    return names


def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: enrich-drep-csv.py <input.csv> [output.csv]")

    in_path  = Path(sys.argv[1])
    out_path = Path(sys.argv[2]) if len(sys.argv) > 2 else \
               in_path.with_name(in_path.stem + "_enriched" + in_path.suffix)

    print(f"Reading  : {in_path}")

    with open(in_path, newline="") as f:
        reader = list(csv.DictReader(f))

    drep_ids = [row["drep_id"].strip('"') for row in reader]
    print(f"DReps    : {len(drep_ids)}")

    print(f"Fetching drep_info …")
    info_map = fetch_drep_info(drep_ids)
    print(f"  ✓ info received for {len(info_map)} DReps")

    print(f"Resolving names …")
    name_map = resolve_names(info_map)
    resolved = sum(1 for n in name_map.values() if n)
    print(f"  ✓ names resolved: {resolved}/{len(name_map)}")

    # Write enriched CSV
    fieldnames = ["drep_id", "name", "ref_proposal_vote",
                  "target_proposal_vote", "status", "voting_power_ada"]

    with open(out_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in reader:
            drep_id = row["drep_id"].strip('"')
            info    = info_map.get(drep_id, {})
            ada     = int(info.get("amount") or 0) // 1_000_000
            writer.writerow({
                "drep_id":              drep_id,
                "name":                 name_map.get(drep_id, ""),
                "ref_proposal_vote":    row["ref_proposal_vote"].strip('"'),
                "target_proposal_vote": row["target_proposal_vote"].strip('"'),
                "status":               row["status"].strip('"'),
                "voting_power_ada":     ada,
            })

    print(f"Written  : {out_path}")


if __name__ == "__main__":
    main()
