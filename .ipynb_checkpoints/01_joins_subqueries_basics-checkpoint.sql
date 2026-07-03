SQL Analytics Practice - Day 1
Topics: SELECT, WHERE, GROUP BY, HAVING, JOIN, CASE WHEN, CTE
Author: Yucheng Gao
Date: 2026-07-01

Tables used in this practice:

users
- user_id
- signup_date
- country
- device

orders
- order_id
- user_id
- order_date
- amount
- status

events
- event_id
- user_id
- event_date
- event_type
- traffic_source
*/

-- Question 1: Find all users from the United States

SELECT *
FROM users
WHERE country = 'US';

-- Question 2: Count users by country

SELECT country, COUNT(*) AS user_count
FROM users
GROUP BY country
ORDER BY user_count DESC;

-- Question 3: Count users by device

SELECT device, COUNT(*) AS user_count
FROM users
GROUP BY device
ORDER BY user_count DESC;

-- Question 4: Calculate order count and total spending for each user

SELECT user_id, COUNT(*) AS order_count, SUM(amount) AS total_amount
FROM orders
GROUP BY user_id
ORDER BY total_amount DESC;

-- Question 5: Find users with total spending above 100

SELECT user_id, SUM(amount) AS total_amount
FROM orders
GROUP BY user_id
HAVING total_amount > 100
ORDER BY total_amount DESC;

-- Question 6: Join users and orders to view user information for each order

SELECT *
FROM users u
JOIN orders o ON o.user_id = u.user_id;

-- Question 7: Calculate average order amount by device

SELECT device, AVG(amount) AS average_amount
FROM users u
JOIN orders o ON o.user_id = u.user_id
GROUP BY device
ORDER BY average_amount DESC;

-- Question 8: Count purchase events by traffic source

SELECT traffic_source, COUNT(*) AS purchase_count
FROM events
WHERE event_type = 'purchase'
GROUP BY traffic_source
ORDER BY purchase_count DESC;

-- Question 9: Calculate purchase conversion rate by traffic source

WITH source_metrics AS (
    SELECT traffic_source, 
    COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END) AS view_users, 
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchase_users
    FROM events
    GROUP BY traffic_source
)

SELECT
    traffic_source,
    view_users,
    purchase_users,
    1.0 * purchase_users / NULLIF(view_users, 0) AS purchase_conversion_rate
FROM source_metrics
ORDER BY purchase_conversion_rate DESC;

-- Question 10: Use a CTE to find high-value users

WITH high_value AS (
    SELECT user_id, SUM(amount) as total_amount, COUNT(order_id) AS order_counts
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
)

SELECT *
FROM users u
RIGHT JOIN high_value h ON h.user_id = u.user_id
WHERE total_amount > 200
ORDER BY total_amount DESC;