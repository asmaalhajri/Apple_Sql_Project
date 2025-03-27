--Apple Sales Porject -- 1M rows in Sales dataset

select * from category;
select * from products;
select * from stores;
select * from sales;
select * from warranty;

-EDA
select distinct repair_status from warranty;
select count(*) from sales; --1M rows

--Improving Query Performance
--Creating index

--et 96 ms
--after index et 0.1ms
explain analyze -- to check execution time
select * from sales 
where product_id ='p-44'

create index sales_product_id on sales(product_id);
create index sales_store_id on sales(store_id);
create index sales_sale_date on sales(sale_date);

--et 166ms
--after index et 8.9
explain analyze
select * from sales 
where store_id='ST-31'

--Business Question
--number of stores per country
select count(*) as total_stores,country from stores
group by 2
order by 1 desc;

--number of units sold per each store
select store_id,sum(quantity) as usnits_sold from sales
group by 1
order by 2 desc;

select store_name, sa.store_id ,sum(quantity) as units_sold 
from sales sa 
left join stores st 
on st.store_id=sa.store_id
group by 1,2
order by 3 desc;

--how much sales in december 2023
select count(sale_id)as total_sales
from sales 
where extract(year from sale_date)=2023 
and extract(month from sale_date)=12;

--how many stores without a warranty claim

SELECT count(*) from stores
where store_id not in (select distinct store_id 
from sales sa 
right join warranty w 
on sa.sale_id=w.sale_id );


-- percentage %%% of warranties with repair_status 'Warranty void'
select (round((count(*)*100.0)/(select count(*) from warranty),2))::text || '%' as Warranty_void_percentage 
from warranty 
where repair_status='Warranty Void';

--store with highest units sold in the last year 
select store_name ,st.store_id from sales sa join stores st on sa.store_id= st.store_id
where sale_date >=(current_date - interval '1 year')
group by st.store_name, st.store_id
order by sum(quantity) desc
limit 1 ;

--count the number of unique products sold in the last year
select count(distinct product_id) 
from sales
where sale_date>= (current_date - interval'1 year');

-- average price of each category 
select c.category_id, c.category_name, round(avg(price)::numeric,2) as average_price 
from category c  
join products p 
on p.category_id=c.category_id
group by 1,2
order by 3 desc;

--how many claims filled in 2020
select count(*) 
from warranty
where extract(year from claim_date)=2020;

--for each store , identify the best-selling day based on highest quantities sold
select * from
(select 
	store_id ,
	to_char(sale_date,'Day') as day_name ,
	sum(quantity) as total_units_sold,
	rank() over(partition by store_id order by sum(quantity)desc) as rank
from sales 
group by 1,2)as  t1
where rank=1

--least selling product in each country for each year on total units sold
select * 
from(select 
	country,
	year1,
	total_quantity,
	product_name,
	rank() over(partition by country , year1 order by total_quantity asc) as rank
from(select 
	st.country , 
	extract(year from sale_date) as year1 , 
	sum(quantity)as total_quantity,
	sa.product_id
from sales sa 
join stores st
on sa.store_id= st.store_id
group by 1,2,4) as t2
join products as p 
on t2.product_id=p.product_id
)as t3
where rank=1

--how many warranty claims filed within 180 days of product sale
select count(*) as Number_of_Claims
from warranty w
join sales s
on w.sale_id=s.sale_id
where w.claim_date - s.sale_date <= 180

-- how many warranty claims were filed for products launched in the last 2 years
select * from products

select t1.product_id, count(claim_id)
from warranty as w 
right join
(select s.sale_id, p.product_id
from sales s
join products p
on s.product_id= p.product_id
where launch_date>=current_date - interval '2 year'
)as t1
on t1.sale_id=w.sale_id
group by t1.product_id

--list the MONTHS in the LAST THREE YEARS where sales exceeded 5000 UNITS in the USA

select to_char(sale_date,'MM-YYYY') as month, sum(sa.quantity)
from sales sa
join stores st
on sa.store_id=st.store_id
where st.country = 'USA' 
and sale_date >= current_date - interval'3 year'
group by 1
having sum(sa.quantity)>5000

--identify the product category with the MOST warranty filed within the last 2 YEARS
select c.category_name,count(claim_id) as total_claims
from category c
join products p
on c.category_id=p.category_id
join sales s 
on s.product_id= p.product_id
join warranty w
on s.sale_id=w.sale_id
where claim_date>= current_date - interval '2 year'
group by 1 
order by count(claim_id) desc
limit 1

--determine the probabilty of getting a warranty claim after each purchase for each country 
select st.country, sum(sa.quantity)as total_units_sold, count(w.claim_id) as total_claims ,coalesce(round(nullif(count(w.claim_id)::numeric,0)/sum(sa.quantity)::numeric*100,2),0)
from sales sa
join stores st 
on sa.store_id=st.store_id
left join warranty w
on sa.sale_id=w.sale_id
group by 1
order by 4 desc

--year by year growth ratio for each store
--CTE 1
with current_s as 
(select st.store_name ,extract(year from sa.sale_date) as current_year, sum(sa.quantity *p.price) as current_profit
from sales sa 
join stores st
on sa.store_id=st.store_id
join products p
on sa.product_id=p.product_id
group by 1,2
order by 1,2),
--CTE 2
previous_s as(
select *, lag(current_profit)over (partition by store_name order by current_year) as previous_profit 
from current_s) 

select * , ROUND((current_profit - previous_profit)::NUMERIC / previous_profit::NUMERIC, 2) as yearly_growth
from previous_s
where previous_profit is not null

--correlation between product price and warranty claims for products sold in the last 5 years (segmented by price range)
select distinct(price) from products
order by price   --<500, 500-1000, >1000

select 
case 
	when p.price<500 then 'Low Price'
	when p.price>=500 and p.price<=1000 then 'Medium Price'
	else 'High Price'
end as product_Price_category,
count(w.claim_id) as Number_of_Claims
from sales sa
join warranty w
on sa.sale_id= w.sale_id
join products p 
on sa.product_id=p.product_id
where sa.sale_date>= current_date - interval'5 year'
group by 1

--identify the store with the highest percentage of 'Paid Repaired' claim

select sa.store_id, st.store_name,round(count(
											case when w.repair_status = 'Paid Repaired' then 1 end)::numeric 
    										/ count(*)::numeric * 100,2  ) as Paid_Repaired_Percentage
											from sales sa
JOIN stores st 
on st.store_id = sa.store_id
right join warranty w 
on sa.sale_id = w.sale_id
group by sa.store_id, st.store_name
order by Paid_Repaired_Percentage desc
limit 1;

--monthly running total for each store (for the past 4 years) and compare trends over this period of time
with monthly as(select sa.store_id, extract(year from sale_date) as year, extract(month from sale_date)as month, sum(p.price*sa.quantity)as monthly_profit
from sales sa
join products p
on p.product_id=sa.product_id
where sa.sale_date>=current_date -interval '4 year'
group by 1,2,3
order by 1,2,3)
select *, sum(monthly_profit)over(partition by monthly.store_id order by year, month) as running_total 
from monthly 

--Analyze product sales trends over time, segmented into key periods: from launch to 6 months, 6-12 months
--, 12-18 months, and beyond 18 months

select p.product_name,
	case 
		when s.sale_date between p.launch_date and p.launch_date + INTERVAL '6 month' then '0-6 month'
		when s.sale_date between  p.launch_date + INTERVAL '6 month'  and p.launch_date + INTERVAL '12 month' then '6-12' 
		when s.sale_date between  p.launch_date + INTERVAL '12 month'  and p.launch_date + INTERVAL '18 month' then '12-18'
		else '18+'
	end as plc,
	sum(s.quantity) as total_qty_sale
	
from sales as s
join products as p
on s.product_id = p.product_id
group by 1, 2
order by 1, 3 desc 
