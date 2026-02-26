-- =============================================================================
-- Query 11: Commitment Savings Details (All Charge Types)
-- Shows savings from each individual commitment including all charge types
-- Includes all commitments active since 10/1/2025
-- =============================================================================
SELECT
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType,

    -- Commitment usage period
    MIN(ChargePeriodStart) AS FirstUsageDate,
    MAX(ChargePeriodEnd) AS LastUsageDate,

    -- Cost metrics (all charge types)
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
    COUNT(DISTINCT ServiceName) AS ServicesWithCommitment,
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered,

    -- Usage volume
    SUM(PricingQuantity) AS TotalPricingQuantity,
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysWithUsage

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    -- Must have commitment discount applied
    CommitmentDiscountId IS NOT NULL
    -- Include all commitments active since 10/1/2025
    AND ChargePeriodStart >= '2025-10-01'
    -- Exclude corrections
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType

ORDER BY TotalSavings DESC;
