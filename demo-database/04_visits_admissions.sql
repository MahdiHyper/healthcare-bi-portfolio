/* =====================================================================
   Script 04 — CORE.PATIENT_VISITS (3,000) + ADMISSION.ADMISSIONS (600)
   Pareto-shaped doctor volumes (a few doctors carry most visits, as in
   real hospitals), correct status lifecycles, and length-of-stay logic.
   ===================================================================== */

USE HIS;
GO

/* ================= OPD VISITS ================= */
CREATE TABLE CORE.PATIENT_VISITS (
    ID           INT      NOT NULL PRIMARY KEY,
    PATIENT_ID   INT      NOT NULL,
    SECTION_ID   INT      NULL,
    DOCTOR_ID    INT      NULL,
    DEALING_TYPE INT      NULL,      -- 1 Insurance / 2 Cash
    STATUS       INT      NULL,      -- 1 Open / 2 Closed
    VISIT_DATE   DATETIME NULL
);
GO

IF OBJECT_ID('tempdb..#v') IS NOT NULL DROP TABLE #v;

;WITH nums AS (
    SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT
    n,
    1 + ABS(CHECKSUM(NEWID())) % 2500 AS patient_id,
    ABS(CHECKSUM(NEWID())) % 100      AS r_doc,       -- Pareto selector
    ABS(CHECKSUM(NEWID())) % 40       AS r_doc_any,
    ABS(CHECKSUM(NEWID())) % 100      AS r_dealing,
    ABS(CHECKSUM(NEWID())) % 100      AS r_status,
    ABS(CHECKSUM(NEWID())) % 540      AS r_day,       -- last ~18 months
    ABS(CHECKSUM(NEWID())) % 600      AS r_min        -- time of day
INTO #v
FROM nums;

INSERT INTO CORE.PATIENT_VISITS (ID, PATIENT_ID, SECTION_ID, DOCTOR_ID, DEALING_TYPE, STATUS, VISIT_DATE)
SELECT
    v.n,
    v.patient_id,
    s.SECTION,
    doc.DOCTOR_ID,
    CASE WHEN v.r_dealing < 55 THEN 1 ELSE 2 END,      -- 55% insurance
    CASE WHEN v.r_status < 95 THEN 2 ELSE 1 END,       -- 5% still open
    DATEADD(MINUTE, 480 + v.r_min, DATEADD(DAY, -v.r_day, CAST(CAST(GETDATE() AS DATE) AS DATETIME)))
FROM #v v
CROSS APPLY (SELECT CASE
                 WHEN v.r_doc < 60 THEN 1 + v.r_doc % 8          -- top 8 doctors take 60% of volume
                 ELSE 1 + v.r_doc_any % 40
             END AS DOCTOR_ID) doc
JOIN CORE.STAFF s ON s.ID = doc.DOCTOR_ID;

DROP TABLE #v;
GO

/* ================= IPD ADMISSIONS ================= */
CREATE TABLE ADMISSION.ADMISSIONS (
    ID               INT      NOT NULL PRIMARY KEY,
    PATIENT_ID       INT      NOT NULL,
    SECTION_ID       INT      NULL,     -- IPD floor
    BED_ID           INT      NULL,
    ADMISSION_DOCTOR INT      NULL,
    DEALING_TYPE     INT      NULL,     -- 1 Credit / 2 Cash
    STATUS           INT      NULL,     -- 1..6 lifecycle
    ADMISSION_DATE   DATETIME NULL,
    DISCHARGE_DATE   DATETIME NULL
);
GO

IF OBJECT_ID('tempdb..#a') IS NOT NULL DROP TABLE #a;

;WITH nums AS (
    SELECT TOP (600) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT
    n,
    1 + ABS(CHECKSUM(NEWID())) % 2500 AS patient_id,
    1 + ABS(CHECKSUM(NEWID())) % 60   AS bed_id,
    1 + ABS(CHECKSUM(NEWID())) % 40   AS doctor_id,
    ABS(CHECKSUM(NEWID())) % 100      AS r_dealing,
    ABS(CHECKSUM(NEWID())) % 100      AS r_status,
    ABS(CHECKSUM(NEWID())) % 520      AS r_day,
    1 + ABS(CHECKSUM(NEWID())) % 14   AS r_los
INTO #a
FROM nums;

INSERT INTO ADMISSION.ADMISSIONS
    (ID, PATIENT_ID, SECTION_ID, BED_ID, ADMISSION_DOCTOR, DEALING_TYPE, STATUS, ADMISSION_DATE, DISCHARGE_DATE)
SELECT
    a.n,
    a.patient_id,
    b.SECTION_ID,
    a.bed_id,
    a.doctor_id,
    CASE WHEN a.r_dealing < 45 THEN 1 ELSE 2 END,
    st.STATUS,
    adm.ADMISSION_DATE,
    CASE WHEN st.STATUS IN (5, 6)
         THEN DATEADD(DAY, CASE WHEN st.STATUS = 6 THEN 0 ELSE a.r_los END, adm.ADMISSION_DATE)
         ELSE NULL END                                    -- statuses 1-4: still in-house
FROM #a a
JOIN ADMISSION.BEDS b ON b.ID = a.bed_id
CROSS APPLY (SELECT CASE
                 WHEN a.r_status < 80 THEN 5              -- 80% final discharge
                 WHEN a.r_status < 85 THEN 6              -- 5% canceled
                 ELSE 1 + a.r_status % 4                  -- 15% active (1-4)
             END AS STATUS) st
CROSS APPLY (SELECT CASE
                 WHEN st.STATUS IN (5, 6)
                     THEN DATEADD(DAY, -(30 + a.r_day), CAST(CAST(GETDATE() AS DATE) AS DATETIME))
                     ELSE DATEADD(DAY, -(a.r_day % 12), CAST(CAST(GETDATE() AS DATE) AS DATETIME))
             END AS ADMISSION_DATE) adm;                  -- active cases admitted recently

/* Mark beds of active admissions as Occupied */
UPDATE b
SET b.STATUS = 2, b.PATIENT_ID = x.PATIENT_ID, b.ADMISSION_ID = x.ID
FROM ADMISSION.BEDS b
JOIN (
    SELECT BED_ID, MAX(ID) AS ID, MAX(PATIENT_ID) AS PATIENT_ID
    FROM ADMISSION.ADMISSIONS
    WHERE STATUS IN (1,2,3,4)
    GROUP BY BED_ID
) x ON x.BED_ID = b.ID;

DROP TABLE #a;
GO

PRINT 'Script 04 complete.';
SELECT (SELECT COUNT(*) FROM CORE.PATIENT_VISITS)   AS Visits,
       (SELECT COUNT(*) FROM ADMISSION.ADMISSIONS)  AS Admissions;
