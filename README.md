# AD Replication Summary Toolkit

A read-only PowerShell toolkit for Active Directory replication review.

## Features

- Domain controller inventory
- Replication partner metadata
- Last-attempt and last-success context
- CSV, JSON, and HTML reports

## Run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_Replication_Summary_Toolkit.ps1
```

## Requirements

RSAT Active Directory module and domain read permissions.

## Safety

Read-only reporting only. No replication settings are changed.
