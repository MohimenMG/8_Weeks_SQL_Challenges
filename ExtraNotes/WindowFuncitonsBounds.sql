-- window function bounds examples

-- default behaviour sum all rows previous to the current row and the current row
SELECT 
generate_series(0,10) AS row_num, 1 AS values_,
sum(1) over(ORDER BY generate_series(0,10)
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)

-- sum 2 rows previous to the current row with the current row
SELECT 
generate_series(0,10) AS row_num, 1 AS values_,
sum(1) over(ORDER BY generate_series(0,10)
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)


-- three intervals running total (current + previous 2 values)
-- abriviated (no need to define the current row)
SELECT 
generate_series(0,10) AS row_num, 1 AS values_,
sum(1) over(ORDER BY generate_series(0,10) 
ROWS 2 PRECEDING)

-- current + next 2 vlaues
SELECT 
generate_series(0,10) AS row_num, 1 AS values_,
sum(1) over(ORDER BY generate_series(0,10) 
ROWS BETWEEN CURRENT ROW and 2 FOLLOWING)


-- source: https://learnsql.com/blog/sql-window-functions-rows-clause/
