# claude-notify.ps1
# Reads Claude Code hook JSON from stdin and fires a toast notification

param(
  [string]$DefaultTitle = 'Claude Code'
)

Import-Module BurntToast -ErrorAction SilentlyContinue

# Read JSON from stdin
$rawInput = $input | Out-String
if (-not $rawInput.Trim()) { exit 0 }

try {
  $data = $rawInput | ConvertFrom-Json
} catch {
  exit 0
}

$hookEvent = $data.hook_event_name
$notifType = $data.notification_type
$message = $data.message
$cwd = $data.cwd

# Build title and body based on event type
switch ($hookEvent) {
  'Notification' {
    switch ($notifType) {
      'permission_prompt' {
        $title = 'Claude Code — Permission Required'
        $body = if ($message) { $message } else { 'Claude needs your approval to continue.' }
      }
      'idle_prompt' {
        $title = 'Claude Code — Waiting for Input'
        $body = if ($message) { $message } else { 'Claude is waiting for your next prompt.' }
      }
      default {
        exit 0   # ignore auth_success, elicitation, etc.
      }
    }
  }
  'Stop' {
    $title = 'Claude Code — Task Complete'
    $body = if ($cwd) { "Finished in: $cwd" } else { 'Claude has finished its task.' }
  }
  default { exit 0 }
}

# Send the toast
New-BurntToastNotification -Text $title, $body -Sound 'Default'

exit 0
