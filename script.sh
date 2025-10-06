#!/bin/bash

# Define the keys directory
keys_dir="./keys"
txs_dir="./txs"
stake_dir="$txs_dir/stake"
stake_register_dir="$stake_dir/register"
stake_deleg_dir="$stake_dir/pool-deleg"
stake_vote_deleg_dir="$stake_dir/vote-deleg"
# tx_path_stub="$stake_dir/stake-register"
# tx_signed_path="$tx_path_stub.signed"
# tx_path_deleg="$stake_dir/stake-pool-deleg"
txs_drep_dir="$txs_dir/drep"

mkdir "$keys_dir"
mkdir -p "$txs_dir"
mkdir "$txs_drep_dir"
mkdir "$keys_dir/drep"

num=10  # Number of stake keys to generate

# ======================================================Generate multiple stake keys=================================================
for ((cnt=1; cnt<=num; cnt++)); do
    mkdir -p "$keys_dir/stake$cnt"

    cardano-cli conway stake-address key-gen \
      --verification-key-file "$keys_dir/stake$cnt/stake.vkey" \
      --signing-key-file "$keys_dir/stake$cnt/stake.skey"
    cardano-cli conway address key-gen \
      --verification-key-file "$keys_dir/stake$cnt/payment.vkey" \
      --signing-key-file "$keys_dir/stake$cnt/payment.skey"
    cardano-cli conway stake-address build \
        --stake-verification-key-file "$keys_dir/stake$cnt/stake.vkey" \
        --out-file "$keys_dir/stake$cnt/stake.addr"

    cardano-cli address build \
        --payment-verification-key-file "$keys_dir/stake$cnt/payment.vkey" \
        --stake-verification-key-file "$keys_dir/stake$cnt/stake.vkey" \
        --out-file "$keys_dir/stake$cnt/payment.addr"
    # Set permissions to read-only for owner, no write/execute for anyone
    sudo chmod 400 "$keys_dir/stake$cnt/stake.skey" "$keys_dir/stake$cnt/payment.skey" \
           
    
done
# Register the stake keys
key_reg_deposit_amount=$(cardano-cli conway query gov-state | jq -r .currentPParams.stakeAddressDeposit)

for ((cnt=1; cnt<=num; cnt++)); do
    cardano-cli conway stake-address registration-certificate \
    --stake-verification-key-file "$keys_dir/stake$cnt/stake.vkey" \
    --key-reg-deposit-amt "$key_reg_deposit_amount" \
    --out-file "$stake_register_dir/stake-register$cnt.cert"
done

# Build the transaction

# use witness-override 2 for the orch wallet and one stake key
for ((cnt=4; cnt<=num; cnt++)); do

    cardano-cli conway transaction build \
    --witness-override 2 \
    --tx-in $(cardano-cli conway query utxo --address $(cat ../smart-contracts/tests/payment.addr)  --out-file  /dev/stdout | jq -r 'keys[0]') \
    --change-address $(cat ../smart-contracts/tests/payment.addr)  \
    --certificate-file "$stake_register_dir/stake-register$cnt.cert" \
    --out-file "$stake_register_dir/stake-register$cnt.unsigned"

    # Sign the transaction

    cardano-cli conway transaction sign \
    --tx-body-file "$stake_register_dir/stake-register$cnt.unsigned" \
    --signing-key-file /home/ebardo/cardano/smart-contracts/tests/payment.skey \
    --signing-key-file "$keys_dir/stake$cnt/stake.skey" \
    --out-file "$stake_register_dir/stake-register$cnt.signed"

    # Submit the transaction
    cardano-cli conway transaction submit \
    --tx-file "$stake_register_dir/stake-register$cnt.signed"
    tx_id=$(cardano-cli conway transaction txid --tx-file "$stake_register_dir/stake-register$cnt.signed")
    echo "Transaction ID for stake address registration $cnt: $tx_id"
    read -p "Press [Enter] key to continue ..."
done



# ======================================================Delegate to an SPO=================================================
# SPO keyhash
spo_id="abfd70f18b095ce3c29b5d239e8fcfd2a55d476c75e640f07fc7616f"

for ((cnt=1; cnt<=num; cnt++)); do
    
    echo "Creating stake pool delegation certificate \\n"

    cardano-cli conway stake-address stake-delegation-certificate \
    --stake-verification-key-file $keys_dir/stake$cnt/stake.vkey \
    --stake-pool-id "$spo_id" \
    --out-file "$stake_deleg_dir/stake-pool-deleg$cnt.cert"

    echo "Building stake pool delegation transaction \\n"

    cardano-cli conway transaction build \
    --witness-override 2 \
    --tx-in $(cardano-cli conway query utxo --address $(cat ../smart-contracts/tests/payment.addr)  --out-file  /dev/stdout | jq -r 'keys[0]') \
    --change-address $(cat ../smart-contracts/tests/payment.addr) \
    --certificate-file "$stake_deleg_dir/stake-pool-deleg$cnt.cert" \
    --out-file "$stake_deleg_dir/stake-pool-deleg$cnt.unsigned"

    echo "Signing stake pool delegation transaction \n"

    cardano-cli conway transaction sign \
    --tx-body-file "$stake_deleg_dir/stake-pool-deleg$cnt.unsigned"\
    --signing-key-file /home/ebardo/cardano/smart-contracts/tests/payment.skey \
    --signing-key-file "$keys_dir/stake$cnt/stake.skey" \
     --out-file "$stake_deleg_dir/stake-pool-deleg$cnt.signed"

    echo "Submitting stake pool delegation transaction \n"

    cardano-cli conway transaction submit \
    --tx-file "$stake_deleg_dir/stake-pool-deleg$cnt.signed"
    read -p "Press [Enter] key to continue ..."
done

# ======================================================Create a Dreps=================================================
# Create drep keys and id 
cardano-cli conway governance drep key-gen \
 --verification-key-file "$keys_dir/drep/drep2.vkey" \
 --signing-key-file "$keys_dir/drep/drep2.skey"

cardano-cli conway governance drep id \
 --drep-verification-key-file "$keys_dir/drep/drep2.vkey" \
 --out-file "$keys_dir/drep/drep2.id"

 #Register the drep
 cardano-cli conway governance drep registration-certificate \
 --drep-key-hash "$(cat $keys_dir/drep/drep2.id)" \
 --key-reg-deposit-amt "$(cardano-cli conway query gov-state | jq -r .currentPParams.dRepDeposit)" \
 --out-file $txs_drep_dir/drep-register2.cert

cardano-cli conway transaction build \
 --witness-override 2 \
 --tx-in $(cardano-cli conway query utxo --address $(cat ../smart-contracts/tests/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat ../smart-contracts/tests/payment.addr) \
 --certificate-file $txs_drep_dir/drep-register2.cert \
 --out-file $txs_drep_dir/drep-reg-tx.unsigned

 # Sign the transaction with drep key
cardano-cli conway transaction sign \
 --tx-body-file $txs_drep_dir/drep-reg-tx.unsigned \
 --signing-key-file $keys_dir/drep/drep2.skey \
 --signing-key-file '/home/ebardo/cardano/smart-contracts/tests/payment.skey' \
 --out-file $txs_drep_dir/drep-reg-tx.signed

 cardano-cli conway transaction assemble \
  --tx-body-file $txs_drep_dir/drep-reg-tx.unsigned \
  --witness-file $txs_drep_dir/orch.witness \
  --witness-file $txs_drep_dir/drep.witness\
  --out-file $txs_drep_dir/drep-reg-tx.fully-signed

cardano-cli conway transaction submit \
 --tx-file $txs_drep_dir/drep-reg-tx.fully-signed

# ======================================================Delegate to a Drep=================================================
#Delegate to the drep created
drep_id=$(cat $keys_dir/drep/drep.id)
# 1 - create the vote delegation certificates
export i=1
for ((cnt=i; cnt<=num; cnt++)); do

drepId=$(($cnt % 2 + 1))
drep_id=$(cat $keys_dir/drep/drep$drepId.id)

    cardano-cli conway stake-address vote-delegation-certificate \
    --stake-verification-key-file $keys_dir/stake$cnt/stake.vkey \
    --drep-key-hash "$drep_id" \
    --out-file $stake_dir/vote-deleg/vote-deleg-key-hash$cnt.cert
 
# 2 - build the transaction (To follow CIP-149, we need to attach a metadata file)

metadataId=$(($cnt % 3 + 1)) # Cycle through 3 different metadata files for testing purposes
cardano-cli conway transaction build \
    --witness-override 2 \
    --tx-in $(cardano-cli conway query utxo --address $(cat ../smart-contracts/tests/payment.addr)  --out-file  /dev/stdout | jq -r 'keys[0]') \
    --change-address $(cat ../smart-contracts/tests/payment.addr) \
    --certificate-file $stake_dir/vote-deleg/vote-deleg-key-hash$cnt.cert \
    --metadata-json-file ./metadata/drep-compensation-$metadataId.jsonld \
    --out-file $stake_dir/vote-deleg/vote-deleg-$cnt.unsigned

cardano-cli conway transaction sign \
    --tx-body-file ./txs/stake/vote-deleg/vote-deleg-$cnt.unsigned \
    --signing-key-file /home/ebardo/cardano/smart-contracts/tests/payment.skey \
    --signing-key-file $keys_dir/stake$cnt/stake.skey \
    --out-file ./txs/stake/vote-deleg/vote-deleg-$cnt.signed

cardano-cli conway transaction submit \
    --tx-file ./txs/stake/vote-deleg/vote-deleg-$cnt.signed
echo $(cardano-cli conway transaction txid --tx-file ./txs/stake/vote-deleg/vote-deleg-$cnt.signed)
read -p "Press [Enter] key to continue to the next delegation..."
done

''''' 
Test by querying :
1- Drep info , delegators and check the compensation % if any 
2- Stake adresses that have delegated to the drep , what % have opt in for compensation
'''''
# cardano-cli conway transaction build \
#  --tx-in $(cardano-cli conway query utxo --address $(cat ./keys/stake3/payment.addr)  --out-file  /dev/stdout | jq -r 'keys[0]') \
#  --change-address $(cat ./keys/stake3/payment.addr) \
#  --tx-out $(cat ../smart-contracts/tests/payment.addr)+9997000000 \
#  --out-file ./txs/stake/query-utxo3.unsigned

#  cardano-cli conway transaction sign \
#     --tx-body-file ./txs/stake/query-utxo3.unsigned \
#     --signing-key-file ./keys/stake3/payment.skey\
#     --out-file ./txs/stake/query-utxo3.signed

# cardano-cli conway transaction submit \
#     --tx-file ./txs/stake/query-utxo3.signed