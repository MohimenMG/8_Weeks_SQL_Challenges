sum(CASE 
	WHEN platform = 'Shopify' THEN transactions
	ELSE NULL
END) AS shopify_transactions,
---
sum(transactions) total_number_of_transactions,
---
sum(CASE 
	WHEN platform = 'Retail' THEN transactions
	ELSE NULL
END)/ sum(transactions)::float *100 AS Percent_shopify_transactions,
---
sum(CASE 
	WHEN platform = 'Shopify' THEN transactions
	ELSE NULL
END) / sum(transactions)::float *100 percent_retail_transactions
SELECT * FROM weekly_sales ws;

--A. Data Cleansing Steps

--In a single query, perform the following operations:
	-- 1. generate a new table in the data_mart schema named clean_weekly_sales:
DROP TABLE clean_weekly_sales;
CREATE TABLE clean_weekly_sales AS
	--2. Convert the week_date to a DATE format
WITH cleaned_weekly_sales AS (
SELECT week_date, to_date(week_date, 'dd/mm/yy') AS week_date_, *
FROM weekly_sales ws)
	--3. Add a week_number as the second column for each week_date value, example: any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc
	--4. Add a month_number with the calendar month for each week_date value as the 3rd column
	--5. Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values
	--6. Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value
		--segment	age_band
		--1	Young Adults
		--2	Middle Aged
		--3 or 4	Retirees
	--7. Add a new demographic column using the following mapping for the first letter in the segment values:
		--segment	demographic
		--C	Couples
		--F	Families
		--Ensure all null string values with an "unknown" string value in the original segment column as well as the new age_band and demographic columns
	--
	--8. Generate a new avg_transaction column as the sales value divided by transactions rounded to 2 decimal places for each record
SELECT week_date_, 
CASE 
	WHEN date_part('day',week_date_) BETWEEN 1 AND 7 THEN 1
	WHEN date_part('day',week_date_) BETWEEN 8 AND 14 THEN 2
	WHEN date_part('day',week_date_) BETWEEN 15 AND 21 THEN 3
	WHEN date_part('day',week_date_) BETWEEN 22 AND 28 THEN 4
	WHEN date_part('day',week_date_) BETWEEN 29 AND 31 THEN 5
END AS week_number,
date_part('month',week_date_) month_number,
date_part('year',week_date_) calendar_year,
CASE 
	WHEN segment = 'null' THEN 'unknown'
	WHEN right(segment,1)::int = 1 THEN 'Young Adults' 
	WHEN right(segment,1)::int = 2 THEN 'Middle Aged'
	WHEN right(segment,1)::int BETWEEN 3 AND 4 THEN 'Retirees'
END AS age_band,
CASE 
	WHEN segment = 'null' THEN 'unknown'
	WHEN left(segment,1) = 'C' THEN 'Couples'
	WHEN left(segment,1) = 'F' THEN 'Family'
END AS demographic,
 round( (sales::float/transactions):: decimal , 2)  AS avg_transaction, region, platform, customer_type, transactions , sales
FROM cleaned_weekly_sales


--B. Data Exploration
SELECT * FROM clean_weekly_sales cws;

	--1. What day of the week is used for each week_date value? !!!!!!!!!!!
SELECT 
date_part('dow', week_date_)AS day_of_week
FROM clean_weekly_sales cws
GROUP BY 1;
	--2. What range of week numbers are missing from the dataset? !!!!!!!!!!!
SELECT calendar_year, month_number, cws.week_number
FROM clean_weekly_sales cws  
GROUP BY calendar_year, month_number, cws.week_number
ORDER BY 1, 2, 3;

	--3. How many total transactions were there for each year in the dataset?
SELECT calendar_year , sum(transactions) total_number_of_transactions
FROM clean_weekly_sales cws 
GROUP BY 1;

	--4. What is the total sales for each region for each month?
SELECT region , month_number , sum(sales) total_sales
FROM clean_weekly_sales cws 
GROUP BY 1, 2
ORDER BY 2, 3 DESC, 1 ;

	--5. What is the total count of transactions for each platform
SELECT platform, sum(transactions) total_number_of_transactions
FROM clean_weekly_sales cws 
GROUP BY 1
ORDER BY 2 desc;
	
	--6. What is the percentage of sales for Retail vs Shopify for each month?	--What is the percentage of sales by demographic for each year in the dataset?

SELECT  
sum(CASE 
	WHEN platform = 'Retail' THEN transactions
	ELSE NULL
END) AS retail_transactions,
---
FROM clean_weekly_sales cws;

	--7. Which age_band and demographic values contribute the most to Retail sales?
SELECT age_band, sum(sales) group_sales
FROM clean_weekly_sales cws
GROUP BY 1
ORDER BY 2 desc;

SELECT demographic, sum(sales) group_sales
FROM clean_weekly_sales cws
GROUP BY 1
ORDER BY 2 desc;

SELECT age_band, demographic, sum(sales) group_sales
FROM clean_weekly_sales cws
GROUP BY 1,2
ORDER BY 3 desc;
	
	--8. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? 
		 -- If not - how would you calculate it instead?
SELECT avg_transaction 
FROM clean_weekly_sales cws 


SELECT 
calendar_year, 
platform,
round(sum(sales)/ sum(transactions)::numeric, 2)  AS avg_transaction, 
round (avg(avg_transaction),2) AS avg_of_avg_transaction -- avg of avg transactions results in a different result
FROM clean_weekly_sales cws 
GROUP BY 1,2
ORDER BY 1,2;
-- we can't use the avg transactions since we would be getting the avg of the avg transaction not the average transaction size for each year
-- to calculate the avg yearly transactions we have to divide the total year sales by the total number of transactions this year

--C. Before & After Analysis
--This technique is usually used when we inspect an important event and want to inspect the impact before and after a certain point in time.
--Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.
--We would include all week_date values for 2020-06-15 as the start of the period after the change and the previous week_date values would be before
--Using this analysis approach - answer the following questions:

--1. What is the total sales for the 4 weeks before and after 2020-06-15?
SELECT 
CASE 
	WHEN week_date_ < '2020-06-15' THEN 'before change'
	WHEN week_date_ >= '2020-06-15' THEN 'after change'
END AS before_changes,
sum(sales) AS total_sales
FROM clean_weekly_sales cws 
WHERE week_date_ BETWEEN '2020-06-15'::date - INTERVAL '4 weeks' AND '2020-06-15'::date + INTERVAL '4 weeks'
GROUP BY 1
ORDER BY 2 DESC; -- sales increased after changes 


--2. What is the growth or reduction rate in actual values and percentage of sales?
WITH sales_change AS (
	SELECT 
		CASE 
			WHEN week_date_ < '2020-06-15' THEN 'before change'
			WHEN week_date_ >= '2020-06-15' THEN 'after change'
		END AS changes,
		sum(sales) AS total_sales
	FROM clean_weekly_sales cws 
	WHERE week_date_ BETWEEN '2020-06-15'::date - INTERVAL '4 weeks' AND '2020-06-15'::date + INTERVAL '4 weeks'
	GROUP BY 1
	ORDER BY 1 DESC
)
SELECT 
	changes, 
	round(((total_sales -  LAG(total_sales) over()) / LAG(total_sales) over()::decimal), 4) * 100 AS percent_change
FROM sales_change;

--3. What about the entire 12 weeks before and after?
WITH sales_change AS (
	SELECT 
		CASE 
			WHEN week_date_ < '2020-06-15' THEN 'before change'
			WHEN week_date_ >= '2020-06-15' THEN 'after change'
		END AS changes,
		sum(sales) AS total_sales
	FROM clean_weekly_sales cws 
	WHERE week_date_ BETWEEN '2020-06-15'::date - INTERVAL '12 weeks' AND '2020-06-15'::date + INTERVAL '12 weeks'
	GROUP BY 1
	ORDER BY 1 DESC
)
SELECT 
	changes, 
	round(((total_sales -  LAG(total_sales) over()) / LAG(total_sales) over()::decimal), 5) * 100 AS percent_change
FROM sales_change;


--4. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
-- 4 week period
WITH sales_change AS (
	SELECT
	-- calendar_year, 
	CASE 
		WHEN week_date_ >= '2020-06-15'::date - INTERVAL '4 weeks' AND week_date_ < '2020-06-15'::date THEN 'before change'
		WHEN week_date_ >= '2020-06-15'::date AND week_date_ <= '2020-06-15'::date + INTERVAL '4 weeks' THEN 'after change'
		WHEN week_date_ >= '2019-06-15'::date - INTERVAL '4 weeks' AND week_date_ < '2019-06-15'::date THEN 'before change'
		WHEN week_date_ >= '2019-06-15'::date AND week_date_ <= '2019-06-15'::date + INTERVAL '4 weeks' THEN 'after change'
		WHEN week_date_ >= '2018-06-15'::date - INTERVAL '4 weeks' AND week_date_ < '2018-06-15'::date THEN 'before change'
		WHEN week_date_ >= '2018-06-15'::date AND week_date_ <= '2018-06-15'::date + INTERVAL '4 weeks' THEN 'after change'
		ELSE 'other period'
	END AS changes,
	sum(CASE 
			WHEN week_date_ >= '2020-06-15'::date - INTERVAL '4 weeks' AND week_date_ < '2020-06-15'::date THEN sales
			WHEN week_date_ >= '2020-06-15'::date AND week_date_ <= '2020-06-15'::date + INTERVAL '4 weeks' THEN sales
			ELSE NULL
		END) AS sales_2020,
	sum(CASE 
			WHEN week_date_ >= '2019-06-15'::date - INTERVAL '4 weeks' AND week_date_ < '2019-06-15'::date THEN sales
			WHEN week_date_ >= '2019-06-15'::date AND week_date_ <= '2019-06-15'::date + INTERVAL '4 weeks' THEN sales
			ELSE NULL
		END) AS sales_2019,
	sum(CASE 
		WHEN week_date_ >= '2018-06-15'::date - INTERVAL '4 weeks' AND week_date_ < '2018-06-15'::date THEN sales
		WHEN week_date_ >= '2018-06-15'::date AND week_date_ <= '2018-06-15'::date + INTERVAL '4 weeks' THEN sales
		ELSE NULL 
	END) AS sales_2018
	FROM clean_weekly_sales cws
	GROUP BY 1
	ORDER BY 1 DESC)
SELECT 
	changes, 
	sales_2020,
	round(((sales_2020 -  LAG(sales_2020) over()) / LAG(sales_2020) over()::decimal), 5) * 100 AS percent_change_2020,
	sales_2019,
	round(((sales_2019 -  LAG(sales_2019) over()) / LAG(sales_2019) over()::decimal), 5) * 100 AS percent_change_2019,
	sales_2018,
	round(((sales_2018 -  LAG(sales_2018) over()) / LAG(sales_2018) over()::decimal), 5) * 100 AS percent_change_2018
FROM sales_change
WHERE changes <> 'other period';

-- 4 week period
WITH sales_change AS (
	SELECT
	-- calendar_year, 
	CASE 
		WHEN week_date_ >= '2020-06-15'::date - INTERVAL '12 weeks' AND week_date_ < '2020-06-15'::date THEN 'before change'
		WHEN week_date_ >= '2020-06-15'::date AND week_date_ <= '2020-06-15'::date + INTERVAL '12 weeks' THEN 'after change'
		WHEN week_date_ >= '2019-06-15'::date - INTERVAL '12 weeks' AND week_date_ < '2019-06-15'::date THEN 'before change'
		WHEN week_date_ >= '2019-06-15'::date AND week_date_ <= '2019-06-15'::date + INTERVAL '12 weeks' THEN 'after change'
		WHEN week_date_ >= '2018-06-15'::date - INTERVAL '12 weeks' AND week_date_ < '2018-06-15'::date THEN 'before change'
		WHEN week_date_ >= '2018-06-15'::date AND week_date_ <= '2018-06-15'::date + INTERVAL '12 weeks' THEN 'after change'
		ELSE 'other period'
	END AS changes,
	sum(CASE 
			WHEN week_date_ >= '2020-06-15'::date - INTERVAL '12 weeks' AND week_date_ < '2020-06-15'::date THEN sales
			WHEN week_date_ >= '2020-06-15'::date AND week_date_ <= '2020-06-15'::date + INTERVAL '12 weeks' THEN sales
			ELSE NULL
		END) AS sales_2020,
	sum(CASE 
			WHEN week_date_ >= '2019-06-15'::date - INTERVAL '12 weeks' AND week_date_ < '2019-06-15'::date THEN sales
			WHEN week_date_ >= '2019-06-15'::date AND week_date_ <= '2019-06-15'::date + INTERVAL '12 weeks' THEN sales
			ELSE NULL
		END) AS sales_2019,
	sum(CASE 
		WHEN week_date_ >= '2018-06-15'::date - INTERVAL '12 weeks' AND week_date_ < '2018-06-15'::date THEN sales
		WHEN week_date_ >= '2018-06-15'::date AND week_date_ <= '2018-06-15'::date + INTERVAL '12 weeks' THEN sales
		ELSE NULL 
	END) AS sales_2018
	FROM clean_weekly_sales cws
	GROUP BY 1
	ORDER BY 1 DESC)
SELECT 
	changes, 
	sales_2020,
	round(((sales_2020 -  LAG(sales_2020) over()) / LAG(sales_2020) over()::decimal), 5) * 100 AS percent_change_2020,
	sales_2019,
	round(((sales_2019 -  LAG(sales_2019) over()) / LAG(sales_2019) over()::decimal), 5) * 100 AS percent_change_2019,
	sales_2018,
	round(((sales_2018 -  LAG(sales_2018) over()) / LAG(sales_2018) over()::decimal), 5) * 100 AS percent_change_2018
FROM sales_change
WHERE changes <> 'other period';


--D. Bonus Question
--Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?
--
--region
--platform
--age_band
--demographic
--customer_type
--Do you have any further recommendations for Danny’s team at Data Mart or any interesting insights based off this analysis?
--1. region
WITH sales_change AS (
	SELECT 
		region AS union_col,
		sum(CASE 
			WHEN week_date_ < '2020-06-15' THEN sales
			ELSE 0
		END) AS before_changes,
		sum(CASE 
			WHEN week_date_ >= '2020-06-15' THEN sales
			ELSE 0
		END) AS after_changes
	FROM clean_weekly_sales cws 
	WHERE week_date_ BETWEEN '2020-06-15'::date - INTERVAL '12 weeks' AND '2020-06-15'::date + INTERVAL '12 weeks'
	GROUP BY 1
	ORDER BY 1 DESC, 2)
	SELECT  *, round((after_changes - before_changes)/before_changes::decimal *100,2) percent_change
	FROM sales_change
	-- 2. platform
	UNION ALL 
	SELECT  *, round((after_changes - before_changes)/before_changes::decimal *100,2) percent_change
	FROM
	(SELECT 
		platform AS union_col,
		sum(CASE 
			WHEN week_date_ < '2020-06-15' THEN sales
			ELSE 0
		END) AS before_changes,
		sum(CASE 
			WHEN week_date_ >= '2020-06-15' THEN sales
			ELSE 0
		END) AS after_changes
	FROM clean_weekly_sales cws 
	WHERE week_date_ BETWEEN '2020-06-15'::date - INTERVAL '12 weeks' AND '2020-06-15'::date + INTERVAL '12 weeks'
	GROUP BY 1
	ORDER BY 1 DESC, 2) AS sales_change
	-- 3. age_band
	UNION ALL
	SELECT  *, round((after_changes - before_changes)/before_changes::decimal *100,2) percent_change
	from
	(
	SELECT 
		age_band,
		sum(CASE 
			WHEN week_date_ < '2020-06-15' THEN sales
			ELSE 0
		END) AS before_changes,
		sum(CASE 
			WHEN week_date_ >= '2020-06-15' THEN sales
			ELSE 0
		END) AS after_changes
	FROM clean_weekly_sales cws 
	WHERE week_date_ BETWEEN '2020-06-15'::date - INTERVAL '12 weeks' AND '2020-06-15'::date + INTERVAL '12 weeks'
	GROUP BY 1
	ORDER BY 1 DESC, 2) AS sales_change 
	-- 4. demographic 
	UNION ALL
	SELECT  *, round((after_changes - before_changes)/before_changes::decimal *100,2) percent_change
	from
	(
	SELECT 
		demographic,
		sum(CASE 
			WHEN week_date_ < '2020-06-15' THEN sales
			ELSE 0
		END) AS before_changes,
		sum(CASE 
			WHEN week_date_ >= '2020-06-15' THEN sales
			ELSE 0
		END) AS after_changes
	FROM clean_weekly_sales cws 
	WHERE week_date_ BETWEEN '2020-06-15'::date - INTERVAL '12 weeks' AND '2020-06-15'::date + INTERVAL '12 weeks'
	GROUP BY 1
	ORDER BY 1 DESC, 2) AS sales_change
	-- 5. customer_type 
	UNION ALL
	SELECT  *, round((after_changes - before_changes)/before_changes::decimal *100,2) percent_change
	from
	(
	SELECT 
		customer_type,
		sum(CASE 
			WHEN week_date_ < '2020-06-15' THEN sales
			ELSE 0
		END) AS before_changes,
		sum(CASE 
			WHEN week_date_ >= '2020-06-15' THEN sales
			ELSE 0
		END) AS after_changes
	FROM clean_weekly_sales cws 
	WHERE week_date_ BETWEEN '2020-06-15'::date - INTERVAL '12 weeks' AND '2020-06-15'::date + INTERVAL '12 weeks'
	GROUP BY 1
	ORDER BY 1 DESC, 2) AS sales_change
	ORDER BY 4
	-- the largest loss after the changes implemeted in 2020 was in the region of Asia at 3.26 percent decrease in sales

	

--E. Conclusion
--This case study actually is based off a real life change in Australia retailers 
--where plastic bags were no longer provided for free - 
--as you can expect, some customers would have changed their shopping behaviour because of this change!
--
--Analysis which is related to certain key events which can have a significant 
--impact on sales or engagement metrics is always a part of the data analytics menu. 
--Learning how to approach these types of problems is a super valuable lesson and hopefully these ideas
--can help you next time you’re faced with a tough problem like this in the workplace!