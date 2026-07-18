/* =====================================================================
   Script 05 — Billing & Collections
   ORDERANDBILLING.PATIENT_STATEMENT  (one per encounter)
   ORDERANDBILLING.BILL_SERVICES      (~12,000 service lines)
   ORDERANDBILLING.STATEMENT_TRANSACTIONS (~3,000 payments/refunds)
   Encodes the real HIS billing pattern: insurance encounters split into
   Credit lines (PAYER_ID set) + Copayment lines (PAYER_ID NULL),
   cash encounters are fully patient-paid.
   ===================================================================== */

USE HIS;
GO

/* ================= PATIENT_STATEMENT ================= */
CREATE TABLE ORDERANDBILLING.PATIENT_STATEMENT (
    ID              INT      NOT NULL PRIMARY KEY,
    PATIENT_ID      INT      NOT NULL,
    PATIENT_TYPE_ID INT      NOT NULL,   -- 1 IPD / 2 OPD
    ENCOUNTER_ID    INT      NOT NULL,   -- visit or admission ID
    STATUS          INT      NOT NULL,   -- 1 Open / 3 Issued / 4 Canceled
    ISSUE_DATE      DATETIME NULL,
    DISCHARGE_DATE  DATETIME NULL,
    CREATED_DATE    DATETIME NOT NULL
);
GO

/* OPD statements: one per visit (IDs 1..3000) */
INSERT INTO ORDERANDBILLING.PATIENT_STATEMENT
    (ID, PATIENT_ID, PATIENT_TYPE_ID, ENCOUNTER_ID, STATUS, ISSUE_DATE, DISCHARGE_DATE, CREATED_DATE)
SELECT
    v.ID, v.PATIENT_ID, 2, v.ID,
    CASE WHEN v.STATUS = 2 THEN 3 ELSE 1 END,       -- closed visit => issued
    CASE WHEN v.STATUS = 2 THEN v.VISIT_DATE END,
    NULL,
    v.VISIT_DATE
FROM CORE.PATIENT_VISITS v;

/* IPD statements: one per admission (IDs 10001..10600) */
INSERT INTO ORDERANDBILLING.PATIENT_STATEMENT
    (ID, PATIENT_ID, PATIENT_TYPE_ID, ENCOUNTER_ID, STATUS, ISSUE_DATE, DISCHARGE_DATE, CREATED_DATE)
SELECT
    10000 + a.ID, a.PATIENT_ID, 1, a.ID,
    CASE WHEN a.STATUS = 6 THEN 4                    -- canceled admission => canceled statement
         WHEN a.STATUS = 5 THEN 3 ELSE 1 END,
    CASE WHEN a.STATUS = 5 THEN a.DISCHARGE_DATE END,
    a.DISCHARGE_DATE,
    a.ADMISSION_DATE
FROM ADMISSION.ADMISSIONS a;
GO

/* ================= BILL_SERVICES ================= */
CREATE TABLE ORDERANDBILLING.BILL_SERVICES (
    ID           INT           NOT NULL PRIMARY KEY,
    STATEMENT_ID INT           NOT NULL,
    ENCOUNTER_ID INT           NOT NULL,
    PATIENT_ID   INT           NOT NULL,
    STAFF_ID     INT           NULL,
    SECTION_ID   INT           NULL,
    ACTION_ID    INT           NULL,
    PAYER_ID     INT           NULL,     -- set = Credit line · NULL = patient-paid
    NET_AMOUNT   DECIMAL(12,2) NOT NULL,
    DISCOUNT_AMT DECIMAL(12,2) NOT NULL DEFAULT 0,
    STATUS       INT           NOT NULL DEFAULT 1,
    CREATED_DATE DATETIME      NOT NULL
);
GO

IF OBJECT_ID('tempdb..#b') IS NOT NULL DROP TABLE #b;

/* ~12,000 lines: OPD statements get 1-4 lines, IPD get 8-20 lines.
   Strategy: sample statements with repetition using a numbers table. */
;WITH nums AS (
    SELECT TOP (12000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT
    n,
    ABS(CHECKSUM(NEWID())) % 100 AS r_pick,      -- OPD vs IPD line pool
    ABS(CHECKSUM(NEWID())) % 3000 AS r_opd,
    ABS(CHECKSUM(NEWID())) % 600  AS r_ipd,
    ABS(CHECKSUM(NEWID())) % 100  AS r_payer,
    ABS(CHECKSUM(NEWID())) % 100  AS r_disc,
    ABS(CHECKSUM(NEWID())) % 8    AS r_payer_id,
    5 + ABS(CHECKSUM(NEWID())) % 146  AS amt_opd,
    20 + ABS(CHECKSUM(NEWID())) % 381 AS amt_ipd
INTO #b
FROM nums;

INSERT INTO ORDERANDBILLING.BILL_SERVICES
    (ID, STATEMENT_ID, ENCOUNTER_ID, PATIENT_ID, STAFF_ID, SECTION_ID, ACTION_ID,
     PAYER_ID, NET_AMOUNT, DISCOUNT_AMT, STATUS, CREATED_DATE)
SELECT
    b.n,
    ps.ID,
    ps.ENCOUNTER_ID,
    ps.PATIENT_ID,
    COALESCE(v.DOCTOR_ID, a.ADMISSION_DOCTOR),
    COALESCE(v.SECTION_ID, a.SECTION_ID),
    b.n,                                            -- synthetic ACTION_ID (must be NOT NULL for revenue)
    /* Insurance encounter: 80% of lines are Credit (payer set), 20% Copayment (NULL).
       Cash encounter: always NULL. */
    CASE WHEN COALESCE(v.DEALING_TYPE, a.DEALING_TYPE) = 1 AND b.r_payer < 80
         THEN 1 + b.r_payer_id ELSE NULL END,
    CASE WHEN ps.PATIENT_TYPE_ID = 2 THEN b.amt_opd ELSE b.amt_ipd END,
    CASE WHEN b.r_disc < 12
         THEN ROUND(0.10 * CASE WHEN ps.PATIENT_TYPE_ID = 2 THEN b.amt_opd ELSE b.amt_ipd END, 2)
         ELSE 0 END,
    1,
    ps.CREATED_DATE
FROM #b b
JOIN ORDERANDBILLING.PATIENT_STATEMENT ps
     ON ps.ID = CASE WHEN b.r_pick < 55 THEN 1 + b.r_opd            -- 55% of lines on OPD statements
                     ELSE 10001 + b.r_ipd END                        -- 45% on IPD statements
LEFT JOIN CORE.PATIENT_VISITS   v ON ps.PATIENT_TYPE_ID = 2 AND v.ID = ps.ENCOUNTER_ID
LEFT JOIN ADMISSION.ADMISSIONS  a ON ps.PATIENT_TYPE_ID = 1 AND a.ID = ps.ENCOUNTER_ID;

DROP TABLE #b;
GO

/* ================= STATEMENT_TRANSACTIONS (collections) ================= */
CREATE TABLE ORDERANDBILLING.STATEMENT_TRANSACTIONS (
    ID                   INT           NOT NULL PRIMARY KEY,
    PATIENT_STATEMENT_ID INT           NOT NULL,
    AMOUNT               DECIMAL(12,2) NOT NULL,
    PAYMENT_CODE         INT           NOT NULL,   -- 1 Payment / 2 Refund / 4 Down Payment
    PAYMENT_TYPE         INT           NOT NULL,   -- 1 Cash / 2 Cheque / 3 Card / 4 Transfer
    FUND_ID              INT           NOT NULL,
    CASHIER_ID           INT           NOT NULL,   -- -> CASHIER_FUNDS.ID
    STATUS               INT           NOT NULL DEFAULT 1,
    CREATED_DATE         DATETIME      NOT NULL
);
GO

IF OBJECT_ID('tempdb..#t') IS NOT NULL DROP TABLE #t;

;WITH nums AS (
    SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT
    n,
    ABS(CHECKSUM(NEWID())) % 100  AS r_code,
    ABS(CHECKSUM(NEWID())) % 100  AS r_type,
    1 + ABS(CHECKSUM(NEWID())) % 5 AS cashier_fund_id,
    ABS(CHECKSUM(NEWID())) % 3000 AS r_stmt
INTO #t
FROM nums;

INSERT INTO ORDERANDBILLING.STATEMENT_TRANSACTIONS
    (ID, PATIENT_STATEMENT_ID, AMOUNT, PAYMENT_CODE, PAYMENT_TYPE, FUND_ID, CASHIER_ID, STATUS, CREATED_DATE)
SELECT
    t.n,
    ps.ID,
    /* Pay ~ the patient-owed part of the statement (non-payer lines), capped for realism */
    ROUND(COALESCE(owed.PatientOwed, 40) * (0.5 + (t.r_type % 6) / 10.0), 2),
    CASE WHEN t.r_code < 85 THEN 1 WHEN t.r_code < 90 THEN 2 ELSE 4 END,
    CASE WHEN t.r_type < 55 THEN 1 WHEN t.r_type < 70 THEN 3
         WHEN t.r_type < 85 THEN 4 ELSE 2 END,
    cf.FUND_ID,
    cf.ID,
    1,
    DATEADD(HOUR, 2, ps.CREATED_DATE)
FROM #t t
JOIN ORDERANDBILLING.PATIENT_STATEMENT ps ON ps.ID = 1 + t.r_stmt   -- collections against OPD statements
JOIN ORDERANDBILLING.CASHIER_FUNDS cf ON cf.ID = t.cashier_fund_id
OUTER APPLY (
    SELECT SUM(bs.NET_AMOUNT) AS PatientOwed
    FROM ORDERANDBILLING.BILL_SERVICES bs
    WHERE bs.STATEMENT_ID = ps.ID AND bs.PAYER_ID IS NULL
) owed
WHERE ps.STATUS <> 4;

DROP TABLE #t;
GO

PRINT 'Script 05 complete.';
SELECT (SELECT COUNT(*) FROM ORDERANDBILLING.PATIENT_STATEMENT)       AS Statements,
       (SELECT COUNT(*) FROM ORDERANDBILLING.BILL_SERVICES)           AS BillLines,
       (SELECT COUNT(*) FROM ORDERANDBILLING.STATEMENT_TRANSACTIONS)  AS Transactions;
