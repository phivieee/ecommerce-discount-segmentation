--
-- E-Commerce Discount & Customer Segmentation Analysis
-- PostgreSQL SQL Pipeline
-
-- Purpose:
--   Rebuild the data preparation and analytical views used by
--   the Tableau project from data/dataset_raw.csv.
--
-- Main outputs:
--   vw_ecommerce_sales_clean
--   vw_sales_formula_check
--   vw_category_performance
--   vw_discount_analysis_by_level
--   vw_discount_analysis_by_category
--   vw_discount_analysis_by_product
--   vw_monthly_sales_trend
--   vw_payment_mode_analysis
--   vw_region_performance
--   vw_customer_features
--   vw_customer_segments
--   vw_repeat_customer_summary
--   vw_customer_segment_summary
--   vw_discount_by_customer_segment
--

-- 1. RAW DATA TABLE
--   
CREATE TABLE IF NOT EXISTS ecommerce_sales_raw (
    order_id        BIGINT,
    order_date      DATE,
    customer_name   TEXT,
    region          TEXT,
    city            TEXT,
    category        TEXT,
    sub_category    TEXT,
    product_name    TEXT,
    quantity        INTEGER,
    unit_price      NUMERIC(14,2),
    discount        NUMERIC(5,2),
    sales           NUMERIC(16,2),
    profit          NUMERIC(16,2),
    payment_mode    TEXT
);

-- 2. DATA CLEANING & TRANSFORMATION
-- 

DROP VIEW IF EXISTS vw_discount_by_customer_segment;
DROP VIEW IF EXISTS vw_customer_segment_summary;
DROP VIEW IF EXISTS vw_repeat_customer_summary;
DROP VIEW IF EXISTS vw_customer_segments;
DROP VIEW IF EXISTS vw_customer_features;
DROP VIEW IF EXISTS vw_region_performance;
DROP VIEW IF EXISTS vw_payment_mode_analysis;
DROP VIEW IF EXISTS vw_monthly_sales_trend;
DROP VIEW IF EXISTS vw_discount_analysis_by_product;
DROP VIEW IF EXISTS vw_discount_analysis_by_category;
DROP VIEW IF EXISTS vw_discount_analysis_by_level;
DROP VIEW IF EXISTS vw_category_performance;
DROP VIEW IF EXISTS vw_sales_formula_check;
DROP VIEW IF EXISTS vw_ecommerce_sales_clean;


CREATE VIEW vw_ecommerce_sales_clean AS
WITH prepared AS (
    SELECT
        order_id,
        order_date,
        TRIM(customer_name) AS customer_name,
        TRIM(region) AS region,
        TRIM(city) AS city,
        TRIM(category) AS category,
        TRIM(sub_category) AS sub_category,
        TRIM(product_name) AS product_name,
        TRIM(payment_mode) AS payment_mode,
        quantity,
        unit_price,
        discount,
        sales,
        profit,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY order_date, customer_name
        ) AS duplicate_rank
    FROM ecommerce_sales_raw
    WHERE order_id IS NOT NULL
      AND order_date IS NOT NULL
      AND customer_name IS NOT NULL
      AND quantity IS NOT NULL
      AND unit_price IS NOT NULL
      AND discount IS NOT NULL
      AND sales IS NOT NULL
      AND profit IS NOT NULL
      AND quantity > 0
      AND unit_price >= 0
      AND discount BETWEEN 0 AND 100
      AND sales >= 0
)
SELECT
    order_id,
    order_date,
    MD5(LOWER(TRIM(customer_name))) AS customer_key,
    customer_name,
    region,
    city,
    category,
    sub_category,
    product_name,
    payment_mode,
    quantity,
    unit_price::NUMERIC(14,2) AS unit_price,
    discount::NUMERIC(5,2) AS discount_pct,
    ROUND((quantity * unit_price)::NUMERIC, 2) AS gross_sales,
    ROUND(((quantity * unit_price) - sales)::NUMERIC, 2) AS discount_amount,
    sales::NUMERIC(16,2) AS net_sales,
    profit::NUMERIC(16,2) AS profit,
    ROUND(
        100.0 * profit / NULLIF(sales, 0),
        2
    ) AS profit_margin_pct,
    EXTRACT(YEAR FROM order_date)::INTEGER AS order_year,
    EXTRACT(MONTH FROM order_date)::INTEGER AS order_month,
    TO_CHAR(order_date, 'YYYY-MM') AS order_month_year
FROM prepared
WHERE duplicate_rank = 1;


-- Validation: check whether Sales follows
-- Quantity * Unit Price * (1 - Discount / 100).
CREATE VIEW vw_sales_formula_check AS
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE ABS(
            net_sales
            - ROUND(gross_sales * (1 - discount_pct / 100.0), 2)
        ) > 0.01
    ) AS mismatch_rows,
    ROUND(
        AVG(
            ABS(
                net_sales
                - ROUND(gross_sales * (1 - discount_pct / 100.0), 2)
            )
        ),
        2
    ) AS avg_difference
FROM vw_ecommerce_sales_clean;



-- 3. DISCOUNT, SALES & PROFITABILITY ANALYSIS
--

CREATE VIEW vw_category_performance AS
SELECT
    category,
    sub_category,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(net_sales), 2) AS net_revenue_after_discount,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(discount_pct), 2) AS avg_discount_pct,
    ROUND(SUM(discount_amount), 2) AS total_discount_amount
FROM vw_ecommerce_sales_clean
GROUP BY category, sub_category;


CREATE VIEW vw_discount_analysis_by_level AS
WITH discount_summary AS (
    SELECT
        discount_pct,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(quantity) AS total_quantity,
        SUM(gross_sales) AS gross_revenue_before_discount,
        SUM(discount_amount) AS total_discount_amount,
        SUM(net_sales) AS net_revenue_after_discount,
        SUM(profit) AS total_profit
    FROM vw_ecommerce_sales_clean
    GROUP BY discount_pct
)
SELECT
    discount_pct,
    total_orders,
    total_customers,
    total_quantity,
    ROUND(gross_revenue_before_discount, 2) AS gross_revenue_before_discount,
    ROUND(total_discount_amount, 2) AS total_discount_amount,
    ROUND(net_revenue_after_discount, 2) AS net_revenue_after_discount,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(
        net_revenue_after_discount / NULLIF(total_orders, 0),
        2
    ) AS avg_order_value,
    ROUND(
        total_profit / NULLIF(total_orders, 0),
        2
    ) AS avg_profit_per_order,
    ROUND(
        100.0 * total_profit / NULLIF(net_revenue_after_discount, 0),
        2
    ) AS profit_margin_pct,
    ROUND(
        100.0 * net_revenue_after_discount
        / NULLIF(SUM(net_revenue_after_discount) OVER (), 0),
        2
    ) AS revenue_share_pct,
    ROUND(
        100.0 * total_profit
        / NULLIF(SUM(total_profit) OVER (), 0),
        2
    ) AS profit_share_pct
FROM discount_summary;


CREATE VIEW vw_discount_analysis_by_category AS
SELECT
    category,
    discount_pct,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(gross_sales), 2) AS gross_revenue_before_discount,
    ROUND(SUM(discount_amount), 2) AS total_discount_amount,
    ROUND(SUM(net_sales), 2) AS net_revenue_after_discount,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(discount_pct), 2) AS avg_discount_pct,
    ROUND(
        SUM(net_sales) / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS avg_order_value
FROM vw_ecommerce_sales_clean
GROUP BY category, discount_pct;


CREATE VIEW vw_discount_analysis_by_product AS
SELECT
    category,
    sub_category,
    product_name,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    ROUND(AVG(discount_pct), 2) AS avg_discount_pct,
    ROUND(SUM(gross_sales), 2) AS gross_revenue_before_discount,
    ROUND(SUM(discount_amount), 2) AS total_discount_amount,
    ROUND(SUM(net_sales), 2) AS net_revenue_after_discount,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0),
        2
    ) AS profit_margin_pct
FROM vw_ecommerce_sales_clean
GROUP BY category, sub_category, product_name;


CREATE VIEW vw_monthly_sales_trend AS
SELECT
    order_month_year,
    MIN(order_date) AS month_start_date,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(gross_sales), 2) AS gross_revenue_before_discount,
    ROUND(SUM(discount_amount), 2) AS total_discount_amount,
    ROUND(SUM(net_sales), 2) AS net_revenue_after_discount,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(discount_pct), 2) AS avg_discount_pct
FROM vw_ecommerce_sales_clean
GROUP BY order_month_year;


CREATE VIEW vw_payment_mode_analysis AS
SELECT
    payment_mode,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(net_sales), 2) AS net_revenue_after_discount,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(discount_pct), 2) AS avg_discount_pct
FROM vw_ecommerce_sales_clean
GROUP BY payment_mode;


CREATE VIEW vw_region_performance AS
SELECT
    region,
    city,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(net_sales), 2) AS net_revenue_after_discount,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(discount_pct), 2) AS avg_discount_pct,
    ROUND(SUM(discount_amount), 2) AS total_discount_amount
FROM vw_ecommerce_sales_clean
GROUP BY region, city;


--
-- 4. CUSTOMER FEATURE ENGINEERING
--

CREATE VIEW vw_customer_features AS
WITH customer_base AS (
    SELECT
        customer_key,
        MIN(customer_name) AS customer_name,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(quantity) AS total_quantity,
        SUM(gross_sales) AS gross_revenue_before_discount,
        SUM(discount_amount) AS total_discount_amount,
        SUM(net_sales) AS total_spending,
        SUM(net_sales) / NULLIF(COUNT(DISTINCT order_id), 0) AS avg_order_value,
        SUM(profit) AS total_profit,
        100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0) AS profit_margin_pct,
        AVG(discount_pct) AS avg_discount_pct,
        COUNT(DISTINCT order_id) FILTER (
            WHERE discount_pct > 0
        ) AS discounted_order_count,
        COUNT(DISTINCT order_id) FILTER (
            WHERE discount_pct = 0
        ) AS non_discounted_order_count,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        COUNT(DISTINCT category) AS category_count,
        COUNT(DISTINCT sub_category) AS sub_category_count,
        COUNT(DISTINCT payment_mode) AS payment_mode_count
    FROM vw_ecommerce_sales_clean
    GROUP BY customer_key
),
favorite_category AS (
    SELECT customer_key, category AS favorite_category
    FROM (
        SELECT
            customer_key,
            category,
            ROW_NUMBER() OVER (
                PARTITION BY customer_key
                ORDER BY
                    COUNT(DISTINCT order_id) DESC,
                    SUM(net_sales) DESC,
                    category
            ) AS rn
        FROM vw_ecommerce_sales_clean
        GROUP BY customer_key, category
    ) ranked
    WHERE rn = 1
),
favorite_payment AS (
    SELECT customer_key, payment_mode AS favorite_payment_mode
    FROM (
        SELECT
            customer_key,
            payment_mode,
            ROW_NUMBER() OVER (
                PARTITION BY customer_key
                ORDER BY COUNT(DISTINCT order_id) DESC
            ) AS rn
        FROM vw_ecommerce_sales_clean
        GROUP BY customer_key, payment_mode
    ) ranked
    WHERE rn = 1
),
reference_date AS (
    SELECT MAX(order_date) + 1 AS analysis_date
    FROM vw_ecommerce_sales_clean
)
SELECT
    cb.customer_key,
    cb.customer_name,
    cb.total_orders,
    cb.total_quantity,
    ROUND(cb.gross_revenue_before_discount, 2) AS gross_revenue_before_discount,
    ROUND(cb.total_discount_amount, 2) AS total_discount_amount,
    ROUND(cb.total_spending, 2) AS total_spending,
    ROUND(cb.avg_order_value, 2) AS avg_order_value,
    ROUND(cb.total_profit, 2) AS total_profit,
    ROUND(cb.profit_margin_pct, 2) AS profit_margin_pct,
    ROUND(cb.avg_discount_pct, 2) AS avg_discount_pct,
    cb.discounted_order_count,
    cb.non_discounted_order_count,
    ROUND(
        100.0 * cb.discounted_order_count / NULLIF(cb.total_orders, 0),
        2
    ) AS discount_order_pct,
    cb.first_order_date,
    cb.last_order_date,
    (rd.analysis_date - cb.last_order_date)::INTEGER AS recency_days,
    cb.category_count,
    cb.sub_category_count,
    cb.payment_mode_count,
    fc.favorite_category,
    fp.favorite_payment_mode,
    CASE
        WHEN cb.total_orders > 1 THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS repeat_status
FROM customer_base cb
CROSS JOIN reference_date rd
LEFT JOIN favorite_category fc
    ON cb.customer_key = fc.customer_key
LEFT JOIN favorite_payment fp
    ON cb.customer_key = fp.customer_key;


--
-- 5. RFM & CUSTOMER SEGMENTATION
-- 

CREATE VIEW vw_customer_segments AS
WITH scored AS (
    SELECT
        cf.*,

        -- More recent customers receive a higher score.
        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS recency_score,

        -- Customers with more orders receive a higher score.
        NTILE(5) OVER (
            ORDER BY total_orders ASC
        ) AS frequency_score,

        -- Higher spending receives a higher score.
        NTILE(5) OVER (
            ORDER BY total_spending ASC
        ) AS monetary_score

    FROM vw_customer_features cf
),
rfm_labeled AS (
    SELECT
        s.*,
        ROUND(
            (recency_score + frequency_score + monetary_score)::NUMERIC / 3.0,
            2
        ) AS rfm_score,

        CASE
            WHEN recency_score >= 4
             AND frequency_score >= 4
             AND monetary_score >= 4
                THEN 'Champion'

            WHEN frequency_score >= 4
             AND monetary_score >= 4
                THEN 'Big Spender'

            WHEN recency_score <= 2
             AND frequency_score >= 3
                THEN 'At Risk Customer'

            WHEN recency_score >= 4
             AND frequency_score <= 2
                THEN 'New / Recent Customer'

            ELSE 'Regular Customer'
        END AS rfm_segment,

        CASE
            WHEN discounted_order_count = 0
                THEN 'Non Discount Buyer'

            WHEN discount_order_pct = 100
             AND avg_discount_pct >= 15
                THEN 'High Discount Dependent'

            WHEN discount_order_pct = 100
             AND avg_discount_pct >= 10
                THEN 'Moderate Discount Sensitive'

            ELSE 'Mixed Buyer'
        END AS discount_behavior_segment,

        CASE
            WHEN profit_margin_pct >= 20
                THEN 'High Margin Customer'
            WHEN profit_margin_pct >= 10
                THEN 'Healthy Margin Customer'
            ELSE 'Low Margin Customer'
        END AS profitability_segment

    FROM scored s
),
final_segment AS (
    SELECT
        r.*,
        CASE
            WHEN discount_behavior_segment = 'High Discount Dependent'
             AND profitability_segment = 'Low Margin Customer'
                THEN 'Discount Seeker - Low Margin'

            WHEN discount_behavior_segment = 'High Discount Dependent'
                THEN 'Discount Seeker'

            WHEN profitability_segment = 'Low Margin Customer'
             AND rfm_segment IN (
                 'Champion',
                 'Big Spender',
                 'Regular Customer'
             )
                THEN 'Low Margin Customer'

            WHEN rfm_segment = 'Champion'
                THEN 'High Value / Champion'

            WHEN rfm_segment = 'Big Spender'
                THEN 'Profitable Big Spender'

            WHEN rfm_segment = 'New / Recent Customer'
                THEN 'New / Recent Customer'

            WHEN rfm_segment = 'At Risk Customer'
                THEN 'At Risk Customer'

            ELSE 'Regular Customer'
        END AS customer_segment
    FROM rfm_labeled r
)
SELECT
    customer_key,
    customer_name,
    total_orders,
    total_quantity,
    gross_revenue_before_discount,
    total_discount_amount,
    total_spending,
    avg_order_value,
    total_profit,
    profit_margin_pct,
    avg_discount_pct,
    discounted_order_count,
    non_discounted_order_count,
    discount_order_pct,
    first_order_date,
    last_order_date,
    recency_days,
    category_count,
    sub_category_count,
    payment_mode_count,
    favorite_category,
    favorite_payment_mode,
    repeat_status,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_score,
    rfm_segment,
    discount_behavior_segment,
    profitability_segment,
    customer_segment
FROM final_segment;


-- 
-- 6. CUSTOMER SEGMENT SUMMARY
-- 
CREATE VIEW vw_repeat_customer_summary AS
SELECT
    repeat_status,
    COUNT(*) AS total_customers,
    ROUND(SUM(total_spending), 2) AS total_spending,
    ROUND(SUM(total_profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(total_profit) / NULLIF(SUM(total_spending), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(total_orders::NUMERIC), 2) AS avg_orders_per_customer,
    ROUND(AVG(avg_discount_pct), 2) AS avg_discount_pct
FROM vw_customer_segments
GROUP BY repeat_status;


CREATE VIEW vw_customer_segment_summary AS
SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(SUM(total_spending), 2) AS total_spending,
    ROUND(SUM(total_profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(total_profit) / NULLIF(SUM(total_spending), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(total_orders::NUMERIC), 2) AS avg_orders_per_customer,
    ROUND(AVG(avg_order_value), 2) AS avg_order_value,
    ROUND(AVG(avg_discount_pct), 2) AS avg_discount_pct,
    ROUND(AVG(discount_order_pct), 2) AS avg_discount_order_pct,
    COUNT(*) FILTER (
        WHERE repeat_status = 'Repeat Customer'
    ) AS repeat_customers,
    COUNT(*) FILTER (
        WHERE repeat_status = 'One-Time Customer'
    ) AS one_time_customers
FROM vw_customer_segments
GROUP BY customer_segment;


--
-- 7. DISCOUNT PERFORMANCE BY CUSTOMER SEGMENT
--
CREATE VIEW vw_discount_by_customer_segment AS
SELECT
    cs.customer_segment,
    cs.rfm_segment,
    cs.discount_behavior_segment,
    cs.profitability_segment,
    ec.discount_pct,
    COUNT(DISTINCT ec.order_id) AS total_orders,
    COUNT(DISTINCT ec.customer_key) AS total_customers,
    SUM(ec.quantity) AS total_quantity,
    ROUND(SUM(ec.gross_sales), 2) AS gross_revenue_before_discount,
    ROUND(SUM(ec.discount_amount), 2) AS total_discount_amount,
    ROUND(SUM(ec.net_sales), 2) AS net_revenue_after_discount,
    ROUND(SUM(ec.profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(ec.profit) / NULLIF(SUM(ec.net_sales), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(ec.discount_pct), 2) AS avg_discount_pct
FROM vw_ecommerce_sales_clean ec
JOIN vw_customer_segments cs
    ON ec.customer_key = cs.customer_key
GROUP BY
    cs.customer_segment,
    cs.rfm_segment,
    cs.discount_behavior_segment,
    cs.profitability_segment,
    ec.discount_pct;


-- 
-- 8. OPTIONAL INDEXES
--
-- These indexes improve repeated analysis on the raw table.

CREATE INDEX IF NOT EXISTS idx_ecommerce_raw_order_id
    ON ecommerce_sales_raw(order_id);

CREATE INDEX IF NOT EXISTS idx_ecommerce_raw_order_date
    ON ecommerce_sales_raw(order_date);

CREATE INDEX IF NOT EXISTS idx_ecommerce_raw_customer_name
    ON ecommerce_sales_raw(customer_name);

CREATE INDEX IF NOT EXISTS idx_ecommerce_raw_category
    ON ecommerce_sales_raw(category);

CREATE INDEX IF NOT EXISTS idx_ecommerce_raw_discount
    ON ecommerce_sales_raw(discount);


-- 
-- 9. VALIDATION QUERIES
-- 
-- Expected from the supplied project dataset:
--   cleaned orders       : 5,000
--   unique customers     : 4,844
--   net sales            : 533,666,024.35
--   total profit         : 79,708,734.91
--   overall profit margin: ~14.94%
--   date range           : 2023-10-04 to 2025-10-03

SELECT
    COUNT(*) AS cleaned_orders,
    COUNT(DISTINCT customer_key) AS unique_customers,
    ROUND(SUM(net_sales), 2) AS total_net_sales,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0),
        2
    ) AS overall_profit_margin_pct,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM vw_ecommerce_sales_clean;

SELECT *
FROM vw_sales_formula_check;

SELECT *
FROM vw_discount_analysis_by_level
ORDER BY discount_pct;

SELECT *
FROM vw_customer_segment_summary
ORDER BY total_spending DESC;
