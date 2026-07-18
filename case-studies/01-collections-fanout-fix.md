# Case Study — Fixing a Bug That Inflated Reported Cash

**Client:** A private hospital (anonymized) · **Role:** BI Developer — SQL data layer, DAX measures, dashboard design
**Stack:** SQL Server, Power BI, DAX

---

## The Problem

The hospital's collections dashboard was overstating cash. Totals on the dashboard didn't match the finance department's own numbers — and a dashboard that finance doesn't trust is worse than no dashboard at all, because every meeting turns into an argument about whose number is right.

The overstatement wasn't constant, which made it harder to spot: some days reconciled perfectly, others were inflated. That pattern is a classic fingerprint of a data-grain problem, not a calculation error.

## The Investigation

Instead of tweaking DAX, I went down to the data layer and compared **row counts** between the source payment transactions and the rows arriving in the model.

The culprit was a **fan-out**: the cashier funds table could hold multiple rows per receipt. Joining it to the payments table meant that a single payment was duplicated once per matching cashier row — and every duplicate carried the full payment amount. On days where cashiers had multiple fund rows, totals inflated; on clean days, they didn't.

```
Payment (1 row, 100 JOD)
   └── JOIN cashier_funds  ──►  2 matching rows
                                = 2 rows × 100 JOD
                                = 200 JOD reported   ❌
```

## The Solution

I rebuilt the collections view so the join could never multiply rows:

- Replaced the direct join with an **OUTER APPLY (TOP 1)** pattern — guaranteeing exactly one cashier row per receipt, deterministically ordered.
- Kept the whole fix inside the SQL view layer so the Power BI model and DAX measures stayed untouched, and query folding was preserved for the gateway.
- Wrote reconciliation queries comparing the view's totals against raw source transactions, per day and per cashier.

## The Result

- Dashboard totals now reconcile with the finance department's records exactly.
- The corrected view became the standard collections pattern reused on later hospital deployments.
- Finance signed off, and the collections page went from "the number we argue about" to the number the daily meeting starts from.

## The Takeaway

Most dashboard "calculation bugs" are actually **grain bugs** living in the joins underneath. Fixing them in the SQL layer — instead of patching over them with DAX — is what makes a dashboard permanently trustworthy.
