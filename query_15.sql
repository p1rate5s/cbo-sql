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
-- Lookback: Since 3/1/2025 (full year)
-- =============================================================================
WITH daily_spend AS (
    SELECT
        CAST(ChargePeriodStart AS DATE) AS usage_day,
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
        AND ChargePeriodStart >= '2025-03-01'
        AND (ChargeClass IS NULL OR ChargeClass != 'Correction')
        -- SKUs eligible for Compute Savings Plans (from sp_eastus_all.csv)
        AND x_SkuDescription IN (
            'Azure App Service Isolated v2 Plan',
            'Azure App Service Isolated v2 Plan - Linux',
            'Azure App Service Premium v3 Plan',
            'Azure App Service Premium v3 Plan - Linux',
            'Azure App Service Premium v4 Plan',
            'Azure App Service Premium v4 Plan - Linux',
            'Azure Container Apps',
            'Azure Spring Apps Enterprise',
            'Container Instances',
            'DCadsv5-series Linux',
            'DCasv5-series Linux',
            'DCdsv3 Series Linux',
            'DCsv2 Series Dedicated Host',
            'DCsv3 Series Linux',
            'DSv3 Series Dedicated Host',
            'DSv4 Series Dedicated Host',
            'Dadsv5 Series Dedicated Host',
            'Dasv4 Series Dedicated Host',
            'Dasv5 Series Dedicated Host',
            'Dasv6 Series Dedicated Host',
            'Ddsv4 Series Dedicated Host',
            'Ddsv5 Series DedicatedHost',
            'Ddsv6 Series DedicatedHost',
            'Dsv5 Series DedicatedHost',
            'Dsv6 Series Dedicated Host',
            'ECadsv5-series Linux',
            'ECasv5-series Linux',
            'ESv3 Series Dedicated Host',
            'ESv4 Series Dedicated Host',
            'Eadsv5 Series DedicatedHost',
            'Easv4 Series Dedicated Host',
            'Easv5 Series DedicatedHost',
            'Easv6 Series Dedicated Host',
            'Ebdsv5 Series Dedicated Host',
            'Ebsv5 Series Dedicated Host',
            'Edsv4 Series Dedicated Host',
            'Edsv5 Series DedicatedHost',
            'Esv5 Series DedicatedHost',
            'Esv6 Series DedicatedHost',
            'FSv2 Series Dedicated Host',
            'FX Series Dedicated Host',
            'Flex Consumption',
            'LSv2 Series Dedicated Host',
            'Lasv3 Series DedicatedHost',
            'Lasv3 Series Linux',
            'Lsv3 Series Dedicated Host',
            'MS Series Dedicated Host',
            'MSv2 Series Dedicated Host',
            'MdSv2 Series Dedicated Host',
            'NCads A100 v4 Series Linux',
            'NVSv3 Series Dedicated Host',
            'NVasv4 Series Dedicated Host',
            'Premium Functions',
            'Virtual Machines Av2 Series',
            'Virtual Machines BS Series',
            'Virtual Machines Basv2 Series',
            'Virtual Machines Bpsv2 Series',
            'Virtual Machines Bsv2 Series',
            'Virtual Machines D Series',
            'Virtual Machines DCSv2 Series',
            'Virtual Machines DCadsv6 series',
            'Virtual Machines DCasv6 series',
            'Virtual Machines DCedsv6 Series',
            'Virtual Machines DCedsv6 Series Windows',
            'Virtual Machines DCesv6 Series',
            'Virtual Machines DCesv6 Series Windows',
            'Virtual Machines DS Series',
            'Virtual Machines DSv2 Series',
            'Virtual Machines DSv3 Series',
            'Virtual Machines Dadsv5 Series',
            'Virtual Machines Dadsv6 Series',
            'Virtual Machines Dadsv7 Series',
            'Virtual Machines Daldsv6 Series',
            'Virtual Machines Daldsv7 Series',
            'Virtual Machines Dalsv6 Series',
            'Virtual Machines Dalsv7 Series',
            'Virtual Machines Dasv4 Series',
            'Virtual Machines Dasv5 Series',
            'Virtual Machines Dasv6 Series',
            'Virtual Machines Dasv7 Series',
            'Virtual Machines Dav4 Series',
            'Virtual Machines Ddsv4 Series',
            'Virtual Machines Ddsv5 Series',
            'Virtual Machines Ddsv6 Series',
            'Virtual Machines Ddv4 Series',
            'Virtual Machines Ddv5 Series',
            'Virtual Machines Dldsv5 Series',
            'Virtual Machines Dldsv6 Series',
            'Virtual Machines Dlsv5 Series',
            'Virtual Machines Dlsv6 Series',
            'Virtual Machines Dpdsv5 Series',
            'Virtual Machines Dpdsv6 Series',
            'Virtual Machines Dpldsv5 Series',
            'Virtual Machines Dpldsv6 Series',
            'Virtual Machines Dplsv5 Series',
            'Virtual Machines Dplsv6 Series',
            'Virtual Machines Dpsv5 Series',
            'Virtual Machines Dpsv6 Series',
            'Virtual Machines Dsv4 Series',
            'Virtual Machines Dsv5 Series',
            'Virtual Machines Dsv6 Series',
            'Virtual Machines Dv2 Series',
            'Virtual Machines Dv3 Series',
            'Virtual Machines Dv4 Series',
            'Virtual Machines Dv5 Series',
            'Virtual Machines ECadsv6 series Linux',
            'Virtual Machines ECasv6 series',
            'Virtual Machines ECedsv6 Series',
            'Virtual Machines ECedsv6 Series Windows',
            'Virtual Machines ECesv6 Series',
            'Virtual Machines ECesv6 Series Windows',
            'Virtual Machines ESv3 Series',
            'Virtual Machines Eadsv5 Series',
            'Virtual Machines Eadsv6 Series',
            'Virtual Machines Eadsv7 Series',
            'Virtual Machines Easv4 Series',
            'Virtual Machines Easv5 Series',
            'Virtual Machines Easv6 Series',
            'Virtual Machines Easv7 Series',
            'Virtual Machines Eav4 Series',
            'Virtual Machines Ebdsv5 Series',
            'Virtual Machines Ebdsv6-Series Linux',
            'Virtual Machines Ebsv5 Series',
            'Virtual Machines Ebsv6-Series Linux',
            'Virtual Machines Edsv4 Series',
            'Virtual Machines Edsv5 Series',
            'Virtual Machines Edsv6 Series',
            'Virtual Machines Edv4 Series',
            'Virtual Machines Edv5 Series',
            'Virtual Machines Epdsv5 Series',
            'Virtual Machines Epdsv6 Series',
            'Virtual Machines Epsv5 Series',
            'Virtual Machines Epsv6 Series',
            'Virtual Machines Esv4 Series',
            'Virtual Machines Esv5 Series',
            'Virtual Machines Esv6 Series',
            'Virtual Machines Ev3 Series',
            'Virtual Machines Ev4 Series',
            'Virtual Machines Ev5 Series',
            'Virtual Machines F Series',
            'Virtual Machines FS Series',
            'Virtual Machines FSv2 Series',
            'Virtual Machines FX Series',
            'Virtual Machines FXmdsv2 Series',
            'Virtual Machines FXmsv2 Series',
            'Virtual Machines Fadsv7 Series',
            'Virtual Machines Faldsv7 Series',
            'Virtual Machines Falsv6 Series',
            'Virtual Machines Falsv7 Series',
            'Virtual Machines Famdsv7 Series',
            'Virtual Machines Famsv6 Series',
            'Virtual Machines Famsv7 Series',
            'Virtual Machines Fasv6 Series',
            'Virtual Machines Fasv7 Series',
            'Virtual Machines H Series',
            'Virtual Machines HBS Series',
            'Virtual Machines HBSv2 Series',
            'Virtual Machines HBrsv3 Series',
            'Virtual Machines HBrsv4 series',
            'Virtual Machines HCS Series',
            'Virtual Machines HXrs Series',
            'Virtual Machines LS Series',
            'Virtual Machines LSv2 Series',
            'Virtual Machines Laosv4 Series',
            'Virtual Machines Lasv4 Series',
            'Virtual Machines Lsv3 Series',
            'Virtual Machines Lsv4 Series',
            'Virtual Machines MS Series',
            'Virtual Machines MSv2 Series',
            'Virtual Machines Mbdsv3 Series',
            'Virtual Machines Mbsv3 Series',
            'Virtual Machines MdSv2 Series',
            'Virtual Machines Mdsv3 High Memory Series Linux',
            'Virtual Machines Mdsv3 Medium Memory Series DedicatedHost',
            'Virtual Machines Mdsv3 Medium Memory Series Linux',
            'Virtual Machines Mdsv3 Very High Memory Series Linux',
            'Virtual Machines Msv3 High Memory Series Linux',
            'Virtual Machines Msv3 Medium Memory Series DedicatedHost',
            'Virtual Machines Msv3 Medium Memory Series Linux',
            'Virtual Machines NCSv3 Series',
            'Virtual Machines NCadsH100v5 Series',
            'Virtual Machines NCadsH100v5 Series Windows',
            'Virtual Machines NCasT4 v3 Series',
            'Virtual Machines NDamsr A100 v4 Series Linux',
            'Virtual Machines NDasr A100 v4 Series',
            'Virtual Machines NDrSv2 Series',
            'Virtual Machines NP Series',
            'Virtual Machines NVSv3 Series',
            'Virtual Machines NVadsA10v5 Series',
            'Virtual Machines NVadsV710v5 Series',
            'Virtual Machines NVasv4 Series'
        )
    GROUP BY
        CAST(ChargePeriodStart AS DATE)
)

SELECT
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
    percentile_approx(daily_total_effective, 0.25) / 24 * 8760 AS Total_P25_AnnualCommitment,
    percentile_approx(daily_total_effective, 0.50) / 24 * 8760 AS Total_P50_AnnualCommitment,
    percentile_approx(daily_total_effective, 0.90) / 24 * 8760 AS Total_P90_AnnualCommitment,
    percentile_approx(daily_uncovered_effective, 0.25) / 24 * 8760 AS Uncovered_P25_AnnualCommitment,
    percentile_approx(daily_uncovered_effective, 0.50) / 24 * 8760 AS Uncovered_P50_AnnualCommitment,

    -- === ESTIMATED ANNUAL SAVINGS (assuming 25% discount on committed spend) ===
    SUM(daily_total_effective) / COUNT(*) * 365 AS Total_AnnualizedSpend,
    SUM(daily_uncovered_effective) / COUNT(*) * 365 AS Uncovered_AnnualizedSpend,
    percentile_approx(daily_total_effective, 0.50) / 24 * 8760 * 0.25 AS Total_P50_EstimatedAnnualSavings,
    percentile_approx(daily_uncovered_effective, 0.50) / 24 * 8760 * 0.25 AS Uncovered_P50_EstimatedAnnualSavings

FROM daily_spend;
