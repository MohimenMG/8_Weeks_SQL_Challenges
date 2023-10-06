-- data cleaning 
 
------------------------------------------------------------------------------------------------
-- removing null strings from customer orders table
-- add the item_id column which identify each pizza a customer buys in an order:
   -- a customer can buy the same pizza kind in the same order (using the id to identify each pizza for the extras and exclusions)
drop table t_customer_orders;

create table t_customer_orders as
select 
order_id,
row_number() over(partition by order_id) as order_item_id,
customer_id,
pizza_id,
case when exclusions = '' or exclusions = 'null' then Null else replace(exclusions,' ','') end as exclusions,
case when extras = '' or extras = 'null' then Null else replace(extras,' ','') end as extras,
order_time
from customer_orders;

select * from t_customer_orders;

------------------------------------------------------------------------------------------------
-- add exclusions and extras to a new table
-- compute the number of exclusions and extras for each item (pizza)

drop table t_order_items;

create table t_order_items as 
select 
order_id,
order_item_id,
pizza_id,
exclusions,
extras,
(length(exclusions) - (length(exclusions)-1)/2) as number_of_exclusions,
(length(extras) - (length(extras)-1)/2) as number_of_extras
from t_customer_orders;

select * from t_order_items;

-------------------------------------------------------------------------------------------------
-- transform the exclusions and extras table (t_order_items) where the item 
-- move the multi-value columns (exclusion and extras to a new table with queryable single values)

-- exclusions table
drop table t_order_changes;

create table t_order_changes as
with recursive t_order_items_exclusions as (
select
	*
from
	(
	select
		order_id,
		order_item_id,
		1 as change_index,
		split_part(exclusions,
		',',
		1) as exclusion_id,
		number_of_exclusions
	from
		t_order_items
) as t1
where
	exclusion_id is not null
union all
select
	t1.order_id,
	t1.order_item_id,
	t2.change_index + 1 as change_index,
	split_part(t1.exclusions,
	',',
	t2.change_index + 1) as exclusion_id,
	t1.number_of_exclusions
from
	t_order_items t1,
	(
	select
		change_index
	from
		t_order_items_exclusions
	limit 1) t2
where
	t1.number_of_exclusions = t2.change_index + 1),
-- extras table
t_order_items_extras as (
select
	*
from
	(
	select
		order_id,
		order_item_id,
		1 as change_index,
		split_part(extras,
		',',
		1)as extras_id,
		number_of_extras
	from
		t_order_items
) as t1
where
	extras_id is not null
union all
select
	t1.order_id,
	t1.order_item_id,
	t2.change_index + 1 as change_index,
	split_part(t1.extras,
	',',
	t2.change_index + 1) as extras_id,
	t1.number_of_extras
from
	t_order_items t1,
	(
	select
		change_index
	from
		t_order_items_extras
	limit 1) t2
where
	t1.number_of_extras = t2.change_index + 1)
-- query the new order changes table that adds a row for each change to every item (pizza) for every order
select
	order_id,
	order_item_id,
	'Execlude' as change_type,
	exclusion_id as topping_id
from
	t_order_items_exclusions
union all
select
	order_id,
	order_item_id,
	'Extra' as change_type,
	extras_id as topping_id
from
	t_order_items_extras
order by
	1,
	2
;

alter table t_order_changes
alter column topping_id type integer using topping_id::int
;

select * from t_order_changes;


-- removing null strings and 
-- setting distance to float, duration to float, and order_time to timestamp

drop table t_runner_orders;

create table t_runner_orders as
select 
order_id,
runner_id,
cast(case 
	when pickup_time = 'null' then null 
	else pickup_time end as timestamp) as pickup_time  ,
cast(case 
	when distance = 'null' then NULL 
	when replace(distance,' ','') like '%km' then substring(distance,1, length(distance)-2 ) 
	else distance end as float) as distance,	
cast (case 
	when duration = 'null' then NULL 
	when duration like '%minutes' then substring(duration,1, length(duration) - 7)	
	when duration like '%minute' then substring(duration,1, length(duration) - 6)
	when duration like '%mins' then substring(duration,1, length(duration)-4)
	else duration end as float) as duration,
case
	when  replace(cancellation,' ','') = '' or cancellation = 'null' then null
	else cancellation
end as cancellation 
from runner_orders;

select * from t_runner_orders;

------------------------------------------------------------------------------------------------------------

-- transform the pizza_recipes table from comma delimited to rows
drop table t_pizza_recipes;

create table t_pizza_recipes as 
with recursive t_pizza_recipes as (
select 
pizza_id,
change_index,
topping_id
from(
	select 
		pizza_id, 
		toppings, 
		1 as change_index,
		split_part(toppings,',',1) as topping_id,
		number_of_toppings
	from(
		select *, (length(toppings) - length(replace(toppings,',',''))+1) as number_of_toppings
		from(
			select
				pizza_id,
				REPLACE(toppings,' ','') as toppings
			from
				pizza_recipes
				) as t1
				) as t2
				) as t3
union all
select * from
(select 
t1.pizza_id,
t2.change_index+1 as change_index,
split_part(t1.toppings,',',t2.change_index+1) as topping_id
from pizza_recipes t1, (select change_index from t_pizza_recipes limit 1) as t2
) as t3
where topping_id != ''
)
select pizza_id, cast(replace(topping_id, ' ', '') as int) as topping_id from t_pizza_recipes order by 1,2;

select * from t_pizza_recipes;

------------------------------------------------------------------
-- drop all transformed tables

--drop table t_customer_orders;
--drop table t_order_changes;
--drop table t_runner_orders;
--drop table t_pizza_recipes;
