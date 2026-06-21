[CmdletBinding()]
param(
    [string]$DomainController = $env:COMPUTERNAME,
    [switch]$SyncAll,
    [switch]$RegisterDns,
    [switch]$RestartNetlogon,
    [switch]$RestartKdc,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$OutputPath = (Join-Path $env:ProgramData 'ADReplicationRepair')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:VerificationFailures = 0
$script:Actions = 0

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($env:OS -ne 'Windows_NT') { Write-Error 'This tool requires Windows and Active Directory support tools.'; exit 3 }
if (-not ($SyncAll -or $RegisterDns -or $RestartNetlogon -or $RestartKdc)) { Write-Error 'Choose at least one repair action.'; exit 2 }
foreach ($command in 'repadmin.exe','dcdiag.exe') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { Write-Error "$command is required. Install the AD DS/RSAT tools."; exit 3 }
}
$isLocalTarget = $DomainController -in @($env:COMPUTERNAME,'localhost','.')
if ($isLocalTarget -and ($RegisterDns -or $RestartNetlogon -or $RestartKdc) -and -not $DryRun -and -not (Test-Administrator)) {
    Write-Error 'Run from an elevated PowerShell session for local service repairs.'
    exit 4
}

$runPath = Join-Path $OutputPath (Get-Date -Format 'yyyyMMdd_HHmmss')
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
$logPath = Join-Path $runPath 'repair.log'
$beforePath = Join-Path $runPath 'before.json'
$afterPath = Join-Path $runPath 'after.json'

function Write-Log([string]$Message) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Tee-Object -FilePath $logPath -Append
}
function Invoke-RepairAction([string]$Description,[scriptblock]$Script) {
    $script:Actions++
    Write-Log "ACTION: $Description"
    if ($DryRun) { Write-Log "DRY-RUN: $Description"; return }
    try {
        $result = & $Script 2>&1
        if ($null -ne $result) { $result | Out-String | Add-Content $logPath }
        Write-Log "SUCCESS: $Description"
    } catch {
        $script:Failures++
        Write-Log "FAILED: $Description - $($_.Exception.Message)"
    }
}
function Get-ReplicationState {
    $showOutput = & repadmin.exe /showrepl $DomainController 2>&1
    $showExit = $LASTEXITCODE
    $summaryOutput = & repadmin.exe /replsummary 2>&1
    $summaryExit = $LASTEXITCODE
    $dcdiagOutput = & dcdiag.exe /s:$DomainController /test:Replications /test:DNS 2>&1
    $dcdiagExit = $LASTEXITCODE
    [pscustomobject]@{
        Collected = Get-Date
        DomainController = $DomainController
        ShowReplExitCode = $showExit
        ShowRepl = ($showOutput | Out-String)
        ReplSummaryExitCode = $summaryExit
        ReplSummary = ($summaryOutput | Out-String)
        DcdiagExitCode = $dcdiagExit
        Dcdiag = ($dcdiagOutput | Out-String)
    }
}

$beforeState = Get-ReplicationState
$beforeState | ConvertTo-Json -Depth 5 | Set-Content $beforePath -Encoding UTF8
Write-Log "Saved pre-repair replication evidence to $beforePath"

if (-not $DryRun -and -not $Yes) {
    if ((Read-Host "Apply replication repairs to '$DomainController'? Type YES") -cne 'YES') { Write-Log 'Repair cancelled.'; exit 10 }
}

if ($SyncAll) {
    Invoke-RepairAction "Synchronising replication on $DomainController" {
        $output = & repadmin.exe /syncall $DomainController /AdeP 2>&1
        $output | Set-Content (Join-Path $runPath 'syncall.txt') -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw "repadmin /syncall exited with code $LASTEXITCODE." }
    }
}

$remoteRepair = {
    param([bool]$DoDns,[bool]$DoNetlogon,[bool]$DoKdc)
    $ErrorActionPreference = 'Stop'
    if ($DoDns) {
        & ipconfig.exe /registerdns | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "ipconfig /registerdns exited with code $LASTEXITCODE." }
    }
    if ($DoNetlogon) {
        Restart-Service Netlogon -Force
        (Get-Service Netlogon).WaitForStatus('Running',[TimeSpan]::FromSeconds(30))
    }
    if ($DoKdc) {
        Restart-Service KDC -Force
        (Get-Service KDC).WaitForStatus('Running',[TimeSpan]::FromSeconds(30))
    }
}

if ($RegisterDns -or $RestartNetlogon -or $RestartKdc) {
    Invoke-RepairAction "Running selected DNS and service repairs on $DomainController" {
        if ($isLocalTarget) {
            & $remoteRepair ([bool]$RegisterDns) ([bool]$RestartNetlogon) ([bool]$RestartKdc)
        } else {
            Invoke-Command -ComputerName $DomainController -ScriptBlock $remoteRepair -ArgumentList ([bool]$RegisterDns),([bool]$RestartNetlogon),([bool]$RestartKdc) -ErrorAction Stop
        }
    }
}

if (-not $DryRun) { Start-Sleep -Seconds 4 }
$afterState = Get-ReplicationState
$afterState | ConvertTo-Json -Depth 5 | Set-Content $afterPath -Encoding UTF8

if (-not $DryRun) {
    if ($SyncAll -and $afterState.ReplSummaryExitCode -ne 0) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: repadmin /replsummary still reports an error.' }
    if ($RegisterDns -and -not (Resolve-DnsName -Name $DomainController -ErrorAction SilentlyContinue)) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: the domain controller name did not resolve after DNS registration.' }
    if ($RestartNetlogon -or $RestartKdc) {
        $serviceProbe = { param([bool]$CheckNetlogon,[bool]$CheckKdc) [pscustomobject]@{ Netlogon = if ($CheckNetlogon) { (Get-Service Netlogon).Status } else { $null }; Kdc = if ($CheckKdc) { (Get-Service KDC).Status } else { $null } } }
        try {
            $serviceState = if ($isLocalTarget) { & $serviceProbe ([bool]$RestartNetlogon) ([bool]$RestartKdc) } else { Invoke-Command -ComputerName $DomainController -ScriptBlock $serviceProbe -ArgumentList ([bool]$RestartNetlogon),([bool]$RestartKdc) -ErrorAction Stop }
            if ($RestartNetlogon -and $serviceState.Netlogon -ne 'Running') { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: Netlogon is not running.' }
            if ($RestartKdc -and $serviceState.Kdc -ne 'Running') { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: KDC is not running.' }
        } catch {
            $script:VerificationFailures++
            Write-Log "VERIFY FAILED: could not query service state - $($_.Exception.Message)"
        }
    }
}

if ($script:Failures -gt 0) { exit 20 }
if ($script:VerificationFailures -gt 0) { exit 30 }
Write-Log "Workflow completed. Actions: $script:Actions; DryRun: $DryRun"
exit 0
