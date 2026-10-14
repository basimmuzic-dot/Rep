# One-time Windows setup: saves your API keys, does the first login/sync, and schedules automatic refresh.
# Run in PowerShell from the tgsearch folder:   powershell -ExecutionPolicy Bypass -File .\setup_windows.ps1
$ErrorActionPreference = "Stop"
$dir = $PSScriptRoot
$py  = (Get-Command python).Source

& $py -m pip install -r "$dir\requirements.txt"

Write-Host "Get these at https://my.telegram.org -> API development tools"
$id   = Read-Host "api_id"
$hash = Read-Host "api_hash"
[Environment]::SetEnvironmentVariable("TG_API_ID",   $id,   "User")
[Environment]::SetEnvironmentVariable("TG_API_HASH", $hash, "User")
$env:TG_API_ID = $id; $env:TG_API_HASH = $hash

Write-Host "First sync: Telegram will send a login code to your Telegram app. Enter it when asked."
& $py "$dir\tgsearch.py" sync --limit-per-chat 2000

# Scheduled refresh every 3 hours, as you, only while you're logged in (keeps the session private).
$log    = Join-Path $env:USERPROFILE ".tgsearch\sync.log"
$cmd    = "& '$py' '$dir\tgsearch.py' sync *>> '$log'"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `"$cmd`""
$trig   = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 3)
Register-ScheduledTask -TaskName "tgsearch-sync" -Action $action -Trigger $trig -Force | Out-Null
Write-Host "Done. Auto-refresh scheduled every 3 hours (log: $log). Remove with: Unregister-ScheduledTask tgsearch-sync"
