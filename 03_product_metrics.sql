/*
SQL Analytics Practice - Day 3
Topic: Product Metrics
Author: Yucheng Gao
Date: 2026-07-03

Goal:
Practice common product analytics metrics used in Data Analyst and Product Analyst roles.
The focus is not complex modeling, but learning how to define business metrics,
identify the correct numerator and denominator, and translate product questions
into SQL queries.

Tables used:

1. users
- user_id
- signup_date
- country
- device

This table provides user-level attributes such as signup date, country, and device.
It is mainly used when segmenting product or order metrics by user characteristics.

2. orders
- order_id
- user_id
- order_date
- amount
- status

This table provides transaction-level order data.
It is mainly used to calculate completed order count, GMV, AOV, ARPU, repeat purchase rate,
and high-value users. In most revenue-related queries, only completed orders are included.

3. events
- event_id
- user_id
- event_date
- event_type
- traffic_source

This table provides user behavior event data.
It is mainly used to calculate DAU, purchase users, conversion rate, traffic-source performance,
and product engagement metrics.
*/

/*
Questions:

Question 1: Calculate Daily Active Users (DAU)
Business question:
For each day, count the number of unique users who generated at least one event.
This measures daily product activity and user engagement.
Tables used:
- events
Key metric:
- DAU = COUNT(DISTINCT user_id)
*/

SELECT
    event_date,
    COUNT(DISTINCT user_id) AS dau
FROM events
GROUP BY event_date
ORDER BY event_date;

/*
Question 2: Calculate daily purchase users
Business question:
For each day, count the number of unique users who completed a purchase event.
This measures how many users performed the target transaction behavior each day.
Tables used:
- events
Key metric:
- Daily purchase users = COUNT(DISTINCT user_id) where event_type = 'purchase'
*/

SELECT 
    event_date,
    COUNT(DISTINCt user_id) AS dpu
FROM events
WHERE event_type = 'purchase'
GROUP BY event_date
ORDER BY event_date;

/*
Question 3: Calculate daily purchase conversion rate
Business question:
For each day, calculate the share of product-view users who eventually purchased.
This helps evaluate whether daily traffic is converting into purchases.
Tables used:
- events
Key metrics:
- View users = users with event_type = 'view_product'
- Purchase users = users with event_type = 'purchase'
- Purchase conversion rate = purchase_users / view_users
*/

SELECT
    event_date,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchase_users,
    COUNT(DISTINCT CASE WHEN event_type = 'view_product' THEN user_id END) AS view_users,
    1.0 * COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) 
        / NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'view_product' THEN user_id END), 0) AS purchase_conversion_rate
FROM events
GROUP BY event_date 
ORDER BY event_date;

/*
Question 4: Calculate daily completed GMV
Business question:
For each day, calculate total completed order value and completed order count.
This measures daily revenue performance based only on valid completed orders.
Tables used:
- orders
Key metrics:pur
- Completed order count
- Daily GMV = SUM(amount) where status = 'completed'
*/

SELECT 
    order_date,
    COUNT(order_id) AS order_count，
    SUM(amount) AS gmv
FROM orders
WHERE status = 'completed'
GROUP BY order_date
ORDER BY order_date;

/*
Question 5: Calculate daily Average Order Value (AOV)
Business question:
For each day, calculate the average value of completed orders.
This helps understand whether revenue changes are driven by order volume or order size.
Tables used:
- orders
Key metric:
- AOV = daily_gmv / completed_order_count
*/

WITH dgmv AS(
    SELECT 
    order_date,
    COUNT(order_id) AS order_count，
    SUM(amount) AS gmv
FROM orders
WHERE status = 'completed'
GROUP BY order_date
)

SELECT 
    order_date,
    gmv / order_count
FROM dgmv
ORDER BY order_date;

/*
Question 6: Calculate daily Average Revenue Per User (ARPU)
Business question:
For each day, calculate completed GMV divided by daily active users.
This measures average monetization per active user.
Tables used:
- events
- orders
Key metrics:
- DAU from events
- Daily GMV from completed orders
- ARPU = daily_gmv / DAU
*/

WITH daily_active AS (
    SELECT
        event_date,
        COUNT(DISTINCT user_id) AS dau
    FROM events
    GROUP BY event_date
),

daily_revenue AS (
    SELECT
        order_date,
        SUM(amount) AS daily_gmv
    FROM orders
    WHERE status = 'completed'
    GROUP BY order_date
)

SELECT
    a.event_date,
    a.dau,
    COALESCE(r.daily_gmv, 0) AS daily_gmv,
    1.0 * COALESCE(r.daily_gmv, 0) / NULLIF(a.dau, 0) AS arpu
FROM daily_active a
LEFT JOIN daily_revenue r
    ON a.event_date = r.order_date
ORDER BY a.event_date;

/*
Question 7: Calculate conversion rate by traffic source
Business question:
Compare active users, product-view users, purchase users, and purchase conversion rate
across traffic sources to understand which acquisition channels bring higher-intent users.
Tables used:
- events
Key metrics:
- Active users
- View users
- Purchase users
- Purchase conversion rate by traffic_source
*/

SELECT
    traffic_source,
    COUNT(DISTINCT user_id) AS active_users,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchase_users,
    COUNT(DISTINCT CASE WHEN event_type = 'view_product' THEN user_id END) AS view_users,
    1.0 * COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) 
        / NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'view_product' THEN user_id END), 0) AS purchase_conversion_rate
FROM events
GROUP BY traffic_source 
ORDER BY purchase_conversion_rate DESC;

/*
Question 8: Calculate order performance by device
Business question:
Compare completed order count, GMV, and AOV across user devices.
This helps identify whether mobile, desktop, or tablet users generate different order value.
Tables used:
- orders
- users
Key metrics:
- Completed order count by device
- Total GMV by device
- AOV by device
*/

SELECT
    u.device,
    COUNT(o.order_id) AS completed_order_count,
    SUM(o.amount) AS total_gmv,
    1.0 * SUM(o.amount) / NULLIF(COUNT(o.order_id), 0) AS aov
FROM orders o
LEFT JOIN users u
    ON o.user_id = u.user_id
WHERE o.status = 'completed'
GROUP BY u.device
ORDER BY total_gmv DESC;

/*
Question 9: Calculate repeat purchase rate
Business question:
Among users with completed orders, calculate the percentage of users who placed
at least two completed orders. This measures basic customer loyalty and repeat behavior.
Tables used:
- orders
Key metrics:
- Purchasing users = users with at least one completed order
- Repeat purchase users = users with at least two completed orders
- Repeat purchase rate = repeat_purchase_users / purchasing_users
*/

WITH userorder AS (
    SELECT 
        user_id,
        COUNT(*) AS total_orders
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
)

SELECT 
    1.0 * COUNT(CASE WHEN total_orders > 1 THEN user_id END)
        / NULLIF(COUNT(*), 0) AS repeat_purchase_rate
FROM userorder;

/*
Question 10: Identify high-value users
Business question:
Calculate total completed spending per user and identify users whose cumulative spending
exceeds a selected threshold. This supports customer segmentation and targeted marketing.
Tables used:
- orders
- users
Key metrics:
- Completed order count per user
- Total completed spending per user
- High-value users where total_spending >= 200
*/

WITH a AS (
    SELECT
        user_id,
        COUNT(order_id) AS order_count,
        SUM(amount) AS total_spend
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
)

SELECT
    a.user_id,
    u.country,
    u.device,
    a.order_count,
    a.total_spend
FROM a
LEFT JOIN users u
    ON a.user_id = u.user_id
WHERE a.total_spend >= 200
ORDER BY a.total_spend DESC;

/*
Core SQL skills practiced:
- Aggregation with GROUP BY
- COUNT(DISTINCT ...)
- CASE WHEN for conditional metrics
- CTE-based query organization
- Joining behavior, order, and user tables
- Revenue metrics using completed-order filters
- Product metric numerator and denominator definition
- Segment-level analysis by traffic_source and device
*/