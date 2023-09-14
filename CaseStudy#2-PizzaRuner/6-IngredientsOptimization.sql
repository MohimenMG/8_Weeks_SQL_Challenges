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