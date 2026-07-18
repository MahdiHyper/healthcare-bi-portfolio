/* =====================================================================
   PORTFOLIO DEMO DATABASE — Hospital BI (100% synthetic data)
   Script 01 — Databases & Schemas
   Author  : Mahdi Al-Suleiman
   Target  : SQL Server 2019+ (built on SQL Server 2022 Developer)
   Safety  : Aborts if HIS or Appointment already exist, to protect
             any real database with the same name.
   ===================================================================== */

USE master;
GO
IF DB_ID('HIS') IS NOT NULL
BEGIN
    RAISERROR('A database named HIS already exists on this server. Aborting to protect it.', 20, 1) WITH LOG;
END
GO
CREATE DATABASE HIS;
GO
IF DB_ID('Appointment') IS NOT NULL
BEGIN
    RAISERROR('A database named Appointment already exists on this server. Aborting to protect it.', 20, 1) WITH LOG;
END
GO
CREATE DATABASE Appointment;
GO

USE HIS;
GO
CREATE SCHEMA CORE;
GO
CREATE SCHEMA ORDERANDBILLING;
GO
CREATE SCHEMA ADMISSION;
GO

USE Appointment;
GO
CREATE SCHEMA APPOINTMENT;
GO

PRINT 'Script 01 complete — databases HIS + Appointment created.';
