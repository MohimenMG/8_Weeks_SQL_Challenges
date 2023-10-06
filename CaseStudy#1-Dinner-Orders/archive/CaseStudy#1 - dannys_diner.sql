-- DANI SQL Challenge week #1
create schema dannys_diner_1;

create table sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

insert
	into
	sales
  ("customer_id",
	"order_date",
	"product_id")
values
  ('A',
'2021-01-01',
'1'),
  ('A',
'2021-01-01',
'2'),
  ('A',
'2021-01-07',
'2'),
  ('A',
'2021-01-10',
'3'),
  ('A',
'2021-01-11',
'3'),
  ('A',
'2021-01-11',
'3'),
  ('B',
'2021-01-01',
'2'),
  ('B',
'2021-01-02',
'2'),
  ('B',
'2021-01-04',
'1'),
  ('B',
'2021-01-11',
'1'),
  ('B',
'2021-01-16',
'3'),
  ('B',
'2021-02-01',
'3'),
  ('C',
'2021-01-01',
'3'),
  ('C',
'2021-01-01',
'3'),
  ('C',
'2021-01-07',
'3');

create table menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

insert
	into
	menu
  ("product_id",
	"product_name",
	"price")
values
  ('1',
'sushi',
'10'),
  ('2',
'curry',
'15'),
  ('3',
'ramen',
'12');

create table members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

insert
	into
	members
  ("customer_id",
	"join_date")
values
  ('A',
'2021-01-07'),
  ('B',
'2021-01-09');
--------------------------------------------------------------------------
 select
	*
from
	sales s ;

select
	distinct *
from
	(
	select
		customer_id,
		order_date,
		product_id ,
		dense_rank() over(partition by customer_id
	order by
		order_date) as r
	from
		;
-- 1. What is the total amount each customer spent at the restaurant?
select
	customer_id customer,
	sum(price) spent
from
	menu mu
join sales s on
	mu.product_id = s.product_id
group by
	s.customer_id
order by
	1;
-- 2. How many days has each customer visited the restaurant?
select
	customer_id,
	count(distinct order_date)
from
	menu mu
join sales s on
	mu.product_id = s.product_id
group by
	1
order by
	1;
-- 3. What was the first item from the menu purchased by each customer?
select
	customer_id,
	product_name
from
	(
	select
		customer_id,
		product_name,
		order_date,
		dense_rank() over(partition by customer_id
	order by
		order_date) rank_
	from
		menu mu
	join sales s on
		mu.product_id = s.product_id
	order by
		1
) t1
where
	rank_ = 1
group by
	1,
	2;
-- 4. What is the most purchased item on the menu?
select
	mu.product_name product,
	count(*)
from
	menu mu
join sales s on
	mu.product_id = s.product_id
group by
	1
order by
	2 desc
limit 1;
-- 4.1. how many times was the most purchased item on the menu purchased by all customers?
select
	s.customer_id,
	count(mu.product_id)
from
	menu mu
join sales s on
	mu.product_id = s.product_id
where
	mu.product_id = (
	select
		product
	from
		(
		select
			mu.product_id product,
			count(*)
		from
			menu mu
		group by
			1
		order by
			2 desc
		limit 1) t1)
group by
	1;
-- 5. Which item was the most popular for each customer? 
with t1 as (
select
	s.customer_id,
	mu.product_name fav,
	count(mu.product_id),
	rank() over(partition by s.customer_id
order by
	count(mu.product_id) desc) rank_
from
	menu mu
join sales s on
	mu.product_id = s.product_id
group by
	1,
	2
order by
	1,
	4)
select
	customer_id,
	fav
from
	t1
where
	rank_ = 1
 ;
-- 6. Which item was purchased first by the customer after they became a member?
with t1 as (
select
	m.customer_id,
	product_name,
	rank() over(partition by m.customer_id
order by
	order_date) rank_
from
	sales s
join members m on
	m.customer_id = s.customer_id
join menu mu on
	mu.product_id = s.product_id
where
	order_date > join_date
)
select
	*
from
	t1
where
	rank_ = 1
;
-- 7. Which item was purchased just before the customer became a member?
with t1 as (
select
	m.customer_id,
	product_name,
	order_date,
	row_number() over(partition by m.customer_id
order by
	order_date desc) rank_
from
	sales s
join members m on
	m.customer_id = s.customer_id
join menu mu on
	mu.product_id = s.product_id
where
	order_date < join_date
)
select
	*
from
	t1
where
	rank_ = 1
	-- notice we want the transaction that before the membership, we dont have the time to know but the last transaction on the last day should be the one
	-- row number should be used instead of rank for this reason
;
-- 8. What is the total items and amount spent for each member before they became a member?
select
	s.customer_id,
	count(mu.product_id) items ,
	sum(price) amount_spent
from
	sales s
join members m on
	m.customer_id = s.customer_id
join menu mu on
	mu.product_id = s.product_id
where
	order_date < join_date
group by
	1;
-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
with t1 as(
select
	s.customer_id as id,
	case
		when product_name = 'sushi' then price * 10 * 2
		else price * 10
	end as points
from
	sales s
full join members m on
	m.customer_id = s.customer_id
join menu mu on
	mu.product_id = s.product_id
order by
	m.customer_id)
select
	id,
	sum(points)
from
	t1
group by
	1
order by
	1
;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
with t1 as(
select
	s.customer_id as id,
	join_date,
	order_date,
	join_date + 6 valid_date,
	product_name,
	price,
	case
		when product_name = 'sushi' then price * 10 * 2
		when order_date between join_date and join_date + 6 then price * 10 * 2
		else price * 10
	end as points,
	case
		when product_name = 'sushi' then 'sushi'
		when order_date between join_date and join_date + 6 then 'join bouns week'
		else 'no bouns'
	end as points_describe
from
	sales s
join members m on
	m.customer_id = s.customer_id
join menu mu on
	mu.product_id = s.product_id
where
	date_trunc('month',
	order_date) = date_trunc('MONTH',
	date'2021-01-31')
	and order_date >= join_date
order by
	1,
	2
)
select
	id,
	sum(points)
from
	t1
group by
	1
order by
	1
;

-- bonus. Recreate a table joining all the tables together with an extra flag field 'member' of values 'Y' and 'N'
-- the ranking of customer products, but only for member purchases (expects nulls for null member purchases)
with t1 as(
select 
	s.customer_id id,
	order_date,
	mu.product_name,
	price,
	case 
		when order_date >= join_date then 'Y'
		else 'N'
	end as "member"
from
	sales s
full join members m on
	m.customer_id = s.customer_id
join menu mu on
	mu.product_id = s.product_id
order by
	1,
	2
)
select
	*,
	case
		when "member" = 'N' then null
		else rank() over(partition by id,
		"member"
	order by
		order_date)
	end as customer_product_ranking
from
	t1;


