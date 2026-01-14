-- =============================================================================
-- FOCUS Query: Commitment Analysis
-- Purpose: Analyze commitment coverage, savings from existing commitments,
--          and identify underutilized commitments
-- Timeframe: Past 30 days
-- =============================================================================

-- =============================================================================
-- Query 1: Existing Commitment Coverage Analysis
-- Shows how much you're saving with current commitments by service
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,
    RegionId,
    RegionName,

    -- Total costs
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,

    -- Savings from commitments
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavingsRealized,

    -- Savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Coverage metrics
    COUNT(DISTINCT CommitmentDiscountId) AS UniqueCommitmentsUsed,
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered,
    SUM(PricingQuantity) AS TotalPricingQuantity

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName,
    RegionId,
    RegionName

HAVING SUM(ListCost) > 0

ORDER BY TotalSavingsRealized DESC;


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

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName

ORDER BY TotalEffectiveCost DESC;


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

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

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


-- =============================================================================
-- Query 4: Commitment Coverage Rate by Pricing Category
-- Shows current coverage vs. opportunity across pricing categories
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    PricingCategory,

    -- Costs by pricing category
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavingsRealized,

    -- Calculate percentage of total
    SUM(EffectiveCost) * 100.0 / SUM(SUM(EffectiveCost)) OVER (PARTITION BY ProviderName, ServiceCategory) AS PctOfServiceSpend,

    -- Savings rate achieved
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    PricingCategory

ORDER BY
    ProviderName,
    ServiceCategory,
    TotalEffectiveCost DESC;


-- =============================================================================
-- Query 5: Commitment Utilization Analysis
-- Identifies underutilized commitments by looking at commitment discount usage
-- =============================================================================
SELECT
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType,
    ServiceCategory,
    ServiceName,
    RegionId,

    -- Usage metrics
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysUsed,
    MIN(ChargePeriodStart) AS FirstUsage,
    MAX(ChargePeriodEnd) AS LastUsage,

    -- Cost metrics
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Quantity metrics
    SUM(PricingQuantity) AS TotalQuantityUsed,
    AVG(PricingQuantity) AS AvgDailyQuantity,

    -- Resource coverage
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND CommitmentDiscountId IS NOT NULL
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType,
    ServiceCategory,
    ServiceName,
    RegionId

ORDER BY TotalSavings DESC;


-- =============================================================================
-- Query 6: Commitment Savings Summary by Type
-- High-level view of savings by commitment discount type
-- =============================================================================
SELECT
    ProviderName,
    CommitmentDiscountType,

    -- Count of commitments
    COUNT(DISTINCT CommitmentDiscountId) AS TotalCommitments,

    -- Cost metrics
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Coverage
    COUNT(DISTINCT ServiceName) AS ServicesWithCommitments,
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND CommitmentDiscountId IS NOT NULL
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    CommitmentDiscountType

ORDER BY TotalSavings DESC;


-- =============================================================================
-- Query 7: Daily Commitment Usage Trend
-- Shows daily usage pattern to identify underutilization
-- =============================================================================
SELECT
    CAST(ChargePeriodStart AS DATE) AS UsageDate,
    ProviderName,
    CommitmentDiscountType,

    -- Daily costs
    SUM(ListCost) AS DailyListCost,
    SUM(EffectiveCost) AS DailyEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS DailySavings,

    -- Daily savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS DailySavingsRatePct,

    -- Daily quantity
    SUM(PricingQuantity) AS DailyQuantity,
    COUNT(DISTINCT CommitmentDiscountId) AS CommitmentsUsed

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND CommitmentDiscountId IS NOT NULL
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    CAST(ChargePeriodStart AS DATE),
    ProviderName,
    CommitmentDiscountType

ORDER BY UsageDate DESC, DailySavings DESC;


-- =============================================================================
-- Query 8: Highest Cost Services (3-Month Average)
-- Shows services ranked by cost with 3-month lookback for average monthly cost
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,

    -- Total cost over 3 months
    SUM(EffectiveCost) AS Total3MonthEffectiveCost,
    SUM(ListCost) AS Total3MonthListCost,

    -- Average monthly cost (total / 3)
    SUM(EffectiveCost) / 3.0 AS AvgMonthlyEffectiveCost,
    SUM(ListCost) / 3.0 AS AvgMonthlyListCost,

    -- Savings metrics
    SUM(ListCost) - SUM(EffectiveCost) AS Total3MonthSavings,
    (SUM(ListCost) - SUM(EffectiveCost)) / 3.0 AS AvgMonthlySavings,

    -- Savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Resource and usage metrics
    COUNT(DISTINCT ResourceId) AS UniqueResources,
    SUM(PricingQuantity) AS TotalPricingQuantity,
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysWithUsage

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -90, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName

HAVING SUM(EffectiveCost) > 0

ORDER BY Total3MonthEffectiveCost DESC;


-- =============================================================================
-- Query 9: Active Commitments Since 10/1/2025 with Savings
-- Lists all commitments active since October 1, 2025 and their savings
-- =============================================================================
SELECT
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType,

    -- Commitment start date (first usage date as proxy)
    MIN(ChargePeriodStart) AS CommitmentStartDate,

    -- Cost metrics
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Savings rate
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS SavingsRatePct,

    -- Coverage metrics
    COUNT(DISTINCT ServiceName) AS ServicesWithCommitments,
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered,

    -- Usage period
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysUsed,
    MAX(ChargePeriodEnd) AS LastUsageDate

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND CommitmentDiscountId IS NOT NULL
    AND ChargePeriodStart >= '2025-10-01'
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType

ORDER BY TotalSavings DESC;


-- =============================================================================
-- Query 10: Commitment Coverage for Eligible Services Only
-- Shows coverage for Azure services that support RI/Savings Plans
-- Based on Azure commitment eligibility list
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

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
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


-- =============================================================================
-- Query 11: Commitment Savings Details (Usage Only - Excludes Purchases)
-- Shows savings from each individual commitment excluding purchase costs
-- Only counts usage charges, not the upfront or recurring commitment fees
-- Includes all commitments active since 10/1/2025
-- =============================================================================
SELECT
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType,

    -- Commitment usage period
    MIN(ChargePeriodStart) AS FirstUsageDate,
    MAX(ChargePeriodEnd) AS LastUsageDate,

    -- Cost metrics (usage only, no purchases)
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS TotalUsageSavings,

    -- Savings rate on usage
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS UsageSavingsRatePct,

    -- Coverage
    COUNT(DISTINCT ServiceName) AS ServicesWithCommitment,
    COUNT(DISTINCT ResourceId) AS UniqueResourcesCovered,

    -- Usage volume
    SUM(PricingQuantity) AS TotalPricingQuantity,
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysWithUsage

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    -- Only usage charges - explicitly exclude purchases
    ChargeCategory = 'Usage'
    -- Exclude any purchase-related charge types
    AND (ChargeSubcategory IS NULL OR ChargeSubcategory NOT IN ('Purchase', 'Refund'))
    -- Must have commitment discount applied
    AND CommitmentDiscountId IS NOT NULL
    -- Include all commitments active since 10/1/2025
    AND ChargePeriodStart >= '2025-10-01'
    -- Exclude corrections
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    CommitmentDiscountId,
    CommitmentDiscountName,
    CommitmentDiscountType

ORDER BY TotalUsageSavings DESC;


-- =============================================================================
-- Query 12: Azure Hybrid Benefit Usage Summary by Service Type
-- Counts services and resources using Azure Hybrid Benefit (AHUB)
-- AHUB allows using on-premises Windows Server/SQL Server licenses on Azure
-- Grouped by ServiceCategory (service type)
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,

    -- Count of services and resources using Hybrid Benefit
    COUNT(DISTINCT ServiceName) AS ServicesWithAHUB,
    COUNT(DISTINCT ResourceId) AS ResourcesWithAHUB,

    -- Total usage records with AHUB
    COUNT(*) AS TotalAHUBRecords,

    -- Cost metrics
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) AS TotalListCost,
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Savings rate from AHUB
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS AHUBSavingsRatePct,

    -- Usage volume
    SUM(PricingQuantity) AS TotalPricingQuantity,
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysWithUsage

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    -- Filter for Azure Hybrid Benefit
    AND (
        -- Check for AHUB in pricing or tags
        LOWER(SkuPriceId) LIKE '%ahub%'
        OR LOWER(SkuPriceId) LIKE '%hybrid%benefit%'
        OR LOWER(PricingCategory) LIKE '%hybrid%'
        OR LOWER(CommitmentDiscountType) LIKE '%hybrid%'
        -- Check common tag names for AHUB
        OR LOWER(Tags) LIKE '%hybridbenefit%'
        OR LOWER(Tags) LIKE '%ahub%'
        -- Check resource name patterns (common for AHUB-enabled resources)
        OR LOWER(ChargeDescription) LIKE '%hybrid benefit%'
        OR LOWER(ChargeDescription) LIKE '%ahub%'
    )
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory

HAVING COUNT(DISTINCT ResourceId) > 0

ORDER BY ResourcesWithAHUB DESC, TotalEffectiveCost DESC;


-- =============================================================================
-- Query 13: Azure Hybrid Benefit Usage by Subscription and Service Type
-- Counts services and resources using Azure Hybrid Benefit (AHUB)
-- Grouped by SubAccountName (subscription) and ServiceCategory (service type)
-- =============================================================================
SELECT
    ProviderName,
    SubAccountId,
    SubAccountName,
    ServiceCategory,

    -- Count of services and resources using Hybrid Benefit
    COUNT(DISTINCT ServiceName) AS ServicesWithAHUB,
    COUNT(DISTINCT ResourceId) AS ResourcesWithAHUB,

    -- Total usage records with AHUB
    COUNT(*) AS TotalAHUBRecords,

    -- Cost metrics
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) AS TotalListCost,
    SUM(ListCost) - SUM(EffectiveCost) AS TotalSavings,

    -- Savings rate from AHUB
    CASE
        WHEN SUM(ListCost) > 0
        THEN (SUM(ListCost) - SUM(EffectiveCost)) * 100.0 / SUM(ListCost)
        ELSE 0
    END AS AHUBSavingsRatePct,

    -- Usage volume
    SUM(PricingQuantity) AS TotalPricingQuantity,
    COUNT(DISTINCT CAST(ChargePeriodStart AS DATE)) AS DaysWithUsage

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    -- Filter for Azure Hybrid Benefit
    AND (
        -- Check for AHUB in pricing or tags
        LOWER(SkuPriceId) LIKE '%ahub%'
        OR LOWER(SkuPriceId) LIKE '%hybrid%benefit%'
        OR LOWER(PricingCategory) LIKE '%hybrid%'
        OR LOWER(CommitmentDiscountType) LIKE '%hybrid%'
        -- Check common tag names for AHUB
        OR LOWER(Tags) LIKE '%hybridbenefit%'
        OR LOWER(Tags) LIKE '%ahub%'
        -- Check resource name patterns (common for AHUB-enabled resources)
        OR LOWER(ChargeDescription) LIKE '%hybrid benefit%'
        OR LOWER(ChargeDescription) LIKE '%ahub%'
    )
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    SubAccountId,
    SubAccountName,
    ServiceCategory

HAVING COUNT(DISTINCT ResourceId) > 0

ORDER BY SubAccountName, ResourcesWithAHUB DESC, TotalEffectiveCost DESC;


-- =============================================================================
-- Query 14: Azure Hybrid Benefit Detail Records
-- Lists all detail records for services using Azure Hybrid Benefit (AHUB)
-- =============================================================================
SELECT
    ProviderName,
    SubAccountId,
    SubAccountName,
    ServiceCategory,
    ServiceName,
    ResourceId,
    ResourceName,
    RegionId,
    RegionName,
    SkuId,
    SkuPriceId,
    x_SkuDetails,
    PricingCategory,
    CommitmentDiscountType,
    ChargeDescription,
    ChargePeriodStart,
    ChargePeriodEnd,
    PricingQuantity,
    PricingUnit,
    ListUnitPrice,
    ListCost,
    EffectiveCost,
    ListCost - EffectiveCost AS Savings,
    Tags

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    -- Filter for Azure Hybrid Benefit
    AND (
        -- Check for AHUB in SKU details
        LOWER(x_SkuDetails) LIKE '%ahub%'
        OR LOWER(x_SkuDetails) LIKE '%hybrid%benefit%'
        -- Check for AHUB in pricing or tags
        OR LOWER(SkuPriceId) LIKE '%ahub%'
        OR LOWER(SkuPriceId) LIKE '%hybrid%benefit%'
        OR LOWER(PricingCategory) LIKE '%hybrid%'
        OR LOWER(CommitmentDiscountType) LIKE '%hybrid%'
        -- Check common tag names for AHUB
        OR LOWER(Tags) LIKE '%hybridbenefit%'
        OR LOWER(Tags) LIKE '%ahub%'
        -- Check resource name patterns (common for AHUB-enabled resources)
        OR LOWER(ChargeDescription) LIKE '%hybrid benefit%'
        OR LOWER(ChargeDescription) LIKE '%ahub%'
    )
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

ORDER BY SubAccountName, ServiceName, ResourceName, ChargePeriodStart;
