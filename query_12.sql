-- =============================================================================
-- Query 12: Commitment Savings Opportunity - Uncovered Eligible Services
-- Identifies commitment-eligible services NOT currently covered by commitments
-- Shows potential savings if these services were covered
-- Assumes ~20-30% savings rate typical for RI/Savings Plans
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,
    RegionId,

    -- Current spend (uncovered/on-demand)
    SUM(EffectiveCost) AS TotalUncoveredCost,
    SUM(ListCost) AS TotalListCost,
    SUM(ContractedCost) AS TotalContractedCost,

    -- Estimated savings potential (assuming 25% typical RI/SP discount)
    SUM(EffectiveCost) * 0.25 AS EstimatedSavings25Pct,
    SUM(EffectiveCost) * 0.30 AS EstimatedSavings30Pct,

    -- Usage volume
    SUM(PricingQuantity) AS TotalPricingQuantity,

    -- Usage consistency (important for commitment ROI)
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysWithUsage,

    -- Average daily cost (helps estimate commitment size)
    SUM(EffectiveCost) / NULLIF(COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)), 0) AS AvgDailyCost

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    -- Only uncovered usage (not already under commitment)
    AND CommitmentDiscountName IS NULL
    -- Since 10/1/2025
    AND ChargePeriodStart >= '2025-10-01'
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')
    -- Filter to only services eligible for commitment discounts
    AND (
        -- Compute services
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
        -- Database services
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
        -- Analytics services
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
        -- Storage services
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
        -- App/Web services
        OR ServiceName IN (
            'Azure App Service',
            'App Service',
            'App Service Environment'
        )
        -- AI/ML services
        OR ServiceName IN (
            'Azure OpenAI Service',
            'Azure OpenAI',
            'OpenAI Service',
            'Azure AI Foundry',
            'Azure Machine Learning'
        )
        -- Security services
        OR ServiceName IN (
            'Microsoft Defender for Cloud',
            'Microsoft Sentinel',
            'Azure Sentinel'
        )
        -- Networking services
        OR ServiceName IN (
            'Azure Virtual WAN',
            'Virtual WAN',
            'Azure ExpressRoute',
            'ExpressRoute'
        )
        -- Other eligible services
        OR ServiceName IN (
            'Azure SignalR Service',
            'SignalR Service'
        )
        -- Match by ServiceCategory for broader coverage
        OR ServiceCategory IN (
            'Compute',
            'Databases',
            'Analytics',
            'AI and Machine Learning'
        )
    )

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName,
    RegionId

HAVING SUM(EffectiveCost) > 0

ORDER BY TotalUncoveredCost DESC;
