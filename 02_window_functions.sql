/*
SQL Analytics Practice - Day 2
Topic: Window Functions
Author: Yucheng Gao
Date: 2026-07-02

Tables used:

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

users
- user_id
- signup_date
- country
- device
*/

/*
Question 1: Rank each user's orders by order date

Business question:
For each user, assign a sequence number to their orders based on order date.
This helps identify whether an order is the user's first, second, third, etc. order.

Skills:
- ROW_NUMBER()
- PARTITION BY
- ORDER BY
*/

SELECT order_id, user_id, order_date, amount, ROW_NUMBER() OVER(PARTITION BY user_id, ORDER BY order_date) AS order_sequence
FROM orders
ORDER BY user_id, order_date;

/*
Question 2: Find each user's first order

Business question:
Identify the first order placed by each user.
This is commonly used to define first purchase date, new customer acquisition,
or cohort start date.

Skills:
- ROW_NUMBER()
- CTE
- Filtering ranked records
*/

WITH ordered AS (
    SELECT 
        order_id,
        user_id,
        order_date,
        amount,
        status,
        ROW NUMBER() OVER(
            PARTITION BY user_id
            ORDER BY order_date
        ) AS order_number
    FROM orders
)

SELECT 
    order_id,
    user_id,
    order_date,
    amount,
    status
FROM ordered
WHERE order_number = 1
ORDER BY user_id;

/*
Question 3: Find each user's most recent order

Business question:
Identify the latest order placed by each user.
This can be used for customer recency analysis, churn monitoring,
and lifecycle segmentation.

Skills:
- ROW_NUMBER()
- ORDER BY DESC
- CTE
*/

WITH ordered AS (
    SELECT 
        order_id,
        user_id,
        order_date,
        amount,
        status,
        ROW NUMBER() OVER(
            PARTITION BY user_id
            ORDER BY order_date DESC
        ) AS order_number
    FROM orders
)

SELECT 
    order_id,
    user_id,
    order_date,
    amount,
    status
FROM ordered
WHERE order_number = 1
ORDER BY user_id;

/*
Question 4: Calculate the time gap between each order and the previous order

Business question:
For each user's orders, calculate the previous order date and the number of days
between the current order and the previous order.
This is useful for repeat purchase behavior, churn analysis, and customer lifecycle analysis.

Skills:
- LAG()
- Date difference
- PARTITION BY user_id
*/

SELECT user_id, julianday(order_date) - julianday(prev_date)
FROM(
    SELECT 
        user_id, 
        order_date, 
        LAG(order_date) OVER(
            PARTITION BY user_id
            ORDER BY order_date 
        ) AS prev_date
    FROM orders
)
ORDER BY user_id, order_date;

/*
Question 5: Calculate cumulative spending for each user

Business question:
For each user, calculate cumulative spending after each order.
This helps track customer value growth over time.

Skills:
- SUM() OVER()
- PARTITION BY
- ORDER BY
- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
*/

SELECT 
    order_id,
    user_id,
    order_date,
    amount,
    SUM(amount) OVER(
        PARTITION BY user_id
        ORDER BY order_date
    ) AS spend_to_date
FROM orders
ORDER BY user_id, order_date;

/*
Question 6: Calculate daily GMV and cumulative GMV

Business question:
Calculate total completed order value by day, then calculate cumulative GMV over time.
This is commonly used in business performance tracking.

Skills:
- CTE
- Aggregation before window function
- SUM() OVER()
*/

WITH orderdata AS (
    SELECT
        order_date,
        COUNT(*) AS completed_order_count,
        SUM(amount) AS daily_gmv
    FROM orders
    WHERE status = 'completed'
    GROUP BY order_date
)

SELECT
    order_date,
    completed_order_count,
    daily_gmv,
    SUM(completed_order_count) OVER(
        ORDER BY order_date
    ) AS cumulative_order_count,
    SUM(daily_gmv) OVER(
        ORDER BY order_date
    ) AS cumulative_gmv
FROM orderdata
ORDER BY order_date;

/*
Question 7: Calculate 7-day moving average GMV

Business question:
Calculate daily GMV and smooth the trend using a 7-day moving average.
This helps reduce daily noise and reveal business trends.

Skills:
- AVG() OVER()
- Moving average
- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
*/

WITH daily_gmv AS (
    SELECT
        order_date,
        SUM(amount) AS gmv
    FROM orders
    WHERE status = 'completed'
    GROUP BY order_date
)

SELECT
    order_date,
    gmv,
    AVG(gmv) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS gmv_7day_moving_avg
FROM daily_gmv
ORDER BY order_date;

/*
Question 8: Find the top 3 users by spending within each traffic source

Business question:
For each traffic source, identify the top 3 users by completed order spending.
This can help analyze high-value users by acquisition channel.

Important note:
This query assumes that events can be used to connect users with traffic sources.
In real business data, attribution logic should be carefully defined to avoid duplicate counting.

Skills:
- DENSE_RANK()
- CTE
- Ranking within groups
*/

WITH user_source_spending AS (
    SELECT
        e.traffic_source,
        o.user_id,
        SUM(o.amount) AS total_amount
    FROM orders o
    LEFT JOIN events e
        ON o.user_id = e.user_id
    WHERE o.status = 'completed'
    GROUP BY
        e.traffic_source,
        o.user_id
),

ranked_users AS (
    SELECT
        traffic_source,
        user_id,
        total_amount,
        DENSE_RANK() OVER (
            PARTITION BY traffic_source
            ORDER BY total_amount DESC
        ) AS spending_rank
    FROM user_source_spending
)

SELECT
    traffic_source,
    user_id,
    total_amount,
    spending_rank
FROM ranked_users
WHERE spending_rank <= 3
ORDER BY traffic_source, spending_rank, total_amount DESC;

/*
Question 9: Find each user's first purchase event

Business question:
Identify the first purchase event for each user.
This is useful for activation analysis, conversion analysis, and cohort definition.

Skills:
- ROW_NUMBER()
- Filtering event_type
- CTE
*/

WITH numbered AS (
    SELECT
        user_id,
        event_id,
        event_date,
        traffic_source
        ROW_NUMBER() OVER(
            PARTITION BY user_id
            ORDER BY event_date
        ) AS rank
    FROM events
    WHERE event_type = 'purchase'
)

SELECT 
    user_id,
    event_id,
    event_date,
    traffic_source,
FROM numbered
WHERE rank = 1
ORDER BY user_id;

/*
Question 10: Calculate the time gap between consecutive user events

Business question:
For each user, compare every event with the previous event and calculate the number
of days since the previous event.
This can be used for user journey analysis, session behavior, and time-to-conversion analysis.

Skills:
- LAG()
- Previous event type
- Previous event date
- Date difference
*/

WITH compare AS (
    SELECT
        user_id,
        event_id,
        event_type,
        event_date,
        LAG(event_date) OVER(
            PARTITION BY user_id
            ORDER BY event_date
        ) AS last_event_date
    FROM events
)

SELECT 
    user_id,
    event_id,
    event_type,
    event_date,
    last_event_date,
    julianday(event_date) - julianday(last_event_date) AS time_gap
FROM compare
ORDER BY user_id, event_date;
    
