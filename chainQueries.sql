/*Test queries*/
SELECT * FROM TX 
LIMIT 10;

select * from tx
where encode(hash, 'hex')='cb8910345d1508c6a17b2ce98a3b04f0135dc872846861d7e29537fcc69582a4';

SELECT * FROM delegation_vote dv
JOIN tx_metadata tm ON dv.tx_id = tm.tx_id
where key = 3692;

SELECT * FROM delegation_vote dv
join stake_address sa on dv.addr_id = sa.id
where sa.view = 'stake_test1up5mrawxwp0cvc42ud3pwvcearm3en6l8acpzffnnya3zyg0v8tyr';

/*Count total delegations and those with metadata*/
SELECT
    COUNT(*) AS total_delegations,
    COUNT(DISTINCT dv.id) FILTER (WHERE tm.id IS NOT NULL) AS delegations_with_metadata
FROM delegation_vote dv
LEFT JOIN tx_metadata tm ON dv.tx_id = tm.tx_id;

/*delegations with drep donation */
SELECT
    COUNT(*) AS total_delegations,
    COUNT(DISTINCT dv.id) FILTER (WHERE tm.id IS NOT NULL) AS delegations_with_metadata,
    count(DISTINCT dv.id) FILTER (WHERE tm.key = 3692) AS delegations_with_drep_delegation
FROM delegation_vote dv
LEFT JOIN tx_metadata tm ON dv.tx_id = tm.tx_id;

