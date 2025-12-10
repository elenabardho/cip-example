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

    tx_id=$(cardano-cli conway transaction txid --tx-file "$stake_deleg_dir/stake-pool-deleg$cnt.signed")
    echo "Transaction ID for stake pool delegation $cnt: $tx_id"
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
 --drep-key-hash "$(cat $keys_dir/drep/drep.id)" \
 --key-reg-deposit-amt "$(cardano-cli conway query gov-state | jq -r .currentPParams.dRepDeposit)" \
 --drep-metadata-url "https://ipfs.io/ipfs/bafkreiaebdt43kqssaajkcpbg7wab5vq4g6e5kzwf4pals74lqk744wjrq" \
 --drep-metadata-hash "0a9cc483c16fcf5e1d04e35f6e25695952a2d2bc0c86897544d01c342775681c" \
 --check-drep-metadata-hash \
 --out-file $txs_drep_dir/drep-register-update.cert

cardano-cli conway transaction build \
 --witness-override 2 \
 --tx-in $(cardano-cli conway query utxo --address $(cat ../smart-contracts/tests/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat ../smart-contracts/tests/payment.addr) \
 --certificate-file $txs_drep_dir/drep-register.cert \
 --out-file $txs_drep_dir/drep-reg-tx.unsigned

 # Sign the transaction with drep key
cardano-cli conway transaction sign \
 --tx-body-file $txs_drep_dir/drep-reg-tx.unsigned \
 --signing-key-file $keys_dir/drep/drep.skey \
 --signing-key-file '/home/ebardo/cardano/smart-contracts/tests/payment.skey' \
 --out-file $txs_drep_dir/drep-reg-tx.signed

 cardano-cli conway transaction assemble \
  --tx-body-file $txs_drep_dir/drep-reg-tx.unsigned \
  --witness-file $txs_drep_dir/orch.witness \
  --witness-file $txs_drep_dir/drep.witness\
  --out-file $txs_drep_dir/drep-reg-tx.fully-signed

cardano-cli conway transaction submit \
 --tx-file $txs_drep_dir/drep-reg-tx.signed

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

#=================================================Withdraw rewards + donate to a dRep=========================================================

cardano-cli conway transaction build-raw \
 --tx-in 6709d5d4fa3b6c526879ab99cc50c67938ca6dfd1382838aed554dc4e90806c3#5 \
 --withdrawal stake_test1uqgykl0j0tdn689syxuasmg35hfjaqnd06t2fav38r7fyqcc0w7lk+3382884997 \
 --tx-out addr_test1vqwq0fz83ux6rwvm6r2fmegtzhrnl4tk00h74hhrwwje69qez9ftk+507432749\
 --tx-out addr_test1qphtuq30j8tvmq0v38l9zye7sun36n6nzyygcc2mqds2sdssfd7ly7km85wtqgdempk3rfwn96px6l5k5n6ezw8ujgps20sdh8+2879452248 \
 --fee 1000000 \
 --out-file withdrawal-elena.unsigned

cardano-cli conway transaction sign \

cardano-cli conway transaction build \
    --tx-in 058d6f46cbc9ae0495ed9d5fbe03547f6971f7f302f00605def67c845f4fdb16#0 \
    --withdrawal stake_test1ursa8kegf22wcjqqlc0230rtlemck5lhqycd3u8lattqh2c2ckq5g+700000000000 \
    --change-address $address \
    --tx-out 

cardano-cli conway transaction build \
    --socket-path /Users/elenabardho/.dmtr/tmp/skillful-patience-7gn0eo/cardanonode-opplay.socket \
    --testnet-magic 2 \
    --tx-in 09e735369a1782d190dab39c9f7a94bcc9b4faf40f0148c623f96fa4686f063f#0 \
    --withdrawal stake_test1uqgykl0j0tdn689syxuasmg35hfjaqnd06t2fav38r7fyqcc0w7lk+435725771  \
    --tx-out addr_test1vqwq0fz83ux6rwvm6r2fmegtzhrnl4tk00h74hhrwwje69qez9ftk+65358865 \
    --change-address addr_test1qphtuq30j8tvmq0v38l9zye7sun36n6nzyygcc2mqds2sdssfd7ly7km85wtqgdempk3rfwn96px6l5k5n6ezw8ujgps20sdh8 \
    --out-file ./cip-example/tx.unsigned

''''' 
Test by querying :
1- Drep info , delegators and check the compensation % if any 
2- Stake adresses that have delegated to the drep , what % have opt in for compensation
'''''

# ======================================================Update a Drep=================================================
cardano-cli conway governance drep update-certificate \
    --drep-verification-key-file ./keys/drep/drep2.vkey \
    --drep-metadata-url "https://ipfs.io/ipfs/bafkreia7qqyqzpv2rpcwfehhwamn4slpmuhymtw3anj6o32bbteq4mglpq" \
    --drep-metadata-hash "e84645190e9c04689261536011c0782027476ff0280d796f2c7474077e72f3ed" \
    --check-drep-metadata-hash \
    --out-file $txs_drep_dir/drep-register-update2.cert

cardano-cli conway transaction build \
 --witness-override 2 \
 --tx-in $(cardano-cli conway query utxo --address $(cat ../smart-contracts/tests/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat ../smart-contracts/tests/payment.addr) \
 --certificate-file $txs_drep_dir/drep-register-update2.cert \
 --out-file $txs_drep_dir/drep-reg-tx2.unsigned

 # Sign the transaction with drep key
cardano-cli conway transaction sign \
 --tx-body-file $txs_drep_dir/drep-reg-tx2.unsigned \
 --signing-key-file $keys_dir/drep/drep2.skey \
 --signing-key-file '/home/ebardo/cardano/smart-contracts/tests/payment.skey' \
 --out-file $txs_drep_dir/drep-reg-tx2.signed

 cardano-cli conway transaction submit  --tx-file $txs_drep_dir/drep-reg-tx2.signed