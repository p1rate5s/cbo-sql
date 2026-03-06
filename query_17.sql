-- =============================================================================
-- Query 17: Storage Reserved Instance Opportunity Analysis
-- Analyzes storage spend to identify reservation purchase opportunities.
--
-- Azure storage reservations cover CAPACITY charges only (not operations,
-- transactions, or bandwidth). This query classifies each storage charge as
-- either RI-eligible (capacity) or not (operations/bandwidth/other), then
-- shows spend patterns and potential savings by storage type and region.
--
-- Eligible storage services:
--   - Azure Blob Storage (Block Blobs) - 100 TB or 1 PB blocks/month
--   - Azure Files (Premium/Hot/Cool) - 10 TiB or 100 TiB blocks
--   - Azure Disk Storage (Premium SSD P30+, Ultra Disks)
--   - Azure NetApp Files
--   - Azure Backup Storage
--
-- Reservations are region-specific and tier-specific.
-- Typical discounts: ~25% (1-year term), ~38% (3-year term)
--
-- How to read the results:
--   - Focus on rows where IsCapacityCharge = 'Yes' (RI-eligible)
--   - Higher DaysWithUsage = more consistent = better RI candidate
--   - Use Uncovered_AvgMonthlyCost to estimate reservation size needed
--   - Compare EstSavings_1yr_25pct vs EstSavings_3yr_38pct for term decision
--
-- Lookback: Since 3/1/2025 (full year)
-- =============================================================================
WITH storage_charges AS (
    SELECT
        x_SkuMeterSubcategory,
        RegionId,
        CommitmentDiscountName,
        CAST(ChargePeriodStart AS DATE) AS usage_day,
        -- Classify: is this a capacity/data-stored charge (RI-eligible)?
        -- or an operations/transactions/bandwidth charge (not RI-eligible)?
        CASE
            -- Managed disks: Premium SSD P30 and above are RI-eligible
            WHEN x_SkuMeterSubcategory = 'Premium SSD Managed Disks'
                 AND ChargeDescription RLIKE '- P(30|40|50|60|80) '
                THEN 'Yes'
            -- Ultra Disks: provisioned capacity is RI-eligible
            WHEN x_SkuMeterSubcategory = 'Ultra Disks'
                 AND ChargeDescription LIKE '%Provisioned Capacity%'
                THEN 'Yes'
            -- Blob storage: data stored charges are RI-eligible (not operations)
            WHEN x_SkuMeterSubcategory = 'Tiered Block Blob'
                 AND ChargeDescription LIKE '%Data Stored%'
                THEN 'Yes'
            -- Azure Files: data stored / capacity charges are RI-eligible
            WHEN x_SkuMeterSubcategory IN ('Files', 'Files v2')
                 AND ChargeDescription LIKE '%Data Stored%'
                THEN 'Yes'
            -- Azure NetApp Files: capacity charges are RI-eligible
            WHEN x_SkuMeterSubcategory LIKE '%NetApp%'
                 AND ChargeDescription NOT LIKE '%Operations%'
                 AND ChargeDescription NOT LIKE '%Snapshots%'
                THEN 'Yes'
            -- Azure Backup: stored data charges are RI-eligible
            WHEN x_SkuMeterSubcategory LIKE '%Backup%'
                 AND ChargeDescription LIKE '%Data Stored%'
                THEN 'Yes'
            ELSE 'No'
        END AS IsCapacityCharge,
        EffectiveCost,
        ListCost,
        ContractedCost,
        PricingQuantity
    FROM `edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`
    WHERE
        ChargeCategory = 'Usage'
        AND ChargePeriodStart >= '2025-03-01'
        AND (ChargeClass IS NULL OR ChargeClass != 'Correction')
        -- Filter to storage-related charges via meter category
        AND x_SkuMeterCategory = 'Storage'
        -- Exclude bandwidth (never RI-eligible)
        AND (x_SkuMeterSubcategory IS NULL
             OR x_SkuMeterSubcategory NOT IN ('Bandwidth'))
),

daily_summary AS (
    SELECT
        x_SkuMeterSubcategory,
        RegionId,
        IsCapacityCharge,
        usage_day,
        -- Total eligible spend (covered + uncovered)
        SUM(EffectiveCost) AS daily_total_effective,
        SUM(ListCost) AS daily_total_list,
        SUM(ContractedCost) AS daily_total_contracted,
        SUM(PricingQuantity) AS daily_total_quantity,
        -- Uncovered spend only
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN EffectiveCost ELSE 0 END) AS daily_uncovered_effective,
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN ListCost ELSE 0 END) AS daily_uncovered_list,
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN ContractedCost ELSE 0 END) AS daily_uncovered_contracted,
        SUM(CASE WHEN CommitmentDiscountName IS NULL THEN PricingQuantity ELSE 0 END) AS daily_uncovered_quantity
    FROM storage_charges
    GROUP BY
        x_SkuMeterSubcategory,
        RegionId,
        IsCapacityCharge,
        usage_day
)

SELECT
    x_SkuMeterSubcategory AS StorageType,
    RegionId,
    IsCapacityCharge,

    -- === USAGE CONSISTENCY ===
    COUNT(*) AS DaysWithUsage,

    -- === TOTAL SPEND (covered + uncovered) ===
    SUM(daily_total_effective) AS Total_EffectiveCost,
    SUM(daily_total_list) AS Total_ListCost,
    SUM(daily_total_contracted) AS Total_ContractedCost,
    AVG(daily_total_effective) AS Total_AvgDailyCost,
    AVG(daily_total_effective) * 30.44 AS Total_AvgMonthlyCost,

    -- === UNCOVERED SPEND ONLY ===
    SUM(daily_uncovered_effective) AS Uncovered_EffectiveCost,
    SUM(daily_uncovered_list) AS Uncovered_ListCost,
    SUM(daily_uncovered_contracted) AS Uncovered_ContractedCost,
    AVG(daily_uncovered_effective) AS Uncovered_AvgDailyCost,
    AVG(daily_uncovered_effective) * 30.44 AS Uncovered_AvgMonthlyCost,

    -- === DAILY DISTRIBUTION (uncovered) ===
    MIN(daily_uncovered_effective) AS Uncovered_MinDaily,
    percentile_approx(daily_uncovered_effective, 0.25) AS Uncovered_P25_Daily,
    percentile_approx(daily_uncovered_effective, 0.50) AS Uncovered_P50_Daily,
    percentile_approx(daily_uncovered_effective, 0.75) AS Uncovered_P75_Daily,
    MAX(daily_uncovered_effective) AS Uncovered_MaxDaily,

    -- === COVERAGE RATIO ===
    CASE
        WHEN SUM(daily_total_effective) > 0
        THEN (SUM(daily_total_effective) - SUM(daily_uncovered_effective)) * 100.0
             / SUM(daily_total_effective)
        ELSE 0
    END AS CoverageRatePct,

    -- === ESTIMATED ANNUALIZED UNCOVERED SPEND ===
    AVG(daily_uncovered_effective) * 365 AS Uncovered_AnnualizedCost,

    -- === ESTIMATED SAVINGS (on uncovered annualized spend) ===
    -- 1-year term (~25% discount)
    AVG(daily_uncovered_effective) * 365 * 0.25 AS EstSavings_1yr_25pct,
    -- 3-year term (~38% discount)
    AVG(daily_uncovered_effective) * 365 * 0.38 AS EstSavings_3yr_38pct

FROM daily_summary

GROUP BY
    x_SkuMeterSubcategory,
    RegionId,
    IsCapacityCharge

HAVING SUM(daily_uncovered_effective) > 0

ORDER BY Uncovered_EffectiveCost DESC;
