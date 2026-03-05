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
        -- Uses LIKE prefix matching because FOCUS x_SkuDescription appends
        -- VM size and region (e.g., "Virtual Machines Dadsv5 Series - D16ads v5 - US East")
        AND (
            x_SkuDescription LIKE 'Azure App Service Isolated v2 Plan%'
            OR x_SkuDescription LIKE 'Azure App Service Premium v3 Plan%'
            OR x_SkuDescription LIKE 'Azure App Service Premium v4 Plan%'
            OR x_SkuDescription LIKE 'Azure Container Apps%'
            OR x_SkuDescription LIKE 'Azure Spring Apps Enterprise%'
            OR x_SkuDescription LIKE 'Container Instances%'
            OR x_SkuDescription LIKE 'DCadsv5-series Linux%'
            OR x_SkuDescription LIKE 'DCasv5-series Linux%'
            OR x_SkuDescription LIKE 'DCdsv3 Series Linux%'
            OR x_SkuDescription LIKE 'DCsv2 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'DCsv3 Series Linux%'
            OR x_SkuDescription LIKE 'DSv3 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'DSv4 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Dadsv5 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Dasv4 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Dasv5 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Dasv6 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Ddsv4 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Ddsv5 Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Ddsv6 Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Dsv5 Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Dsv6 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'ECadsv5-series Linux%'
            OR x_SkuDescription LIKE 'ECasv5-series Linux%'
            OR x_SkuDescription LIKE 'ESv3 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'ESv4 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Eadsv5 Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Easv4 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Easv5 Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Easv6 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Ebdsv5 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Ebsv5 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Edsv4 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Edsv5 Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Esv5 Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Esv6 Series DedicatedHost%'
            OR x_SkuDescription LIKE 'FSv2 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'FX Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Flex Consumption%'
            OR x_SkuDescription LIKE 'LSv2 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Lasv3 Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Lasv3 Series Linux%'
            OR x_SkuDescription LIKE 'Lsv3 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'MS Series Dedicated Host%'
            OR x_SkuDescription LIKE 'MSv2 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'MdSv2 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'NCads A100 v4 Series Linux%'
            OR x_SkuDescription LIKE 'NVSv3 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'NVasv4 Series Dedicated Host%'
            OR x_SkuDescription LIKE 'Premium Functions%'
            OR x_SkuDescription LIKE 'Virtual Machines Av2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines BS Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Basv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Bpsv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Bsv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines D Series%'
            OR x_SkuDescription LIKE 'Virtual Machines DCSv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines DCadsv6 series%'
            OR x_SkuDescription LIKE 'Virtual Machines DCasv6 series%'
            OR x_SkuDescription LIKE 'Virtual Machines DCedsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines DCesv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines DS Series%'
            OR x_SkuDescription LIKE 'Virtual Machines DSv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines DSv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dadsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dadsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dadsv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Daldsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Daldsv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dalsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dalsv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dasv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dasv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dasv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dasv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dav4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ddsv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ddsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ddsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ddv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ddv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dldsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dldsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dlsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dlsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dpdsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dpdsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dpldsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dpldsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dplsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dplsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dpsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dpsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dsv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines ECadsv6 series Linux%'
            OR x_SkuDescription LIKE 'Virtual Machines ECasv6 series%'
            OR x_SkuDescription LIKE 'Virtual Machines ECedsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines ECesv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines ESv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Eadsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Eadsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Eadsv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Easv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Easv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Easv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Easv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Eav4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ebdsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ebdsv6-Series Linux%'
            OR x_SkuDescription LIKE 'Virtual Machines Ebsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ebsv6-Series Linux%'
            OR x_SkuDescription LIKE 'Virtual Machines Edsv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Edsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Edsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Edv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Edv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Epdsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Epdsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Epsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Epsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Esv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Esv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Esv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ev3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ev4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ev5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines F Series%'
            OR x_SkuDescription LIKE 'Virtual Machines FS Series%'
            OR x_SkuDescription LIKE 'Virtual Machines FSv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines FX Series%'
            OR x_SkuDescription LIKE 'Virtual Machines FXmdsv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines FXmsv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Fadsv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Faldsv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Falsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Falsv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Famdsv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Famsv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Famsv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Fasv6 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Fasv7 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines H Series%'
            OR x_SkuDescription LIKE 'Virtual Machines HBS Series%'
            OR x_SkuDescription LIKE 'Virtual Machines HBSv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines HBrsv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines HBrsv4 series%'
            OR x_SkuDescription LIKE 'Virtual Machines HCS Series%'
            OR x_SkuDescription LIKE 'Virtual Machines HXrs Series%'
            OR x_SkuDescription LIKE 'Virtual Machines LS Series%'
            OR x_SkuDescription LIKE 'Virtual Machines LSv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Laosv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Lasv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Lsv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Lsv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines MS Series%'
            OR x_SkuDescription LIKE 'Virtual Machines MSv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Mbdsv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Mbsv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines MdSv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Mdsv3 High Memory Series Linux%'
            OR x_SkuDescription LIKE 'Virtual Machines Mdsv3 Medium Memory Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Virtual Machines Mdsv3 Medium Memory Series Linux%'
            OR x_SkuDescription LIKE 'Virtual Machines Mdsv3 Very High Memory Series Linux%'
            OR x_SkuDescription LIKE 'Virtual Machines Msv3 High Memory Series Linux%'
            OR x_SkuDescription LIKE 'Virtual Machines Msv3 Medium Memory Series DedicatedHost%'
            OR x_SkuDescription LIKE 'Virtual Machines Msv3 Medium Memory Series Linux%'
            OR x_SkuDescription LIKE 'Virtual Machines NCSv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines NCadsH100v5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines NCasT4 v3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines NDamsr A100 v4 Series Linux%'
            OR x_SkuDescription LIKE 'Virtual Machines NDasr A100 v4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines NDrSv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines NP Series%'
            OR x_SkuDescription LIKE 'Virtual Machines NVSv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines NVadsA10v5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines NVadsV710v5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines NVasv4 Series%'
            -- Combined series names used in FOCUS (maps to separate SKUs in pricing API)
            OR x_SkuDescription LIKE 'Virtual Machines D/DS Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dv2/DSv2 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dv3/DSv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dv4/Dsv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Dv5/Dsv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ev3/ESv3 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ev4/Esv4 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines Ev5/Esv5 Series%'
            OR x_SkuDescription LIKE 'Virtual Machines F/FS Series%'
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
