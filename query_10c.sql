-- =============================================================================
-- Query 10c: Commitment Coverage for Eligible Services (January 2026)
-- Shows coverage for Azure services that support RI/Savings Plans
-- Based on Azure commitment eligibility list
-- Includes data for January 2026 only
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
    COUNT(DISTINCT CASE WHEN PricingCategory != 'Committed' OR PricingCategory IS NULL THEN ResourceId END) AS UncoveredResources,

    -- Resource coverage percentage
    CASE
        WHEN COUNT(DISTINCT ResourceId) > 0
        THEN COUNT(DISTINCT CASE WHEN PricingCategory = 'Committed' THEN ResourceId END) * 100.0 / COUNT(DISTINCT ResourceId)
        ELSE 0
    END AS ResourceCovPct

FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= '2026-01-01'
    AND ChargePeriodStart < '2026-02-01'
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
    ServiceName

HAVING SUM(EffectiveCost) > 0

ORDER BY TotalEffectiveCost DESC;
