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