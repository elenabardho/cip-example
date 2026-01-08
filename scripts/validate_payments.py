#!/usr/bin/env python3
"""
Validate payment CSV against outputs.json
Checks that each row in the CSV matches an entry in outputs.json
"""

import json
import csv
import sys
from pathlib import Path


def load_outputs(json_path):
    """Load and index outputs.json by address"""
    with open(json_path, 'r') as f:
        outputs = json.load(f)
    
    # Create a dictionary indexed by address for quick lookup
    outputs_dict = {}
    for output in outputs:
        address = output['address']
        coin = output['amount']['coin']
        outputs_dict[address] = coin
    
    return outputs_dict


def validate_csv(csv_path, outputs_dict):
    """Validate CSV entries against outputs dictionary"""
    errors = []
    warnings = []
    matches = []
    
    with open(csv_path, 'r') as f:
        # Skip the header row
        reader = csv.reader(f)
        header = next(reader)
        
        for row_num, row in enumerate(reader, start=2):  # Start at 2 because of header
            if not row or len(row) < 2:
                warnings.append(f"Row {row_num}: Empty or incomplete row")
                continue
            
            wallet_address = row[0].strip()
            csv_amount = row[1].strip()
            
            # Check if address exists in outputs.json
            if wallet_address not in outputs_dict:
                errors.append(f"Row {row_num}: Address NOT FOUND in outputs.json")
                errors.append(f"  Address: {wallet_address}")
                errors.append(f"  CSV Amount: {csv_amount}")
            else:
                json_amount = outputs_dict[wallet_address]
                
                # Check if amounts match
                if csv_amount == json_amount:
                    matches.append(f"Row {row_num}: ✓ MATCH - {wallet_address[:20]}... = {csv_amount} lovelace")
                else:
                    errors.append(f"Row {row_num}: AMOUNT MISMATCH")
                    errors.append(f"  Address: {wallet_address}")
                    errors.append(f"  CSV Amount: {csv_amount}")
                    errors.append(f"  JSON Amount: {json_amount}")
    
    return matches, errors, warnings


def check_extra_entries(csv_path, outputs_dict):
    """Check if outputs.json has entries not in CSV"""
    csv_addresses = set()
    
    with open(csv_path, 'r') as f:
        reader = csv.reader(f)
        next(reader)  # Skip header
        for row in reader:
            if row and len(row) >= 1:
                csv_addresses.add(row[0].strip())
    
    json_addresses = set(outputs_dict.keys())
    extra_in_json = json_addresses - csv_addresses
    
    return extra_in_json


def main():
    # Determine file paths
    script_dir = Path(__file__).parent
    csv_path = script_dir / "inputOutputs/payment.csv"
    json_path = script_dir / "inputOutputs/outputs.json"
    
    # Allow command line arguments to override
    if len(sys.argv) > 1:
        csv_path = Path(sys.argv[1])
    if len(sys.argv) > 2:
        json_path = Path(sys.argv[2])
    
    # Check if files exist
    if not csv_path.exists():
        print(f"❌ ERROR: CSV file not found: {csv_path}")
        sys.exit(1)
    
    if not json_path.exists():
        print(f"❌ ERROR: JSON file not found: {json_path}")
        sys.exit(1)
    
    print("=" * 80)
    print("PAYMENT VALIDATION REPORT")
    print("=" * 80)
    print(f"CSV File:  {csv_path}")
    print(f"JSON File: {json_path}")
    print("=" * 80)
    
    # Load outputs.json
    try:
        outputs_dict = load_outputs(json_path)
        print(f"\n✓ Loaded {len(outputs_dict)} entries from outputs.json")
    except Exception as e:
        print(f"❌ ERROR loading outputs.json: {e}")
        sys.exit(1)
    
    # Validate CSV
    try:
        matches, errors, warnings = validate_csv(csv_path, outputs_dict)
    except Exception as e:
        print(f"❌ ERROR validating CSV: {e}")
        sys.exit(1)
    
    # Check for extra entries in JSON
    extra_in_json = check_extra_entries(csv_path, outputs_dict)
    
    # Print results
    print("\n" + "=" * 80)
    print("VALIDATION RESULTS")
    print("=" * 80)
    
    if matches:
        print(f"\n✓ MATCHES ({len(matches)}):")
        for match in matches:
            print(f"  {match}")
    
    if warnings:
        print(f"\n⚠ WARNINGS ({len(warnings)}):")
        for warning in warnings:
            print(f"  {warning}")
    
    if errors:
        print(f"\n❌ ERRORS ({len(errors)}):")
        for error in errors:
            print(f"  {error}")
    
    if extra_in_json:
        print(f"\n⚠ EXTRA ENTRIES IN JSON NOT IN CSV ({len(extra_in_json)}):")
        for addr in sorted(extra_in_json):
            print(f"  {addr} = {outputs_dict[addr]} lovelace")
    
    # Summary
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    total_csv_rows = len(matches) + (len(errors) // 3)  # Approximate
    print(f"CSV Rows Processed: {total_csv_rows}")
    print(f"Matches: {len(matches)}")
    print(f"Errors: {len([e for e in errors if 'Row' in e])}")
    print(f"Warnings: {len(warnings)}")
    print(f"Extra in JSON: {len(extra_in_json)}")
    
    # Exit code
    if errors:
        print("\n❌ VALIDATION FAILED - Errors found")
        sys.exit(1)
    elif warnings or extra_in_json:
        print("\n⚠ VALIDATION PASSED WITH WARNINGS")
        sys.exit(0)
    else:
        print("\n✅ VALIDATION PASSED - All entries match!")
        sys.exit(0)


if __name__ == "__main__":
    main()
