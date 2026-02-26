-- =============================================================================
-- Query 4: Commitment Coverage Rate by Pricing Category
-- Shows current coverage vs. opportunity across pricing categories
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    PricingCategory,

    -- Costs by pricing category
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavingsRealized,

    -- Calculate percentage of total
    SUM(EffectiveCost) * 100.0 / SUM(SUM(EffectiveCost)) OVER (PARTITION BY ProviderName, ServiceCategory) AS PctOfServiceSpend,

    -- Savings rate achieved
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    PricingCategory

ORDER BY
    ProviderName,
    ServiceCategory,
    TotalEffectiveCost DESC;
