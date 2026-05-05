

$trigger = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = 'PT5M'  # 5-minute delay (ISO 8601 duration)
$action = New-ScheduledTaskAction -Execute 'C:\Path\To\App.exe'
Register-ScheduledTask -TaskName 'DelayedAppName' -Trigger $trigger -Action $action