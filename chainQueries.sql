/*Count total delegations and those with metadata*/
SELECT
    COUNT(*) AS total_delegations,
    COUNT(DISTINCT dv.id) FILTER (
        WHERE
            tm.id IS NOT NULL
    ) AS delegations_with_metadata
FROM
    delegation_vote dv
    LEFT JOIN tx_metadata tm ON dv.tx_id = tm.tx_id;

/*delegations with drep donation */
SELECT
    COUNT(*) AS total_delegations,
    COUNT(DISTINCT dv.id) FILTER (
        WHERE
            tm.id IS NOT NULL
    ) AS delegations_with_metadata,
    count(DISTINCT dv.id) FILTER (
        WHERE
            tm.key = 3692
    ) AS delegations_with_drep_delegation
FROM
    delegation_vote dv
    LEFT JOIN tx_metadata tm ON dv.tx_id = tm.tx_id;

/* List of dreps and their delegators who opt in for donations to them */
select
    txm.key,
    CAST(txm.json ->> 'donationBasisPoints' as FLOAT) / 10 as donation_percentage,
    encode (tx.hash, 'hex') as tx_hash,
    sa.view as stake_address,
    dh.view as drep_hash
from
    tx_metadata txm
    join tx on tx.id = txm.tx_id
    join delegation_vote dv on dv.tx_id = tx.id
    join stake_address sa on dv.addr_id = sa.id
    join drep_hash dh on dh.id = dv.drep_hash_id
where
    txm.key = 3692;


/*Average donation per drep */ 

-- SELECT
--     dh.view AS drep_hash,
--     AVG(CAST(txm.json ->> 'donationBasisPoints' as FLOAT) / 10) AS average_donation,
--     COUNT(sa.view) AS total_delegators
-- FROM
--     tx_metadata txm
--     JOIN tx ON tx.id = txm.tx_id
--     JOIN delegation_vote dv ON dv.tx_id = tx.id
--     JOIN stake_address sa ON dv.addr_id = sa.id
--     JOIN drep_hash dh ON dh.id = dv.drep_hash_id
-- WHERE
--     txm.key = 3692
-- GROUP BY
--     dh.view;

/* how many donations different dreps have recieved through delegation each epoch */
