#!/bin/bash

#####################################################################
# Governance Actions Statistics Script
# Fetches all governance actions from Koios API and analyzes them
# Compares overall stats with Intersect-submitted actions
#####################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# CSV file path (adjust if needed)
CSV_FILE="${1:-.}/inputOutputs/stakeAccountList.csv"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Cardano Governance Actions Statistics                  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Fetch data from Koios API
echo -e "${YELLOW}Fetching governance actions from Koios API...${NC}"
DATA=$(curl -s -X GET "https://api.koios.rest/api/v1/proposal_list" \
  -H "accept: application/json")

if [ -z "$DATA" ]; then
    echo -e "${RED}Error: Failed to fetch data from Koios API${NC}"
    exit 1
fi

# Filter for epoch 531 and above
DATA=$(echo "$DATA" | jq '[.[] | select(.proposed_epoch >= 531)]')

echo -e "${GREEN}✓ Data fetched successfully${NC}"
echo -e "${GREEN}✓ Filtered for Epoch 531 and above${NC}"
echo ""

#####################################################################
# SECTOR 1: GOVERNANCE ACTIONS OVERVIEW
#####################################################################

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}SECTOR 1: GOVERNANCE ACTIONS OVERVIEW${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Total counts
TOTAL=$(echo "$DATA" | jq 'length')
TOTAL_RATIFIED=$(echo "$DATA" | jq '[.[] | select(.ratified_epoch != null)] | length')

echo -e "${BLUE}Total Governance Actions Submitted:${NC}  $TOTAL"
echo -e "${BLUE}Total Ratified:${NC}                     $TOTAL_RATIFIED"

# if [ "$TOTAL" -gt 0 ]; then
#     RATIFICATION_MARGIN=$(echo "scale=2; ($TOTAL_RATIFIED * 100) / $TOTAL" | bc)
#     echo -e "${BLUE}Ratification Margin:${NC}               $RATIFICATION_MARGIN%"
# fi

# Ratification margin excluding Info Actions
TOTAL_EXCLUDING_INFO=$(echo "$DATA" | jq '[.[] | select(.proposal_type != "InfoAction")] | length')
TOTAL_RATIFIED_EXCLUDING_INFO=$(echo "$DATA" | jq '[.[] | select(.proposal_type != "InfoAction" and .ratified_epoch != null)] | length')

if [ "$TOTAL_EXCLUDING_INFO" -gt 0 ]; then
    RATIFICATION_MARGIN_EXCLUDING_INFO=$(echo "scale=2; ($TOTAL_RATIFIED_EXCLUDING_INFO * 100) / $TOTAL_EXCLUDING_INFO" | bc)
    echo -e "${BLUE}Ratification Margin (excl. Info Actions):${NC} $RATIFICATION_MARGIN_EXCLUDING_INFO%"
fi

echo ""

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Error: CSV file not found at $CSV_FILE${NC}"
    exit 1
fi

# Read Intersect stake accounts from CSV
declare -a INTERSECT_ACCOUNTS
while IFS= read -r account; do
    if [ ! -z "$account" ] && [ "$account" != "stakeAccount" ]; then
        INTERSECT_ACCOUNTS+=("$account")
    fi
done < "$CSV_FILE"

# Remove duplicates
declare -a UNIQUE_ACCOUNTS
for account in "${INTERSECT_ACCOUNTS[@]}"; do
    if [[ ! " ${UNIQUE_ACCOUNTS[@]} " =~ " ${account} " ]]; then
        UNIQUE_ACCOUNTS+=("$account")
    fi
done
INTERSECT_ACCOUNTS=("${UNIQUE_ACCOUNTS[@]}")

# Build filter for Intersect accounts
ACCOUNT_FILTER=""
for i in "${!INTERSECT_ACCOUNTS[@]}"; do
    if [ $i -eq 0 ]; then
        ACCOUNT_FILTER=".return_address == \"${INTERSECT_ACCOUNTS[$i]}\""
    else
        ACCOUNT_FILTER="$ACCOUNT_FILTER or .return_address == \"${INTERSECT_ACCOUNTS[$i]}\""
    fi
done

# Additional Intersect governance action IDs
INTERSECT_GOV_IDS=("gov_action1q0m8z7glm9cprucwf44hdjdfra8khnakpm3hu5ueh929hvljw4aqqzuxfxz" "gov_action1jr84r96lnsvu9yd6c0jhxe9gj5r7vnd2pgkntc6klplxdpyzz4tqqc9uldx")

# Add governance IDs to filter
for id in "${INTERSECT_GOV_IDS[@]}"; do
    ACCOUNT_FILTER="$ACCOUNT_FILTER or .proposal_id == \"$id\""
done

# Filter data for Intersect accounts and governance IDs
INTERSECT_DATA=$(echo "$DATA" | jq "[.[] | select($ACCOUNT_FILTER)]")

# Intersect counts
INTERSECT_TOTAL=$(echo "$INTERSECT_DATA" | jq 'length')
INTERSECT_RATIFIED=$(echo "$INTERSECT_DATA" | jq '[.[] | select(.ratified_epoch != null)] | length')

echo -e "${BLUE}Intersect Actions Submitted:${NC}       $INTERSECT_TOTAL"
echo -e "${BLUE}Intersect Ratified:${NC}                $INTERSECT_RATIFIED"

if [ "$INTERSECT_TOTAL" -gt 0 ]; then
    INTERSECT_MARGIN=$(echo "scale=2; ($INTERSECT_RATIFIED * 100) / $INTERSECT_TOTAL" | bc)
    INTERSECT_PERCENT=$(echo "scale=2; ($INTERSECT_TOTAL * 100) / $TOTAL" | bc)
    # echo -e "${BLUE}Intersect Ratification Margin:${NC}    $INTERSECT_MARGIN%"
    echo -e "${BLUE}Intersect % of Total:${NC}            $INTERSECT_PERCENT%"
fi

# Intersect ratification margin excluding Info Actions
INTERSECT_TOTAL_EXCLUDING_INFO=$(echo "$INTERSECT_DATA" | jq '[.[] | select(.proposal_type != "InfoAction")] | length')
INTERSECT_RATIFIED_EXCLUDING_INFO=$(echo "$INTERSECT_DATA" | jq '[.[] | select(.proposal_type != "InfoAction" and .ratified_epoch != null)] | length')

if [ "$INTERSECT_TOTAL_EXCLUDING_INFO" -gt 0 ]; then
    INTERSECT_MARGIN_EXCLUDING_INFO=$(echo "scale=2; ($INTERSECT_RATIFIED_EXCLUDING_INFO * 100) / $INTERSECT_TOTAL_EXCLUDING_INFO" | bc)
    echo -e "${BLUE}Intersect Ratification Margin (excl. Info):${NC} $INTERSECT_MARGIN_EXCLUDING_INFO%"
fi

echo ""

#####################################################################
# SECTOR 2: BREAKDOWN BY TYPE
#####################################################################

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}SECTOR 2: GOVERNANCE ACTIONS BY TYPE BREAKDOWN${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Function to display type breakdown
display_type_breakdown() {
    local type_name=$1
    local type_value=$2
    
    # Overall stats
    local total_of_type=$(echo "$DATA" | jq "[.[] | select(.proposal_type == \"$type_value\")] | length")
    local ratified_of_type=$(echo "$DATA" | jq "[.[] | select(.proposal_type == \"$type_value\" and .ratified_epoch != null)] | length")
    
    # Intersect stats
    local intersect_of_type=$(echo "$INTERSECT_DATA" | jq "[.[] | select(.proposal_type == \"$type_value\")] | length")
    local intersect_ratified_of_type=$(echo "$INTERSECT_DATA" | jq "[.[] | select(.proposal_type == \"$type_value\" and .ratified_epoch != null)] | length")
    
    # Calculations
    local overall_margin=0
    local intersect_margin=0
    local intersect_percent_of_total=0
    local intersect_percent_of_ratified=0
    
    if [ "$total_of_type" -gt 0 ]; then
        overall_margin=$(echo "scale=2; ($ratified_of_type * 100) / $total_of_type" | bc)
    fi
    
    if [ "$intersect_of_type" -gt 0 ]; then
        intersect_margin=$(echo "scale=2; ($intersect_ratified_of_type * 100) / $intersect_of_type" | bc)
        intersect_percent_of_total=$(echo "scale=2; ($intersect_of_type * 100) / $total_of_type" | bc)
    fi
    
    if [ "$ratified_of_type" -gt 0 ] && [ "$intersect_ratified_of_type" -gt 0 ]; then
        intersect_percent_of_ratified=$(echo "scale=2; ($intersect_ratified_of_type * 100) / $ratified_of_type" | bc)
    fi
    
    # Display
    echo -e "${YELLOW}$type_name${NC}"
    echo -e "  ${BLUE}Total:${NC} $total_of_type submitted → $ratified_of_type ratified (${overall_margin}%)"
    
    if [ "$intersect_of_type" -gt 0 ]; then
        echo -e "  ${BLUE}Intersect:${NC} $intersect_of_type submitted → $intersect_ratified_of_type ratified (${intersect_margin}%)"
        echo -e "  ${GREEN}├─${NC} Intersect submitted $intersect_percent_of_total% of total $type_name submissions"
        echo -e "  ${GREEN}└─${NC} Intersect accounts hold $intersect_percent_of_ratified% of all ratified $type_name"
    else
        echo -e "  ${BLUE}Intersect:${NC} 0 submitted"
    fi
    echo ""
}

# Display each type
display_type_breakdown "Info Actions" "InfoAction"
display_type_breakdown "Parameter Updates" "ParameterChange"
display_type_breakdown "Constitution Updates" "NewConstitution"
display_type_breakdown "Committee Changes" "NewCommittee"
display_type_breakdown "Hard Fork Initiations" "HardForkInitiation"
display_type_breakdown "Treasury Withdrawals" "TreasuryWithdrawals"
display_type_breakdown "No Confidence Votes" "NoConfidence"

echo ""

#####################################################################
# SECTOR 3: METADATA SIGNATURES ANALYSIS
#####################################################################

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}SECTOR 3: GOVERNANCE ACTIONS SIGNED BY INTERSECT${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Intersect signature patterns - looking for "Intersect" or "intersect" in authors/signatures
INTERSECT_SIGNED=$(echo "$DATA" | jq '[.[] | select(.meta_json != null and (.meta_json.authors[] // empty | .name | ascii_downcase | contains("intersect")))] | length')
INTERSECT_SIGNED_RATIFIED=$(echo "$DATA" | jq '[.[] | select(.meta_json != null and (.meta_json.authors[] // empty | .name | ascii_downcase | contains("intersect")) and .ratified_epoch != null)] | length')

echo -e "${BLUE}Governance actions with Intersect signatures:${NC}  $INTERSECT_SIGNED"
echo -e "${BLUE}Ratified (Intersect signed):${NC}                 $INTERSECT_SIGNED_RATIFIED"

if [ "$INTERSECT_SIGNED" -gt 0 ]; then
    SIGNED_MARGIN=$(echo "scale=2; ($INTERSECT_SIGNED_RATIFIED * 100) / $INTERSECT_SIGNED" | bc)
    SIGNED_PERCENT=$(echo "scale=2; ($INTERSECT_SIGNED * 100) / $TOTAL" | bc)
    echo -e "${BLUE}Ratification margin (signed):${NC}              $SIGNED_MARGIN%"
    echo -e "${BLUE}% of total actions signed:${NC}                $SIGNED_PERCENT%"
fi

echo ""

# Breakdown by type for signed actions
echo -e "${BLUE}Signed Actions by Type:${NC}"
echo ""

# Function to display signed type breakdown
display_signed_type_breakdown() {
    local type_name=$1
    local type_value=$2
    
    # Overall stats for signed
    local signed_of_type=$(echo "$DATA" | jq "[.[] | select(.meta_json != null and (.meta_json.authors[] // empty | .name | ascii_downcase | contains(\"intersect\")) and .proposal_type == \"$type_value\")] | length")
    local signed_ratified_of_type=$(echo "$DATA" | jq "[.[] | select(.meta_json != null and (.meta_json.authors[] // empty | .name | ascii_downcase | contains(\"intersect\")) and .proposal_type == \"$type_value\" and .ratified_epoch != null)] | length")
    
    # Compare with Intersect submitted
    local intersect_submitted_of_type=$(echo "$INTERSECT_DATA" | jq "[.[] | select(.proposal_type == \"$type_value\")] | length")
    
    if [ "$signed_of_type" -gt 0 ]; then
        local signed_margin=$(echo "scale=2; ($signed_ratified_of_type * 100) / $signed_of_type" | bc)
        local signed_percent_of_intersect=0
        if [ "$intersect_submitted_of_type" -gt 0 ]; then
            signed_percent_of_intersect=$(echo "scale=2; ($signed_of_type * 100) / $intersect_submitted_of_type" | bc)
        fi
        
        echo -e "  ${YELLOW}$type_name:${NC} $signed_of_type signed → $signed_ratified_of_type ratified (${signed_margin}%)"
        if [ "$intersect_submitted_of_type" -gt 0 ]; then
            echo -e "    ${GREEN}└─${NC} $signed_percent_of_intersect% of Intersect $type_name submissions are signed"
        fi
    fi
}

# Display signed breakdown for each type
display_signed_type_breakdown "Info Actions" "InfoAction"
display_signed_type_breakdown "Parameter Updates" "ParameterChange"
display_signed_type_breakdown "Constitution Updates" "NewConstitution"
display_signed_type_breakdown "Committee Changes" "NewCommittee"
display_signed_type_breakdown "Hard Fork Initiations" "HardForkInitiation"
display_signed_type_breakdown "Treasury Withdrawals" "TreasuryWithdrawals"
display_signed_type_breakdown "No Confidence Votes" "NoConfidence"

#####################################################################
# SECTOR 4: ALL GOVERNANCE ACTIONS SUBMITTED BY INTERSECT
#####################################################################

echo ""
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}SECTOR 4: ALL GOVERNANCE ACTIONS SUBMITTED BY INTERSECT${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Function to display Intersect GAs by type
display_intersect_gas_by_type() {
    local type_name=$1
    local type_value=$2
    
    local type_gas=$(echo "$INTERSECT_DATA" | jq --arg type "$type_value" '[.[] | select(.proposal_type == $type)] | sort_by(.proposal_id)')
    local type_count=$(echo "$type_gas" | jq 'length')
    
    if [ "$type_count" -gt 0 ]; then
        echo -e "${BLUE}${type_name}:${NC} ($type_count)"
        echo "$type_gas" | jq -r '.[] | "  \(.proposal_id) - \(.meta_json.body.title // "N/A")"'
        echo ""
    fi
}

display_intersect_gas_by_type "Info Actions" "InfoAction"
display_intersect_gas_by_type "Parameter Updates" "ParameterChange"
display_intersect_gas_by_type "Constitution Updates" "NewConstitution"
display_intersect_gas_by_type "Committee Changes" "NewCommittee"
display_intersect_gas_by_type "Hard Fork Initiations" "HardForkInitiation"
display_intersect_gas_by_type "Treasury Withdrawals" "TreasuryWithdrawals"
display_intersect_gas_by_type "No Confidence Votes" "NoConfidence"

echo ""
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Analysis complete!${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

