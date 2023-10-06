-- A. Customer Journey

-- Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.
SELECT * FROM plans;

select count(distinct customer_id)  from subscriptions s;

SELECT
	s.customer_id,
	p.plan_name,
	p.price,
	s.start_date
FROM
	subscriptions s
JOIN "plans" p 
ON
	p.plan_id = s.plan_id
WHERE
	customer_id < 9;


-- Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!

-------------------------------------------------------------------------
-- B. Data Analysis Questions

-- 1. How many customers has Foodie-Fi ever had?
SELECT
	count(DISTINCT customer_id)
FROM
	subscriptions s;


-- 2. What is the monthly distribution of trial plan start_date values for our dataset 
-- use the start of the month as the group by value
SELECT 
	date_part('month', start_date) AS month_number, 
	to_char(date_trunc('month', start_date), 'month') AS month_name,
	count(*) trial_plan_count
FROM subscriptions s
JOIN "plans" p 
ON
	p.plan_id = s.plan_id
WHERE plan_name = 'trial'
GROUP BY 1,2
ORDER BY 1;

-- 3. What plan start_date values occur after the year 2020 for our dataset?
-- Show the breakdown by count of events for each plan_name
SELECT s.plan_id, plan_name, count(*)
FROM subscriptions s
JOIN "plans" p 
ON
	p.plan_id = s.plan_id
WHERE date_trunc('MONTH', start_date)::date >= date('2021-01-01')
GROUP BY 1,2
ORDER BY 1;

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT  
count(*) AS count_churned_customers,
100 * count(*)::float / (SELECT count(DISTINCT customer_id) FROM subscriptions s)  AS percent_churned_customers
FROM subscriptions s
WHERE plan_id = 4;

-- 5. How many customers have churned straight after their initial free trial
-- what percentage is this rounded to the nearest whole number?

	-- 1. using row_number
SELECT 
	count(DISTINCT customer_id) AS count_non_paying_customers,
	100 * count(*) / (SELECT count(DISTINCT customer_id) FROM subscriptions) AS percentnon_paying_customers
FROM
(SELECT customer_id, plan_id, ROW_NUMBER() over(PARTITION BY customer_id ORDER BY plan_id) AS plan_number
FROM subscriptions s) AS t1
WHERE plan_id = 4 AND plan_number = 2

	-- 2. using lead
SELECT 
	count(DISTINCT customer_id) AS count_non_paying_customers,
	100 * count(*) / (SELECT count(DISTINCT customer_id) FROM subscriptions) AS percentnon_paying_customers
FROM 
(SELECT customer_id, plan_id, lead(plan_id) over(PARTITION BY customer_id) AS next_plan
FROM subscriptions s
ORDER BY customer_id, start_date) AS t1
WHERE plan_id = 0 AND next_plan = 4;

-- 6. What is the number and percentage of customer plans after their initial free trial?
WITH next_plans AS (
  SELECT 
    customer_id, 
    plan_id, 
    LEAD(plan_id) OVER( PARTITION BY customer_id ORDER BY plan_id) as next_plan_id
  FROM subscriptions
)
SELECT 
  next_plan_id AS plan_id, 
  COUNT(customer_id) AS converted_customers,
  ROUND(100 * 
    COUNT(customer_id)::NUMERIC 
    / (SELECT COUNT(DISTINCT customer_id) 
      FROM subscriptions)
  ,1) AS conversion_percentage
FROM next_plans
WHERE next_plan_id IS NOT NULL 
  AND plan_id = 0
GROUP BY next_plan_id
ORDER BY next_plan_id; 
	

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
SELECT plan_id,plan_name, count(*) AS count_customers_on_plan, 100 * count(*)::float / (SELECT count(DISTINCT customer_id) FROM subscriptions s)  AS percent_customers_on_plan
FROM 
(SELECT
	s.plan_id,
	s.customer_id,
	p.plan_name,
	s.start_date,
	max(start_date) OVER(PARTITION BY customer_id) AS current_plan_start_date
FROM
	subscriptions s
JOIN "plans" p 
ON
	p.plan_id = s.plan_id
WHERE start_date <= '2020-12-31' 
ORDER BY s.customer_id, start_date) AS t1
WHERE start_date = current_plan_start_date
GROUP BY plan_id, plan_name

-- 8. How many customers have upgraded to an annual plan in 2020?
SELECT count(DISTINCT customer_id) AS number_of_annual_subscribers
FROM
	subscriptions s
WHERE start_date <= '2020-12-31' AND plan_id = 3 -- pro annual plan id = 3
;

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
SELECT round(avg(days_from_join))
FROM 
(
SELECT customer_id, plan_id, start_date, (start_date - min(start_date) OVER(PARTITION BY customer_id) ) AS days_from_join
FROM subscriptions s
ORDER BY customer_id, start_date) AS t1
WHERE plan_id = 3 -- annual plan id = 3
; 


-- Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

	-- using case
SELECT 
	CASE 
		WHEN days_from_join <= 30 THEN '0-30'
		WHEN days_from_join <= 60 THEN '31-60'
		WHEN days_from_join <= 90 THEN '61-90'
		WHEN days_from_join <= 120 THEN '91-120'
		WHEN days_from_join <= 150 THEN '121-150'
		WHEN days_from_join <= 180 THEN '151-180'
		WHEN days_from_join <= 210 THEN '181-210'
		WHEN days_from_join <= 240 THEN '211-240'
		WHEN days_from_join <= 270 THEN '241-270'
		WHEN days_from_join <= 300 THEN '271-300'
		WHEN days_from_join <= 330 THEN '301-330'
		WHEN days_from_join <= 360 THEN '331-360'
		WHEN days_from_join <= 390 THEN '361-390'
	END AS join_days_range,
	count(customer_id) ASnumber_of_customers 
FROM 
(
SELECT customer_id, plan_id, start_date, (start_date - min(start_date) OVER(PARTITION BY customer_id) ) AS days_from_join
FROM subscriptions s
ORDER BY customer_id, start_date) AS t1
WHERE plan_id = 3 -- annual plan id = 3
GROUP BY 1
ORDER BY 1
;

	-- using width bucket
SELECT 
	WIDTH_BUCKET(days_from_join, 0, 360, 12) AS bucket_number,
	((WIDTH_BUCKET(days_from_join, 0, 360, 12)*30)-30)::varchar 
		|| ' - ' || (WIDTH_BUCKET(days_from_join, 0, 360, 12)*30)::varchar AS join_days_range,
	count(customer_id) AS number_of_customers
FROM 
(
SELECT 
	customer_id, plan_id, start_date,
	(start_date - min(start_date) OVER(PARTITION BY customer_id) ) AS days_from_join
FROM subscriptions s
ORDER BY customer_id, start_date) AS t1
WHERE plan_id = 3 -- annual plan id = 3
GROUP BY 1
ORDER BY 1


-- How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

SELECT * FROM "plans" p;

-- using window funcitons
SELECT *
FROM (
SELECT *, 
count(*) OVER(PARTITION BY customer_id) AS plan_changes, 
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date) AS plan_number
FROM subscriptions s
WHERE start_date < '2021-01-01' AND plan_id NOT IN (0,3,4)
ORDER BY customer_id, start_date)AS t1
WHERE plan_changes > 1 AND plan_id> plan_number
;

-- using self join (expensive but easier logic)
SELECT *
FROM subscriptions s
JOIN subscriptions s2 
ON s.customer_id = s2.customer_id 
WHERE s.plan_id = 2 AND s2.plan_id = 1 AND s.start_date < s2.start_date
ORDER BY s.customer_id, s.start_date, s2.customer_id, s2.start_date;
---------------------------------------------------------------------------------------
-- C. Challenge Payment Question

-- The Foodie-Fi team wants you to create a new payments table for the year 2020
-- that includes amounts paid by each customer in the subscriptions table with the following requirements:
    -- monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
    -- upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
    -- upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
    -- once a customer churns they will no longer make payments

SELECT *
FROM
(
SELECT 
	customer_id,
	plan_name,
	CASE 
		WHEN plan_name = 'pro annual' AND previous_plan = 'pro monthly' THEN previous_plan_renew_date
		ELSE plan_start_date
	END::date
	AS payment_due_date,
	CASE 
		WHEN plan_name = 'pro annual' AND previous_plan = 'pro monthly' THEN price
		ELSE (price - previous_payment)
	END AS payment
FROM 
(
	SELECT 
		s.customer_id AS customer_id,
		p.plan_name AS plan_name,
		p.price AS price, 
		LAG(price) OVER(PARTITION BY customer_id) AS previous_payment,
		LAG(plan_name) OVER(PARTITION BY customer_id) AS previous_plan,
		s.start_date AS plan_start_date,
		LAG(s.start_date) OVER(PARTITION BY customer_id) +
		INTERVAL'1 month' *
		(
			date_part ('month', s.start_date) -
			date_part('month', LAG(s.start_date) OVER(PARTITION BY s.customer_id))
			)  AS previous_plan_renew_date
	FROM subscriptions s
	JOIN "plans" p 
	ON p.plan_id = s.plan_id 
	WHERE date_part('year', start_date) = 2020
	ORDER BY s.customer_id, s.start_date
) AS t1
) AS t2
WHERE payment IS NOT NULL
;

