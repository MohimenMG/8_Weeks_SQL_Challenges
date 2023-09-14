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
