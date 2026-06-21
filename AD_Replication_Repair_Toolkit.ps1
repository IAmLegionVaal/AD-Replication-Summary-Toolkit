[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [string]$DomainController=$env:COMPUTERNAME,
 [switch]$SyncAll,
 [switch]$RegisterDns,
 [switch]$RestartNetlogon,
 [switch]$RestartKdc,
 [switch]$DryRun,
 [switch]$Yes,
 [string]$OutputPath=(Join-Path $env:ProgramData 'ADReplicationRepair')
)
$ErrorActionPreference='Stop';$script:Failures=0;$script:Actions=0
$run=Join-Path $OutputPath (Get-Date -Format yyyyMMdd_HHmmss);New-Item -ItemType Directory $run -Force|Out-Null
$log=Join-Path $run 'repair.log';$before=Join-Path $run 'before.txt';$after=Join-Path $run 'after.txt'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"|Tee-Object -FilePath $log -Append}
function Act($d,[scriptblock]$a){$script:Actions++;Log $d;if($DryRun){Log "DRY-RUN: $d";return};try{&$a;Log "SUCCESS: $d"}catch{$script:Failures++;Log "FAILED: $d - $($_.Exception.Message)"}}
function State($path){@("Collected: $(Get-Date -Format o)",(& repadmin.exe /showrepl $DomainController 2>&1|Out-String),(& repadmin.exe /replsummary 2>&1|Out-String),(& dcdiag.exe /s:$DomainController /test:Replications /test:DNS 2>&1|Out-String))|Set-Content $path -Encoding UTF8}
if(-not($SyncAll -or $RegisterDns -or $RestartNetlogon -or $RestartKdc)){Write-Error 'Choose at least one repair action.';exit 2}
State $before
if(-not $Yes -and -not $DryRun){if((Read-Host "Apply replication repairs to '$DomainController'? Type YES") -ne 'YES'){Log 'Cancelled.';exit 10}}
if($SyncAll){Act "Synchronising replication on $DomainController" {& repadmin.exe /syncall $DomainController /AdeP|Out-File (Join-Path $run 'syncall.txt');if($LASTEXITCODE){throw "repadmin exited $LASTEXITCODE"}}}
$remote={param($Dns,$Netlogon,$Kdc) if($Dns){& ipconfig.exe /registerdns|Out-Null};if($Netlogon){Restart-Service Netlogon -Force};if($Kdc){Restart-Service KDC -Force}}
if($RegisterDns -or $RestartNetlogon -or $RestartKdc){Act "Running service repairs on $DomainController" {if($DomainController -in @($env:COMPUTERNAME,'localhost','.')){& $remote $RegisterDns $RestartNetlogon $RestartKdc}else{Invoke-Command -ComputerName $DomainController -ScriptBlock $remote -ArgumentList $RegisterDns,$RestartNetlogon,$RestartKdc}}}
Start-Sleep 4;State $after
if($script:Failures){exit 20};Log "Repair completed. Actions: $script:Actions";exit 0
