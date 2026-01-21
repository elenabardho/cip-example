export payment_addr="addr_test1qphtuq30j8tvmq0v38l9zye7sun36n6nzyygcc2mqds2sdssfd7ly7km85wtqgdempk3rfwn96px6l5k5n6ezw8ujgps20sdh8"

cardano-cli conway transaction build \
    $(cardano-cli conway query utxo --address $payment_addr --out-file /dev/stdout \
        | jq -r 'to_entries 
        | map(select(.value.datum == null and .value.datumhash == null and .value.inlineDatum == null and .value.inlineDatumRaw == null and .value.referenceScript == null)) 
        | map(" --tx-in " + .key) 
        | .[]') \
  --change-address "$payment_addr" \
  --out-file "/Users/elenabardho/Cardano/cip-example/combineUtxo.unsigned"