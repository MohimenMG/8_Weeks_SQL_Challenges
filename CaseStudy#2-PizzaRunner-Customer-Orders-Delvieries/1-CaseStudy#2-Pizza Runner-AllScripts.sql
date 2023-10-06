--==========================================================
show search_path;
set search_path to pizza_runner; 
show search_path;


select order_id, order_item_id, customer_id, pizza_id, order_time from t_customer_orders; -- derived table (data-cleaning.sql)
select *  from t_order_changes; -- derived table (data-cleaning.sql)

select * from t_runner_orders; -- derived table (data-cleaning.sql)
select * from runners;

select * from pizza_names;
select * from pizza_toppings;
select * from t_pizza_recipes;  -- derived table (data-cleaning.sql)


-- A. Pizza Metrics

-- 1. How many pizzas were ordered?
select count(*) from pizza_runner.customer_orders;
 
-- 2. How many unique customer orders were made?
select count(*) from (
select order_id from pizza_runner.customer_orders group by 1 order by 1) as t1;

-- 3. How many successful orders were delivered by each runner?
select runner_id , count(*)
from (select *
from t_runner_orders ro
where cancellation is null or cancellation not like '%Cancellation') as t1
group by 1;

-- 4. How many of each type of pizza was delivered?
select pn.pizza_name, count(*) as delivered_pizza
from customer_orders co
join t_runner_orders ro 
	on ro.order_id = co.order_id
join pizza_names pn 
	on pn.pizza_id = co.pizza_id
where ro.distance <> 0
group by 1;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
select customer_id, pizza_name , count(*)
from customer_orders co 
join pizza_names pn on co.pizza_id = pn.pizza_id 
group by 1,2
order by 1;

-- 6. What was the maximum number of pizzas delivered in a single order?
select 
order_id,
count(*) pizza_count,
dense_rank() over(order by count(order_id) desc) order_count_rank
from customer_orders co
group by order_id
limit 1;


-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select customer_id,change_flag ,count(*) as count_
from 
(select 
customer_id, 
case 
	when exclusions is not null or extras is not null then 'made changes'
	else 'no changes' 
end as change_flag,
exclusions, extras
from t_customer_orders tco
join t_runner_orders tro on tro.order_id = tco.order_id
where tro.distance  <> 0) as t1
group by 1,2
order by 1,2;

-- 8. How many pizzas were delivered that had both exclusions and extras?
select
case 
	when exclusions is not null and extras is not null then 'exclusions and extras'
	else 'niether or one' 
end as both_flag, count(*)
from t_customer_orders cu
join t_runner_orders ro on ro.order_id = cu.order_id
where ro.distance <> 0
group by 1
limit 1
;

-- 9. What was the total volume of pizzas ordered for each hour of the day?
select date_part('hour',order_time) as hour_of_day ,count(*) count_pizza_by_hour
from t_customer_orders
group by 1
order by 1 desc;

--10. What was the volume of orders for each day of the week?
select  to_char(order_time, 'day') as day_of_week, count(distinct order_id) count_pizza_by_day
from t_customer_orders
group by 1
order by 2 desc;

------------------------------------------------------------------------------------------
--B. Runner and Customer Experience

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select 
case 
	when date_part('WEEK', registration_date) = 53 then 1 
	else date_part('WEEK', registration_date)+1
end as week_of_year, count(*) as number_of_runners_registered_this_week
from runners
group by 1
order by 1;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
select runner_id, round (extract(minute from avarage_pickup_time) + extract(second from avarage_pickup_time)/60) as pickup_time_in_mins
from 
(select tro.runner_id, avg( (tro.pickup_time - tco.order_time) ) avarage_pickup_time
from t_runner_orders tro
join t_customer_orders tco
on tro.order_id = tco.order_id
where tro.distance <> 0
group by 1
) as t1
order by 2

;
-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
select  
number_of_pizzas, 
avg( round( extract(minute from avarage_cooking_and_pickup_time)
	 + extract(second from avarage_cooking_and_pickup_time)/60) ) as avarage_cooking_time
from 
(select tro.order_id as order_id,count(*) as number_of_pizzas, avg( (tro.pickup_time - tco.order_time) ) avarage_cooking_and_pickup_time
from t_runner_orders tro
join t_customer_orders tco
on tro.order_id = tco.order_id
where tro.distance <> 0
group by 1
) as t1
group by 1
order by 1
;


-- 4. What was the average distance travelled for each customer?
select customer_id, avg(distance)
from t_runner_orders ro
join t_customer_orders co on ro.order_id = co.order_id  
group by 1
order by 1
;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
select max(duration) - min(duration) delivary_time_difference_mins
from t_runner_orders ro
;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
select order_id, runner_id, avg(distance/(duration/60)) avg_speed_in_km_per_hour
from t_runner_orders
where distance <> 0
group by 1,2
order by 2,3;

-- 7. What is the successful delivery percentage for each runner?

select runner_id , (cast(successful_runs as float)/count_runs)*100 as percentage_successful
from
(select runner_id, cancellation, count_runs, count(*) as successful_runs
from(
select runner_id, cancellation, count(*) over(partition by runner_id) as count_runs
from t_runner_orders) as t1
group by 1,2,3
having cancellation is null
order by 1,2 desc) as t2
;

---------------------------------------------------------------------------------
--C. Ingredient Optimisation

-- 1. What are the standard (common) ingredients for each pizza?
select pr.topping_id , pt.topping_name
from t_pizza_recipes pr
join t_pizza_recipes pr1 on pr.topping_id = pr1.topping_id and pr1.pizza_id = 1
join pizza_toppings pt on pt.topping_id = pr.topping_id
where pr.pizza_id = 2
;

-- 2. What was the most commonly added extra?
select pt.topping_name, count(*)
from t_order_changes oc
join pizza_toppings pt on pt.topping_id  = cast(oc.topping_id as int)
group by change_type, pt.topping_name
having change_type = 'Extra'
order by 2 desc
limit 1
;

select * from pizza_toppings pt;
select * from t_order_changes toc join pizza_toppings pt on pt.topping_id= toc.topping_id ;

-- 3. What was the most common exclusion?
select pt.topping_name, count(*)
from t_order_changes oc
join pizza_toppings pt on pt.topping_id  = oc.topping_id 
group by change_type, pt.topping_name
having change_type = 'Execlude'
order by 2 desc
limit 1
;

-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--	Meat Lovers
--	Meat Lovers - Exclude Beef
--	Meat Lovers - Extra Bacon
--	Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

select order_id, order_item_id,
case 
	when changes is null then pizza_name
	else pizza_name || ' - ' || changes
end as order_string
from 
(select order_id, order_item_id, pizza_name, string_agg(change_type || ': ' || changes , ' - ') as changes
from (
select order_id, order_item_id, pizza_name, change_type, STRING_AGG(topping_name, ', ') as changes
from(
select 
	o.order_id as order_id,
	o.order_item_id as order_item_id,
	pn.pizza_name as pizza_name,
	oc.change_type as change_type,
	pt.topping_name as topping_name
from t_order_items o
join pizza_names pn 
	on pn.pizza_id = o.pizza_id
left join t_order_changes oc 
	on oc.order_id = o.order_id and oc.order_item_id = o.order_item_id
left join pizza_toppings pt 
	on cast(pt.topping_id as int) = cast(oc.topping_id as int)
order by 1,2) as t1
group by 1,2,3,4) as t2
group by 1,2,3) as t3
;

-- 5. Generate an alphabetically ordered comma separated ingredient list
--for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
	--For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"


select order_id, order_item_id,pizza_name, string_agg(
	case 
		when change_type = 'Extra' and recipe_topping_id is not null then '2x' || topping_name
		when change_type = 'Extra' and recipe_topping_id is null then topping_name
		when change_type = 'Execlude' then null
		when recipe_topping_id is null then null
		else topping_name
	end, ', ') as ingredients
from
(
	select 
		tco.order_id as order_id,
		tco.order_item_id as order_item_id,
		tco.pizza_id as pizza_id,
		t1.pizza_name as pizza_name,
		t1.topping_name as topping_name,
		t1.topping_id as topping_id,
		t1.recipe_topping_id as recipe_topping_id,
		toc.topping_id as change_toppning_id,
		toc.change_type as change_type
	from 
		t_customer_orders tco
	join 
		(
		select 
			distinct tpr.pizza_id as pizza_id,
			pn.pizza_name as pizza_name,
			pt.topping_id as topping_id,
			pt.topping_name as topping_name,
			tpr2.topping_id as recipe_topping_id
		from 
			t_pizza_recipes tpr
		cross join pizza_toppings pt
		left join 
			t_pizza_recipes tpr2 
		on
			tpr.pizza_id = tpr2.pizza_id
			and pt.topping_id = tpr2.topping_id
		join pizza_names pn 
		on pn.pizza_id = tpr.pizza_id 
		order by
			pizza_id,
			topping_id
		) as t1 
		on
		tco.pizza_id = t1.pizza_id
	left join 
		t_order_changes toc 
		on
		toc.order_id = tco.order_id
		and toc.order_item_id = tco.order_item_id
		and toc.topping_id = t1.topping_id
	order by
		order_id,
		order_item_id,
		topping_name
	) as t2
group by 1,2,3;


-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
select topping_name,
	sum(case 
		when change_type = 'Extra' and recipe_topping_id is not null then 2
		when change_type = 'Extra' and recipe_topping_id is null then 1
		when change_type = 'Execlude' then 0
		when recipe_topping_id is null then 0
		else 1
	end) as ingredient_count
from
(
	select 
		tco.order_id as order_id,
		tco.order_item_id as order_item_id,
		tco.pizza_id as pizza_id,
		t1.pizza_name as pizza_name,
		t1.topping_name as topping_name,
		t1.topping_id as topping_id,
		t1.recipe_topping_id as recipe_topping_id,
		toc.topping_id as change_toppning_id,
		toc.change_type as change_type,
		tro.cancellation
	from 
		t_customer_orders tco
	join 
		(
		select 
			distinct tpr.pizza_id as pizza_id,
			pn.pizza_name as pizza_name,
			pt.topping_id as topping_id,
			pt.topping_name as topping_name,
			tpr2.topping_id as recipe_topping_id
		from 
			t_pizza_recipes tpr
		cross join pizza_toppings pt
		left join 
			t_pizza_recipes tpr2 
		on
			tpr.pizza_id = tpr2.pizza_id
			and pt.topping_id = tpr2.topping_id
		join pizza_names pn 
		on pn.pizza_id = tpr.pizza_id 
		order by
			pizza_id,
			topping_id
		) as t1 
		on
		tco.pizza_id = t1.pizza_id
	left join 
		t_order_changes toc 
		on
		toc.order_id = tco.order_id
		and toc.order_item_id = tco.order_item_id
		and toc.topping_id = t1.topping_id
	left join t_runner_orders tro on tro.order_id = toc.order_id
	order by
		order_id,
		order_item_id,
		topping_name
	) as t2
where t2.cancellation is null
group by 1
order by 2 desc
;
------------------------------------------------------------
-- D. Pricing and Ratings

-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 
--and there were no charges for changes 
--how much money has Pizza Runner made so far if there are no delivery fees?
select sum(price)
from 
(select order_id, order_item_id, pn.pizza_name, pn.pizza_id,
case
	when pn.pizza_id = 1 then 12
	when pn.pizza_id = 2 then 10
	else null
end as price
from t_customer_orders tco 
join pizza_names pn 
on pn.pizza_id = tco.pizza_id) as t1;

-- 2. What if there was an additional $1 charge for any pizza extras?
--any extra cost an additional $1 while extra cheese costs $2

select 
	sum(price_extra)
from
(select
	tco.order_id,
	tco.order_item_id,
	pn.pizza_name,
		sum(case 
			when toc.change_type = 'Extra' and pt.topping_name  = 'Cheese' then 2
			when toc.change_type = 'Extra' then 1
			else 0 end)  +
	avg(pn.price) as price_extra
	-- change_type,
	-- toc.topping_id,
	-- pt.topping_name,
from t_customer_orders tco 
join pizza_names pn 
on pn.pizza_id = tco.pizza_id
left join t_order_changes toc on toc.order_id = tco.order_id and toc.order_item_id = tco.order_item_id
left join pizza_toppings pt on toc.topping_id = pt.topping_id
group by 1,2,3
order by 1,2,3
) as t1

-- 3. The Pizza Runner team now wants to add an additional ratings system
--that allows customers to rate their runner, how would you design an additional table for this new dataset
-- generate a schema for this new table and insert your own data for ratings
-- for each successful customer order between 1 to 5.
 
-- USE EPAND SCHEMA fILE
/* Alter Table t_runner_orders add column runner_rating */

-- 4. Using your newly generated table 
-- can you join all of the information together to 
-- form a table which has the following information for successful deliveries?
	--customer_id, order_id, runner_id, rating, 
	-- order_time, pickup_time, Time between order and pickup
	--Delivery duration, Average speed, Total number of pizzas

-- USE EXPAND SCHEMA File
-- create table runner_orders_new as 

select
	tco.customer_id, ro.order_id, ro.runner_id, 
	tco.order_time, ro.pickup_time, ro.pickup_time- tco.order_time as order_to_pickup_time, 
	ro.duration, ro.distance/(ro.duration/60) as avarage_delivery_speed,
	count(*) as number_of_pizzas,
	4 as rating
from t_runner_orders ro
join t_customer_orders tco on tco.order_id = ro.order_id
group by 1,2,3,4,5,6,7,8


--If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras
-- and each runner is paid $0.30 per kilometre traveled 
-- how much money does Pizza Runner have left over after these deliveries?
select sum(order_total - delivery_expense) as total_profit
from
(select tco.order_id as order_id, tro.distance * 0.3 as delivery_expense, sum(price) as order_total
from t_customer_orders tco 
join t_runner_orders tro 
on tro.order_id = tco.order_id
join pizza_names pn 
on pn.pizza_id = tco.pizza_id
where distance is not null
group by 1,2
order by 1,2) as t1;

--------------------------------------------------
-- E. Bonus Questions
--If Danny wants to expand his range of pizzas
-- how would this impact the existing data design? 
-- Write an INSERT statement to demonstrate what would happen
--  if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?


-- USE EXPAND SCHEMA FILE
/* insert into pizza_names (pizza_id, pizza_name, price)
values (3, 'Supreme', 15);

insert into t_pizza_recipes (topping_id)
select topping_id from pizza_toppings;


update t_pizza_recipes set pizza_id = 3 where pizza_id is null;
*/

