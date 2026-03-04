-- =============================================================================
-- Query 15: Savings Plan Sizing Analysis
-- Determines how large of a savings plan ($/hour commitment) to purchase
-- by analyzing the distribution of hourly on-demand eligible spend.
--
-- How to read the results:
--   - P10_HourlySpend = very conservative commitment (covers 90% of hours)
--   - P25_HourlySpend = conservative commitment (covers 75% of hours)
--   - P50_HourlySpend = moderate commitment (covers 50% of hours)
--   - P75_HourlySpend = aggressive commitment (covers 25% of hours)
--   - MinHourlySpend  = safest floor (never overpays)
--
-- A savings plan is a fixed $/hour commitment. Choose a percentile that
-- matches your risk tolerance. Hours above the commitment pay on-demand.
-- =============================================================================
WITH hourly_spend AS (
    SELECT
        DATE_TRUNC('hour', ChargePeriodStart) AS usage_hour,
        ServiceCategory,
        SUM(ContractedCost) AS hourly_contracted_cost,
        SUM(EffectiveCost) AS hourly_effective_cost,
        SUM(ListCost) AS hourly_list_cost
    FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`
    WHERE
        ChargeCategory = 'Usage'
        AND CommitmentDiscountName IS NULL
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

    -- Spend distribution (use these to size your savings plan)
    MIN(hourly_effective_cost) AS MinHourlySpend,
    percentile_approx(hourly_effective_cost, 0.10) AS P10_HourlySpend,
    percentile_approx(hourly_effective_cost, 0.25) AS P25_HourlySpend,
    percentile_approx(hourly_effective_cost, 0.50) AS P50_HourlySpend,
    percentile_approx(hourly_effective_cost, 0.75) AS P75_HourlySpend,
    percentile_approx(hourly_effective_cost, 0.90) AS P90_HourlySpend,
    MAX(hourly_effective_cost) AS MaxHourlySpend,
    AVG(hourly_effective_cost) AS AvgHourlySpend,

    -- Total spend in period
    SUM(hourly_effective_cost) AS TotalEffectiveCost,
    SUM(hourly_list_cost) AS TotalListCost,
    SUM(hourly_contracted_cost) AS TotalContractedCost,

    -- Estimated annual commitment cost at each percentile ($/hr * 8760 hrs/yr)
    percentile_approx(hourly_effective_cost, 0.10) * 8760 AS P10_AnnualCommitment,
    percentile_approx(hourly_effective_cost, 0.25) * 8760 AS P25_AnnualCommitment,
    percentile_approx(hourly_effective_cost, 0.50) * 8760 AS P50_AnnualCommitment

FROM hourly_spend

GROUP BY ServiceCategory

ORDER BY TotalEffectiveCost DESC;
