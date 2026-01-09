/* Get all transaction IDs for a specific stake address */

-- Step 1: Get all tx_ids for stake_test1uqgykl0j0tdn689syxuasmg35hfjaqnd06t2fav38r7fyqcc0w7lk

-- Step 2: Expand to see ADA values from tx_out

-- Step 3: Attach the withdrawal amount

-- Step 4: Include inputs of the tx

WITH stake_outputs AS (
    SELECT
        tx.id AS tx_id,
        encode(tx.hash, 'hex') AS tx_hash,
        txo.value AS output_lovelace,
        COALESCE(w.amount, 0) AS withdrawal_lovelace,
        b.block_no,
        b.time AS tx_timestamp
    FROM
        stake_address sa
        JOIN tx_out txo ON txo.stake_address_id = sa.id
        JOIN tx ON tx.id = txo.tx_id
        JOIN block b ON b.id = tx.block_id
        LEFT JOIN withdrawal w ON w.tx_id = tx.id AND w.addr_id = sa.id
    WHERE
        sa.view = 'stake_test1uqgykl0j0tdn689syxuasmg35hfjaqnd06t2fav38r7fyqcc0w7lk'
),
tx_inputs AS (
    SELECT
        txi.tx_in_id,
        SUM(txo_input.value) AS total_input_lovelace
    FROM
        tx_in txi
        JOIN tx_out txo_input ON txo_input.tx_id = txi.tx_out_id AND txo_input.index = txi.tx_out_index
    GROUP BY
        txi.tx_in_id
)
SELECT
    so.tx_id,
    so.tx_hash,
    so.output_lovelace AS lovelace_value,
    so.output_lovelace / 1000000.0 AS ada_value,
    COALESCE(ti.total_input_lovelace, 0) AS input_lovelace,
    COALESCE(ti.total_input_lovelace, 0) / 1000000.0 AS input_ada,
    so.withdrawal_lovelace,
    so.withdrawal_lovelace / 1000000.0 AS withdrawal_ada,
    so.block_no,
    so.tx_timestamp
FROM
    stake_outputs so
    LEFT JOIN tx_inputs ti ON ti.tx_in_id = so.tx_id
ORDER BY
    so.block_no DESC;

