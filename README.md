# E-Commerce Discount & Customer Segmentation Analysis

## Project Overview

This project analyses e-commerce transaction data to understand how discount levels affect sales and profitability, while also identifying customer groups based on purchasing behaviour and customer value.

The analysis uses **SQL/PostgreSQL** to prepare clean analytical datasets and customer segments, then uses **Tableau** to analyse the results and present them through interactive dashboards. The main business focus is to determine whether higher discounts actually improve commercial performance and which customer segments contribute the most value.

## Objective

- Analyse the relationship between **discount level, net sales, profit, and profit margin**.
- Compare discount performance across different product categories.
- Identify customer groups based on **spending, profitability, discount behaviour, and RFM characteristics**.
- Compare the behaviour and profitability of **repeat customers and one-time customers**.
- Identify high-value customer segments that can support more effective promotional strategies.
- Present the findings in an interactive Tableau dashboard for easier business decision-making.

## Tools Used

- **PostgreSQL / SQL: Data Cleaning & Transformation**  
  Used to prepare the raw transaction data, build clean analytical views, aggregate business metrics, and create customer segmentation datasets.

- **SQL: Analysis Preparation**  
  Used to calculate metrics such as net revenue, total profit, profit margin, average order value, discount performance, customer features, repeat purchasing behaviour, and segment-level performance.

- **Tableau: Analysis & Visualization**  
  Used to explore patterns in the prepared SQL datasets and build interactive dashboards for discount analysis and customer segmentation.

## Workflow Process


1. **Raw Data**  
   E-commerce transaction data is stored in CSV format and contains order, customer, product, discount, sales, profit, region, and payment information.

2. **Data Cleaning**  
   The raw dataset is checked and prepared before analysis so that transaction fields are consistent and ready to be used in SQL-based calculations.

3. **Transformation**  
   SQL/PostgreSQL is used to create analytical views, aggregate business metrics, calculate customer-level features, classify repeat customers, and build customer segments.

4. **Analysis**  
   The transformed datasets are analysed to compare discount levels, profitability, customer value, category performance, payment methods, and purchasing behaviour.

5. **Visualization**  
   Tableau is used to turn the analysis into interactive dashboards that make the main patterns, comparisons, and business insights easier to interpret.

## Dataset

The dataset contains **5,000 e-commerce orders** from **4 October 2023 to 3 October 2025**, representing **4,844 unique customers** across four regions and ten product categories.

| Field | Description |
|---|---|
| `Order ID` | Unique transaction identifier |
| `Order Date` | Transaction date |
| `Customer Name` | Customer name |
| `Region` | Customer region |
| `City` | Customer city |
| `Category` | Product category |
| `Sub-Category` | Product sub-category |
| `Product Name` | Product name |
| `Quantity` | Number of units purchased |
| `Unit Price` | Price per unit |
| `Discount` | Discount percentage applied |
| `Sales` | Net sales value after discount |
| `Profit` | Profit generated from the order |
| `Payment Mode` | Customer payment method |

**Dataset summary:**

- Total Orders: **5,000**
- Unique Customers: **4,844**
- Net Sales: **533.67 million**
- Total Profit: **79.71 million**
- Overall Profit Margin: **14.94%**
- Discount Levels: **0%, 5%, 10%, 15%, and 20%**

## Insights

- The **5% discount level** produces the highest overall profit margin at approximately **15.22%**, suggesting that a small discount can perform better than deeper discount levels from a profitability perspective.

- Orders with a **20% discount** generate approximately **96.61 million** in net revenue from **1,021 orders**, while orders with **no discount** generate approximately **117.11 million** from only **998 orders**. This indicates that more discounted orders do not automatically create higher revenue.

- Average order value decreases from approximately **117.34 thousand** at **0% discount** to approximately **94.62 thousand** at **20% discount**, showing that deeper discounts are associated with lower revenue per order in this dataset.

- The **Profitable Big Spender** segment is the strongest contributor, generating approximately **147.73 million** in total spending and **25.70 million** in profit.

- The **High Value / Champion** segment contributes approximately **108.91 million** in spending with a profit margin of approximately **17.28%**, making it another important segment for retention-focused strategies.

- **Discount Seeker** customers receive an average discount of approximately **17.54%** while maintaining a profit margin of approximately **17.32%**, showing that discount-sensitive customers can still remain commercially valuable when targeted appropriately.

- Repeat customers represent only **154 customers**, compared with **4,690 one-time customers**, but repeat customers achieve a slightly higher profit margin of approximately **15.59%** versus **14.89%** for one-time customers. This highlights an opportunity to improve customer retention.

- **Net Banking** generates the highest net revenue among payment methods at approximately **111.47 million**.

Overall, the analysis shows that **higher discounts do not necessarily produce better business performance**. A more targeted discount strategy based on customer value and profitability is likely to be more effective than applying deeper discounts broadly.
