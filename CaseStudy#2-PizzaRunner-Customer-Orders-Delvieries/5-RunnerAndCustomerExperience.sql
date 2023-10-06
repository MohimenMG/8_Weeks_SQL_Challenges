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
