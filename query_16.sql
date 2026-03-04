-- =============================================================================
-- Query 16: Compute Savings Plan Sizing - Simple Validation
-- Same as Query 15 but without per-service breakdown or UNION ALL.
-- Single aggregation across all compute to validate Q15 totals.
-- Lookback: Since 10/1/2025
-- =============================================================================
SELECT
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS TotalDays,

    -- Total daily spend
    SUM(EffectiveCost) AS Total_EffectiveCost,
    SUM(EffectiveCost) / COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS Total_AvgDaily,
    SUM(EffectiveCost) / COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) / 24 AS Total_AvgHourly,

    -- Uncovered daily spend
    SUM(CASE WHEN CommitmentDiscountName IS NULL THEN EffectiveCost ELSE 0 END) AS Uncovered_EffectiveCost,
    SUM(CASE WHEN CommitmentDiscountName IS NULL THEN EffectiveCost ELSE 0 END) / COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS Uncovered_AvgDaily,
    SUM(CASE WHEN CommitmentDiscountName IS NULL THEN EffectiveCost ELSE 0 END) / COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) / 24 AS Uncovered_AvgHourly

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= '2025-10-01'
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')
    AND (
        ServiceName IN (
            'Virtual Machines',
            'Azure Dedicated Host',
            'Azure Functions',
            'Azure Container Instances',
            'Azure Container Apps',
            'Azure Kubernetes Service',
            'Azure Batch',
            'Azure Spring Apps',
            'Azure Virtual Desktop',
            'Azure VMware Solution'
        )
        OR ServiceName IN (
            'Azure App Service',
            'App Service',
            'App Service Environment'
        )
        OR ServiceCategory = 'Compute'
    );
