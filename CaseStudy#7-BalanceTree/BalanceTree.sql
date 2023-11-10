SET search_path = balanced_tree
--The following questions can be considered key business questions 
--and metrics that the Balanced Tree team requires for their monthly reports.
--
--Each question can be answered using a single query 
-- but as you are writing the SQL to solve each individual problem,
-- keep in mind how you would generate all of these metrics in a single SQL script 
-- which the Balanced Tree team can run each month.
--

SELECT * FROM product_details;
SELECT * FROM product_hierarchy ph;
SELECT * FROM product_prices;
SELECT * FROM sales;

--A High Level Sales Analysis
SELECT * FROM sales;

--1 What was the total quantity sold for all products?
--2 What is the total generated revenue for all products before discounts?
--3 What was the total discount amount for all products?
	-- the discount seems to be the total TRANSACTION discount 
	-- since its being repeated for every item in the txn
SELECT 
	sum(total_qty) total_qty,
	sum(total_revenue_no_discount) total_revenue_no_discount, 
	sum(discount) discount
FROM
	(SELECT 
		txn_id,
		sum(qty) total_qty,
		sum(qty*price) total_revenue_no_discount,
		discount
	FROM sales 
	GROUP BY txn_id, discount)
	AS t1

--B Transaction Analysis
SELECT * FROM sales;

--How many unique transactions were there?
SELECT count(*) total_transactions_items, count(DISTINCT(txn_id)) transactions_count FROM sales;
--What is the average unique products purchased in each transaction?
SELECT round(avg(txn_unq_prod_count)) as avg_txn_unq_prod_count
FROM 
(SELECT txn_id, count(*) txn_unq_prod_count
FROM sales
GROUP BY txn_id) AS t1;
--What are the 25th, 50th and 75th percentile values for the revenue per transaction?
SELECT round(percentile) percentile, round(avg(revenue)) revenue
FROM (
	SELECT *, rank() OVER(ORDER BY revenue)/(SELECT count(DISTINCT (txn_id)) FROM sales)::float * 100 AS percentile
	FROM 
		(SELECT 
			txn_id,
			sum(qty * price) - discount AS revenue
		FROM sales
		GROUP BY txn_id, discount) 
	AS t1) 
AS t2
WHERE round(percentile) IN(25,50,75)
GROUP BY round(percentile);
--What is the average discount value per transaction?
SELECT round(avg(total_txn_discount)) avg_txn_discount
FROM 
	(SELECT 
		txn_id , 
		discount total_txn_discount 
	FROM sales 
	GROUP BY txn_id, discount)
	AS t1;
--What is the percentage split of all transactions for members vs non-members?
--What is the average revenue for member transactions and non-member transactions?
WITH revenue_members AS (
	SELECT 
		txn_id,
		"member",
		sum(qty*price) total_revenue_no_discount,
		discount
	FROM sales 
	GROUP BY txn_id, discount, "member"),
revenue AS (
	SELECT  sum(total_revenue_no_discount) - sum(discount) AS revenue 
	FROM revenue_members
)
SELECT 
	"member",
	(sum(total_revenue_no_discount) - sum(discount)) / (SELECT * FROM revenue)*100 total_revenue_pct,
	avg(total_revenue_no_discount- discount) avg_member_revenue
FROM revenue_members
GROUP BY "member"



--Product Analysis
--What are the top 3 products by total revenue before discount?
SELECT pd.product_name, sum(s.qty) * sum(s.price) Product_revenue 
FROM sales s
JOIN product_details pd
ON pd.product_id = s.prod_id
GROUP BY prod_id, pd.product_name
ORDER BY 2 DESC
LIMIT 3;

--What is the total quantity, revenue and discount for each segment?
SELECT pd.segment_name segment_name, sum(s.qty) segment_qty, sum(s.qty)*sum(s.price) segment_revenue 
FROM sales s
JOIN product_details pd 
ON pd.product_id = s.prod_id
GROUP BY pd.segment_name

--What is the top selling product for each segment?
SELECT segment_name, product_name, total_quantity
FROM (
	SELECT segment_name, product_name ,rank() OVER(PARTITION BY segment_name ORDER BY total_quantity desc) AS Rank_, total_quantity
	FROM (
		SELECT pd.segment_name, pd.product_name, sum(s.qty) total_quantity
		FROM sales s
		JOIN product_details pd 
		ON pd.product_id = s.prod_id
		GROUP BY pd.segment_name, pd.product_name
		ORDER BY 1, 3 DESC
		) t1 
) t2
WHERE Rank_ = 1

--What is the total quantity, revenue and discount for each category?!!!!!!

		SELECT pd.category_name, sum(qty) total_catigory_qty, sum(qty * s.price) total_qty_revenue_no_discount
		FROM sales s
		JOIN product_details pd 
		ON pd.product_id = s.prod_id
		GROUP BY 1
		ORDER BY 1

SELECT txn_id, discount
FROM sales s 
GROUP BY 1,2

--What is the top selling product for each category?
SELECT category_name, product_name, total_quantity
FROM (
	SELECT category_name, product_name ,rank() OVER(PARTITION BY category_name ORDER BY total_quantity desc) AS Rank_, total_quantity
	FROM (
		SELECT pd.category_name, pd.product_name, sum(s.qty) total_quantity
		FROM sales s
		JOIN product_details pd 
		ON pd.product_id = s.prod_id
		GROUP BY pd.category_name, pd.product_name
		ORDER BY 1, 3 DESC
		) t1 
) t2
WHERE Rank_ = 1

--What is the percentage split of revenue by product for each segment?

	SELECT segment_name, product_name, revenue_no_discount ,revenue_no_discount /(SELECT sum(price * qty) FROM sales)::float *100 revenue_pct
	FROM (
		SELECT pd.segment_name, pd.product_name, sum(s.qty * s.price) AS revenue_no_discount
		FROM sales s
		JOIN product_details pd 
		ON pd.product_id = s.prod_id
		GROUP BY pd.segment_name, pd.product_name
		ORDER BY 1, 3 DESC
		) t1 


--What is the percentage split of revenue by segment for each category?
	SELECT category_name, segment_name, revenue_no_discount ,revenue_no_discount /(SELECT sum(price * qty) FROM sales)::float *100 revenue_pct
	FROM (
		SELECT pd.category_name, pd.segment_name,  sum(s.qty * s.price) AS revenue_no_discount
		FROM sales s
		JOIN product_details pd 
		ON pd.product_id = s.prod_id
		GROUP BY pd.category_name, pd.segment_name 
		ORDER BY 1, 3 DESC
		) t1 
		
--What is the percentage split of total revenue by category?
	SELECT pd.category_name,  sum(s.qty * s.price)/(SELECT sum(price * qty) FROM sales)::float * 100 AS revenue_no_discount
	FROM sales s
	JOIN product_details pd 
	ON pd.product_id = s.prod_id
	GROUP BY pd.category_name 
		
--What is the total transaction “penetration” for each product? 
	-- hint: penetration = 
	-- number of transactions where at least 1 quantity of a product was purchased 
	-- divided by total number of transactions
WITH transaction_count AS (
	SELECT count(DISTINCT txn_id)
	FROM sales
),
product_transaction AS (
	SELECT product_id, count(*) product_transaction_count
	FROM sales s
	JOIN product_details pd 
	ON pd.product_id = s.prod_id
	GROUP BY product_id
)
SELECT 
	product_name, 
	product_transaction_count,
	product_transaction_count/(SELECT * FROM transaction_count)::float  product_penertration
FROM product_transaction
ORDER BY 2

--What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
	SELECT 	product_combi, count(*)
	FROM (
		SELECT txn_id, string_agg(product_name, ', ') product_combi
		FROM (	
			SELECT *, count(*) OVER(PARTITION BY txn_id) products_count
			FROM sales s
			JOIN product_details pd 
			ON pd.product_id = s.prod_id 
			ORDER BY txn_id, product_name ASC
			) t1 
		WHERE products_count >= 3
		GROUP BY txn_id
		) t2
		GROUP BY product_combi
		ORDER BY 2 DESC
		LIMIT 1;
	
--Reporting Challenge
--Write a single SQL script that combines all of the previous questions into a scheduled report that the Balanced Tree team can run at the beginning of each month to calculate the previous month’s values.
--
--Imagine that the Chief Financial Officer (which is also Danny) has asked for all of these questions at the end of every month.
--
--He first wants you to generate the data for January only - but then he also wants you to demonstrate that you can easily run the samne analysis for February without many changes (if at all).
--
--Feel free to split up your final outputs into as many tables as you need - but be sure to explicitly reference which table outputs relate to which question for full marks :)
--
--Bonus Challenge
--Use a single SQL query to transform the product_hierarchy and product_prices datasets to the product_details table.
--
--Hint: you may want to consider using a recursive CTE to solve this problem!
--
	
SELECT * FROM product_details ;
SELECT * FROM product_hierarchy ph;
SELECT * FROM product_prices pp;


	SELECT 
		pp.product_id, pp.price,
		(ph3.level_text || ' ' ||  ph2.level_text || ' - ' || ph.level_text) AS product_name,  
		ph.id AS category_id, ph2.id AS segment_id, ph3.id AS style_id,
		ph.level_text AS category_name, ph2.level_text AS segment_name, ph3.level_text AS style_name 
	FROM product_hierarchy ph 
	JOIN product_hierarchy ph2 
	ON ph.id = ph2.parent_id
	JOIN product_hierarchy ph3 
	ON ph2.id = ph3.parent_id
	JOIN product_prices pp 
	ON pp.id = ph3.id



--Conclusion
--Sales, transactions and product exposure is always going to be a main objective for many data analysts and data scientists when working within a company that sells some type of product - Spoiler alert: nearly all companies will sell products!
--
--Being able to navigate your way around a product hierarchy and understand the different levels of the structures as well as being able to join these details to sales related datasets will be super valuable for anyone wanting to work within a financial, customer or exploratory analytics capacity.
--
--Hopefully these questions helped provide some exposure to the type of analysis we perform daily in these sorts of roles!