# Optimizing COD Logistics Routing

### A Data-Driven Logistics Partner Selection Framework Using Python, SQL & Power BI

This project explores how an e-commerce business can make better delivery-partner decisions for **Cash on Delivery (COD)** orders. Rather than choosing a logistics provider solely on the upfront shipping charge, the routing framework considers **Return to Origin (RTO) risk**, expected reverse-logistics cost, serviceability, and order value.

> **Project scope:** This is a proof-of-concept built using **10,000 simulated orders** and historical-style risk assumptions. The reported results are simulation outputs, not verified operational results for Meesho, Valmo, or any other company.

## Business Problem

When a customer rejects or does not accept a COD order, the shipment may return to the seller. This **Return to Origin (RTO)** creates additional logistics expense because the seller may pay for both forward and reverse transportation.

The central question is:

**How can we select a delivery partner for each order while minimizing expected RTO-related logistics loss?**

The prototype compares two options:

- **Valmo:** A lower-cost delivery option in the simulated setup, with limited PIN-code serviceability.
- **Third-Party Logistics (3PL):** A broader-coverage alternative used when Valmo is unavailable or the order exceeds a defined value threshold.

## Objectives

- Analyze RTO patterns across payment types and delivery locations.
- Estimate the expected financial impact of an RTO for each carrier.
- Apply transparent, rule-based routing decisions at the order level.
- Evaluate routing allocation and costs against a simple all-3PL baseline.
- Present the findings through a Power BI dashboard.

## Tech Stack

| Tool | Purpose |
| --- | --- |
| **Python** | Data simulation, expected-loss calculations, and routing logic |
| **pandas / NumPy** | Data transformation and numerical operations |
| **SQL** | RTO analysis, risk segmentation, and savings queries |
| **Power BI** | Visual analysis of risk, allocation, carrier costs, and financial impact |
| **Google Colab / Jupyter** | Development and execution of the routing prototype |

## Project Workflow

```text
Simulated Order Data (10,000 orders)
              |
              v
     SQL-Based RTO Analysis
              |
              v
  Historical PIN-Level Risk Input
              |
              v
  Expected Monetary Value (EMV)
              |
              v
  Serviceability + Value Rules
              |
              v
      Partner Assignment
              |
              v
    Export Results to CSV
              |
              v
       Power BI Dashboard
```

## Methodology

### 1. Data preparation

The simulated order data includes attributes such as order value, payment type, delivery PIN-code risk, Valmo serviceability, and carrier costs.

### 2. RTO risk analysis

SQL is used to examine RTO patterns by payment type and PIN code, including risk tiers and geographic concentrations of failed deliveries.

### 3. Expected Monetary Value (EMV)

The prototype estimates the **expected RTO-related loss** using:

```text
EMV Loss = P(RTO) × (Forward Shipping Cost + Reverse Shipping Cost)
```

For the baseline implementation, reverse shipping cost is assumed to be approximately equal to forward shipping cost:

```text
EMV_Valmo = Historical_PIN_Risk × (2 × Valmo_Cost)
EMV_3PL   = Historical_PIN_Risk × (2 × 3PL_Cost)
```

**Example:** If the historical RTO probability is 30% and Valmo's forward shipping cost is ₹40, its estimated RTO loss is `0.30 × (₹40 + ₹40) = ₹24`.

This is an expected **RTO-loss component**, not a complete model of every shipping or business cost.

### 4. Routing decision rules

The engine applies the following rules in order:

1. **Serviceability:** If Valmo does not serve the destination, assign **3PL**.
2. **High-value protection:** If the order value is **above ₹2,200**, assign **3PL**.
3. **Expected-loss comparison:** Otherwise, select the partner with the lower EMV; ties go to **Valmo**.

```python
import numpy as np

# Assumption: reverse shipping cost equals forward shipping cost.
df['EMV_Valmo'] = df['Historical_PIN_Risk'] * (df['Valmo_Cost'] * 2)
df['EMV_3PL'] = df['Historical_PIN_Risk'] * (df['3PL_Cost'] * 2)

def route_order(row):
    if not row['Valmo_Serviceable']:
        return '3PL'
    if row['Order_Value_INR'] > 2200:
        return '3PL'
    return 'Valmo' if row['EMV_Valmo'] <= row['EMV_3PL'] else '3PL'

df['Assigned_Partner'] = df.apply(route_order, axis=1)
df['Final_Fulfillment_Cost'] = np.where(
    df['Assigned_Partner'] == 'Valmo',
    df['Valmo_Cost'],
    df['3PL_Cost']
)
```

> **Important modeling limitation:** The Phase 1 implementation uses the same historical PIN-level RTO probability for both carriers. Therefore, when all other assumptions are equal, the EMV comparison mainly reflects differences in carrier cost. A genuinely carrier-risk-sensitive model would estimate **P(RTO | order, carrier)** separately for each partner.

## Results From the Simulated Scenario

| Metric | Reported Result |
| --- | ---: |
| Orders simulated | **10,000** |
| Orders routed to Valmo | **68%** |
| Average RTO rate across PIN codes | **24.7%** |
| Reported relative COD expected-loss difference | **80% higher than prepaid** |

**Note:** The **68%** figure is the share of orders allocated to Valmo, **not** a 68% cost reduction. Results depend on the simulated data and assumptions and should not be treated as production-validated savings.

## Power BI Dashboard

The dashboard is designed to communicate:

- **RTO risk:** Patterns by payment type, PIN code, and risk segment.
- **Carrier comparison:** Valmo versus 3PL cost and expected-loss estimates.
- **Routing allocation:** Distribution of orders between the two partners.
- **Financial impact:** Fulfillment-cost comparisons against an all-3PL baseline.

## SQL Analysis

The SQL component covers:

- RTO rate by payment type.
- Highest-risk PIN codes, with a minimum-order threshold.
- Per-order expected-loss and routing logic.
- Monthly cost comparison with an all-3PL baseline.
- Low-, medium-, and high-risk segmentation.

SQL syntax may require minor adaptation to the target database engine.

## Repository Contents

The project materials include a Python/Colab routing notebook, a Power BI-ready CSV dataset, a Power BI dashboard, SQL reference queries, and a project presentation. Refer to the files in this repository for their exact names.

## Limitations

- **Synthetic data:** The dataset demonstrates the approach but does not establish real-world carrier performance.
- **Shared carrier risk:** Both partners use the same historical PIN-level RTO estimate in Phase 1.
- **Simplified cost model:** The baseline EMV focuses on RTO-related shipping loss and assumes similar forward/reverse shipping costs.
- **Rule-based routing:** The current solution is a decision framework, **not a trained machine-learning model**.
- **No live A/B test:** Business impact has not been verified through real-world controlled experimentation.

## Future Improvements

1. Use real operational data with carrier-specific delivery and RTO outcomes.
2. Predict order- and carrier-specific RTO probabilities using features such as PIN code, customer history, product category, and delivery characteristics.
3. Introduce a fuller expected-cost function that includes forward fulfillment, reverse logistics, delivery failure, and service-quality penalties.
4. Incorporate capacity constraints and real-time carrier serviceability.
5. Validate routing decisions through an A/B test against the existing allocation strategy.

## Key Takeaway

This project demonstrates how **SQL-based risk analysis**, **Python decision logic**, and **Power BI reporting** can be combined to build an explainable logistics-routing prototype. Its main contribution is a structured approach to evaluating delivery-partner decisions in terms of **expected financial impact**, rather than upfront shipping cost alone.

---

**Project:** Optimizing COD Logistics Routing  
**Author:** Udit Jaiswal  
**Focus:** Business Analytics · Logistics Optimization · Decision Analytics
