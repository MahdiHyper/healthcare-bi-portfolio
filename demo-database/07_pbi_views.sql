/* =====================================================================
   Script 07 — The Power BI View Layer (vw_PBI_*)
   This is the actual BI architecture the dashboards sit on:
   ALL business logic lives here in SQL — DAX only aggregates.
   Views are single-record grain (no GROUP BY) and fold cleanly
   through Power Query, keeping gateway refreshes light.
   ===================================================================== */

USE HIS;
GO

/* ---------- 1. Revenue ---------- */
CREATE VIEW dbo.vw_PBI_BillServices AS
SELECT
    bls.ID,
    bls.STATEMENT_ID,
    bls.ENCOUNTER_ID,
    bls.NET_AMOUNT,
    bls.DISCOUNT_AMT,
    bls.NET_AMOUNT + bls.DISCOUNT_AMT AS GROSS_AMOUNT,
    bls.PAYER_ID,
    bls.PATIENT_ID,
    bls.STAFF_ID,
    bls.SECTION_ID,
    pst.PATIENT_TYPE_ID,
    CAST(COALESCE(pst.ISSUE_DATE, pst.CREATED_DATE) AS DATE) AS BILLING_DATE,
    /* Revenue classification — the heart of hospital billing:
       Credit    = insurance company pays (PAYER_ID set)
       Copayment = patient's share of an insurance encounter
       Cash      = fully patient-paid encounter                     */
    CASE
        WHEN bls.PAYER_ID > 0 THEN 'Credit'
        WHEN COALESCE(vis.DEALING_TYPE, adm.DEALING_TYPE) = 1 THEN 'Copayment'
        ELSE 'Cash'
    END AS REVENUE_TYPE,
    CASE pst.PATIENT_TYPE_ID WHEN 1 THEN 'IPD' ELSE 'OPD' END AS PATIENT_TYPE_LABEL
FROM ORDERANDBILLING.BILL_SERVICES bls
JOIN ORDERANDBILLING.PATIENT_STATEMENT pst ON bls.STATEMENT_ID = pst.ID
LEFT JOIN CORE.PATIENT_VISITS  vis ON pst.PATIENT_TYPE_ID = 2 AND bls.ENCOUNTER_ID = vis.ID
LEFT JOIN ADMISSION.ADMISSIONS adm ON pst.PATIENT_TYPE_ID = 1 AND bls.ENCOUNTER_ID = adm.ID
WHERE bls.STATUS = 1
  AND bls.NET_AMOUNT >= 0
  AND bls.ACTION_ID IS NOT NULL
  AND pst.STATUS = 3;                       -- Issued statements only
GO

/* ---------- 2. OPD Visits ---------- */
CREATE VIEW dbo.vw_PBI_Visits AS
SELECT
    vis.ID,
    vis.PATIENT_ID,
    vis.SECTION_ID,
    vis.DOCTOR_ID,
    vis.DEALING_TYPE,
    vis.STATUS,
    CAST(vis.VISIT_DATE AS DATE) AS DATE_KEY,
    CASE pat.GENDER_ID WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' ELSE '-' END AS GENDER
FROM CORE.PATIENT_VISITS vis
LEFT JOIN CORE.PATIENTS pat ON vis.PATIENT_ID = pat.ID;
GO

/* ---------- 3. Admissions ---------- */
CREATE VIEW dbo.vw_PBI_Admissions AS
SELECT
    adm.ID,
    adm.PATIENT_ID,
    adm.SECTION_ID,
    adm.BED_ID,
    adm.DEALING_TYPE,
    adm.STATUS,
    adm.ADMISSION_DATE,
    adm.DISCHARGE_DATE,
    CAST(adm.ADMISSION_DATE AS DATE) AS DATE_KEY,
    /* Length-of-stay edge cases learned the hard way in production:
       canceled = 0 · same-day active = 1 · discharge <= admission = 1  */
    CASE
        WHEN adm.STATUS = 6 THEN 0
        WHEN adm.DISCHARGE_DATE IS NULL
             THEN IIF(DATEDIFF(DAY, adm.ADMISSION_DATE, GETDATE()) = 0, 1,
                      DATEDIFF(DAY, adm.ADMISSION_DATE, GETDATE()))
        WHEN DATEDIFF(DAY, adm.ADMISSION_DATE, adm.DISCHARGE_DATE) <= 0 THEN 1
        ELSE DATEDIFF(DAY, adm.ADMISSION_DATE, adm.DISCHARGE_DATE)
    END AS LENGTH_OF_STAY,
    CASE adm.STATUS
        WHEN 1 THEN 'In-Hospital'      WHEN 2 THEN 'Release Permission'
        WHEN 3 THEN 'Drug Card Closed' WHEN 4 THEN 'Finance Settled'
        WHEN 5 THEN 'Final Discharge'  WHEN 6 THEN 'Canceled'
        ELSE 'None'
    END AS ADMISSION_STATUS
FROM ADMISSION.ADMISSIONS adm;
GO

/* ---------- 4. Appointments (cross-database reference) ---------- */
CREATE VIEW dbo.vw_PBI_Appointments AS
SELECT
    app.ID,
    COALESCE(app.PATIENT_ID, -1) AS PATIENT_ID,   -- protect against NULLs dropping rows in DAX filters
    app.RESOURCE_ID,
    app.GENDER_ID,
    app.STATUS,
    CAST(app.[DATE] AS DATE) AS DATE_KEY,
    /* Past Booked/Confirmed that never happened = No Show */
    CASE
        WHEN app.STATUS IN (1, 2) AND CAST(app.[DATE] AS DATE) < CAST(GETDATE() AS DATE) THEN 'No Show'
        WHEN app.STATUS IN (3, 6) THEN 'Completed'
        WHEN app.STATUS = 1 THEN 'Booked'
        WHEN app.STATUS = 2 THEN 'Confirmed'
        WHEN app.STATUS = 4 THEN 'Cancelled'
        WHEN app.STATUS = 5 THEN 'No Show'
    END AS APPOINTMENT_STATUS,
    CASE app.GENDER_ID WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' ELSE '-' END AS GENDER
FROM Appointment.APPOINTMENT.APPOINTMENTS app;
GO

/* ---------- 5. Patients ---------- */
CREATE VIEW dbo.vw_PBI_Patients AS
SELECT
    pat.ID,
    pat.GENDER_ID,
    pat.NATIONALITY_ID,
    pat.HearUs,
    CAST(pat.CREATED_DATE AS DATE) AS DATE_KEY,
    DATEDIFF(YEAR, pat.BIRTH_DATE, GETDATE()) AS AGE,
    CASE
        WHEN DATEDIFF(YEAR, pat.BIRTH_DATE, GETDATE()) < 18 THEN '0 - 17'
        WHEN DATEDIFF(YEAR, pat.BIRTH_DATE, GETDATE()) < 35 THEN '18 - 34'
        WHEN DATEDIFF(YEAR, pat.BIRTH_DATE, GETDATE()) < 50 THEN '35 - 49'
        WHEN DATEDIFF(YEAR, pat.BIRTH_DATE, GETDATE()) < 65 THEN '50 - 64'
        ELSE '65+'
    END AS AGE_GROUP,
    CASE pat.GENDER_ID WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' ELSE '-' END AS GENDER,
    COALESCE(cou.TITLE, 'Not Specified') AS NATIONALITY_LABEL,
    COALESCE(cod.TITLE, 'Not Specified') AS SOURCE_LABEL
FROM CORE.PATIENTS pat
LEFT JOIN CORE.COUNTRIES cou ON pat.NATIONALITY_ID = cou.ID
LEFT JOIN CORE.CODES cod ON pat.HearUs = cod.ID AND cod.GROUP_CODE = 'HEAR_US' AND cod.IS_ACTIVE = 1;
GO

/* ---------- 6. Collections ---------- */
CREATE VIEW dbo.vw_PBI_Collections AS
SELECT
    str.ID,
    str.PATIENT_STATEMENT_ID AS STATEMENT_ID,
    str.AMOUNT,
    str.PAYMENT_CODE,
    str.PAYMENT_TYPE,
    str.FUND_ID,
    CAST(str.CREATED_DATE AS DATE) AS DATE_KEY,
    pst.PATIENT_ID,
    pst.PATIENT_TYPE_ID,
    fun.TITLE AS FUND_NAME,
    stf.FULL_NAME AS CASHIER_NAME,
    CASE str.PAYMENT_CODE WHEN 1 THEN 'Payment' WHEN 2 THEN 'Refund' WHEN 4 THEN 'Down Payment' END AS PAYMENT_CODE_LABEL,
    CASE str.PAYMENT_TYPE WHEN 1 THEN 'Cash' WHEN 2 THEN 'Cheque'
                          WHEN 3 THEN 'Credit Card' WHEN 4 THEN 'Bank Transfer' END AS PAYMENT_METHOD_LABEL,
    CASE pst.PATIENT_TYPE_ID WHEN 1 THEN 'IPD' WHEN 2 THEN 'OPD' ELSE 'Other' END AS PATIENT_TYPE_LABEL
FROM ORDERANDBILLING.STATEMENT_TRANSACTIONS str
LEFT JOIN ORDERANDBILLING.FUNDS fun         ON str.FUND_ID = fun.ID
LEFT JOIN ORDERANDBILLING.CASHIER_FUNDS caf ON str.CASHIER_ID = caf.ID
LEFT JOIN CORE.STAFF stf                    ON caf.STAFF_ID = stf.ID
LEFT JOIN ORDERANDBILLING.PATIENT_STATEMENT pst ON str.PATIENT_STATEMENT_ID = pst.ID
WHERE str.STATUS = 1
  AND str.PAYMENT_CODE IN (1, 2, 4);
GO

/* ---------- 7. Patient Account Balance (what remains to collect) ---------- */
CREATE VIEW dbo.vw_PBI_PatientAccountBalance AS
SELECT
    bls.PATIENT_ID,
    CAST(COALESCE(pst.ISSUE_DATE, pst.CREATED_DATE) AS DATE) AS DATE_KEY,
    bls.NET_AMOUNT AS Total_To_Collect
FROM ORDERANDBILLING.BILL_SERVICES bls
JOIN ORDERANDBILLING.PATIENT_STATEMENT pst ON bls.STATEMENT_ID = pst.ID
WHERE bls.STATUS = 1
  AND bls.NET_AMOUNT >= 0
  AND bls.ACTION_ID IS NOT NULL
  AND pst.STATUS <> 4                       -- everything alive except Canceled
  AND bls.PAYER_ID IS NULL;                 -- patient-owed only (Cash + Copayment)
GO

PRINT 'Script 07 complete — 7 Power BI views created.';
