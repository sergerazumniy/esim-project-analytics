# Data Dictionary

Two CSV files, covering January 1 – February 28, 2026. Both are committed to this repository as-is.

> About this data: it was generated for a take-home analytics exercise and is fully synthetic - no real users, orders, or personal data. That is why it is safe to publish here in full, unlike a real production export.

## **users_jan_feb_2026.csv**

One row per registered user (~26.9k rows).

| Column | Type | Description |
|---|---|---|
| **user_id** | integer | Unique user identifier (primary key). |
| **registered_date** | date | Date the user registered. |
| **country** | text | User's country at registration (14 distinct values). |
| **platform** | text | Platform used to register: **ios**, **android**, or **web**. |
| **acquisition_channel** | text | Marketing channel that brought the user in: **organic**, **paid_social**, **paid_search**, **referral**, or **affiliate**. |

## **orders_jan_feb_2026.csv**

One row per order (~3.6k rows).

| Column | Type | Description |
|---|---|---|
| **order_id** | integer | Unique order identifier (primary key). |
| **user_id** | integer | Foreign key to **users.user_id**. Every order has a matching user. |
| **created_date** | date | Date the order was placed. |
| **country** | text | Country the eSIM package was purchased for. |
| **packet_size_name** | text | Package/tariff name, e.g. **5 GB**, **Unlimited 30 days** (9 distinct values). |
| **price_eur** | numeric | Order value in EUR. |
| **order_status** | text | **paid** or **refunded**. |
| **platform** | text | Platform the order was placed on: **ios**, **android**, or **web**. |

## Known data quirks (checked in **notebooks/00_data_quality_and_overview.ipynb**)

- No missing values, no duplicate keys, no orders before their user's registration date.
- A user's registration country and an order's purchase country sometimes match in a way that looks too clean for real-world eSIM/roaming behavior. Treated as a synthetic-data artifact, not a data quality defect.
- Both months show the exact same within-month revenue ramp-up shape (low right after the 1st, rising toward month-end) - most likely an artifact of how the data was generated rather than a real seasonality pattern. See notebook **00** for details.
