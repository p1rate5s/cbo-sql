-- =============================================================================
-- Query 5: Commitment Utilization Analysis
-- Identifies underutilized commitments by looking at commitment discount usage
-- =============================================================================
SELECT
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType,
    ServiceCategory,
    ServiceName,
    RegionId,

    -- Usage metrics
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysUsed,
    MIN(ChargePeriodStart) AS FirstUsage,
    MAX(ChargePeriodEnd) AS LastUsage,

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

    -- Quantity metrics
    SUM(PricingQuantity) AS TotalQuantityUsed,
    AVG(PricingQuantity) AS AvgDailyQuantity,

    -- Resource coverage
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND CommitmentDiscountId IS NOT NULL
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType,
    ServiceCategory,
    ServiceName,
    RegionId

ORDER BY TotalSavings DESC;
