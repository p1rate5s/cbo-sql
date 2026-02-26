-- =============================================================================
-- Query 8: Highest Cost Services (3-Month Average)
-- Shows services ranked by cost with 3-month lookback for average monthly cost
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,

    -- Total cost over 3 months
    SUM(EffectiveCost) AS Total3MonthEffectiveCost,
    SUM(ListCost) AS Total3MonthListCost,

    -- Average monthly cost (total / 3)
    SUM(EffectiveCost) / 3.0 AS AvgMonthlyEffectiveCost,
    SUM(ListCost) / 3.0 AS AvgMonthlyListCost,

    -- Savings metrics
    SUM(ListCost) - SUM(EffectiveCost) AS Total3MonthSavings,
    (SUM(ListCost) - SUM(EffectiveCost)) / 3.0 AS AvgMonthlySavings,

    -- Savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Resource and usage metrics
    COUNT(DISTINCT ResourceId) AS UniqueResources,
    SUM(PricingQuantity) AS TotalPricingQuantity,
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysWithUsage

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -90, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName

HAVING SUM(EffectiveCost) > 0

ORDER BY Total3MonthEffectiveCost DESC;
