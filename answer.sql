
-- QUESTION 1:
/* 
Write an SQL query to calculate the total sales of furniture products, grouped by each quarter of the year, 
and order the results chronologically. 
*/

SELECT 
	CONCAT('Q', Datepart(Quarter, Order_date), '-', Year(Order_date)) AS Quarter_Year,
	ROUND(SUM(sales),2) AS Total_sales
FROM ORDERS
JOIN PRODUCT on ORDERS.PRODUCT_ID = PRODUCT.ID
	AND PRODUCT.NAME = 'Furniture'
GROUP BY YEAR(ORDER_DATE), Datepart(Quarter,Order_date)
ORDER BY YEAR(ORDER_DATE), Datepart(Quarter,Order_date);
	


-- QUESTION 2:
/* 
Analyze the impact of different discount levels on sales performance across product categories, 
specifically looking at the number of orders and total profit generated for each discount classification.

Discount level condition:
No Discount = 0
0 < Low Discount <= 0.2
0.2 < Medium Discount <= 0.5
High Discount > 0.5 
*/
SELECT
	p.category,
	CASE 
		WHEN o.DISCOUNT =0 THEN 'No Discount'
		WHEN o.DISCOUNT >0 and o.DISCOUNT <= 0.2 THEN 'Low Discount'
		WHEN o.DISCOUNT>0.2 and o.DISCOUNT <= 0.5 THEN 'Medium Discount'
		ELSE 'High Discount'
	END AS LevelDiscount,
	COUNT(distinct(o.order_id)) as Num_orders,
	ROUND(sum(o.profit),2) as total_profit
FROM ORDERS o
JOIN product p on o.PRODUCT_ID=p.ID
GROUP BY 
	p.category,
	CASE 
		WHEN o.DISCOUNT =0 THEN 'No Discount'
		WHEN o.DISCOUNT >0 and o.DISCOUNT <= 0.2 THEN 'Low Discount'
		WHEN o.DISCOUNT>0.2 and o.DISCOUNT <= 0.5 THEN 'Medium Discount'
		ELSE 'High Discount'
	END
ORDER BY p.CATEGORY;

-- QUESTION 3:
/* 
Determine the top-performing product categories within each customer segment based on sales and profit, 
focusing specifically on those categories that rank within the top two for profitability. 
*/
with salerank as(
	SELECT 
		c.SEGMENT,
		p.category,
		sum(o.sales) as total_sales,
		sum(o.profit) as total_profit,
		RANK() Over(PARTITION BY c.segment order by sum(o.sales) DESC)AS Sales_rank
	FROM ORDERS o
	JOIN CUSTOMER c on o.CUSTOMER_ID = c.ID
	JOIN PRODUCT p on o.PRODUCT_ID = p.ID
	GROUP BY c.SEGMENT, p.CATEGORY
),
profitrank as(
	SELECT
		SEGMENT, 
		CATEGORY,
		Sales_rank,
		RANK() OVER (PARTITION BY segment order by total_profit DESC) AS Profit_rank
	FROM salerank
)
SELECT 
	SEGMENT,
	CATEGORY,
	Sales_rank,
	Profit_rank
FROM profitrank
WHERE Profit_rank <3;


-- QUESTION 4
/*
Create a report that displays each employee's performance across different product categories, showing not only the 
total profit per category but also what percentage of their total profit each category represents, with the result 
ordered by the percentage in descending order for each employee.
*/
with profit_employee as(
	SELECT 
		o.ID_EMPLOYEE,
		sum(o.profit) as total_profit_employee
	FROM ORDERS o
	GROUP BY o.ID_EMPLOYEE
),
profit_category as(
SELECT 
	o.ID_EMPLOYEE,
	p.CATEGORY,
	ROUND(SUM(o.profit),2) AS Rounded_Total_Profit
FROM ORDERS o
JOIN PRODUCT p on o.PRODUCT_ID = p.ID
GROUP BY o.ID_EMPLOYEE, p.CATEGORY
)
SELECT
	c.ID_EMPLOYEE,
	c.CATEGORY,
	c.Rounded_Total_Profit,
	ROUND(c.Rounded_Total_Profit/e.total_profit_employee*100,2) AS Profit_percentage
FROM profit_category c
JOIN profit_employee e on e.ID_EMPLOYEE = c.ID_EMPLOYEE
GROUP BY c.ID_EMPLOYEE, c.CATEGORY, c.Rounded_Total_Profit, c.Rounded_Total_Profit/e.total_profit_employee
ORDER BY c.ID_EMPLOYEE, Profit_percentage DESC;

-- QUESTION 5:
/*
Develop a user-defined function in SQL Server to calculate the profitability ratio for each product category 
an employee has sold, and then apply this function to generate a report that sorts each employee's product categories
by their profitability ratio.
*/

	SELECT 
		o.ID_EMPLOYEE,
		p.CATEGORY,
		round(sum(o.sales),2) AS Total_Sales,
		round(sum(o.profit),2) AS Total_Profit,
		round(sum(o.profit)/sum(o.sales),2) AS Profitability_Ratio
	FROM ORDERS o
	JOIN PRODUCT p on o.PRODUCT_ID =p.ID
	GROUP BY 
		o.ID_EMPLOYEE,
		p.CATEGORY
	ORDER BY o.ID_EMPLOYEE, Profitability_Ratio DESC;

-- QUESTION 6:
/* 
Write a stored procedure to calculate the total sales and profit for a specific EMPLOYEE_ID over a specified date range. 
The procedure should accept EMPLOYEE_ID, StartDate, and EndDate as parameters.
*/
CREATE PROCEDURE GetEmployeeSalesProfit
	@EmployeeID int,
	@StartDate DATE,
	@EndDate DATE
AS
BEGIN
SELECT 
	e.NAME as EMPLOYEE_NAME,
	round(sum(o.sales),2) AS TOTAL_SALES,
	round(sum(o.profit),2) AS TOTAL_PROFIT
FROM ORDERS o
JOIN EMPLOYEES e on o.ID_EMPLOYEE = e.ID_EMPLOYEE
WHERE o.ID_EMPLOYEE = @EmployeeID	
	AND o.ORDER_DATE >= @StartDate
	AND o.ORDER_DATE <= @EndDate
GROUP BY e.NAME;
END;
GO

EXEC GetEmployeeSalesProfit @EmployeeID = 3, @StartDate ='2016-12-01', @EndDate = '2016-12-31';

-- QUESTION 7:
/*
Write a query using dynamic SQL query to calculate the total profit for the last six quarters in the datasets, 
pivoted by quarter of the year, for each state.
*/

DECLARE @cols NVARCHAR(MAX);
DECLARE @sql  NVARCHAR(MAX);

;with rank_quarter as (
	SELECT 
		CONCAT('Q', Datepart(Quarter, Order_date), '-', Year(Order_date)) AS Quarter_Year,
		DENSE_RANK() OVER (ORDER BY Year(Order_date) DESC,Datepart(Quarter, Order_date) DESC ) as rank_num
	FROM ORDERS o
	GROUP BY Datepart(Quarter, Order_date), Year(Order_date)
),
last6 as(
SELECT DISTINCT	Quarter_Year, rank_num
FROM rank_quarter
WHERE rank_num <=6
)
SELECT @cols= STRING_AGG(CONCAT('[', Quarter_Year, ']'), ',') 
	WITHIN GROUP (ORDER BY rank_num ASC)
FROM last6;

SET @sql = '
;with rank_quarter as (
	SELECT 
		CONCAT(''Q'', Datepart(Quarter, Order_date), ''-'', Year(Order_date)) AS Quarter_Year,
		DENSE_RANK() OVER (ORDER BY Year(Order_date) DESC,Datepart(Quarter, Order_date) DESC ) as rank_num
	FROM ORDERS o
	GROUP BY Datepart(Quarter, Order_date), Year(Order_date)
),
last6 as(
	SELECT DISTINCT	Quarter_Year
	FROM rank_quarter
	WHERE rank_num <=6
),
sourcetable AS (
	SELECT 
		c.STATE,
		CONCAT(''Q'', Datepart(Quarter, Order_date), ''-'', Year(Order_date)) AS Quarter_Year,
		ROUND(SUM(o.profit),2) AS total_profit
	FROM ORDERS o
	JOIN CUSTOMER c ON o.CUSTOMER_ID = c.ID
	JOIN last6 l ON CONCAT(''Q'', Datepart(Quarter, Order_date), ''-'', Year(Order_date)) = l.Quarter_Year
	GROUP BY c.STATE, Datepart(Quarter, o.Order_date), Year(o.Order_date)
)
SELECT
    STATE, ' + @cols + '
FROM sourcetable
PIVOT (
    SUM(total_profit)
    FOR Quarter_Year IN (' + @cols + ')
) p
ORDER BY STATE;
';

EXEC (@sql);


