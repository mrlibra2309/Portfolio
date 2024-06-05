-- 1: Total sales each Month
SELECT DATE_FORMAT(date, '%Y-%m') as Monthly_sales, 
SUM(total_price) as Total_Sales
FROM fact_table
JOIN time_dim USING(time_key)
GROUP BY Monthly_sales
ORDER BY Monthly_sales;

-- 2: Total sales each Quarter
SELECT CONCAT(year,' ' ,quarter) as Quarter_sales, 
SUM(total_price) as Total_Sales
FROM fact_table
JOIN time_dim USING(time_key)
GROUP BY Quarter_sales
ORDER BY Quarter_sales;

-- 3: Yearly growth
WITH Growth_rate AS (SELECT DATE_FORMAT(date, '%Y') as Current_year,
SUM(total_price) as Current_year_sales,
LAG(SUM(total_price),1,0) OVER (ORDER BY DATE_FORMAT(date, '%Y')) as Previous_year_sales
FROM fact_table
JOIN time_dim USING(time_key)
WHERE DATE_FORMAT(date, '%Y') < 2020
GROUP BY Current_year
ORDER BY Current_year)
SELECT Current_year,
COALESCE(CONCAT(ROUND(((Current_year_sales-Previous_year_sales)*100/Previous_year_sales),2),'%'),0) 
AS Growth_rate
FROM Growth_rate;

-- 4: Average sales per order
SELECT AVG(total_price) as Average_revenue_per_order
FROM fact_table;

-- 5: Customer purchase times 
SELECT customer_key, COUNT(*) as purchase_time
FROM fact_table
GROUP BY customer_key
ORDER BY purchase_time DESC;

-- 6: Retention rate with 5 or more than 5 purchasing time
WITH Retention AS(
SELECT customer_key, COUNT(*) as purchase_time
FROM fact_table
GROUP BY customer_key)
SELECT CONCAT(ROUND((COUNT(CASE WHEN purchase_time >= 5 THEN purchase_time END) / COUNT(*))*100,2), '%') AS Retention_Rate
FROM Retention;

-- 7: Customer classification
WITH avg_spending AS (
SELECT AVG(total_price) as Average_spending, 
customer_key
FROM fact_table
GROUP BY customer_key)
SELECT 
CASE WHEN Average_spending >= 200 THEN '4. VIP Customer'
	WHEN Average_spending >= 150 AND Average_spending < 200 THEN '3. High spending Customer'
    WHEN Average_spending >= 80 AND Average_spending < 150 THEN '2. Regular Customer'
    ELSE '1. Low spending customers' END AS Customer_classification,
    COUNT(customer_key) as Customer_number
FROM avg_spending
GROUP BY Customer_classification
ORDER BY Customer_classification;

-- 8: Customer geography distribution
SELECT COUNT(customer_key) as Customer_number,
division as City
FROM fact_table
JOIN store_dim USING (store_key)
GROUP BY division
ORDER BY Customer_number DESC;

-- 9: Top 3 Favorite items of Top 5 suppliers

WITH top_item AS(
SELECT DENSE_RANK() OVER (PARTITION BY supplier ORDER BY COUNT(customer_key) DESC) as ranking,
COUNT(customer_key) as customer_num_item, item_name, supplier
FROM fact_table
JOIN item_dim USING (item_key)
GROUP BY item_name, supplier
),
top_5_supplier AS(
SELECT COUNT(customer_key) as customer_num_supplier, supplier
FROM fact_table
JOIN item_dim USING (item_key)
GROUP BY supplier
LIMIT 5)
SELECT ranking, supplier, SUM(customer_num_item) as item_quantity, item_name
FROM top_5_supplier
INNER JOIN top_item USING (supplier)
WHERE ranking <=3
GROUP BY item_name, supplier
ORDER BY supplier, item_quantity DESC;

-- 10: Top 5 manufacturer country
SELECT 
	COUNT(customer_key) as item_num,
    manu_country
FROM fact_table
JOIN item_dim USING (item_key)
GROUP BY manu_country
ORDER BY item_num DESC
LIMIT 5;

-- 11: Top 10 best sales categories
SELECT 
	RANK() OVER (ORDER BY COUNT(customer_key) DESC) as Top_sales,
    category,
    COUNT(customer_key) as item_num
FROM fact_table
JOIN item_dim USING (item_key)
GROUP BY category
ORDER BY item_num DESC
LIMIT 10;

-- 12: Primary payment method
SELECT 
    trans_type as type_of_transaction,
	COUNT(customer_key) as transaction_number, 
    CONCAT(ROUND(100.0*COUNT(customer_key)/SUM(COUNT(customer_key)) OVER (),2),'%') as ratio
FROM fact_table
JOIN trans_dim USING (payment_key)
GROUP BY trans_type;

-- 13: Customer Lifetime Value (CLV)
WITH a AS(
	SELECT 
		AVG(total_price) as Average_revenue_per_order_each_customer
	FROM fact_table
	GROUP BY customer_key),
aa AS(
	SELECT 
		ROUND(AVG(Average_revenue_per_order_each_customer),2) as Average_revenue_per_order
	FROM a),
b AS(
	SELECT
	  ABS(MONTH(MAX(date)) - MONTH(MIN(date))) AS lifespan_months,
	  customer_key
	FROM fact_table
	JOIN time_dim USING(time_key)
	GROUP BY customer_key),
bb AS(
	SELECT 
		CASE WHEN lifespan_months < 1 THEN 1
		WHEN lifespan_months >= 1 THEN lifespan_months
		END AS lifespan,
		customer_key
	FROM b),
bbb AS (
	SELECT 
		ROUND(AVG(lifespan),2) as Average_lifespan_per_customer_month
	FROM bb),
c AS (
	SELECT 
		customer_key, COUNT(*) as purchase_time
	FROM fact_table
	GROUP BY customer_key),
cc AS (
	SELECT 
		ROUND(AVG(purchase_time),2) as Average_frequency_purchase_month
	FROM c)
    
SELECT ROUND(aa.Average_revenue_per_order * 
			bbb.Average_lifespan_per_customer_month *
            cc.Average_frequency_purchase_month,2) AS Customer_Lifetime_Value
FROM aa,bbb,cc