# Healthcare BI Portfolio — Mahdi Al-Suleiman

**Power BI Developer | Healthcare Analytics | SQL & Data Modeling**

I build Power BI dashboards for hospitals and clinics — on top of the messy, real-world databases that healthcare systems actually run on. My day job is building and supporting BI for a Hospital Information System (HIS) used by hospitals across Jordan, Kuwait, and Saudi Arabia, which means I work daily with billing tables holding millions of rows, insurance vs. cash revenue logic, admissions and length-of-stay rules, and the silent data-quality traps that make hospital dashboards lie.

📍 Amman, Jordan · 🌐 [Upwork Profile](https://www.upwork.com/freelancers/~01a8bb67789fe9d712)

---

## What's in this repository

### 📊 Case Studies — real client work, anonymized

| Case Study | The One-Line Story |
|---|---|
| [Collections Dashboard — Fixing a Bug That Inflated Reported Cash](case-studies/01-collections-fanout-fix.md) | A hospital's dashboard was overstating collections. I traced it to a fan-out join, rebuilt the data layer, and made the numbers reconcile with finance to the last unit. |
| [Hospital Analytics Platform — 7-Page Executive Suite](case-studies/02-hospital-analytics-platform.md) | A full executive BI suite (revenue, collections, admissions, outpatient visits, appointments, patients) built on a star schema with a SQL view layer, deployed live with daily refresh. |

All client names, real figures, and patient data have been removed. The stories, the technical decisions, and the results are real.

### 🗄️ Demo Hospital Database — built from scratch

A complete synthetic hospital database for SQL Server (13 tables across two databases), mirroring the structure of a real HIS: patients, visits, admissions, billing, collections, and appointments — populated with realistic distributions (Pareto-shaped doctor revenue, believable age and nationality mixes, correct status flows).

➡️ [demo-database/](demo-database/) — six generation scripts, fully commented, runnable end-to-end on SQL Server 2022.

This is the database behind the dashboard screenshots in my Upwork portfolio. It exists so I can demonstrate healthcare BI work publicly **without ever exposing a single row of real patient or client data.**

---

## How I work

- **All business logic lives in SQL views, not DAX.** DAX handles dynamic aggregation only. This keeps models fast, refreshes light, and logic testable in SSMS before it ever reaches Power BI.
- **Star schema, Import mode, query folding preserved.** Views are designed so the on-premises gateway streams folded queries instead of loading raw tables — a major difference in refresh RAM on hospital servers.
- **Validate before visualize.** Every view gets reconciliation queries against the source system (row counts, totals, edge cases) before a single visual is built.
- **Deployment is part of the job.** Gateways, scheduled/incremental refresh, workspace apps, and guest-user access — I deliver dashboards running in production, not .pbix files.

## Stack

SQL Server (T-SQL, views, stored procedures, SSRS) · Power BI (DAX, Power Query, Service, On-Premises Gateway, Incremental Refresh) · Healthcare/HIS domain (revenue cycle, encounters, payers, claims, OPD/IPD workflows)

---

*Interested in working together? Reach me on [Upwork](https://www.upwork.com/freelancers/~01a8bb67789fe9d712).*
