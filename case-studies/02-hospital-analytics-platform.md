# Case Study — Hospital Analytics Platform: 7-Page Power BI Executive Suite

**Client:** A private hospital in the Gulf (anonymized) · **Role:** BI Developer — end to end: SQL layer, data model, DAX, deployment
**Stack:** SQL Server, Power BI (Import mode), DAX, On-Premises Data Gateway, Power BI Service

---

## The Problem

Hospital leadership was running on manual Excel extracts pulled from the HIS by request — days old by the time they were read, inconsistent between departments, and blind to anything the extract didn't include. The executive team, finance manager, and IT consultant each needed a live, trustworthy view of the hospital's operations without asking anyone to run a report.

## The Approach

**1. A SQL view layer as the single source of truth.**
Every page sits on a dedicated `vw_PBI_` view inside the HIS database. All business logic — revenue classification (cash vs. insurance vs. copayment), billing-date rules, length-of-stay edge cases, appointment status mapping — lives in SQL, where it can be tested and reconciled in SSMS before Power BI ever sees it. DAX handles aggregation only.

**2. Star schema, Import mode, query folding preserved.**
Views were designed so Power Query folds every transformation back to the server. On hospital hardware, that's the difference between a gateway refresh that streams quietly and one that eats server RAM.

**3. Validation before visuals.**
Each view was verified with reconciliation queries against source tables — totals, row counts, and edge cases (same-day discharges, canceled admissions, null payer logic) — and business rules were confirmed with the client before being locked in.

## What Was Delivered

A seven-page executive suite:

| Page | What leadership sees |
|---|---|
| **Revenue** | Gross / net / discount, cash vs. insurance vs. copayment split, by department, doctor, and payer |
| **Comparison** | Year-over-year revenue variance with green/red indicators |
| **Collections** | Collected vs. to-collect, balance with dynamic color, by cashier, fund, and payment method |
| **OPD Visits** | Visit volumes, new vs. returning patients, by department and doctor |
| **Admissions** | Admissions, average length of stay, live bed occupancy %, by ward class |
| **Appointments** | Completion, cancellation, and no-show rates by doctor |
| **Patients** | Demographics: age groups, gender, nationality, acquisition source |

## Deployment — the half most freelancers skip

- On-premises Data Gateway installed and configured against the hospital's SQL Server, behind its firewall.
- Daily scheduled refresh in the client's timezone, with failure notifications.
- Published as a Power BI **App** with viewer roles for the CEO, finance manager, and IT consultant — external users provisioned as Azure AD guests.

## The Result

- Leadership moved from days-old Excel extracts to a self-serve suite refreshed daily.
- One agreed set of numbers across finance, operations, and management — reconciled to the HIS.
- The architecture (view layer + star schema + folding-friendly design) became the template now reused across additional hospital deployments.

## The Takeaway

A hospital dashboard succeeds or fails **below the visuals**: in the billing-date rules, the payer logic, and the deployment plumbing. Get those right and the charts are the easy part.
