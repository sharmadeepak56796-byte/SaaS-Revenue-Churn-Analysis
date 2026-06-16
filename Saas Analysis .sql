Select *
from subscriptions;

Select*
from monthly_revenue;

-- What is the overall churn rate, and
-- how has the monthly churn rate trended over the past 4 years? Is churn improving or getting worse?

-- 1. overall churn rate
Select
	round(count(case when churned = 'Yes' then 1 end)*100/count(*)::numeric,2) as overall_churn_rate_pct
from subscriptions;

-- 2. monthly churn rate trended over the past 4 years
select month,
	monthly_churn_rate_pct
from monthly_revenue
order by month;
	
-- 3. Wheather churn improving or worsening
-- Compare first month and last month churn

with churn_trend as(
select 
	month,
	monthly_churn_rate_pct,
	row_number() over (order by month) as rn_start,
	row_number() over(order by month desc) as rn_end
from monthly_revenue
)
select 
	Max(case when rn_start = 1 then monthly_churn_rate_pct end) as first_month_churn,
	max(case when rn_end = 1 then monthly_churn_rate_pct end) as end_month_churn
from churn_trend;

-- 4 Average monthly churn rate

select
	round(avg(monthly_churn_rate_pct)::numeric,2) as avg_monthly_churn_rate
from monthly_revenue;

-- Change between first and last month churn

with churn_trend as(
select 
	month,
	monthly_churn_rate_pct,
	row_number() over (order by month) as rn_start,
	row_number() over(order by month desc) as rn_end
from monthly_revenue
)
select 
	Max(case when rn_start = 1 then monthly_churn_rate_pct end) as first_month_churn,
	max(case when rn_end = 1 then monthly_churn_rate_pct end) as end_month_churn,
	round(
		(Max(case when rn_end = 1 then monthly_churn_rate_pct end)
		-
		max(case when rn_start = 1 then monthly_churn_rate_pct end))::numeric,2
	) as change_in_churn_rate
from churn_trend;

--The overall churn rate was 52.17%. Monthly churn averaged 4.52% over the four-year period.
--Churn moved from 0% in the first month to 1.42% in the latest month, 
--indicating that customer retention has improved/worsened over time. 
--This trend suggests the company's retention efforts are becoming more/less effective.

-- Change_in_churn_rate is > 0 
-- then, churn is woresning because the monthly churn rate is increased over time. 


-- # Which subscription plan (Starter, Professional, Business, Enterprise) has the highest churn rate? 

select plan,
	count(*) as total_customers,
	count(case when churned = 'Yes' then 1 end) as churned_customer,
	round(count(case when churned = 'Yes' then 1 end)*100/count(*)::numeric,2) as churn_rate_pct
from subscriptions
group by plan
order by churn_rate_pct desc;

-- The Starter plan has the highest churn rate at 63.3%, 
-- suggesting that lower-tier customers are more likely to discontinue their subscriptions. 
-- Enterprise customers exhibit the strongest retention, indicating higher perceived value and greater product dependency.


-- # Does billing cycle (monthly vs. annual) significantly impact retention?
select billing_cycle,
	count(*) as total_customers,
	count(case when churned = 'Yes' then 1 end) as churned_customer,
	round(count(case when churned = 'Yes' then 1 end)*100/count(*)::numeric,2) as churn_rate_pct
from subscriptions
group by billing_cycle
order by churn_rate_pct desc;

-- Customers on monthly subscriptions churn at a substantially higher rate than annual subscribers. 
-- Annual contracts appear to improve retention by increasing customer commitment and reducing opportunities to cancel.


-- # What are the top 3 reasons customers churn, and do these reasons differ by plan type or company size?

with churn_reason_rank as (
select plan,
	churn_reason,
	count(*) as churned_customers,
	row_number() over(partition by plan order by count(*) desc) as rnk
from subscriptions
where churned = 'Yes'
group by plan, churn_reason
)
Select plan, 
	churn_reason,
	churned_customers
from churn_reason_rank
where rnk <= 3
order by plan, churned_customers desc;

-- Lower-tier customers primarily churn due to pricing concerns, 
-- while higher-tier customers tend to leave because of missing functionality or service-related issues.

-- # Do churn reason differ form company size

with churn_reason_rank as (
select company_size,
	churn_reason,
	count(*) as churned_customers,
	row_number() over(partition by company_size order by count(*) desc) as rnk
from subscriptions
where churned = 'Yes'
group by company_size, churn_reason
)
Select company_size, 
	churn_reason,
	churned_customers
from churn_reason_rank
where rnk <= 3
order by company_size, churned_customers desc;

-- Smaller businesses are more price-sensitive, 
-- whereas larger organizations are more likely to churn because of product limitations and support expectations.

-- # which churn reason is costing the company the most revenue?

select churn_reason,
	count(*) as churned_customers,
	round(sum(monthly_revenue)::numeric,2) as lost_mrr
from subscriptions
where churned = 'Yes'
group by churn_reason
order by lost_mrr desc;

-- Althrough " Price " is the most comman churn reason, " Missing Features " results in the 
-- highest revenue loss because it affects higher-paying customers.


-- # Calculate the average Customer Lifetime Value (CLV) by plan. 
-- Compare this to the Customer Acquisition Cost (CAC). Which plans are the most and least profitable?


-- Step 1. Calculate the average customerlife value 

-- Churn rate by plan 

with plan_churn as (
	select 
		plan,
		count(*) as total_customers,
		count(case when churned = 'Yes' then 1 end) as churned_customers,
		round(count(case when churned = 'Yes' then 1 end)*1.0/count(*)::numeric,2) as churn_rate
from subscriptions
group by plan
)
select *
from plan_churn;

-- Estimate CLV by plan

with plan_metrics as (
	select 
		plan,
		avg(monthly_revenue) as Arpu,
		count(case when churned = 'Yes' then 1 end)*1.0/count(*) as churn_rate
from subscriptions
group by plan
)
select 
	plan,
		round(Arpu::numeric,2) as Arpu,
		round(churn_rate*100,2) as churn_rate_pct,
		round((Arpu/nullif(churn_rate,0))::numeric,2) as estimate_clv
from plan_metrics
order by estimate_clv desc;
		
-- Step 3: Calculate Average CAC

select 
	round(avg(customer_acquisition_cost)::numeric,2) as avg_cac
from monthly_revenue

-- Step 4: Compare CLV VS CAC

with plan_metrics as (
	select 
		plan,
		avg(monthly_revenue) as Arpu,
		count(case when churned = 'Yes' then 1 end)*1.0/count(*) as churn_rate
from subscriptions
group by plan
),
cac as (
	select 
	round(avg(customer_acquisition_cost)::numeric,2) as avg_cac
from monthly_revenue
)

select
	p.plan,
    ROUND((p.arpu / NULLIF(p.churn_rate,0))::numeric,2) AS clv,
    ROUND(c.avg_cac::numeric,2) AS cac,
    ROUND(
        ((p.arpu / NULLIF(p.churn_rate,0))
        / c.avg_cac)::numeric,
        2
    ) AS clv_cac_ratio
FROM plan_metrics p
CROSS JOIN cac c
ORDER BY clv_cac_ratio DESC;

-- Enterprise customers generate the highest lifetime value and the strongest CLV:CAC ratio,
-- making them the most profitable customer segment. 
-- Starter customers exhibit the lowest lifetime value and weakest CLV:CAC ratio, 
-- suggesting that acquisition costs are barely recovered before these customers churn.






























