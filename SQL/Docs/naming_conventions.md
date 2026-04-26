# **Naming Conventions**

This document outlines the naming conventions used for schemas, tables, views, columns, and other objects in the data warehouse.

## **Table of Contents**

1. [General Principles](#general-principles)
2. [Column Naming Conventions](#column-naming-conventions)
   - [Surrogate Keys](#surrogate-keys)
3. [Stored Procedure](#stored-procedure-naming-conventions)
---

## **General Principles**

- **Naming Conventions**: Use Pascal_Snake_Cases, with each word capitalized and separated by underscores (_).
- **Language**: Use English for all names.
- **Avoid Reserved Words**: Do not use SQL reserved words as object names.


#### **Glossary of Category Patterns**

| Pattern     | Meaning                           | Example(s)                              |
|-------------|-----------------------------------|-----------------------------------------|
| `Dim_`      | Dimension table                  | `Dim_Date`, `Dim_Time`           |
| `Fact_`     | Fact table                       | `Fact_Transactiob`                            |
| `Agg_`      | Aggregated table                 | `Agg_Revenue`, `agg_sales_monthly`    |

## **Column Naming Conventions**

### **Surrogate Keys**  
- All primary keys in dimension tables must use the suffix `_key`.
- **`<Table_Name>_key`**  
  - `<Table_Name>`: Refers to the name of the table or entity the key belongs to.  
  - `_Key`: A suffix indicating that this column is a surrogate key.  
  - Example: `Route_key` → Surrogate key in the `Dim_Route` table.
  
 
## **Stored Procedure**

- All stored procedures used for loading data must follow the naming pattern:
- **`load_<layer>`**.
  
  - `<layer>`: Represents the layer being loaded, such as `bronze`, `silver`, or `gold`.
  - Example: 
    - `load_bronze` → Stored procedure for loading data into the Bronze layer.
    - `load_silver` → Stored procedure for loading data into the Silver layer.
