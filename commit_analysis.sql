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
-- Query 2: All Usage Analysis (regardless of commitment status)
-- Shows all usage with commitment coverage status
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,
    PricingCategory,
    CASE
        WHEN CommitmentDiscountId IS NOT NULL THEN 'Covered by Commitment'
        ELSE 'Not Covered'
    END AS CommitmentStatus,

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

    -- Volume
    SUM(PricingQuantity) AS TotalPricingQuantity,
    COUNT(DISTINCT ResourceId) AS UniqueResourceCount

FROM `edav_dev_od_ocio_cbo`.`bronze`.`azure_focus_base`

WHERE
    ChargeCategory = 'Usage'
    AND ChargePeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName,
    PricingCategory,
    CASE
        WHEN CommitmentDiscountId IS NOT NULL THEN 'Covered by Commitment'
        ELSE 'Not Covered'
    END

HAVING SUM(ListCost) > 0

ORDER BY TotalListCost DESC;


-- =============================================================================
-- Query 3: Commitment Coverage Rate by Service
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
-- Query 4: Commitment Utilization Analysis
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
-- Query 5: Commitment Savings Summary by Type
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
-- Query 6: Daily Commitment Usage Trend
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
