#!/bin/bash

SCRIPT_HASH_1="8583857e4a12ffe1e6f641a1785a0f2f036c565cfbe6ff9db8e5a469"
SCRIPT_HASH_2="eb06997a94b339ee0b0dd0de7bfec2a184d1af577586654d44e90558"
FROM_EPOCH=$(cardano-cli query tip | jq '.epoch' )
SHOW_PROPOSAL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --from-epoch)
      FROM_EPOCH="$2"
      shift 2
      ;;
    --show-proposal)
      SHOW_PROPOSAL=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

EPOCH_FILTER="ratified_epoch=not.is.null"
if [[ -n "$FROM_EPOCH" ]]; then
  EPOCH_FILTER="ratified_epoch=gte.$FROM_EPOCH"
fi

curl -sG "https://api.koios.rest/api/v1/proposal_list" \
  --header 'Accept: application/json' \
  --data-urlencode "$EPOCH_FILTER" \
  --data-urlencode "proposal_type=eq.TreasuryWithdrawals" \
  | jq --arg h1 "$SCRIPT_HASH_1" --arg h2 "$SCRIPT_HASH_2" --argjson show_proposal "$SHOW_PROPOSAL" '
    [.[] | select(
      ([.proposal_description.contents[0][][0].credential.scriptHash] | any(. == $h1 or . == $h2))
    ) | {
      proposal_id,
      ratified_epoch,
      meta_url,
      title: .meta_json.body.title
    } + (if $show_proposal then { proposal_description } else {} end)]
  '
