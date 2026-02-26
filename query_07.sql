-- =============================================================================
-- Query 7: Daily Commitment Usage Trend
-- Shows daily usage pattern to identify underutilization
-- =============================================================================
SELECT
    CAST(ChargePeriodStart AS DATE) AS UsageDate,
    ProviderName,
    CommitmentDiscountType,

    -- Daily costs
    SUM(ListCost) AS DailyListCost,
    SUM(EffectiveCost) AS DailyEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS DailySavings,

    -- Daily savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS DailySavingsRatePct,

    -- Daily quantity
    SUM(PricingQuantity) AS DailyQuantity,
    COUNT(DISTINCT CommitmentDiscountId) AS CommitmentsUsed

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND CommitmentDiscountId IS NOT NULL
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    CAST(ChargePeriodStart AS DATE),
    ProviderName,
    CommitmentDiscountType

ORDER BY UsageDate DESC, DailySavings DESC;
