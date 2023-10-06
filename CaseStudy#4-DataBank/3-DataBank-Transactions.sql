--B. Customer Transactions
SELECT * FROM customer_transactions;

-- 1. What is the unique count and 
-- total amount for each transaction type?
SELECT 
	txn_type,
	count(*), 
	sum(txn_amount) 
FROM customer_transactions 
GROUP BY 1;

-- 2. What is the average total historical 'deposit' 
-- counts and amounts for all customers?
SELECT
	round(avg(total_count)) avg_total_cnt,
	round(avg(total_amount)) avg_total_amount
FROM
	(
	SELECT
		customer_id ,
		count(customer_id) AS total_count,
		sum(txn_amount) AS total_amount
	FROM customer_transactions
	WHERE txn_type = 'deposit'
	GROUP BY customer_id) AS t1;
	
WITH deposits AS (
  SELECT 
    customer_id, 
    COUNT(customer_id) AS txn_count, 
    AVG(txn_amount) AS avg_amount
  FROM data_bank.customer_transactions
  WHERE txn_type = 'deposit'
  GROUP BY customer_id
)
SELECT 
  ROUND(AVG(txn_count)) AS avg_deposit_count, 
  ROUND(AVG(avg_amount)) AS avg_deposit_amt
FROM deposits;

-- 3.For each month - how many Data Bank customers make more than 1 deposit
-- and either 1 purchase or 1 withdrawal in a single month?
WITH monthly_transactions AS (
  SELECT 
    customer_id, 
    DATE_PART('month', txn_date) AS mth,
    SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count,
    SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_count,
    SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count
  FROM data_bank.customer_transactions
  GROUP BY DATE_PART('month', txn_date), customer_id
  ORDER BY mth, customer_id 
)
SELECT
   to_char(to_date(mth::text, 'MM'),'Month'),
  	COUNT(customer_id) AS customer_count
FROM monthly_transactions
WHERE deposit_count > 1 
  AND (purchase_count >= 1 OR withdrawal_count >= 1)
GROUP BY mth
ORDER BY mth;

-- 4. What is the closing balance for each customer at the end of the month?
CREATE VIEW closing_balance AS 
--CTE-1: 
	-- identify inflow(+) or outflow(-) 
	-- identify end of month date for each transaction
	-- aggregate transactions to a monthly granularity 
WITH transactions AS (
SELECT 
customer_id,
(date_trunc('month', txn_date) + INTERVAL '1 month -1 day') ::date AS month_end,
sum(CASE
	WHEN txn_type = 'deposit' THEN txn_amount
	WHEN txn_type = 'purchase' OR txn_type = 'withdrawal' THEN -txn_amount
	ELSE NULL
END) AS amount
FROM customer_transactions
GROUP BY customer_id , month_end
ORDER BY customer_id, month_end
),
--CTE-2: generate end of month dates for each customer
months AS(
SELECT DISTINCT 
customer_id
,('2020-01-31'::date + generate_series(0,3) * INTERVAL '1 month')::date AS dates
FROM customer_transactions
ORDER BY 1,2
),
--CTE-3: adding the no transaction monthes for each customer 
monthly_txn AS (
SELECT 
m.customer_id AS customer_id,
m.dates AS month_end,
CASE 
	WHEN amount IS NULL THEN 0 
	ELSE amount
END AS total_month_change
FROM transactions t
RIGHT JOIN months m
ON t.customer_id = m.customer_id 
AND t.month_end = m.dates
ORDER BY m.customer_id, m.dates
)
-- CTE-4: closing monthly balance for each customer for the first 4 months of 2020
SELECT 
customer_id,
month_end,
total_month_change,
sum(total_month_change) OVER(PARTITION BY customer_id ORDER BY month_end) AS closing_balance
FROM monthly_txn
-- closing balance for each customer for each month
SELECT * FROM closing_balance ;

-- 4.2 show the change in balance each month in the same table output.
SELECT 
customer_id,
month_end,
total_month_change,
closing_balance,
round((((total_month_change + lag(closing_balance) OVER(PARTITION BY customer_id))
	/lag(closing_balance) OVER(PARTITION BY customer_id)) - 1)*100) AS Percent_change
FROM closing_balance

-- 5. What is the percentage of customers who increase their closing balance by more than 5% for atleast 1 month?
SELECT  count(DISTINCT(customer_id)) / 
	(SELECT count(DISTINCT customer_id)
	FROM customer_transactions ct)::float AS percent_customers_with_balance_growth
FROM 
(SELECT 
customer_id,
month_end,
total_month_change,
closing_balance,
CASE WHEN lag(closing_balance) OVER(PARTITION BY customer_id) = 0 THEN NULL
ELSE  round((((total_month_change + lag(closing_balance) OVER(PARTITION BY customer_id))
	/lag(closing_balance) OVER(PARTITION BY customer_id)) - 1)*100) 
END AS Percent_change
FROM closing_balance
) t1
WHERE percent_change >= 5



