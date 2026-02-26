-- =============================================================================
-- Query 3: Commitment Coverage by Service (RI/Savings Plans Only)
-- Shows covered vs uncovered amounts by service
-- Excludes EA contracted pricing - only counts Reserved Instances and Savings Plans
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,

    -- Total usage
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) AS TotalListCost,

    -- Covered by RI/Savings Plans (PricingCategory = 'Committed')
    SUM(CASE WHEN PricingCategory = 'Committed' THEN EffectiveCost ELSE 0 END) AS CoveredEffectiveCost,

    -- Uncovered amounts (Standard/On-Demand pricing)
    SUM(CASE WHEN PricingCategory != 'Committed' OR PricingCategory IS NULL THEN EffectiveCost ELSE 0 END) AS UncoveredEffectiveCost,

    -- Coverage percentage
    CASE
        WHEN SUM(EffectiveCost) > 0
        THEN SUM(CASE WHEN PricingCategory = 'Committed' THEN EffectiveCost ELSE 0 END) * 100.0 / SUM(EffectiveCost)
        ELSE 0
    END AS CoverageRatePct,

    -- Savings from commitments
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Resource counts
    COUNT(DISTINCT CASE WHEN PricingCategory = 'Committed' THEN ResourceId END) AS CoveredResources,
    COUNT(DISTINCT CASE WHEN PricingCategory != 'Committed' OR PricingCategory IS NULL THEN ResourceId END) AS UncoveredResources

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName

HAVING SUM(EffectiveCost) > 0

ORDER BY TotalEffectiveCost DESC;
