-- =============================================================================
-- Query 14: Unique SKUs Covered by Savings Plans or Reserved Instances
-- Shows distinct SKUs that have commitment discount coverage
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,
    SkuId,
    SkuPriceId,
    ChargeDescription,
    RegionId,
    CommitmentDiscountType,
    CommitmentDiscountName,

    -- Cost metrics
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) AS TotalListCost,
    SUM(ContractedCost) AS TotalContractedCost,

    -- Savings
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Usage volume
    SUM(PricingQuantity) AS TotalPricingQuantity,
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysWithUsage

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND CommitmentDiscountName IS NOT NULL
    AND ChargePeriodStart >= '2025-10-01'
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName,
    SkuId,
    SkuPriceId,
    ChargeDescription,
    RegionId,
    CommitmentDiscountType,
    CommitmentDiscountName

ORDER BY TotalEffectiveCost DESC;
