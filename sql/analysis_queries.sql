-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, sum(m.price) AS Total_Amount_Spent FROM sales as s
INNER JOIN menu as m
ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, count(DISTINCT order_date) AS Total_Days_Visited FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT s.customer_id, m.product_name FROM sales AS s
INNER JOIN menu as m
ON s.product_id = m.product_id
WHERE s.order_date = (SELECT min(order_date) FROM sales)
GROUP BY customer_id, m.product_name
ORDER BY s.customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT m.product_name, count(s.product_id) FROM menu AS m
INNER JOIN sales AS s
ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY count(s.product_id) DESC
limit 1;

-- 5. Which item was the most popular for each customer?
WITH ordered_sales AS (
SELECT s.customer_id, m.product_name,
dense_rank() OVER (
PARTITION BY s.customer_id
ORDER BY count(s.product_id) desc) AS rnk
FROM sales as s
inner JOIN menu AS m
ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name
)
SELECT customer_id, product_name
FROM ordered_sales
WHERE rnk = 1;

-- 6. Which item was purchased first by the customer after they became a member?

WITH member_sales_rank as(
SELECT s.customer_id,
        m.product_name,
        s.order_date,
        mb.join_date,
        DENSE_RANK() over(
        PARTITION BY s.customer_id
        ORDER BY s.order_date asc) AS rnk
FROM sales AS s
INNER JOIN members AS mb
ON s.customer_id = mb.customer_id
INNER JOIN menu AS m
ON s.product_id = m.product_id
WHERE s.order_date >= mb.join_date)

SELECT customer_id, product_name
FROM member_sales_rank
where rnk = 1;

-- 7. Which item was purchased just before the customer became a member?
WITH pre_member_sales as(
SELECT s.customer_id,
        m.product_name,
        s.order_date,
        mb.join_date,
        DENSE_RANK() over(
        PARTITION BY s.customer_id
        ORDER BY s.order_date desc) AS rnk
FROM sales AS s
INNER JOIN members AS mb
ON s.customer_id = mb.customer_id
INNER JOIN menu AS m
ON s.product_id = m.product_id
WHERE s.order_date < mb.join_date)

SELECT customer_id, product_name
FROM pre_member_sales
where rnk = 1;

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT 
    s.customer_id,
    COUNT(s.product_id) AS total_items,
    SUM(m.price) AS total_amount_spent
FROM sales AS s
INNER JOIN members AS mb
    ON s.customer_id = mb.customer_id
INNER JOIN menu AS m
    ON s.product_id = m.product_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT s.customer_id, sum(CASE
                          WHEN m.product_name = 'sushi' THEN m.price * 20
                          ELSE m.price * 10
                          end) AS total_points
FROM sales AS s
INNER JOIN menu AS m
ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) 
-- they earn 2x points on all items, not just sushi - how many points do
-- customer A and B have at the end of January?

SELECT s.customer_id, sum(CASE
                          WHEN s.order_date >= mb.join_date AND s.order_date <= mb.join_date+7 THEN m.price * 20
                          ELSE m.price * 10
                          end) AS total_points
FROM sales AS s
INNER JOIN menu AS m
ON s.product_id = m.product_id
INNER JOIN members AS mb
ON s.customer_id = mb.customer_id
WHERE s.order_date <= '2021-01-31'
GROUP BY s.customer_id;

-- Create a master summary table of all customer orders 
-- showing their membership status ('Y'/'N')

CREATE TABLE Joined_table as
SELECT s.customer_id, s.order_date, m.product_name, m.price,
 CASE WHEN s.order_date >= mb.join_date THEN 'Y'
 ELSE 'N'
 END AS member
FROM sales AS s
LEFT JOIN members AS mb
ON s.customer_id = mb.customer_id
INNER JOIN menu as m
ON s.product_id = m.product_id
order BY s.customer_id, s.order_date, m.price desc;

-- Rank member purchases chronologically, but output a true NULL for any non-member orders.

SELECT *, CASE
WHEN member = 'N' THEN NULL
ELSE dense_rank() over(
PARTITION BY customer_id, member
ORDER BY order_date) END AS ranking
FROM Joined_table;


SELECT * FROM Joined_table;
