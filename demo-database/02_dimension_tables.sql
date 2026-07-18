/* =====================================================================
   Script 02 — Dimension Tables & Reference Data
   Sections, staff, countries, lookup codes, payers, funds,
   beds/rooms/classes, appointment resources.
   ===================================================================== */

USE HIS;
GO

/* ---------- CORE.ORGANIZATION_SECTIONS ---------- */
CREATE TABLE CORE.ORGANIZATION_SECTIONS (
    ID            INT           NOT NULL PRIMARY KEY,
    CODE          NVARCHAR(20)  NULL,
    TITLE         NVARCHAR(100) NULL,
    FOREIGN_TITLE NVARCHAR(100) NULL,
    IS_ACTIVE     BIT           NOT NULL DEFAULT 1
);

INSERT INTO CORE.ORGANIZATION_SECTIONS (ID, CODE, TITLE, FOREIGN_TITLE) VALUES
(1 ,'PHA'  ,'Pharmacy'                 ,N'الصيدلية'),
(2 ,'LAB'  ,'Laboratory'               ,N'المختبر'),
(3 ,'RAD'  ,'Radiology'                ,N'الأشعة'),
(4 ,'ER'   ,'Emergency Room'           ,N'الطوارئ'),
(5 ,'OPD01','Internal Medicine Clinic' ,N'عيادة الباطنية'),
(6 ,'OPD02','Pediatrics Clinic'        ,N'عيادة الأطفال'),
(7 ,'OPD03','Orthopedics Clinic'       ,N'عيادة العظام'),
(8 ,'OPD04','ENT Clinic'               ,N'عيادة الأنف والأذن'),
(9 ,'OPD05','Dermatology Clinic'       ,N'عيادة الجلدية'),
(10,'OPD06','Cardiology Clinic'        ,N'عيادة القلب'),
(11,'OPD07','Ophthalmology Clinic'     ,N'عيادة العيون'),
(12,'OPD08','Dental Clinic'            ,N'عيادة الأسنان'),
(13,'OPD09','OB-GYN Clinic'            ,N'عيادة النسائية'),
(14,'OPD10','Urology Clinic'           ,N'عيادة المسالك'),
(15,'OPD11','Neurology Clinic'         ,N'عيادة الأعصاب'),
(16,'OPD12','General Surgery Clinic'   ,N'عيادة الجراحة'),
(17,'OPD13','Family Medicine Clinic'   ,N'عيادة طب الأسرة'),
(18,'OPD14','Psychiatry Clinic'        ,N'عيادة النفسية'),
(19,'IPD1' ,'IPD 1st Floor - Medical'  ,N'الطابق الأول'),
(20,'IPD2' ,'IPD 2nd Floor - Surgical' ,N'الطابق الثاني'),
(21,'IPD3' ,'IPD 3rd Floor - OB'       ,N'الطابق الثالث'),
(22,'IPD4' ,'IPD 4th Floor - Pediatric',N'الطابق الرابع'),
(23,'ADM'  ,'Administration'           ,N'الإدارة');

/* ---------- CORE.COUNTRIES ---------- */
CREATE TABLE CORE.COUNTRIES (
    ID    INT           NOT NULL PRIMARY KEY,
    TITLE NVARCHAR(100) NULL
);
INSERT INTO CORE.COUNTRIES (ID, TITLE) VALUES
(1,'Jordan'),(2,'Saudi Arabia'),(3,'Kuwait'),(4,'Iraq'),(5,'Syria'),
(6,'Egypt'),(7,'Palestine'),(8,'Yemen'),(9,'Lebanon'),(10,'Sudan'),
(11,'United States'),(12,'United Kingdom'),(13,'India');

/* ---------- CORE.CODES (patient acquisition sources) ---------- */
CREATE TABLE CORE.CODES (
    ID         INT           NOT NULL PRIMARY KEY,
    GROUP_CODE NVARCHAR(50)  NULL,
    TITLE      NVARCHAR(100) NULL,
    IS_ACTIVE  BIT           NOT NULL DEFAULT 1
);
INSERT INTO CORE.CODES (ID, GROUP_CODE, TITLE) VALUES
(1,'HEAR_US','Friend / Family Referral'),
(2,'HEAR_US','Social Media'),
(3,'HEAR_US','Google Search'),
(4,'HEAR_US','Insurance Network'),
(5,'HEAR_US','Doctor Referral'),
(6,'HEAR_US','Walk-in / Passing By');

/* ---------- CORE.STAFF (40 doctors + 5 cashiers) ---------- */
CREATE TABLE CORE.STAFF (
    ID        INT           NOT NULL PRIMARY KEY,
    FULL_NAME NVARCHAR(150) NULL,
    SECTION   INT           NULL,   -- FK -> ORGANIZATION_SECTIONS.ID
    STAFF_TYPE NVARCHAR(20) NULL    -- 'Doctor' / 'Cashier'
);

;WITH firsts AS (
    SELECT * FROM (VALUES (0,N'Ahmad'),(1,N'Mohammad'),(2,N'Omar'),(3,N'Khaled'),(4,N'Yousef'),
                          (5,N'Lina'),(6,N'Rana'),(7,N'Dana'),(8,N'Sara'),(9,N'Hala')) f(i, fname)
), lasts AS (
    SELECT * FROM (VALUES (0,N'Haddad'),(1,N'Nassar'),(2,N'Khalil'),(3,N'Odeh'),(4,N'Saleh'),
                          (5,N'Amin'),(6,N'Barakat'),(7,N'Qasem')) l(j, lname)
), nums AS (
    SELECT TOP (40) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM sys.all_objects
)
INSERT INTO CORE.STAFF (ID, FULL_NAME, SECTION, STAFF_TYPE)
SELECT
    n + 1,
    N'Dr. ' + f.fname + N' ' + l.lname,
    5 + (n % 14),                      -- spread doctors across the 14 OPD clinics
    'Doctor'
FROM nums
JOIN firsts f ON f.i = n % 10
JOIN lasts  l ON l.j = (n / 5) % 8;

INSERT INTO CORE.STAFF (ID, FULL_NAME, SECTION, STAFF_TYPE) VALUES
(101, N'Tariq Mansour', 23, 'Cashier'),
(102, N'Aya Suleiman',  23, 'Cashier'),
(103, N'Fadi Ismail',   23, 'Cashier'),
(104, N'Noor Hamdan',   23, 'Cashier'),
(105, N'Zaid Karim',    23, 'Cashier');

/* ---------- ORDERANDBILLING.PAYER (insurance companies) ---------- */
CREATE TABLE ORDERANDBILLING.PAYER (
    ID    INT           NOT NULL PRIMARY KEY,
    TITLE NVARCHAR(100) NULL
);
INSERT INTO ORDERANDBILLING.PAYER (ID, TITLE) VALUES
(1,'Alpha Health Insurance'),(2,'Gulf Care'),(3,'MedNet Partners'),
(4,'National Insurance Co.'),(5,'Unity Assurance'),(6,'Crescent Takaful'),
(7,'Prime Medical Cover'),(8,'Horizon Health Plan');

/* ---------- ORDERANDBILLING.FUNDS + CASHIER_FUNDS ---------- */
CREATE TABLE ORDERANDBILLING.FUNDS (
    ID    INT           NOT NULL PRIMARY KEY,
    TITLE NVARCHAR(100) NULL
);
INSERT INTO ORDERANDBILLING.FUNDS (ID, TITLE) VALUES
(1,'Main Reception Fund'),(2,'ER Fund'),(3,'Pharmacy Fund'),(4,'Admissions Fund');

CREATE TABLE ORDERANDBILLING.CASHIER_FUNDS (
    ID       INT NOT NULL PRIMARY KEY,
    FUND_ID  INT NOT NULL,
    STAFF_ID INT NOT NULL
);
INSERT INTO ORDERANDBILLING.CASHIER_FUNDS (ID, FUND_ID, STAFF_ID) VALUES
(1,1,101),(2,1,102),(3,2,103),(4,3,104),(5,4,105);

/* ---------- ADMISSION.CLASSES / ROOMS / BEDS ---------- */
CREATE TABLE ADMISSION.CLASSES (
    ID    INT           NOT NULL PRIMARY KEY,
    TITLE NVARCHAR(50)  NULL
);
INSERT INTO ADMISSION.CLASSES (ID, TITLE) VALUES
(1,'Suite'),(2,'First Class'),(3,'Second Class'),(4,'Ward');

CREATE TABLE ADMISSION.ROOMS (
    ID       INT NOT NULL PRIMARY KEY,
    CLASS_ID INT NOT NULL,
    CODE     NVARCHAR(20) NULL
);
;WITH nums AS (
    SELECT TOP (30) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects
)
INSERT INTO ADMISSION.ROOMS (ID, CLASS_ID, CODE)
SELECT n,
       CASE WHEN n <= 4 THEN 1 WHEN n <= 12 THEN 2 WHEN n <= 22 THEN 3 ELSE 4 END,
       'R' + RIGHT('000' + CAST(n AS VARCHAR(3)), 3)
FROM nums;

CREATE TABLE ADMISSION.BEDS (
    ID           INT NOT NULL PRIMARY KEY,
    SECTION_ID   INT NULL,          -- IPD floor
    ROOM_ID      INT NOT NULL,
    CODE         NVARCHAR(20) NULL,
    STATUS       INT NOT NULL DEFAULT 1,   -- 1 Vacant / 2 Occupied
    PATIENT_ID   INT NULL,
    ADMISSION_ID INT NULL
);
;WITH nums AS (
    SELECT TOP (60) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects
)
INSERT INTO ADMISSION.BEDS (ID, SECTION_ID, ROOM_ID, CODE, STATUS)
SELECT n,
       19 + ((n - 1) / 15),                 -- 15 beds per IPD floor (sections 19-22)
       ((n - 1) / 2) + 1,                   -- 2 beds per room
       'B' + RIGHT('000' + CAST(n AS VARCHAR(3)), 3),
       1
FROM nums;
GO

/* ---------- Appointment DB: APPOINTMENT.RESOURCES ---------- */
USE Appointment;
GO
CREATE TABLE APPOINTMENT.RESOURCES (
    ID    INT           NOT NULL PRIMARY KEY,
    TITLE NVARCHAR(150) NULL
);
INSERT INTO APPOINTMENT.RESOURCES (ID, TITLE)
SELECT TOP (20) ID, FULL_NAME
FROM HIS.CORE.STAFF
WHERE STAFF_TYPE = 'Doctor'
ORDER BY ID;
GO

PRINT 'Script 02 complete — dimensions loaded.';
