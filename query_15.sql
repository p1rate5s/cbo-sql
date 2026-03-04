-- =============================================================================
-- Query 15: Savings Plan Sizing Analysis
-- Determines how large of a savings plan ($/hour commitment) to purchase
-- by analyzing the distribution of hourly eligible spend.
--
-- Shows BOTH total eligible spend and uncovered-only spend side by side:
--   - Total = all eligible usage (covered + uncovered) — full baseline demand
--   - Uncovered = only on-demand usage not under a commitment
--
-- How to read the results:
--   - P10 = very conservative commitment (covers 90% of hours)
--   - P25 = conservative commitment (covers 75% of hours)
--   - P50 = moderate commitment (covers 50% of hours)
--   - P75 = aggressive commitment (covers 25% of hours)
--   - Min = safest floor (never overpays)
--
-- A savings plan is a fixed $/hour commitment. Choose a percentile that
-- matches your risk tolerance. Hours above the commitment pay on-demand.
-- Lookback: Since 10/1/2025
-- =============================================================================
WITH hourly_spend AS (
    SELECT
        DATE_TRUNC('hour', ChargePeriodStart) AS usage_hour,
        ServiceCategory,
        -- Total eligible spend (covered + uncovered)
        SUM(EffectiveCost) AS hourly_total_effective,
        SUM(ListCost) AS hourly_total_list,
        SUM(ContractedCost) AS hourly_total_contracted,
        -- Uncovered spend only
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN EffectiveCost ELSE 0 END) AS hourly_uncovered_effective,
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN ListCost ELSE 0 END) AS hourly_uncovered_list,
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN ContractedCost ELSE 0 END) AS hourly_uncovered_contracted
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
                'Azure SQL Database',
                'Azure SQL Managed Instance',
                'SQL Database',
                'SQL Managed Instance',
                'Azure Cosmos DB',
                'Cosmos DB',
                'Azure Database for MySQL',
                'Azure Database for PostgreSQL',
                'Azure Database for MariaDB',
                'Azure Cache for Redis'
            )
            OR ServiceName IN (
                'Azure Synapse Analytics',
                'Synapse Analytics',
                'Azure Databricks',
                'Databricks',
                'Azure Data Explorer',
                'Azure Data Factory',
                'Microsoft Fabric',
                'Power BI Embedded'
            )
            OR ServiceName IN (
                'Azure Blob Storage',
                'Storage',
                'Blob Storage',
                'Azure Files',
                'Azure Disk Storage',
                'Managed Disks',
                'Azure Backup',
                'Azure NetApp Files'
            )
            OR ServiceName IN (
                'Azure App Service',
                'App Service',
                'App Service Environment'
            )
            OR ServiceName IN (
                'Azure OpenAI Service',
                'Azure OpenAI',
                'OpenAI Service',
                'Azure AI Foundry',
                'Azure Machine Learning'
            )
            OR ServiceName IN (
                'Microsoft Defender for Cloud',
                'Microsoft Sentinel',
                'Azure Sentinel'
            )
            OR ServiceName IN (
                'Azure Virtual WAN',
                'Virtual WAN',
                'Azure ExpressRoute',
                'ExpressRoute'
            )
            OR ServiceName IN (
                'Azure SignalR Service',
                'SignalR Service'
            )
            OR ServiceCategory IN (
                'Compute',
                'Databases',
                'Analytics',
                'AI and Machine Learning'
            )
        )
    GROUP BY
        DATE_TRUNC('hour', ChargePeriodStart),
        ServiceCategory
)

SELECT
    ServiceCategory,

    -- Total hours observed
    COUNT(*) AS TotalHours,

    -- === TOTAL ELIGIBLE SPEND (covered + uncovered) ===
    -- Hourly distribution - total
    MIN(hourly_total_effective) AS Total_MinHourly,
    percentile_approx(hourly_total_effective, 0.10) AS Total_P10_Hourly,
    percentile_approx(hourly_total_effective, 0.25) AS Total_P25_Hourly,
    percentile_approx(hourly_total_effective, 0.50) AS Total_P50_Hourly,
    percentile_approx(hourly_total_effective, 0.75) AS Total_P75_Hourly,
    percentile_approx(hourly_total_effective, 0.90) AS Total_P90_Hourly,
    MAX(hourly_total_effective) AS Total_MaxHourly,
    AVG(hourly_total_effective) AS Total_AvgHourly,

    -- Period totals - total
    SUM(hourly_total_effective) AS Total_EffectiveCost,
    SUM(hourly_total_list) AS Total_ListCost,
    SUM(hourly_total_contracted) AS Total_ContractedCost,

    -- === UNCOVERED SPEND ONLY ===
    -- Hourly distribution - uncovered
    MIN(hourly_uncovered_effective) AS Uncovered_MinHourly,
    percentile_approx(hourly_uncovered_effective, 0.10) AS Uncovered_P10_Hourly,
    percentile_approx(hourly_uncovered_effective, 0.25) AS Uncovered_P25_Hourly,
    percentile_approx(hourly_uncovered_effective, 0.50) AS Uncovered_P50_Hourly,
    percentile_approx(hourly_uncovered_effective, 0.75) AS Uncovered_P75_Hourly,
    percentile_approx(hourly_uncovered_effective, 0.90) AS Uncovered_P90_Hourly,
    MAX(hourly_uncovered_effective) AS Uncovered_MaxHourly,
    AVG(hourly_uncovered_effective) AS Uncovered_AvgHourly,

    -- Period totals - uncovered
    SUM(hourly_uncovered_effective) AS Uncovered_EffectiveCost,
    SUM(hourly_uncovered_list) AS Uncovered_ListCost,
    SUM(hourly_uncovered_contracted) AS Uncovered_ContractedCost,

    -- === ESTIMATED ANNUAL COMMITMENT ($/hr * 8760 hrs/yr) ===
    -- Based on total spend
    percentile_approx(hourly_total_effective, 0.25) * 8760 AS Total_P25_AnnualCommitment,
    percentile_approx(hourly_total_effective, 0.50) * 8760 AS Total_P50_AnnualCommitment,
    -- Based on uncovered spend
    percentile_approx(hourly_uncovered_effective, 0.25) * 8760 AS Uncovered_P25_AnnualCommitment,
    percentile_approx(hourly_uncovered_effective, 0.50) * 8760 AS Uncovered_P50_AnnualCommitment

FROM hourly_spend

GROUP BY ServiceCategory

ORDER BY Total_EffectiveCost DESC;
