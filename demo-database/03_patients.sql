/* =====================================================================
   Script 03 — CORE.PATIENTS (2,500 synthetic patients)
   Realistic age distribution, gender mix, nationality mix (Jordan-heavy),
   and acquisition sources.
   Technique note: all random attributes are materialized into a temp
   table FIRST, then inserted — never join on NEWID()-derived values
   (non-deterministic re-evaluation is a classic silent-bug source).
   ===================================================================== */

USE HIS;
GO

CREATE TABLE CORE.PATIENTS (
    ID             INT           NOT NULL PRIMARY KEY,
    FULL_NAME      NVARCHAR(150) NULL,
    GENDER_ID      INT           NULL,     -- 1 Male / 2 Female
    BIRTH_DATE     DATE          NULL,
    NATIONALITY_ID INT           NULL,
    HearUs         INT           NULL,
    CREATED_DATE   DATETIME      NOT NULL
);
GO

/* 1. Materialize randoms per patient */
IF OBJECT_ID('tempdb..#p') IS NOT NULL DROP TABLE #p;

;WITH nums AS (
    SELECT TOP (2500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT
    n,
    ABS(CHECKSUM(NEWID())) % 100 AS r_age_bucket,
    ABS(CHECKSUM(NEWID())) % 100 AS r_gender,
    ABS(CHECKSUM(NEWID())) % 100 AS r_nat,
    ABS(CHECKSUM(NEWID())) % 100 AS r_hear,
    ABS(CHECKSUM(NEWID())) % 365 AS r_days_in_bucket,
    ABS(CHECKSUM(NEWID())) % 540 AS r_created_offset,   -- created within last ~18 months
    ABS(CHECKSUM(NEWID())) % 10  AS r_fname,
    ABS(CHECKSUM(NEWID())) % 12  AS r_lname
INTO #p
FROM nums;

/* 2. Insert patients */
;WITH firsts AS (
    SELECT * FROM (VALUES (0,N'Ahmad'),(1,N'Mohammad'),(2,N'Omar'),(3,N'Layth'),(4,N'Kareem'),
                          (5,N'Lina'),(6,N'Rana'),(7,N'Salma'),(8,N'Yara'),(9,N'Hana')) f(i, fname)
), lasts AS (
    SELECT * FROM (VALUES (0,N'Hassan'),(1,N'Mansour'),(2,N'Zayed'),(3,N'Farah'),(4,N'Jaber'),
                          (5,N'Awad'),(6,N'Shaheen'),(7,N'Tamimi'),(8,N'Rashid'),(9,N'Bakri'),
                          (10,N'Sami'),(11,N'Dabbas')) l(j, lname)
)
INSERT INTO CORE.PATIENTS (ID, FULL_NAME, GENDER_ID, BIRTH_DATE, NATIONALITY_ID, HearUs, CREATED_DATE)
SELECT
    p.n,
    f.fname + N' ' + l.lname,
    CASE WHEN p.r_gender < 52 THEN 2 ELSE 1 END,          -- 52% female
    /* Age buckets: 0-17 (20%) · 18-34 (30%) · 35-49 (25%) · 50-64 (15%) · 65-90 (10%) */
    DATEADD(DAY, -p.r_days_in_bucket,
        DATEADD(YEAR,
            -(CASE
                WHEN p.r_age_bucket < 20 THEN  1 + p.r_age_bucket % 17
                WHEN p.r_age_bucket < 50 THEN 18 + p.r_age_bucket % 17
                WHEN p.r_age_bucket < 75 THEN 35 + p.r_age_bucket % 15
                WHEN p.r_age_bucket < 90 THEN 50 + p.r_age_bucket % 15
                ELSE                          65 + p.r_age_bucket % 26
             END),
            CAST(GETDATE() AS DATE))),
    /* Nationality: 70% Jordanian, remainder spread over 12 others */
    CASE WHEN p.r_nat < 70 THEN 1 ELSE 2 + p.r_nat % 12 END,
    /* HearUs: 30% not specified */
    CASE WHEN p.r_hear < 30 THEN NULL ELSE 1 + p.r_hear % 6 END,
    DATEADD(DAY, -p.r_created_offset, GETDATE())
FROM #p p
JOIN firsts f ON f.i = p.r_fname
JOIN lasts  l ON l.j = p.r_lname;

DROP TABLE #p;
GO

PRINT 'Script 03 complete — 2,500 patients created.';
SELECT COUNT(*) AS Patients FROM CORE.PATIENTS;
