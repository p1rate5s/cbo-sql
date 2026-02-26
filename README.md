# cbo-sql

SQL queries for Azure cloud cost optimization analysis using the FOCUS (FinOps Open Cost and Usage Specification) schema.

## Data Source

All queries run against the production FOCUS table:

```
`edav_prd_od_ocio_cbo`.`bronze`.`azure_focus_base`
```

## Queries

| File | Description |
|------|-------------|
| `query_01.sql` | **Existing Commitment Coverage Analysis** - Savings from current commitments by service |
| `query_02.sql` | **Commitment Coverage Percentage Summary** - Covered vs uncovered amounts (RI/Savings Plans only) |
| `query_03.sql` | **Commitment Coverage by Service** - Covered vs uncovered amounts by service (RI/Savings Plans only) |
| `query_04.sql` | **Commitment Coverage Rate by Pricing Category** - Coverage vs opportunity across pricing categories |
| `query_05.sql` | **Commitment Utilization Analysis** - Identifies underutilized commitments |
| `query_06.sql` | **Commitment Savings Summary by Type** - High-level savings by commitment discount type |
| `query_07.sql` | **Daily Commitment Usage Trend** - Daily usage patterns to identify underutilization |
| `query_08.sql` | **Highest Cost Services (3-Month Average)** - Services ranked by cost with 3-month lookback |
| `query_09.sql` | **Active Commitments Since 10/1/2025** - Commitment savings using ContractedCost |
| `query_10.sql` | **Commitment Coverage for Eligible Services** - Coverage for RI/SP eligible services (last 30 days) |
| `query_10b.sql` | **Eligible Services Coverage (Since 10/1/2025)** - Same as Query 10 with extended date range |
| `query_10c.sql` | **Eligible Services Coverage (January 2026)** - Same as Query 10 for January 2026 only |
| `query_11.sql` | **Commitment Savings Details (All Charge Types)** - Individual commitment savings since 10/1/2025 |
| `query_12.sql` | **Commitment Savings Opportunity** - Uncovered eligible services with potential savings estimates |
