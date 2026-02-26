-- =============================================================================
-- Query 1: Existing Commitment Coverage Analysis
-- Shows how much you're saving with current commitments by service
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,
    RegionId,
    RegionName,

    -- Total costs
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,

    -- Savings from commitments
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavingsRealized,

    -- Savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Coverage metrics
    COUNT(DISTINCT CommitmentDiscountId) AS UniqueCommitmentsUsed,
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered,
    SUM(PricingQuantity) AS TotalPricingQuantity

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName,
    RegionId,
    RegionName

HAVING SUM(ListCost) > 0

ORDER BY TotalSavingsRealized DESC;
