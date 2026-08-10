#!/bin/sh

# Fetch proposals with proposal_type = TreasuryWithdrawals and dropped_epoch = null
data=$(curl -s -X GET "https://api.koios.rest/api/v1/proposal_list?select=proposal_id,proposal_type,enacted_epoch,dropped_epoch,withdrawal&proposal_type=eq.TreasuryWithdrawals&dropped_epoch=is.null&enacted_epoch=gt.612")

# Parse and display results
echo "=== Treasury Withdrawals ==="
echo

# Extract and print each proposal with amount
echo "$data" | jq -r '
  .[] | 
  {proposal_id: .proposal_id, proposal_type: .proposal_type, amount: .withdrawal[].amount} |
  "Proposal ID: \(.proposal_id)\nType: \(.proposal_type)\nAmount: \(.amount)\n"
'

# Calculate and print total amount
total=$(echo "$data" | jq '[.[].withdrawal[].amount | tonumber] | add')
echo "=============================="
echo "Total Withdrawal Amount: $total Lovelace"
echo "=============================="

echo "=============================="
left=$((350000000000000 - total))
echo "Total left based on NCL: $left Lovelace"
echo "=============================="

