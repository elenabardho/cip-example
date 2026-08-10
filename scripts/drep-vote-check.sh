#!/bin/bash

#####################################################################
# DRep Voting Comparison Script
#
# 1. Lists all active (registered) DReps that have NOT voted on the
#    TARGET proposal.
# 2. For DReps that voted on the REFERENCE proposal, compares their
#    behaviour on the TARGET: not yet voted / same vote / changed vote.
# 3. For DReps that CHANGED their vote: fetches full drep_info
#    (voting power, delegators, expiry, active status) and resolves
#    the name from their metadata URL.
#
# Output: coloured terminal summary + two CSV files
#####################################################################

set -euo pipefail

# ── Colour codes ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ── Configuration ─────────────────────────────────────────────────
TARGET_PROPOSAL="gov_action1k02990lhw6wh74t7c6ufw3mqaek9ujtvyan99dj5qv5kvcs7pn8sgx6wlxf"
REF_PROPOSAL="gov_action13tfag48nf94rtjcdq7c06vhkslmxxw9h6c88sl7q5g5nnewcsvlp2tyw3h6"
BASE_URL="https://api.koios.rest/api/v1"
PAGE_SIZE=1000

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CSV_NOT_VOTED="drep_not_voted_target_${TIMESTAMP}.csv"
CSV_COMPARISON="drep_ref_vs_target_comparison_${TIMESTAMP}.csv"

# ── Helper: paginate through a Koios GET endpoint ─────────────────
fetch_all_pages() {
    local endpoint="$1"
    local extra_params="${2:-}"
    local all_data="[]"
    local offset=0

    while true; do
        local url="${BASE_URL}${endpoint}?limit=${PAGE_SIZE}&offset=${offset}"
        [[ -n "$extra_params" ]] && url="${url}&${extra_params}"

        local page
        page=$(curl -sf -X GET "$url" -H "accept: application/json") || {
            echo -e "${RED}✗ Failed to fetch: ${url}${NC}" >&2
            exit 1
        }

        local count
        count=$(echo "$page" | jq 'length')
        [[ "$count" -eq 0 ]] && break

        all_data=$(printf '%s\n%s' "$all_data" "$page" | jq -s '.[0] + .[1]')

        [[ "$count" -lt "$PAGE_SIZE" ]] && break
        offset=$((offset + PAGE_SIZE))
        echo -e "  ${YELLOW}↳ paginating — ${offset} records fetched so far…${NC}" >&2
    done

    echo "$all_data"
}

# ── Helper: POST to /drep_info for a JSON array of drep_ids ───────
# Returns the raw drep_info array
fetch_drep_info_batch() {
    local ids_json="$1"   # e.g. ["drep1...", "drep1..."]
    curl -sf -X POST "${BASE_URL}/drep_info" \
        -H "accept: application/json" \
        -H "content-type: application/json" \
        -d "{\"_drep_ids\": ${ids_json}}" || echo "[]"
}

# ── Helper: resolve DRep name from metadata URL ────────────────────
# Tries body.dRepName then body.givenName; returns "—" on failure
fetch_drep_name() {
    local meta_url="$1"
    if [[ -z "$meta_url" || "$meta_url" == "null" ]]; then
        echo "—"
        return
    fi
    local meta
    meta=$(curl -sf --max-time 6 "$meta_url" 2>/dev/null) || { echo "—"; return; }
    local name
    name=$(echo "$meta" | jq -r '(.body.dRepName // .body.givenName // "—") | if . == null then "—" else . end' 2>/dev/null) || name="—"
    echo "$name"
}

# ── Helper: format lovelace → ADA with thousands separator ────────
lovelace_to_ada() {
    local lovelace="$1"
    # integer division, then add commas
    printf "%'.0f" "$(echo "scale=0; ${lovelace}/1000000" | bc)" 2>/dev/null || echo "$lovelace"
}

# ── Vote badge ────────────────────────────────────────────────────
vote_badge() {
    case "$1" in
        Yes)     echo -e "${GREEN}Yes${NC}" ;;
        No)      echo -e "${RED}No${NC}" ;;
        Abstain) echo -e "${YELLOW}Abstain${NC}" ;;
        *)       echo -e "${CYAN}$1${NC}" ;;
    esac
}

# ── Banner ────────────────────────────────────────────────────────
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           DRep Voting Comparison Analysis                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Target proposal  :${NC} ${TARGET_PROPOSAL}"
echo -e "${BLUE}Reference proposal:${NC} ${REF_PROPOSAL}"
echo ""

#####################################################################
# STEP 1 — ALL ACTIVE DREPS
#####################################################################
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA} STEP 1 · Fetching Active DReps${NC}"
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Querying /drep_list …${NC}"
ALL_DREPS=$(fetch_all_pages "/drep_list" "")
TOTAL_DREPS=$(echo "$ALL_DREPS" | jq 'length')
ACTIVE_DREPS=$(echo "$ALL_DREPS" | jq '[.[] | select(.registered == true)]')
ACTIVE_COUNT=$(echo "$ACTIVE_DREPS" | jq 'length')
echo -e "${GREEN}✓ Total DRep entries (all statuses) :${NC} ${TOTAL_DREPS}"
echo -e "${GREEN}✓ Active / registered DReps          :${NC} ${ACTIVE_COUNT}"
echo ""

#####################################################################
# STEP 2 — VOTES ON BOTH PROPOSALS
#####################################################################
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA} STEP 2 · Fetching Votes on Both Proposals${NC}"
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Querying votes on TARGET proposal …${NC}"
TARGET_ALL_VOTES=$(fetch_all_pages "/proposal_votes" "_proposal_id=${TARGET_PROPOSAL}")
TARGET_DREP_VOTES=$(echo "$TARGET_ALL_VOTES" | jq '[.[] | select(.voter_role == "DRep")]')
TARGET_VOTED_COUNT=$(echo "$TARGET_DREP_VOTES" | jq 'length')
T_YES=$(echo "$TARGET_DREP_VOTES"     | jq '[.[] | select(.vote == "Yes")]     | length')
T_NO=$(echo "$TARGET_DREP_VOTES"      | jq '[.[] | select(.vote == "No")]      | length')
T_ABSTAIN=$(echo "$TARGET_DREP_VOTES" | jq '[.[] | select(.vote == "Abstain")] | length')
echo -e "${GREEN}✓ DRep votes on target :${NC} ${TARGET_VOTED_COUNT}  (Yes: ${T_YES}  No: ${T_NO}  Abstain: ${T_ABSTAIN})"

echo ""
echo -e "${YELLOW}Querying votes on REFERENCE proposal …${NC}"
REF_ALL_VOTES=$(fetch_all_pages "/proposal_votes" "_proposal_id=${REF_PROPOSAL}")
REF_DREP_VOTES=$(echo "$REF_ALL_VOTES" | jq '[.[] | select(.voter_role == "DRep")]')
REF_VOTED_COUNT=$(echo "$REF_DREP_VOTES" | jq 'length')
R_YES=$(echo "$REF_DREP_VOTES"     | jq '[.[] | select(.vote == "Yes")]     | length')
R_NO=$(echo "$REF_DREP_VOTES"      | jq '[.[] | select(.vote == "No")]      | length')
R_ABSTAIN=$(echo "$REF_DREP_VOTES" | jq '[.[] | select(.vote == "Abstain")] | length')
echo -e "${GREEN}✓ DRep votes on reference:${NC} ${REF_VOTED_COUNT}  (Yes: ${R_YES}  No: ${R_NO}  Abstain: ${R_ABSTAIN})"
echo ""

#####################################################################
# STEP 3 — ACTIVE DREPS NOT VOTED ON TARGET
#####################################################################
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA} STEP 3 · Active DReps That Have NOT Voted on Target Proposal${NC}"
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo ""

TARGET_VOTER_IDS=$(echo "$TARGET_DREP_VOTES" | jq '[.[].voter_id]')
NOT_VOTED_DREPS=$(echo "$ACTIVE_DREPS" | jq \
    --argjson voted "$TARGET_VOTER_IDS" \
    '[.[] | select(.drep_id as $id | ($voted | index($id)) == null)]')
NOT_VOTED_COUNT=$(echo "$NOT_VOTED_DREPS" | jq 'length')

echo -e "${RED}Active DReps NOT voted on target : ${NOT_VOTED_COUNT} / ${ACTIVE_COUNT}${NC}"
echo -e "${BLUE}(Full list saved to ${CSV_NOT_VOTED})${NC}"
echo ""

{
    echo "drep_id,has_script"
    echo "$NOT_VOTED_DREPS" | jq -r '.[] | [.drep_id, (.has_script | tostring)] | @csv'
} > "$CSV_NOT_VOTED"
echo -e "${GREEN}✓ Not-voted CSV written: ${CSV_NOT_VOTED}${NC}"
echo ""

#####################################################################
# STEP 4 — COMPARISON: REFERENCE VOTERS vs TARGET
#####################################################################
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA} STEP 4 · Reference Proposal Voters — Target Comparison${NC}"
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo ""

TARGET_VOTE_MAP=$(echo "$TARGET_DREP_VOTES" | \
    jq 'map({(.voter_id): .vote}) | add // {}')

CNT_NOT_YET=$(echo "$REF_DREP_VOTES" | jq --argjson m "$TARGET_VOTE_MAP" \
    '[.[] | select($m[.voter_id] == null)] | length')
CNT_SAME=$(echo "$REF_DREP_VOTES" | jq --argjson m "$TARGET_VOTE_MAP" \
    '[.[] | select($m[.voter_id] != null and $m[.voter_id] == .vote)] | length')
CNT_DIFF=$(echo "$REF_DREP_VOTES" | jq --argjson m "$TARGET_VOTE_MAP" \
    '[.[] | select($m[.voter_id] != null and $m[.voter_id] != .vote)] | length')

echo -e "${BLUE}Of ${REF_VOTED_COUNT} DReps that voted on the reference proposal:${NC}"
echo -e "  ${YELLOW}Not yet voted on target  :${NC}  ${CNT_NOT_YET}"
echo -e "  ${GREEN}Voted same on target     :${NC}  ${CNT_SAME}"
echo -e "  ${RED}Voted DIFFERENTLY        :${NC}  ${CNT_DIFF}"
echo ""

# ── 4a: DReps who voted on reference but NOT YET on target ────────
echo -e "${YELLOW}── DReps voted on reference but NOT YET voted on target ────────${NC}"
NOT_YET_LIST=$(echo "$REF_DREP_VOTES" | jq --argjson m "$TARGET_VOTE_MAP" \
    '[.[] | select($m[.voter_id] == null) | {drep_id: .voter_id, ref_vote: .vote}]')

if [ "$CNT_NOT_YET" -eq 0 ]; then
    echo -e "  ${GREEN}All reference-proposal voters have also voted on the target.${NC}"
elif [ "$CNT_NOT_YET" -gt 50 ]; then
    echo -e "  (${CNT_NOT_YET} DReps — showing first 50; full list in ${CSV_COMPARISON})"
    echo "$NOT_YET_LIST" | jq -r '.[0:50][] | "  \(.drep_id)  Ref: \(.ref_vote)  →  Not Voted"'
else
    echo "$NOT_YET_LIST" | jq -r '.[] | "  \(.drep_id)  Ref: \(.ref_vote)  →  Not Voted"'
fi
echo ""

#####################################################################
# STEP 5 — CHANGED-VOTE DREPS: FULL DETAILS
#####################################################################
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA} STEP 5 · DReps Who Changed Their Vote — Full Details${NC}"
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo ""

DIFF_LIST=$(echo "$REF_DREP_VOTES" | jq --argjson m "$TARGET_VOTE_MAP" \
    '[.[] | select($m[.voter_id] != null and $m[.voter_id] != .vote) |
     {drep_id: .voter_id, ref_vote: .vote, target_vote: $m[.voter_id]}]')

if [ "$CNT_DIFF" -eq 0 ]; then
    echo -e "  ${GREEN}No DRep changed their vote between the two proposals.${NC}"
else
    echo -e "${YELLOW}Fetching drep_info for ${CNT_DIFF} DRep(s) that changed vote…${NC}"

    # Build JSON array of IDs and batch-fetch drep_info
    DIFF_IDS=$(echo "$DIFF_LIST" | jq '[.[].drep_id]')
    DIFF_INFO_RAW=$(fetch_drep_info_batch "$DIFF_IDS")

    # Build lookup map: { drep_id: info_object }
    DIFF_INFO_MAP=$(echo "$DIFF_INFO_RAW" | jq 'map({(.drep_id): .}) | add // {}')

    # Merge vote data with drep_info
    ENRICHED=$(printf '%s\n%s' "$DIFF_LIST" "$DIFF_INFO_RAW" | jq -s '
        (.[1] | map({(.drep_id): .}) | add // {}) as $info |
        .[0] | map(. + ($info[.drep_id] // {}))
    ')

    echo ""
    DIFF_COUNT=$(echo "$ENRICHED" | jq 'length')

    for i in $(seq 0 $((DIFF_COUNT - 1))); do
        ROW=$(echo "$ENRICHED" | jq ".[$i]")

        DREP_ID=$(echo "$ROW"   | jq -r '.drep_id')
        REF_V=$(echo "$ROW"     | jq -r '.ref_vote')
        TGT_V=$(echo "$ROW"     | jq -r '.target_vote')
        STATUS=$(echo "$ROW"    | jq -r '.drep_status // "—"')
        ACTIVE=$(echo "$ROW"    | jq -r '.active // "—"')
        EXPIRES=$(echo "$ROW"   | jq -r '.expires_epoch_no // "—"')
        DELEGATORS=$(echo "$ROW"| jq -r '.live_delegator_count // "—"')
        META_URL=$(echo "$ROW"  | jq -r '.meta_url // ""')
        RAW_ADA=$(echo "$ROW"   | jq -r '.amount // "0"')
        ADA=$(lovelace_to_ada "$RAW_ADA")

        # Resolve DRep name from metadata
        NAME=$(fetch_drep_name "$META_URL")

        echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}DRep ID    :${NC} ${DREP_ID}"
        echo -e "  ${BOLD}Name       :${NC} ${NAME}"
        echo -e "  ${BOLD}Vote change:${NC} $(vote_badge "$REF_V") (Reference)  →  $(vote_badge "$TGT_V") (Target)"
        echo -e "  ${BOLD}Status     :${NC} ${STATUS}  |  Active: ${ACTIVE}  |  Expires epoch: ${EXPIRES}"
        echo -e "  ${BOLD}Voting power:${NC} ${ADA} ADA"
        echo -e "  ${BOLD}Delegators :${NC} ${DELEGATORS}"
        if [[ -n "$META_URL" && "$META_URL" != "null" ]]; then
            echo -e "  ${BOLD}Metadata   :${NC} ${META_URL}"
        fi
        echo ""
    done
fi

#####################################################################
# STEP 6 — SAVE COMPARISON CSV (with voting power)
#####################################################################
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA} STEP 6 · Saving Comparison CSV${NC}"
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Fetch drep_info in chunks of 500 for all reference voters
echo -e "${YELLOW}Fetching voting power for ${REF_VOTED_COUNT} reference voters…${NC}"
REF_IDS=$(echo "$REF_DREP_VOTES" | jq '[.[].voter_id]')
REF_INFO_ALL="[]"
CHUNK_SIZE=500
TOTAL_IDS=$(echo "$REF_IDS" | jq 'length')
OFFSET_I=0
while [ "$OFFSET_I" -lt "$TOTAL_IDS" ]; do
    CHUNK=$(echo "$REF_IDS" | jq --argjson o "$OFFSET_I" --argjson c "$CHUNK_SIZE" '.[$o:$o+$c]')
    CHUNK_INFO=$(fetch_drep_info_batch "$CHUNK")
    REF_INFO_ALL=$(printf '%s\n%s' "$REF_INFO_ALL" "$CHUNK_INFO" | jq -s '.[0] + .[1]')
    OFFSET_I=$((OFFSET_I + CHUNK_SIZE))
done

# Build lookup: { drep_id: amount_in_ada }
# amount is in lovelace — divide by 1_000_000 for ADA (integer)
ADA_MAP=$(echo "$REF_INFO_ALL" | jq '
    map({(.drep_id): (.amount // "0" | tonumber / 1000000 | floor)}) | add // {}')

echo -e "${GREEN}✓ Voting power fetched for $(echo "$REF_INFO_ALL" | jq 'length') DReps${NC}"
echo ""

{
    echo "drep_id,ref_proposal_vote,target_proposal_vote,status,voting_power_ada"
    echo "$REF_DREP_VOTES" | jq --argjson m "$TARGET_VOTE_MAP" --argjson ada "$ADA_MAP" -r '
        .[] |
        [
            .voter_id,
            .vote,
            ($m[.voter_id] // "Not Voted"),
            (if   $m[.voter_id] == null  then "Not Voted on Target"
             elif $m[.voter_id] == .vote then "Same Vote"
             else                             "Changed Vote"
             end),
            ($ada[.voter_id] // 0 | tostring)
        ] | @csv'
} > "$CSV_COMPARISON"

echo -e "${GREEN}✓ Comparison CSV written: ${CSV_COMPARISON}${NC}"
echo ""

#####################################################################
# SUMMARY
#####################################################################
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} SUMMARY${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Active DReps total              : ${ACTIVE_COUNT}"
echo -e "  ${RED}Did NOT vote on target          : ${NOT_VOTED_COUNT}${NC}"
echo -e "  Voted on target                 : ${TARGET_VOTED_COUNT}  (Yes: ${T_YES}  No: ${T_NO}  Abstain: ${T_ABSTAIN})"
echo ""
echo -e "  Voted on reference proposal     : ${REF_VOTED_COUNT}  (Yes: ${R_YES}  No: ${R_NO}  Abstain: ${R_ABSTAIN})"
echo -e "  ${YELLOW}  ↳ Not yet on target            : ${CNT_NOT_YET}${NC}"
echo -e "  ${GREEN}  ↳ Same vote on target          : ${CNT_SAME}${NC}"
echo -e "  ${RED}  ↳ Changed vote on target       : ${CNT_DIFF}${NC}"
echo ""
echo -e "  Output files:"
echo -e "    ${BLUE}${CSV_NOT_VOTED}${NC}   — active DReps that haven't voted on target"
echo -e "    ${BLUE}${CSV_COMPARISON}${NC}  — per-DRep comparison (ref vote → target vote)"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Analysis complete!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
