# Financial Transaction Anomaly Detection

Rule-based fraud detection on 85,000+ transactions using SQL, Excel & Power BI. Flags high-risk transactions across 5 fraud signals and segments them into HIGH / MEDIUM / LOW risk tiers.



## Problem Statement
Online payment fraud costs Indian businesses crores annually. This project builds a rule-based fraud detection system to identify high-risk transactions from 85,000+ records and segment them into actionable risk tiers.

## Tools Used
- SQL (DB Browser for SQLite) — fraud detection queries and risk scoring
- MS Excel — data preprocessing, cleaning, and summary dashboard
- Power BI — interactive dashboard for stakeholder reporting

## Dataset
Credit Card Fraud Detection dataset from Kaggle.
85,000+ transaction records with 12 variables including channel, location, login attempts, device, and transaction amount.

## Key Findings
- Overall anomaly rate: 20.1%
- 68% of all flagged transactions came from the online channel
- Peak fraud activity detected between 2–4 AM
- HIGH risk transactions averaged ₹28,450 vs ₹3,800 in LOW risk tier
- 12 accounts triggered 3 or more fraud signals simultaneously

## Files in This Repo
- `project1_transaction_anomaly.sql` — all SQL queries used in the analysis
- `project1_transaction_anomaly.xlsx` — cleaned dataset, summary dashboard, Power BI export tab
- `project1_transaction_anomaly.pptx` — presentation deck with findings and recommendations
