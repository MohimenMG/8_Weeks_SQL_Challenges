## Case Study #4: Data Bank

<img src="https://user-images.githubusercontent.com/81607668/130343294-a8dcceb7-b6c3-4006-8ad2-fab2f6905258.png" alt="Image" width="500" height="520">

## 📚 Table of Contents
- [Business Task](#business-task)
- [Entity Relationship Diagram](#entity-relationship-diagram)
- [Question and Solution](#question-and-solution)

Please note that all the information regarding the case study has been sourced from the following link: [here](https://8weeksqlchallenge.com/case-study-4/). 

***

## Business Task
Danny launched a new initiative, Data Bank which runs **banking activities** and also acts as the world’s most secure distributed **data storage platform**!

Customers are allocated cloud data storage limits which are directly linked to how much money they have in their accounts. 

The management team at Data Bank want to increase their total customer base - but also need some help tracking just how much data storage their customers will need.

This case study is all about calculating metrics, growth and helping the business analyse their data in a smart way to better forecast and plan for their future developments!

## Entity Relationship Diagram

<img width="631" alt="image" src="https://user-images.githubusercontent.com/81607668/130343339-8c9ff915-c88c-4942-9175-9999da78542c.png">

**Table 1: `regions`**

This regions table contains the `region_id` and their respective `region_name` values.

<img width="176" alt="image" src="https://user-images.githubusercontent.com/81607668/130551759-28cb434f-5cae-4832-a35f-0e2ce14c8811.png">

**Table 2: `customer_nodes`**

Customers are randomly distributed across the nodes according to their region. This random distribution changes frequently to reduce the risk of hackers getting into Data Bank’s system and stealing customer’s money and data!

<img width="412" alt="image" src="https://user-images.githubusercontent.com/81607668/130551806-90a22446-4133-45b5-927c-b5dd918f1fa5.png">

**Table 3: Customer Transactions**

This table stores all customer deposits, withdrawals and purchases made using their Data Bank debit card.

<img width="343" alt="image" src="https://user-images.githubusercontent.com/81607668/130551879-2d6dfc1f-bb74-4ef0-aed6-42c831281760.png">

***

## Question and Solution

Please join me in executing the queries using PostgreSQL on [DB Fiddle](https://www.db-fiddle.com/f/2GtQz4wZtuNNu7zXH5HtV4/3). It would be great to work together on the questions!

If you have any questions, reach out to me on [LinkedIn](https://www.linkedin.com/in/katiehuangx/).

## 🏦 A. Customer Nodes Exploration

**1. How many unique nodes are there on the Data Bank system?**

```sql
SELECT COUNT(DISTINCT node_id) AS unique_nodes
FROM data_bank.customer_nodes;
```

**Answer:**

|unique_nodes|
|:----|
|5|

- There are 5 unique nodes on the Data Bank system.

***

**2. What is the number of nodes per region?**

```sql
SELECT
  regions.region_name, 
  COUNT(DISTINCT customers.node_id) AS node_count
FROM data_bank.regions
JOIN data_bank.customer_nodes AS customers
  ON regions.region_id = customers.region_id
GROUP BY regions.region_name;
```

**Answer:**

|region_name|node_count|
|:----|:----|
|Africa|5|
|America|5|
|Asia|5|
|Australia|5|
|Europe|5|

***

**3. How many customers are allocated to each region?**

```sql
SELECT 
  region_id, 
  COUNT(customer_id) AS customer_count
FROM data_bank.customer_nodes
GROUP BY region_id
ORDER BY region_id;
```

**Answer:**

|region_id|customer_count|
|:----|:----|
|1|770|
|2|735|
|3|714|
|4|665|
|5|616|

***

**4. How many days on average are customers reallocated to a different node?**

```sql
WITH node_days AS (
  SELECT 
    customer_id, 
    node_id,
    end_date - start_date AS days_in_node
  FROM data_bank.customer_nodes
  WHERE end_date != '9999-12-31'
  GROUP BY customer_id, node_id, start_date, end_date
) 
, total_node_days AS (
  SELECT 
    customer_id,
    node_id,
    SUM(days_in_node) AS total_days_in_node
  FROM node_days
  GROUP BY customer_id, node_id
)

SELECT ROUND(AVG(total_days_in_node)) AS avg_node_reallocation_days
FROM total_node_days;
```

**Answer:**

|avg_node_reallocation_days|
|:----|
|24|

- On average, customers are reallocated to a different node every 24 days.

***

**5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?**
```sql 
-- CTE-1: find the number of days for each customer data node change
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
-- CTE-2:
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
-- CTE-3:
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
-- CTE-4:
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
	(percentile = 80 OR percentile = 95)
GROUP BY region_id, percentile 
;
```


***

## 🏦 B. Customer Transactions

**1. What is the unique count and total amount for each transaction type?**

```sql
SELECT
  txn_type, 
  COUNT(customer_id) AS transaction_count, 
  SUM(txn_amount) AS total_amount
FROM data_bank.customer_transactions
GROUP BY txn_type;
```

**Answer:**

|txn_type|transaction_count|total_amount|
|:----|:----|:----|
|purchase|1617|806537|
|deposit|2671|1359168|
|withdrawal|1580|793003|

***

**2. What is the average total historical deposit counts and amounts for all customers?**

```sql
WITH deposits AS (
  SELECT 
    customer_id, 
    COUNT(customer_id) AS txn_count, 
    SUM(txn_amount) AS total_amount
  FROM data_bank.customer_transactions
  WHERE txn_type = 'deposit'
  GROUP BY customer_id
)

SELECT 
  ROUND(AVG(txn_count)) AS avg_deposit_count, 
  ROUND(AVG(total_amount)) AS avg_deposit_amt
FROM deposits;
```
**Answer:**

|avg_deposit_count|avg_deposit_amt|
|:----|:----|
|5|2718|

- The average historical deposit count is 5 and the average total historical deposit amount is $ 2718.

***

**3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?**

First, create a CTE called `monthly_transactions` to determine the count of deposit, purchase and withdrawal for each customer categorised by month using `CASE` statement and `SUM()`. 

In the main query, select the `mth` column and count the number of unique customers where:
- `deposit_count` is greater than 1, indicating more than one deposit (`deposit_count > 1`).
- Either `purchase_count` is greater than or equal to 1 (`purchase_count >= 1`) OR `withdrawal_count` is greater than or equal to 1 (`withdrawal_count >= 1`).

```sql
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
```

**Answer:**

|month|customer_count|
|:----|:----|
|jan|168|
|feb|181|
|march|192|
|april|70|

***

**4. What is the closing balance for each customer at the end of the month? Also show the change in balance each month in the same table output.**
for readability i will use a view to generate the closing balance table. a temp table can be used too

```sql
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
```


**Answer:**

Showing results for customers ID 1, 2 and 3 only:
|customer_id|ending_month|total_monthly_change|ending_balance|
|:----|:----|:----|:----|
|1|2020-01-31T00:00:00.000Z|312|312|
|1|2020-02-29T00:00:00.000Z|0|312|
|1|2020-03-31T00:00:00.000Z|-952|-640|
|1|2020-04-30T00:00:00.000Z|0|-640|
|2|2020-01-31T00:00:00.000Z|549|549|
|2|2020-02-29T00:00:00.000Z|0|549|
|2|2020-03-31T00:00:00.000Z|61|610|
|2|2020-04-30T00:00:00.000Z|0|610|
|3|2020-01-31T00:00:00.000Z|144|144|
|3|2020-02-29T00:00:00.000Z|-965|-821|
|3|2020-03-31T00:00:00.000Z|-401|-1222|
|3|2020-04-30T00:00:00.000Z|493|-729|

***

**4. show the change in closing balance each month**

```sql
-- 4.2 show the change in balance each month in the same table output.
SELECT 
customer_id,
month_end,
total_month_change,
closing_balance,
round((((total_month_change + lag(closing_balance) OVER(PARTITION BY customer_id))
	/lag(closing_balance) OVER(PARTITION BY customer_id)) - 1)*100) AS Percent_change
FROM closing_balance
```
Showing results for customers ID 1, 2 and 3 only:
|customer_id|ending_month|total_monthly_change|ending_balance|percent_change|
|:----|:----|:----|:----|:----|
|1|2020-01-31T00:00:00.000Z|312|312|NULL|
|1|2020-02-29T00:00:00.000Z|0|312|0%|
|1|2020-03-31T00:00:00.000Z|-952|-640|-305%|
|1|2020-04-30T00:00:00.000Z|0|-640|0%|
|2|2020-01-31T00:00:00.000Z|549|549|NULL|
|2|2020-02-29T00:00:00.000Z|0|549|0%|
|2|2020-03-31T00:00:00.000Z|61|610|11%|
|2|2020-04-30T00:00:00.000Z|0|610|0%|
|3|2020-01-31T00:00:00.000Z|144|144|NULL|
|3|2020-02-29T00:00:00.000Z|-965|-821|-670%|
|3|2020-03-31T00:00:00.000Z|-401|-1222|49%|
|3|2020-04-30T00:00:00.000Z|493|-729|-0%|

***

__5. What is the percentage of customers who increase their closing balance by more than 5% for atleast 1 month?__

```sql 
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
```
**Answer:**

|percent_customers_with_balance_growth|
|:----|
|0.758|

aproximatly 76% of the customers' balances increased more than 5% for atleast one month

***
## C. Data Allocation
To test out a few different hypotheses, the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:
1. data is allocated based off the amount of money at the end of the previous month
2. data is allocated on the average amount of money kept in the account in the previous 30 days
3. data is updated real-time

```sql

-- create a view for repeatability
CREATE VIEW running_balance AS 
	SELECT 
		customer_id,
		txn_date,
		txn_type,
		txn_amount,
		sum(
			CASE
		 		WHEN txn_type = 'deposit' THEN txn_amount 
				WHEN txn_type = 'purchase' THEN - txn_amount 
				WHEN txn_type = 'withdrawal' THEN - txn_amount 
			END)
	 	OVER
	 		(PARTITION BY customer_id ORDER BY txn_date)
	 	AS running_total_balance
	 	FROM customer_transactions ct
	 	ORDER BY customer_id, txn_date


	-- Option 1: data is allocated based off the amount of money at the end of the previous month
	    -- customer balance at the end of each month
			SELECT * 
			FROM closing_balance cb 
			WHERE total_month_change <> 0;
		
		-- size in bytes and number of rows
			SELECT 
				count(*) number_of_rows, 
				sum(pg_column_size(closing_balance)) tot_size_bytes
			FROM closing_balance cb 
			WHERE total_month_change <> 0;

	-- Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
	
		-- minimum, average and maximum values of the running balance for each customer
		SELECT 
			customer_id, 
			min(running_total_balance), 
			max(running_total_balance), 
			round(avg(running_total_balance)) avarage
		FROM running_balance
		GROUP BY customer_id;
	
		-- size in bytes and number of rows
		SELECT 
		count(*), 
		sum(pg_column_size(min_balance)) min_tot_bytes,
		sum(pg_column_size(max_balance)) max_tot_bytes,
		sum(pg_column_size(avg_balance)) avg_tot_bytes
		FROM 
			(SELECT 
				customer_id, 
				min(running_total_balance) AS min_balance, 
				max(running_total_balance) AS max_balance, 
				round(avg(running_total_balance)) avg_balance
			FROM running_balance
			GROUP BY customer_id) AS t1;
	
    -- Option 3: data is updated real-time
		
		-- running customer balance column that includes the impact each transaction
		SELECT * FROM running_balance rb;
	
		-- size in bytes and number of rows
		SELECT 
			count(*) number_of_rows,
			sum(pg_column_size(running_total_balance)) tot_size_bytes
		FROM running_balance rb;
```

1. data allocated based off the amount of money at the end of the previous month resulted in `1720 rows` and `13753 bytes`
2. data allocated on the average amount of money kept in the account in the previous 30 days resulted in `500 rows` and `4000 bytes` for each of the 3 columns
3. data updated real-time resulted in `5868` and `46944 bytes`
