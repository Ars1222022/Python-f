-- =============================================================================
-- EndpointSecurityML - SQL Server schema (LEGACY / OPTIONAL)
--
-- The project now targets PostgreSQL by default because that is what runs
-- identically on Windows, macOS and Linux (and inside containers).
-- Use this script ONLY if you already maintain a SQL Server instance.
--
-- Run in SSMS / sqlcmd. Safe to re-run.
-- =============================================================================

IF DB_ID('EndpointSecurityML') IS NULL
BEGIN
    CREATE DATABASE EndpointSecurityML;
    PRINT 'Database EndpointSecurityML created';
END
GO

USE EndpointSecurityML;
GO

IF OBJECT_ID('dbo.EndpointActivities', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EndpointActivities (
        ActivityID         INT IDENTITY(1,1) PRIMARY KEY,
        Timestamp          DATETIME2      DEFAULT GETUTCDATE(),
        ComputerName       NVARCHAR(100),
        Username           NVARCHAR(100),
        ProcessName        NVARCHAR(255),
        ParentProcess      NVARCHAR(255),
        NetworkConnections INT            DEFAULT 0,
        IsAttack           BIT            DEFAULT 0,
        ThreatType         NVARCHAR(50)
    );
    PRINT 'Table EndpointActivities created';
END
GO

IF OBJECT_ID('dbo.ThreatDetections', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ThreatDetections (
        DetectionID         INT IDENTITY(1,1) PRIMARY KEY,
        ActivityID          INT            FOREIGN KEY REFERENCES dbo.EndpointActivities(ActivityID),
        Timestamp           DATETIME2      DEFAULT GETUTCDATE(),
        PredictedThreatType NVARCHAR(50),
        ConfidenceScore     FLOAT,
        ModelVersion        NVARCHAR(50)
    );
    PRINT 'Table ThreatDetections created';
END
GO

IF (SELECT COUNT(*) FROM dbo.EndpointActivities) = 0
BEGIN
    PRINT 'Inserting seed data...';

    DECLARE @i INT = 0;
    WHILE @i < 800
    BEGIN
        INSERT INTO dbo.EndpointActivities
            (ComputerName, Username, ProcessName, ParentProcess, NetworkConnections, IsAttack)
        VALUES
        (
            'COMPUTER' + CAST(CAST(RAND()*10 AS INT) AS VARCHAR),
            CASE WHEN RAND() < 0.15 THEN 'system' ELSE 'user' END,
            CASE CAST(RAND()*7 AS INT)
                WHEN 0 THEN 'explorer.exe' WHEN 1 THEN 'svchost.exe'
                WHEN 2 THEN 'chrome.exe'     WHEN 3 THEN 'outlook.exe'
                WHEN 4 THEN 'notepad.exe'    WHEN 5 THEN 'Teams.exe'
                ELSE 'OneDrive.exe' END,
            CASE CAST(RAND()*4 AS INT)
                WHEN 0 THEN 'winlogon.exe' WHEN 1 THEN 'services.exe'
                WHEN 2 THEN 'explorer.exe' ELSE 'userinit.exe' END,
            CAST(RAND()*6 AS INT),
            0
        );
        SET @i = @i + 1;
    END

    SET @i = 0;
    WHILE @i < 200
    BEGIN
        INSERT INTO dbo.EndpointActivities
            (ComputerName, Username, ProcessName, ParentProcess, NetworkConnections, IsAttack, ThreatType)
        VALUES
        (
            'COMPUTER' + CAST(CAST(RAND()*10 AS INT) AS VARCHAR),
            CASE WHEN RAND() < 0.35 THEN 'system' ELSE 'attacker' END,
            CASE CAST(RAND()*4 AS INT)
                WHEN 0 THEN 'powershell.exe' WHEN 1 THEN 'cmd.exe'
                WHEN 2 THEN 'wannacry.exe'    ELSE 'mimikatz.exe' END,
            CASE CAST(RAND()*3 AS INT)
                WHEN 0 THEN 'services.exe' WHEN 1 THEN 'winlogon.exe'
                ELSE 'explorer.exe' END,
            CAST(RAND()*30 + 10 AS INT),
            1,
            CASE WHEN RAND() < 0.5 THEN 'Ransomware' ELSE 'Malware' END
        );
        SET @i = @i + 1;
    END

    PRINT 'Seed data inserted: 800 normal + 200 attack activities';
END
GO

SELECT
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN IsAttack = 1 THEN 1 ELSE 0 END) AS Attacks,
    SUM(CASE WHEN IsAttack = 0 THEN 1 ELSE 0 END) AS Normal
FROM dbo.EndpointActivities;
GO
