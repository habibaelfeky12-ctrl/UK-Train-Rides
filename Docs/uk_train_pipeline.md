# 🚆 UK Train Transactions — Data Pipeline

![Status](https://img.shields.io/badge/Status-Production%20Ready-2ea44f?style=flat-square)
![Phases](https://img.shields.io/badge/Phases-7-0969da?style=flat-square)
![Errors Fixed](https://img.shields.io/badge/Errors%20Fixed-18-e36209?style=flat-square)
![Validation](https://img.shields.io/badge/Validation-100%25%20Pass-2ea44f?style=flat-square)
![Duplicates](https://img.shields.io/badge/Duplicates-Zero-2ea44f?style=flat-square)

> A complete 7-phase data engineering pipeline covering profiling, validation, cleaning, standardization, and production readiness for the UK Train Transactions Dataset.

---

## 📋 Pipeline Overview

| Phase | Name | Status |
|---|---|---|
| 01 | Raw Data & Source Layer | ✅ Complete |
| 02 | Data Profiling & Diagnostic Audit | ✅ Complete |
| 03 | Quality Checks & Validation Logic | ✅ Complete |
| 04 | Cleaning | ✅ Complete |
| 05 | Standardization | ✅ Complete |
| 06 | Post-Cleaning Validation | ✅ Complete |
| 07 | Final Dataset | ✅ Production Ready |

---

## Phase 01 — Raw Data & Source Layer

The project is built on the **UK Train Transactions Dataset**, a comprehensive log of railway operations, passenger ticket sales, and service performance metrics.

<details>
<summary><strong>📖 View Full Data Dictionary (18 Fields)</strong></summary>

<br>

| Field | Description |
|---|---|
| `Transaction ID` | Unique identifier for each ticket purchase |
| `Date of Purchase` | The date the ticket was bought |
| `Time of Purchase` | Exact timestamp of the transaction |
| `Purchase Type` | Whether the ticket was bought online or at a station |
| `Payment Method` | Financial instrument used — Contactless, Credit Card, or Debit Card |
| `Railcard` | Discount card type — Adult, Senior, Disabled, or No Railcard |
| `Ticket Class` | Travel category — Standard or First Class |
| `Ticket Type` | Booking flexibility — Advance, Off-Peak, or Anytime |
| `Price` | Final monetary value after applicable discounts |
| `Departure Station` | The station where the passenger boards |
| `Arrival Destination` | The final destination station |
| `Date of Journey` | Scheduled date of train departure |
| `Departure Time` | Scheduled departure time |
| `Arrival Time` | Scheduled arrival time at destination |
| `Actual Arrival Time` | Real-time recorded arrival at destination |
| `Journey Status` | Operational outcome — On-Time, Delayed, or Cancelled |
| `Reason for Delay` | Recorded cause of any service disruption |
| `Refund Request` | Whether a refund was submitted after a service issue |

</details>

---

## Phase 02 — Data Profiling & Diagnostic Audit

> A systematic diagnostic to identify data quality issues, structural inconsistencies, and logical conflicts **before** applying any transformations.

### 🔍 Key Findings

> [!WARNING]
> **Label Ambiguity — Railcard**
> Passengers without a discount card were labeled `"None"`, which is visually unclear in dashboards. Needs rebranding for reporting clarity.

> [!WARNING]
> **Terminology Fragmentation — Delay Reasons**
> Redundant categories found for the same issues — `"Staffing"` vs `"Staff Shortage"` and `"Weather"` vs `"Weather Conditions"`. This fragmentation skews analysis and creates split bars in visualizations.

> [!NOTE]
> **Semantic Misalignment — Ticket Types**
> Names like `"Advance"` and `"Anytime"` don't clearly communicate booking intent. Moving to functional terms like `"Pre-Booked"` and `"Instant-Booked"` would provide deeper business insight.

> [!CAUTION]
> **Status & Logic Anomalies — OTP Performance**
> Journeys labeled `"Delayed"` were found where Actual Arrival Time was equal to or earlier than Scheduled Arrival Time. This directly compromises On-Time Performance (OTP) metrics.

> [!CAUTION]
> **Data Consistency Gaps — Refunds & Delays**
> `"On Time"` journeys were found containing a recorded Delay Reason or Refund Request of `"Yes"` — logically impossible records requiring cleanup to maintain data purity and financial integrity.

> [!WARNING]
> **Missing Values — Null Fields**
> Nulls identified in Actual Arrival Time (correctly tied to Cancelled status) and Delay Reason (needs to be explicitly labeled `"No Delay"` for clean aggregation).

> [!NOTE]
> **Technical Data Types**
> Key temporal and financial fields were imported as `Text` or `General`, preventing mathematical operations like revenue calculation or journey duration analysis.

---

## Phase 03 — Quality Checks & Validation Logic

> A rigorous validation framework using custom **Power Query logic** to ensure every record adheres to logical and operational rules.

### 🧾 Record & Pricing

| Check | Purpose | Result |
|---|---|---|
| Duplicate Records | Verify no duplicate rows or Transaction IDs exist | ✅ `0 Errors` |
| Pricing Validation | Confirm all price values are greater than zero | ✅ `0 Errors` |

### ⏱️ Purchase & Timing

| Check | Purpose | Result |
|---|---|---|
| Purchase Date Logic | Purchase date and time always precede the journey | ✅ `0 Errors` |
| Pre-Booked Timing Rule | Pre-booked tickets purchased at least 24 hours before journey | ✅ `0 Errors` |

### 🗺️ Operational & Route

| Check | Purpose | Result |
|---|---|---|
| Route Consistency | No journey has identical departure and arrival stations | ✅ `0 Errors` |
| Arrival Time Completeness | All non-cancelled journeys have a recorded Actual Arrival Time | ✅ `0 Issues` |

### 🔄 Journey Status & Refund

| Check | Purpose | Result |
|---|---|---|
| Journey Status Accuracy | Status labels cross-checked against actual arrival times | ⚠️ `18 Fixed` |
| Refund Integrity | Refund requests not associated with "On Time" journeys | ✅ `0 Issues` |
| Off-Peak Usage Rules | Off-peak tickets not used during restricted peak hours on weekdays | ✅ `0 Violations` |

---

## Phase 04 — Cleaning

> Sanitizing the dataset through data type conversion, null handling, and targeted fixes to ensure full logical consistency.

### 🔢 Data Type Transformation

Fields imported as `Text` were re-cast to proper types, enabling revenue calculations and journey duration analysis.

| Field | From | To |
|---|---|---|
| Date of Purchase | Text | `Date` |
| Date of Journey | Text | `Date` |
| Departure / Arrival Times | Text | `Time` |
| Price | Text | `Decimal Number` |

### 🔲 Missing Values

All `null` values in **Delay Reason** replaced with `"No Delay"` to ensure completeness for visualization and aggregation.

### 🏷️ Strategic Data Fixes

<details>
<summary><strong>View All Transformations</strong></summary>

<br>

**Railcard Label**

| Before | After |
|---|---|
| `None` | `No Railcard` |

**Ticket Type Naming**

| Before | After |
|---|---|
| `Advance` | `Pre-Booked` |
| `Anytime` | `Instant-Booked` |

**Terminology Consolidation**

| Before | After |
|---|---|
| `Signal failure` | `Signal Failure` |
| `Staffing` | `Staff Shortage` |
| `Weather Conditions` | `Weather` |
| `Edinburgh` | `Edinburgh Waverley` |

</details>

### ✅ Status & Refund Corrections

For all **18 corrected journeys**, status labels were realigned to match actual arrival times.
For all `"On Time"` journeys:
- Delay Reason → set to `"No Delay"`
- Refund Request `"Yes"` → corrected to `"No"`

---

## Phase 05 — Standardization

> Ensuring a consistent, professional format across all text-based fields by removing noise and unifying casing.

| Task | Action | Purpose |
|---|---|---|
| ✂️ Whitespace Removal | Trim & Clean applied to all text columns | Eliminates hidden spaces causing grouping errors |
| 🔡 Proper Case | All station names and categories converted to Proper Case | Prevents `"london"` / `"LONDON"` / `"London"` from being treated as separate entries |
| 🧹 Character Cleanup | Non-printable and system characters stripped | Prevents formatting errors on export or in Power BI |

---

## Phase 06 — Post-Cleaning Validation

> A final audit to confirm the cleaning process introduced no new errors and all business rules remain intact.

| Audit Check | Result |
|---|---|
| Duplicate Detection | ✅ Zero duplicate records found |
| Business Logic Validation | ✅ All 18 corrected status errors accurately reflected |
| Data Consistency Verification | ✅ 100% naming consistency — no legacy labels remain |

---

## Phase 07 — Final Dataset

> The dataset has successfully completed all pipeline phases and is cleared for analytical modeling.

### 📊 Final Quality Summary

| Metric | Result |
|---|---|
| Duplicate Rows | ✅ Zero |
| Pricing Errors | ✅ Zero |
| Status Corrections Applied | ⚠️ 18 records corrected |
| Categorical Uniformity | ✅ 100% |
| Schema Type Consistency | ✅ Fully Typed |
| Power BI Integration | ✅ Optimized |

---

> [!IMPORTANT]
> **🚀 Status: Production Ready**
> The dataset is logically sound, structurally consistent, and fully verified against all railway operational rules. It is ready for the final modeling and visualization phase.
