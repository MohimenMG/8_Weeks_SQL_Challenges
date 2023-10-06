-- A. Customer Nodes Exploration
SELECT * FROM customer_nodes LIMIT 100;

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
	(percentile = 80 OR percentile = 95)
GROUP BY region_id, percentile 
;