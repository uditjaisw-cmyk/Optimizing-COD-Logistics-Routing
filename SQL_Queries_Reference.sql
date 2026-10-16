
--  DYNAMIC LOGISTICS ROUTING ENGINE — SQL REFERENCE




-- QUERY 1 — RTO Rate by Payment Type
-- Purpose : Identifies which payment method carries higher
--           return risk — foundational routing signal

SELECT
    Payment_Type,
    COUNT(Order_ID)                                             AS Total_Orders,
    ROUND(
        SUM(CASE WHEN Status = 'RTO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(Order_ID), 2
    )                                                           AS Historical_RTO_Pct,
    ROUND(AVG(Fulfillment_Cost), 2)                             AS Avg_Fulfillment_Cost
FROM Meesho_Fulfillment_Logs
GROUP BY Payment_Type
ORDER BY Historical_RTO_Pct DESC;

-- Expected output:
-- Payment_Type       | Total_Orders | Historical_RTO_Pct | Avg_Fulfillment_Cost
-- Cash on Delivery   |     7,500    |       45.2%        |        ₹56.80
-- Prepaid            |     2,500    |       10.1%        |        ₹48.20



-- QUERY 2 — Top 10 Highest-Risk PIN Codes
-- Purpose : Identifies dangerous delivery zones where
--           3PL routing may override Valmo's cost advantage

SELECT
    Destination_PIN,
    COUNT(Order_ID)                                             AS Total_Shipments,
    ROUND(
        SUM(CASE WHEN Status = 'RTO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(Order_ID), 2
    )                                                           AS RTO_Rate_Pct,
    ROUND(AVG(Forward_Cost), 2)                                 AS Avg_Forward_Cost,
    ROUND(AVG(Forward_Cost + Reverse_Cost), 2)                  AS Avg_Total_RTO_Cost
FROM Meesho_Fulfillment_Logs
WHERE Order_Date >= DATEADD(month, -6, GETDATE())
GROUP BY Destination_PIN
HAVING COUNT(Order_ID) >= 50          -- minimum volume for statistical reliability
ORDER BY RTO_Rate_Pct DESC
LIMIT 10;



-- QUERY 3 — EMV Calculation per Order
-- Purpose : Core routing query — computes expected loss for
--           both carriers and recommends optimal assignment

SELECT
    o.Order_ID,
    o.Order_Value,
    o.Payment_Method,
    o.Destination_PIN,
    r.Historical_RTO_Rate,
    c.Valmo_Rate,
    c.Third_Party_Rate,

    -- EMV Formula: P(RTO) × (C_forward + C_reverse)
    -- Assuming C_reverse ≈ C_forward → multiply by 2
    ROUND(r.Historical_RTO_Rate * (c.Valmo_Rate * 2), 2)        AS EMV_Valmo,
    ROUND(r.Historical_RTO_Rate * (c.Third_Party_Rate * 2), 2)  AS EMV_3PL,

    -- Routing Decision Logic
    CASE
        WHEN c.Valmo_Serviceable = 0                THEN '3PL'   -- Rule 1: no coverage
        WHEN o.Order_Value > 2200                   THEN '3PL'   -- Rule 2: high-value safety
        WHEN r.Historical_RTO_Rate * c.Valmo_Rate
           < r.Historical_RTO_Rate * c.Third_Party_Rate
                                                    THEN 'Valmo' -- Rule 3: EMV favors Valmo
        ELSE '3PL'                                               -- Rule 3: EMV favors 3PL
    END                                                          AS Recommended_Partner

FROM Orders o
JOIN RTO_Rate_Lookup r
    ON  o.Destination_PIN    = r.PIN_Code
    AND o.Payment_Method     = r.Payment_Type
JOIN Carrier_Rates c
    ON  o.Destination_PIN    = c.PIN_Code
WHERE o.Order_Date BETWEEN '2024-01-01' AND '2024-01-31'
ORDER BY o.Order_ID;



-- QUERY 4 — Monthly Savings Summary (Management Report)
-- Purpose : Quantifies financial impact of EMV routing
--           vs a naive all-3PL baseline strategy

SELECT
    FORMAT(Order_Date, 'yyyy-MM')                               AS Month,
    COUNT(*)                                                    AS Total_Orders,

    SUM(CASE WHEN Assigned_Partner = 'Valmo' THEN 1 ELSE 0 END) AS Valmo_Orders,
    SUM(CASE WHEN Assigned_Partner = '3PL'   THEN 1 ELSE 0 END) AS PL3_Orders,

    ROUND(
        SUM(CASE WHEN Assigned_Partner = 'Valmo' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1
    )                                                           AS Valmo_Pct,

    ROUND(AVG(Final_Fulfillment_Cost), 2)                       AS Avg_Actual_Cost,
    ROUND(AVG(Third_Party_Rate), 2)                             AS Avg_3PL_Baseline_Cost,
    ROUND(
        SUM(Third_Party_Rate - Final_Fulfillment_Cost), 0
    )                                                           AS Total_Monthly_Saving_INR

FROM Routed_Orders
GROUP BY FORMAT(Order_Date, 'yyyy-MM')
ORDER BY Month;



-- QUERY 5 — Carrier Performance by Risk Tier (Window Function)
-- Purpose : Compares carrier assignment patterns across
--           low / medium / high RTO risk zones

WITH RiskSegmented AS (
    SELECT
        Order_ID,
        Assigned_Partner,
        Final_Fulfillment_Cost,
        Historical_PIN_Risk,
        CASE
            WHEN Historical_PIN_Risk < 0.20 THEN 'Low Risk (<20%)'
            WHEN Historical_PIN_Risk < 0.40 THEN 'Medium Risk (20-40%)'
            ELSE                                 'High Risk (>40%)'
        END AS Risk_Tier
    FROM Routed_Orders
)
SELECT
    Risk_Tier,
    Assigned_Partner,
    COUNT(*)                                                    AS Order_Count,
    ROUND(AVG(Final_Fulfillment_Cost), 2)                       AS Avg_Cost,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (PARTITION BY Risk_Tier), 1
    )                                                           AS Pct_Within_Tier
FROM RiskSegmented
GROUP BY Risk_Tier, Assigned_Partner
ORDER BY Risk_Tier, Assigned_Partner;


