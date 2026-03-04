-- =============================================================================
-- Query 15: Compute Savings Plan Sizing Analysis
-- Determines how large of a compute savings plan ($/hour commitment) to purchase
-- by analyzing the distribution of compute eligible spend.
--
-- NOTE: FOCUS data has daily granularity (ChargePeriodStart is per-day).
-- Daily percentiles show actual daily spend distribution.
-- Hourly estimates are derived by dividing daily values by 24.
--
-- Shows BOTH total eligible spend and uncovered-only spend side by side:
--   - Total = all eligible usage (covered + uncovered) — full baseline demand
--   - Uncovered = only on-demand usage not under a commitment
--
-- Results grouped by ServiceName, with 'ALL SERVICES' totals at the bottom.
--
-- How to read the results:
--   - P10 = very conservative commitment (covers 90% of days)
--   - P25 = conservative commitment (covers 75% of days)
--   - P50 = moderate commitment (covers 50% of days)
--   - P75 = aggressive commitment (covers 25% of days)
--   - Min = safest floor (never overpays)
--
-- A savings plan is a fixed $/hour commitment. Use the Hourly columns
-- to size the commitment. Choose a percentile that matches your risk
-- tolerance. Hours above the commitment pay on-demand.
-- Lookback: Since 10/1/2025
-- =============================================================================
WITH daily_spend AS (
    SELECT
        CAST(ChargePeriodStart AS DATE) AS usage_day,
        ServiceName,
        -- Total eligible spend (covered + uncovered)
        SUM(EffectiveCost) AS daily_total_effective,
        SUM(ListCost) AS daily_total_list,
        SUM(ContractedCost) AS daily_total_contracted,
        -- Uncovered spend only
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN EffectiveCost ELSE 0 END) AS daily_uncovered_effective,
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN ListCost ELSE 0 END) AS daily_uncovered_list,
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN ContractedCost ELSE 0 END) AS daily_uncovered_contracted
    FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`
    WHERE
        ChargeCategory = 'Usage'
        AND ChargePeriodStart >= '2025-10-01'
        AND (ChargeClass IS NULL OR ChargeClass != 'Correction')
        -- Compute services eligible for Azure Compute Savings Plans
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
        )
    GROUP BY
        CAST(ChargePeriodStart AS DATE),
        ServiceName
),

-- Aggregate daily totals across all services for the 'ALL SERVICES' row
daily_spend_all AS (
    SELECT
        usage_day,
        'ALL SERVICES' AS ServiceName,
        SUM(daily_total_effective) AS daily_total_effective,
        SUM(daily_total_list) AS daily_total_list,
        SUM(daily_total_contracted) AS daily_total_contracted,
        SUM(daily_uncovered_effective) AS daily_uncovered_effective,
        SUM(daily_uncovered_list) AS daily_uncovered_list,
        SUM(daily_uncovered_contracted) AS daily_uncovered_contracted
    FROM daily_spend
    GROUP BY usage_day
),

-- Combine per-service and all-services
combined AS (
    SELECT * FROM daily_spend
    UNION ALL
    SELECT * FROM daily_spend_all
)

SELECT
    ServiceName,

    -- Days observed
    COUNT(*) AS TotalDays,

    -- === TOTAL ELIGIBLE SPEND (covered + uncovered) ===
    -- Daily distribution - total
    MIN(daily_total_effective) AS Total_MinDaily,
    percentile_approx(daily_total_effective, 0.10) AS Total_P10_Daily,
    percentile_approx(daily_total_effective, 0.25) AS Total_P25_Daily,
    percentile_approx(daily_total_effective, 0.50) AS Total_P50_Daily,
    percentile_approx(daily_total_effective, 0.75) AS Total_P75_Daily,
    percentile_approx(daily_total_effective, 0.90) AS Total_P90_Daily,
    MAX(daily_total_effective) AS Total_MaxDaily,
    AVG(daily_total_effective) AS Total_AvgDaily,

    -- Hourly estimates (daily / 24) - total
    MIN(daily_total_effective) / 24 AS Total_MinHourly,
    percentile_approx(daily_total_effective, 0.10) / 24 AS Total_P10_Hourly,
    percentile_approx(daily_total_effective, 0.25) / 24 AS Total_P25_Hourly,
    percentile_approx(daily_total_effective, 0.50) / 24 AS Total_P50_Hourly,
    percentile_approx(daily_total_effective, 0.75) / 24 AS Total_P75_Hourly,
    percentile_approx(daily_total_effective, 0.90) / 24 AS Total_P90_Hourly,
    MAX(daily_total_effective) / 24 AS Total_MaxHourly,
    AVG(daily_total_effective) / 24 AS Total_AvgHourly,

    -- Period totals - total
    SUM(daily_total_effective) AS Total_EffectiveCost,
    SUM(daily_total_list) AS Total_ListCost,
    SUM(daily_total_contracted) AS Total_ContractedCost,

    -- === UNCOVERED SPEND ONLY ===
    -- Daily distribution - uncovered
    MIN(daily_uncovered_effective) AS Uncovered_MinDaily,
    percentile_approx(daily_uncovered_effective, 0.10) AS Uncovered_P10_Daily,
    percentile_approx(daily_uncovered_effective, 0.25) AS Uncovered_P25_Daily,
    percentile_approx(daily_uncovered_effective, 0.50) AS Uncovered_P50_Daily,
    percentile_approx(daily_uncovered_effective, 0.75) AS Uncovered_P75_Daily,
    percentile_approx(daily_uncovered_effective, 0.90) AS Uncovered_P90_Daily,
    MAX(daily_uncovered_effective) AS Uncovered_MaxDaily,
    AVG(daily_uncovered_effective) AS Uncovered_AvgDaily,

    -- Hourly estimates (daily / 24) - uncovered
    MIN(daily_uncovered_effective) / 24 AS Uncovered_MinHourly,
    percentile_approx(daily_uncovered_effective, 0.10) / 24 AS Uncovered_P10_Hourly,
    percentile_approx(daily_uncovered_effective, 0.25) / 24 AS Uncovered_P25_Hourly,
    percentile_approx(daily_uncovered_effective, 0.50) / 24 AS Uncovered_P50_Hourly,
    percentile_approx(daily_uncovered_effective, 0.75) / 24 AS Uncovered_P75_Hourly,
    percentile_approx(daily_uncovered_effective, 0.90) / 24 AS Uncovered_P90_Hourly,
    MAX(daily_uncovered_effective) / 24 AS Uncovered_MaxHourly,
    AVG(daily_uncovered_effective) / 24 AS Uncovered_AvgHourly,

    -- Period totals - uncovered
    SUM(daily_uncovered_effective) AS Uncovered_EffectiveCost,
    SUM(daily_uncovered_list) AS Uncovered_ListCost,
    SUM(daily_uncovered_contracted) AS Uncovered_ContractedCost,

    -- === ESTIMATED ANNUAL COMMITMENT ($/hr * 8760 hrs/yr) ===
    -- Based on total spend
    percentile_approx(daily_total_effective, 0.25) / 24 * 8760 AS Total_P25_AnnualCommitment,
    percentile_approx(daily_total_effective, 0.50) / 24 * 8760 AS Total_P50_AnnualCommitment,
    percentile_approx(daily_total_effective, 0.90) / 24 * 8760 AS Total_P90_AnnualCommitment,
    -- Based on uncovered spend
    percentile_approx(daily_uncovered_effective, 0.25) / 24 * 8760 AS Uncovered_P25_AnnualCommitment,
    percentile_approx(daily_uncovered_effective, 0.50) / 24 * 8760 AS Uncovered_P50_AnnualCommitment,

    -- === ESTIMATED ANNUAL SAVINGS (assuming 25% discount on committed spend) ===
    -- Annualized current spend (period total / days * 365)
    SUM(daily_total_effective) / COUNT(*) * 365 AS Total_AnnualizedSpend,
    SUM(daily_uncovered_effective) / COUNT(*) * 365 AS Uncovered_AnnualizedSpend,
    -- Estimated savings at P50 commitment level (25% of committed portion)
    percentile_approx(daily_total_effective, 0.50) / 24 * 8760 * 0.25 AS Total_P50_EstimatedAnnualSavings,
    percentile_approx(daily_uncovered_effective, 0.50) / 24 * 8760 * 0.25 AS Uncovered_P50_EstimatedAnnualSavings

FROM combined

GROUP BY ServiceName

ORDER BY
    CASE WHEN ServiceName = 'ALL SERVICES' THEN 1 ELSE 0 END,
    Total_EffectiveCost DESC;
