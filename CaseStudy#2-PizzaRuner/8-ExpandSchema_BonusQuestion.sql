-- create a new price column in the pizza table and update its vlaues
alter table pizza_names 
add column price float;

select * from pizza_names pn;

update pizza_names set price = 12 where pizza_id = 1; 
update pizza_names set price = 10 where pizza_id = 2; 

--------------------------------------------------------------------------------------------------------
insert into pizza_names (pizza_id, pizza_name, price)
values (3, 'Supreme', 15);

insert into t_pizza_recipes (topping_id)
select topping_id from pizza_toppings;


update t_pizza_recipes set pizza_id = 3 where pizza_id is null;