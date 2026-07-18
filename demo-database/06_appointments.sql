/* =====================================================================
   Script 06 — APPOINTMENT.APPOINTMENTS (2,000 rows)
   Dates generated RELATIVE TO GETDATE() so the demo always contains
   past history + upcoming bookings, no matter when it is run.
   Status logic mirrors a real scheduler:
     past    -> Completed / Seen / Cancelled / No Show
     future  -> Booked / Confirmed
   ===================================================================== */

USE Appointment;
GO

CREATE TABLE APPOINTMENT.APPOINTMENTS (
    ID          INT      NOT NULL PRIMARY KEY,
    PATIENT_ID  INT      NOT NULL,
    RESOURCE_ID INT      NOT NULL,
    GENDER_ID   INT      NULL,
    STATUS      INT      NOT NULL,
    [DATE]      DATETIME NOT NULL
);
GO

IF OBJECT_ID('tempdb..#ap') IS NOT NULL DROP TABLE #ap;

;WITH nums AS (
    SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT
    n,
    1 + ABS(CHECKSUM(NEWID())) % 2500 AS patient_id,
    1 + ABS(CHECKSUM(NEWID())) % 20   AS resource_id,
    ABS(CHECKSUM(NEWID())) % 210      AS r_day,       -- 0..209
    ABS(CHECKSUM(NEWID())) % 100      AS r_status,
    ABS(CHECKSUM(NEWID())) % 540      AS r_min
INTO #ap
FROM nums;

INSERT INTO APPOINTMENT.APPOINTMENTS (ID, PATIENT_ID, RESOURCE_ID, GENDER_ID, STATUS, [DATE])
SELECT
    a.n,
    a.patient_id,
    a.resource_id,
    p.GENDER_ID,
    CASE
        WHEN d.APPT_DATE >= CAST(GETDATE() AS DATE)                   -- future
             THEN CASE WHEN a.r_status < 60 THEN 1 ELSE 2 END          --   Booked / Confirmed
        ELSE CASE                                                      -- past
                 WHEN a.r_status < 62 THEN 3                           --   Completed
                 WHEN a.r_status < 75 THEN 6                           --   Seen
                 WHEN a.r_status < 88 THEN 4                           --   Cancelled
                 ELSE 5                                                --   No Show
             END
    END,
    DATEADD(MINUTE, 480 + a.r_min, CAST(d.APPT_DATE AS DATETIME))
FROM #ap a
JOIN HIS.CORE.PATIENTS p ON p.ID = a.patient_id
CROSS APPLY (SELECT DATEADD(DAY, a.r_day - 180, CAST(GETDATE() AS DATE)) AS APPT_DATE) d;
                                          -- window: 180 days back .. 30 days ahead
DROP TABLE #ap;
GO

PRINT 'Script 06 complete — 2,000 appointments created.';
SELECT STATUS, COUNT(*) AS Cnt FROM APPOINTMENT.APPOINTMENTS GROUP BY STATUS ORDER BY STATUS;
