-- using a recursive querie to 
-- iterate over each index in the list of exclusions and extras 
-- and add each index to a new row
with recursive t_order_items_mod as (
select * 
from(
select 
order_id, order_item_id, 
1 as change_index,
split_part(exclusions,',',1) as exclusion_id,
split_part(extras,',',1)as extras_id,
number_of_exclusions,
number_of_extras
from t_order_items
) as t1
where exclusion_id is not null or extras_id is not null
union all
select 
t1.order_id, t1.order_item_id, 
t2.change_index+1 as change_index,
split_part(t1.exclusions,',',t2.change_index+1) as exclusion_id,
split_part(t1.extras,',',t2.change_index+1) as extras_id,
t1.number_of_exclusions,
t1.number_of_extras
from t_order_items t1, (select change_index from t_order_items_mod limit 1) t2
where t1.number_of_exclusions = t2.change_index+1 or t1.number_of_extras = t2.change_index+1)
select order_id, order_item_id, exclusion_id, extras_id from t_order_items_mod
;