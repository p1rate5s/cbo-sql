-- =============================================================================
-- Query 2: Commitment Coverage Percentage Summary (RI/Savings Plans Only)
-- Shows covered vs uncovered amounts as percentage of total usage
-- Excludes EA contracted pricing - only counts Reserved Instances and Savings Plans
-- =============================================================================
SELECT
    ProviderName,

    -- Total usage
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) AS TotalListCost,

    -- Covered by RI/Savings Plans (PricingCategory = 'Committed')
    SUM(CASE WHEN PricingCategory = 'Committed' THEN EffectiveCost ELSE 0 END) AS CoveredEffectiveCost,
    SUM(CASE WHEN PricingCategory = 'Committed' THEN ListCost ELSE 0 END) AS CoveredListCost,

    -- Uncovered amounts (Standard/On-Demand pricing)
    SUM(CASE WHEN PricingCategory != 'Committed' OR PricingCategory IS NULL THEN EffectiveCost ELSE 0 END) AS UncoveredEffectiveCost,
    SUM(CASE WHEN PricingCategory != 'Committed' OR PricingCategory IS NULL THEN ListCost ELSE 0 END) AS UncoveredListCost,

    -- Coverage percentage (based on EffectiveCost)
    CASE
        WHEN SUM(EffectiveCost) > 0
        THEN SUM(CASE WHEN PricingCategory = 'Committed' THEN EffectiveCost ELSE 0 END) * 100.0 / SUM(EffectiveCost)
        ELSE 0
    END AS CoverageRatePct,

    -- Uncovered percentage
    CASE
        WHEN SUM(EffectiveCost) > 0
        THEN SUM(CASE WHEN PricingCategory != 'Committed' OR PricingCategory IS NULL THEN EffectiveCost ELSE 0 END) * 100.0 / SUM(EffectiveCost)
        ELSE 0
    END AS UncoveredRatePct,

    -- Total savings from commitments
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Overall savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS OverallSavingsRatePct,

    -- Resource counts
    COUNT(DISTINCT CASE WHEN PricingCategory = 'Committed' THEN ResourceId END) AS CoveredResources,
    COUNT(DISTINCT CASE WHEN PricingCategory != 'Committed' OR PricingCategory IS NULL THEN ResourceId END) AS UncoveredResources

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName

ORDER BY TotalEffectiveCost DESC;
