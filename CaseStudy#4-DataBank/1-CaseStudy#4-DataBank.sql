SET SEARCH_PATH to data_bank;

-- A. Customer Nodes Exploration
SELECT * FROM customer_nodes LIMIT 100;

SELECT calculate_median("region_id")FROM customer_nodes;

-- 1. How many unique nodes are there on the Data Bank system?
SELECT count(DISTINCT(node_id)) nodes FROM data_bank.customer_nodes cn;

-- 2. What is the number of nodes per region?
SELECT region_name, count(DISTINCT(node_id)) nodes_count
FROM data_bank.customer_nodes cn
JOIN regions r  ON r.region_id = cn.region_id 
GROUP BY 1;

-- 3. How many customers are allocated to each region?
SELECT region_name, count(customer_id) nodes_count
FROM customer_nodes cn
JOIN regions r  ON r.region_id = cn.region_id 
GROUP BY 1;

-- 4. How many days on average 
-- 	  are customers reallocated to a different node?
WITH t1 as(
	SELECT 
		customer_id, 
		region_id,node_id, 
		start_date, 
		end_date, 
		(end_date - start_date)+1 date_diff -- +1 since END dates ARE inclusive
	FROM data_bank.customer_nodes
	WHERE end_date <> '9999-12-31'
	ORDER BY customer_id, node_id ,start_date
),
t2 AS (
	SELECT customer_id, node_id,sum(date_diff) as tot_date_diff
	FROM t1
	GROUP BY customer_id, node_id
)
SELECT 
	round(avg(tot_date_diff)) avg_relocation_days
FROM t2
;
-- 5. What is the median, 80th and 95th percentile 
-- for this same reallocation days metric for each region?

-- find the number of days for each customer data node change
WITH t1 as(
	SELECT 
		region_id,
		customer_id, 
		node_id, 
		start_date, 
		end_date,
		(end_date - start_date)+1 date_diff -- +1 since END dates ARE inclusive
	FROM data_bank.customer_nodes
	WHERE end_date <> '9999-12-31'
	ORDER BY region_id, customer_id, node_id ,start_date	
	),
-- some customer data was assigned to the same node concurently
-- the duration is aggregated in this query  
t2 AS (
	SELECT 
		region_id,
		customer_id, 
		node_id,
		sum(date_diff) days_node_change
	FROM t1
	GROUP BY region_id, customer_id, node_id
	ORDER BY region_id, days_node_change
),
-- after ordering the number of days per node change per customer
-- the stat is indexed by region
-- an odd flag for number of observations per region was added to help in calculating the median
-- the percentile of each observation was calcualted
t3 AS (
SELECT 
	region_id,
	days_node_change,
	count(*) OVER(PARTITION BY region_id) % 2 AS IS_ODD,
	ceil((count(*) OVER(PARTITION BY region_id)) ::float /2) AS mid_index,
	ROW_NUMBER() OVER(PARTITION BY region_id ORDER BY days_node_change) AS row_index,
	round(
		ROW_NUMBER() OVER(PARTITION BY region_id ORDER BY days_node_change):: float
		/ count(*) OVER(PARTITION BY region_id) ::float
		* 100) AS percentile
FROM t2
)
-- the data was filterd to leave only the median values (odd one value and even two values)
-- another filter was added to keep the 80th and the 95th percentile
-- a median aggrigation was preformed resulting in:
	-- the median (50th) precentile (exact median for every region)
	-- the avarage of values close to 80th precentile (Aporximaiton to simplify query)
	-- the avarage of the values close to 95th precentile (Aproximation to simplfy query)
SELECT region_id, percentile, avg(days_node_change) 
FROM t3
WHERE 
	(is_odd = 0 AND (row_index = mid_index OR row_index = mid_index + 1) ) 
	OR 
	(is_odd = 1 AND row_index = mid_index)
	OR 
	(percentile = 80 OR percentile = 95) -- note the percentiles ARE approximated FOR the sake OF query simplicity
GROUP BY region_id, percentile 
;

--==========================================================================================================--

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
	FROM
		customer_transactions
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

-- For each month - how many Data Bank customers make more than 1 deposit
-- and either 1 purchase or 1 withdrawal in a single month?
WITH monthly_transactions AS (
  SELECT 
    customer_id, 
    DATE_PART('month', txn_date) AS mth,
    SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count,
    SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_count,
    SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count
  FROM customer_transactions
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


-- approach 2
SELECT month_, to_char(to_date(month_::TEXT, 'MM'), 'month'), count(*) FROM (
SELECT month_, customer_id, sum(deposits) cdeposits, sum(purchase) cpurchase, sum(withdrawal)cwithdrawal
FROM (
SELECT * ,
CASE
	WHEN txn_type = 'deposit' AND counts_ > 1 THEN counts_
	ELSE null
END AS deposits,
CASE
	WHEN txn_type = 'purchase' THEN counts_
	ELSE null
END AS purchase,
CASE
	WHEN txn_type = 'withdrawal' THEN counts_
	ELSE null
END AS withdrawal
FROM
(SELECT date_part('Month', txn_date) AS month_ ,customer_id, txn_type, count(*) AS counts_ 
FROM customer_transactions
GROUP BY month_, customer_id, txn_type
ORDER BY MONTH_, customer_id, txn_type) as t1
) AS t2
GROUP BY month_, customer_id
) AS t3
WHERE cdeposits IS NOT NULL AND (cpurchase IS NOT NULL OR cwithdrawal IS NOT null)
GROUP BY 1,2
ORDER BY 1
;

-- approach 1
WITH t1 AS (
SELECT
	date_part('Month',
	txn_date) AS month_,
	customer_id,
	txn_type,
	count(*) AS count_
FROM
	customer_transactions ct
GROUP BY 1,2,3
ORDER BY month_, customer_id),
t2 AS (
SELECT
	month_,
	customer_id,
	string_agg(txn_type,' ') txn_types ,
	sum(count_) AS total_month_txn
FROM
	t1
WHERE 
	(count_ > 1 AND txn_type = 'deposit')
	OR (txn_type <> 'deposit')
GROUP BY month_, customer_id),
t3 AS (
SELECT *
FROM t2
WHERE
	txn_types LIKE('%deposit%')
	AND 
	(txn_types LIKE('%withdrawal%') OR txn_types LIKE('%purchase%')))
SELECT month_, count(*)
FROM t3
GROUP BY month_
;

-- What is the closing balance for each customer at the end of the month?
--  Also show the change in balance each month in the same table output.





-- CTE 1 - To identify transaction amount as an inflow (+) or outflow (-)
WITH monthly_balances_cte AS (
  SELECT 
    customer_id, 
    (DATE_TRUNC('month', txn_date) + INTERVAL '1 MONTH - 1 DAY') AS closing_month, 
    SUM(CASE 
      WHEN txn_type = 'withdrawal' OR txn_type = 'purchase' THEN -txn_amount
      ELSE txn_amount END) AS transaction_balance
  FROM data_bank.customer_transactions
  GROUP BY 
    customer_id, txn_date 
)
-- CTE 2 - Use GENERATE_SERIES() to generate as a series of last day of the month for each customer.
, monthend_series_cte AS (
  SELECT
    DISTINCT customer_id,
    ('2020-01-31'::DATE + GENERATE_SERIES(0,3) * INTERVAL '1 MONTH') AS ending_month
  FROM data_bank.customer_transactions
)
-- CTE 3 - Calculate total monthly change and ending balance for each month using window function SUM()
, monthly_changes_cte AS (
  SELECT 
    monthend_series_cte.customer_id, 
    monthend_series_cte.ending_month,
    SUM(monthly_balances_cte.transaction_balance) OVER (
      PARTITION BY monthend_series_cte.customer_id, monthend_series_cte.ending_month
      ORDER BY monthend_series_cte.ending_month
    ) AS total_monthly_change,
    SUM(monthly_balances_cte.transaction_balance) OVER (
      PARTITION BY monthend_series_cte.customer_id 
      ORDER BY monthend_series_cte.ending_month
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ending_balance
  FROM monthend_series_cte
  LEFT JOIN monthly_balances_cte
    ON monthend_series_cte.ending_month = monthly_balances_cte.closing_month
    AND monthend_series_cte.customer_id = monthly_balances_cte.customer_id
)
-- Final query: Display the output of customer monthly statement with the ending balances. 
SELECT 
customer_id, 
  ending_month, 
  COALESCE(total_monthly_change, 0) AS total_monthly_change, 
  MIN(ending_balance) AS ending_balance
 FROM monthly_changes_cte
 GROUP BY 
  customer_id, ending_month, total_monthly_change
 ORDER BY 
  customer_id, ending_month;

-- 5. What is the percentage of customers who increase their closing balance by more than 5%?
 
 
--============================================================================================================--
-- C. Data Allocation Challenge

-- To test out a few different hypotheses - 
-- the Data Bank team wants to run an experiment 
-- where different groups of customers would be allocated data using 3 different options:
    -- Option 1: data is allocated based off the amount of money at the end of the previous month
    -- Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
    -- Option 3: data is updated real-time

-- For this multi-part challenge question 
-- you have been requested to generate the following data elements to help the Data Bank team
-- estimate how much data will need to be provisioned for each option:
    
 -- running customer balance column that includes the impact each transaction	
  SELECT customer_id,
  txn_date,
  txn_type,
  txn_amount,
  	sum(
	 	CASE
	 		WHEN txn_type = 'deposit' THEN txn_amount 
	 		WHEN txn_type = 'purchase' THEN - txn_amount 
	 		WHEN txn_type = 'withdrawal' THEN - txn_amount 
	 	END)
	 	OVER (PARTITION BY customer_id ORDER BY txn_date)
	 	AS running_total_balance
	 	FROM customer_transactions ct
	 	ORDER BY customer_id, txn_date;
 
-- customer balance at the end of each month
SELECT * FROM closing_balance cb WHERE total_month_change <> 0;
	 
-- minimum, average and maximum values of the running balance for each customer
WITH running_total_balance as(  
SELECT customer_id,
  txn_date,
  txn_type,
  txn_amount,
  	sum(
	 	CASE
	 		WHEN txn_type = 'deposit' THEN txn_amount 
	 		WHEN txn_type = 'purchase' THEN - txn_amount 
	 		WHEN txn_type = 'withdrawal' THEN - txn_amount 
	 	END)
	 	OVER (PARTITION BY customer_id ORDER BY txn_date)
	 	AS running_total_balance
	 	FROM customer_transactions ct
	 	ORDER BY customer_id, txn_date)
SELECT 
customer_id,
-- txn_date,
min(running_total_balance),
max(running_total_balance),
round(avg(running_total_balance))
FROM running_total_balance
GROUP BY customer_id ;

-- Using all of the data available 
-- how much data would have been required for each option on a monthly basis?

SELECT count(*) number_of_rows, sum(pg_column_size(running_total_balance)) AS size_in_bytes
FROM 
(SELECT 
  	sum(
	 	CASE
	 		WHEN txn_type = 'deposit' THEN txn_amount 
	 		WHEN txn_type = 'purchase' THEN - txn_amount 
	 		WHEN txn_type = 'withdrawal' THEN - txn_amount 
	 	END)
	 	OVER (PARTITION BY customer_id ORDER BY txn_date)
	 	AS running_total_balance
	 	FROM customer_transactions ct) t1;

SELECT * FROM customer_transactions ct;

SELECT sum(pg_column_size(customer_id)) AS size_in_bytes FROM customer_nodes;

 -- running customer balance column that includes the impact each transaction

--==================================================================================================================--
D. Extra Challenge

-- Data Bank wants to try another option which is a bit more difficult to implement 
-- they want to calculate data growth using an interest calculation
-- just like in a traditional savings account you might have with a bank.
-- If the annual interest rate is set at 6% and the Data Bank team wants to reward its customers by
-- increasing their data allocation based off the interest calculated on a daily basis at the end of each day
-- how much data would be required for this option on a monthly basis?

Special notes:

-- Data Bank wants an initial calculation which does not allow for compounding interest
-- however they may also be interested in a daily compounding interest calculation 
-- so you can try to perform this calculation if you have the stamina!
-- Extension Request
-- The Data Bank team wants you to use the outputs generated from the above sections to create
-- a quick Powerpoint presentation which will be used as marketing materials for:
    -- external investors who might want to buy Data Bank shares 
    -- new prospective customers who might want to bank with Data Bank.

-- Using the outputs generated from the customer node questions
-- generate a few headline insights which Data Bank might use to
-- market it’s world-leading security features to potential investors and customers.

-- With the transaction analysis - prepare a 1 page presentation slide
-- which contains all the relevant information about the various options 
-- for the data provisioning so the Data Bank management team can make an informed decision.

