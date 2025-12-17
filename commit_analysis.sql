-- =============================================================================
-- FOCUS Query: Commitment Savings Opportunity Analysis
-- Purpose: Identify on-demand (Standard) usage that could benefit from 
--          new commitment discounts (Reserved Instances or Savings Plans)
-- Timeframe: Past 30 days
-- =============================================================================

-- Query 1: Summary of on-demand spend eligible for commitment coverage
-- Shows the total potential savings opportunity by service and region
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,
    RegionId,
    RegionName,
    PricingUnit,
    
    -- Current on-demand spend
    SUM(ListCost) AS OnDemandListCost,
    SUM(EffectiveCost) AS OnDemandEffectiveCost,
    SUM(PricingQuantity) AS TotalPricingQuantity,
    
    -- Estimated savings at different commitment discount levels
    SUM(ListCost) * 0.30 AS EstimatedSavings_30Pct,  -- ~30% typical 1-year RI
    SUM(ListCost) * 0.40 AS EstimatedSavings_40Pct,  -- ~40% typical 3-year RI
    SUM(ListCost) * 0.20 AS EstimatedSavings_20Pct,  -- ~20% typical Savings Plan
    
    -- Count of unique resources that could be covered
    COUNT(DISTINCT ResourceId) AS UniqueResourceCount

FROM `edav_dev_od_ocio_cbo`.`silver_af45`.`focus_monthly`

WHERE 
    -- Only look at usage charges (not purchases or taxes)
    ChargeCategory = 'Usage'
    
    -- Only standard/on-demand pricing (not already committed or dynamic/spot)
    AND PricingCategory = 'Standard'
    
    -- Exclude any usage already covered by commitment discounts
    AND CommitmentDiscountId IS NULL
    
    -- Past 30 days
    AND BillingPeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    
    -- Exclude corrections
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName,
    RegionId,
    RegionName,
    PricingUnit

HAVING SUM(ListCost) > 0

ORDER BY OnDemandListCost DESC;


-- =============================================================================
-- Query 2: Detailed SKU-level commitment opportunity analysis
-- Shows specific SKUs with highest savings potential for targeted purchasing
-- =============================================================================
SELECT
    ProviderName,
    ServiceCategory,
    ServiceName,
    SkuId,
    SkuPriceId,
    RegionId,
    RegionName,
    PricingUnit,
    
    -- Usage metrics
    SUM(PricingQuantity) AS TotalPricingQuantity,
    AVG(PricingQuantity) AS AvgDailyQuantity,
    COUNT(DISTINCT CAST(BillingPeriodStart AS DATE)) AS DaysWithUsage,
    
    -- Cost metrics
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    SUM(ListCost) - SUM(EffectiveCost) AS CurrentSavingsFromNegotiations,
    
    -- Price analysis
    AVG(ListUnitPrice) AS AvgListUnitPrice,
    
    -- Estimated annual projection (normalize to 30 days then multiply by 12)
    (SUM(ListCost) / NULLIF(COUNT(DISTINCT CAST(BillingPeriodStart AS DATE)), 0)) * 365 AS ProjectedAnnualSpend,
    
    -- Savings estimates at different commitment levels
    ((SUM(ListCost) / NULLIF(COUNT(DISTINCT CAST(BillingPeriodStart AS DATE)), 0)) * 365) * 0.30 AS Est_Annual_Savings_30Pct,
    ((SUM(ListCost) / NULLIF(COUNT(DISTINCT CAST(BillingPeriodStart AS DATE)), 0)) * 365) * 0.40 AS Est_Annual_Savings_40Pct

FROM `edav_dev_od_ocio_cbo`.`silver_af45`.`focus_monthly`

WHERE 
    ChargeCategory = 'Usage'
    AND PricingCategory = 'Standard'
    AND CommitmentDiscountId IS NULL
    AND BillingPeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    ServiceCategory,
    ServiceName,
    SkuId,
    SkuPriceId,
    RegionId,
    RegionName,
    PricingUnit

HAVING SUM(ListCost) > 100  -- Filter out trivial amounts

ORDER BY TotalListCost DESC
LIMIT 50;  -- Top 50 opportunities


-- =============================================================================
-- Query 3: Commitment Coverage Rate Analysis
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

FROM `edav_dev_od_ocio_cbo`.`silver_af45`.`focus_monthly`

WHERE 
    ChargeCategory = 'Usage'
    AND BillingPeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
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
-- Query 4: Resource-level commitment opportunity (for capacity reservations)
-- Identifies specific resources with consistent on-demand usage
-- =============================================================================
SELECT
    ProviderName,
    SubAccountId,
    SubAccountName,
    ResourceId,
    ResourceName,
    ResourceType,
    ServiceName,
    SkuId,
    RegionId,
    
    -- Usage consistency metrics
    COUNT(DISTINCT CAST(BillingPeriodStart AS DATE)) AS DaysActive,
    MIN(BillingPeriodStart) AS FirstUsage,
    MAX(ChargePeriodEnd) AS LastUsage,
    
    -- Quantity metrics
    SUM(PricingQuantity) AS TotalQuantity,
    AVG(PricingQuantity) AS AvgDailyQuantity,
    STDDEV(PricingQuantity) AS QuantityVariability,
    
    -- Cost metrics  
    SUM(ListCost) AS TotalListCost,
    SUM(EffectiveCost) AS TotalEffectiveCost,
    
    -- Commitment recommendation flag (adjusted for 30-day window)
    CASE 
        WHEN COUNT(DISTINCT CAST(BillingPeriodStart AS DATE)) >= 25  -- Used most days
            AND STDDEV(PricingQuantity) / NULLIF(AVG(PricingQuantity), 0) < 0.3  -- Low variability
        THEN 'Strong Candidate'
        WHEN COUNT(DISTINCT CAST(BillingPeriodStart AS DATE)) >= 15
        THEN 'Moderate Candidate'
        ELSE 'Review Usage Pattern'
    END AS CommitmentRecommendation

FROM `edav_dev_od_ocio_cbo`.`silver_af45`.`focus_monthly`

WHERE 
    ChargeCategory = 'Usage'
    AND PricingCategory = 'Standard'
    AND CommitmentDiscountId IS NULL
    AND ResourceId IS NOT NULL
    AND BillingPeriodStart >= DATEADD(day, -30, CAST(GETDATE() AS DATE))
    AND (ChargeClass IS NULL OR ChargeClass != 'Correction')

GROUP BY
    ProviderName,
    SubAccountId,
    SubAccountName,
    ResourceId,
    ResourceName,
    ResourceType,
    ServiceName,
    SkuId,
    RegionId

HAVING SUM(ListCost) > 50

ORDER BY TotalListCost DESC
LIMIT 100;