# Demo Hospital Database (SQL Server)

A complete synthetic Hospital Information System database, built from scratch for portfolio and demo purposes. It mirrors the structure of a real HIS — so I can demonstrate healthcare BI work publicly **without exposing a single row of real patient or client data.**

> ⚠️ **All data is synthetic.** Every patient, doctor, amount, and date is generated. Any resemblance to real records is coincidental.

## What it contains

- **Two databases:** `HIS` (core clinical + financial) and `Appointment` (scheduling)
- **13 tables** covering the full analytical surface of a hospital:
  patients, outpatient visits, admissions (with beds/rooms/classes), billing services, patient statements, collections/transactions, staff, organization sections, and appointments
- **Realistic synthetic data:**
  - ~2,500 patients · ~3,000 visits · ~600 admissions · ~12,000 billing rows · ~3,000 collection transactions · ~2,000 appointments
  - Pareto-shaped distributions (a few doctors generate most revenue, as in real hospitals)
  - Correct status flows (admission lifecycle, appointment statuses incl. no-shows, statement statuses)
  - Believable demographics: age distribution, gender mix, 13 nationalities, acquisition sources
  - Insurance vs. cash vs. copayment revenue logic matching real HIS billing patterns

## The scripts

Run in order on SQL Server 2019+ (built and tested on SQL Server 2022 Developer Edition):

| # | Script | Purpose |
|---|---|---|
| 01 | `01_create_databases.sql` | Creates the `HIS` and `Appointment` databases and schemas |
| 02 | `02_dimension_tables.sql` | Staff, sections, countries, beds/rooms/classes, lookup codes |
| 03 | `03_patients.sql` | Patient master with realistic demographics |
| 04 | `04_visits_admissions.sql` | Outpatient visits and inpatient admissions with correct status flows |
| 05 | `05_billing_collections.sql` | Billing services, patient statements, and collection transactions |
| 06 | `06_appointments.sql` | Appointments with date logic relative to the current date |

*(Script filenames may differ slightly — see the files in this folder.)*

## What it demonstrates

1. **Healthcare data modeling** — I can design a hospital schema end to end, not just query one.
2. **Synthetic data craft** — generating data that *behaves* like production data (distributions, edge cases, status flows), which is what makes demo dashboards look credible.
3. **T-SQL fluency** — set-based generation, temp-table materialization to avoid `NEWID()` pitfalls in joins, correct `DATE` vs `DATETIME` handling.

## Use it yourself

Feel free to run these scripts to get a practice hospital database for your own Power BI / SQL learning. Attribution appreciated.
