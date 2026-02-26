-- =============================================================================
-- Query 6: Commitment Savings Summary by Type
-- High-level view of savings by commitment discount type
-- =============================================================================
SELECT
    ProviderName,
    CommitmentDiscountType,

    -- Count of commitments
    COUNT(DISTINCT CommitmentDiscountId) AS TotalCommitments,

    -- Cost metrics
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Coverage
    COUNT(DISTINCT ServiceName) AS ServicesWithCommitments,
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND CommitmentDiscountId IS NOT NULL
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    CommitmentDiscountType

ORDER BY TotalSavings DESC;
