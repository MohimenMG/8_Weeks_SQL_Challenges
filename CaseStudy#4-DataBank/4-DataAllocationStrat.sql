-- C. Data Allocation Challenge

-- To test out a few different hypotheses - 
-- the Data Bank team wants to run an experiment 
-- where different groups of customers would be
--  allocated data using 3 different options:

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
