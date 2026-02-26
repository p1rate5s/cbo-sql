-- =============================================================================
-- Query 9: Active Commitments Since 10/1/2025 with Savings
-- Lists all commitments active since October 1, 2025 and their savings
-- Uses ContractedCost instead of ListCost for savings calculation
-- =============================================================================
SELECT
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType,

    -- Commitment start date (first usage date as proxy)
    MIN(ChargePeriodStart) AS CommitmentStartDate,

    -- Cost metrics
    SUM(ContractedCost) AS TotalContractedCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ContractedCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Savings rate
    CASE
        WHEN SUM(ContractedCost) > 0
        THEN (SUM(ContractedCost) - SUM(EffectiveCost)) * 100.0 / SUM(ContractedCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Coverage metrics
    COUNT(DISTINCT ServiceName) AS ServicesWithCommitments,
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered,

    -- Usage period
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysUsed,
    MAX(ChargePeriodEnd) AS LastUsageDate

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND CommitmentDiscountId IS NOT NULL
    AND ChargePeriodStart >= '2025-10-01'
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType

ORDER BY TotalSavings DESC;
