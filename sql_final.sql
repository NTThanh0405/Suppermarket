--- Doanh thu theo danh mục 
SELECT 
    p.category_name,
    SUM(s.quantity_sold * s.unit_selling_price) AS total_revenue,
    SUM(s.quantity_sold) AS total_quantity,
    COUNT(DISTINCT s.date) AS days_sold
FROM sales s
JOIN products p ON s.item_code = p.item_code
WHERE s.sale_or_return = 'sale'
GROUP BY p.category_name
ORDER BY total_revenue DESC;

--- Top 10 sản phẩm bán chạy nhất (theo doanh thu)
SELECT 
    p.item_name,
    p.category_name,
    SUM(s.quantity_sold) AS total_qty,
    SUM(s.quantity_sold * s.unit_selling_price) AS total_revenue,
    AVG(s.unit_selling_price) AS avg_selling_price
FROM sales s
JOIN products p ON s.item_code = p.item_code
WHERE s.sale_or_return = 'sale'
GROUP BY p.item_code, p.item_name, p.category_name
ORDER BY total_revenue DESC
LIMIT 10;

--- Doanh thu theo ngày + so sánh với ngày trước
SELECT 
    date,
    SUM(quantity_sold * unit_selling_price) AS daily_revenue,
    LAG(SUM(quantity_sold * unit_selling_price)) OVER (ORDER BY date) AS prev_day_revenue,
    (SUM(quantity_sold * unit_selling_price) - 
     LAG(SUM(quantity_sold * unit_selling_price)) OVER (ORDER BY date)) / 
     NULLIF(LAG(SUM(quantity_sold * unit_selling_price)) OVER (ORDER BY date), 0) * 100 AS growth_pct
FROM sales
WHERE sale_or_return = 'sale'
GROUP BY date
ORDER BY date;

--- Lợi nhuận ước tính (bán lẻ - mua buôn - hao hụt)
SELECT 
    s.date,
    p.item_name,
    AVG(w.wholesale_price) AS avg_wholesale,
    AVG(s.unit_selling_price) AS avg_selling,
    l.loss_rate,
    SUM(s.quantity_sold) AS total_qty,
    SUM(s.quantity_sold * 
        (s.unit_selling_price - w.wholesale_price) * 
        (1 - l.loss_rate/100)
       ) AS estimated_gross_profit
FROM sales s
JOIN products p ON s.item_code = p.item_code
JOIN loss_rates l ON s.item_code = l.item_code
JOIN wholesale_prices w ON s.date = w.date AND s.item_code = w.item_code
WHERE s.sale_or_return = 'sale'
GROUP BY s.date, p.item_name, l.loss_rate
ORDER BY estimated_gross_profit DESC
LIMIT 20;

--- Danh mục có tỷ lệ hao hụt trung bình cao nhất
SELECT 
    p.category_name,
    AVG(l.loss_rate) AS avg_loss_rate,
    COUNT(*) AS number_of_items
FROM loss_rates l
JOIN products p ON l.item_code = p.item_code
GROUP BY p.category_name
ORDER BY avg_loss_rate DESC;

--- Sản phẩm hao hụt cao nhưng vẫn bán tốt
SELECT 
    p.item_name,
    l.loss_rate,
    SUM(s.quantity_sold) AS total_sold,
    SUM(s.quantity_sold * s.unit_selling_price) AS revenue
FROM loss_rates l
JOIN products p ON l.item_code = p.item_code
LEFT JOIN sales s ON l.item_code = s.item_code AND s.sale_or_return = 'sale'
WHERE l.loss_rate > 15
GROUP BY p.item_name, l.loss_rate
HAVING SUM(s.quantity_sold) > 100
ORDER BY l.loss_rate DESC;

--- So sánh doanh số khi có/không giảm giá
SELECT 
    discount,
    COUNT(*) AS transaction_count,
    AVG(quantity_sold) AS avg_quantity,
    SUM(quantity_sold * unit_selling_price) AS total_revenue,
    AVG(unit_selling_price) AS avg_selling_price
FROM sales
WHERE sale_or_return = 'sale'
GROUP BY discount;


--- Sản phẩm tăng trưởng doanh thu mạnh nhất 30 ngày gần nhất
WITH monthly AS (
    SELECT 
        item_code,
        DATE_FORMAT(date, '%Y-%m') AS month,
        SUM(quantity_sold * unit_selling_price) AS revenue
    FROM sales
    WHERE sale_or_return = 'sale'
    GROUP BY item_code, month
)
SELECT 
    m1.item_code,
    p.item_name,
    m1.revenue AS current_month,
    m2.revenue AS prev_month,
    (m1.revenue - m2.revenue) * 100.0 / m2.revenue AS growth_pct
FROM monthly m1
JOIN monthly m2 ON m1.item_code = m2.item_code 
    AND m1.month = DATE_FORMAT(DATE_ADD(STR_TO_DATE(m2.month,'%Y-%m'), INTERVAL 1 MONTH), '%Y-%m')
JOIN products p ON m1.item_code = p.item_code
ORDER BY growth_pct DESC
LIMIT 10;