---
name: gpg-unlock-for-signed-commits
description: "Commits in the user's repos are GPG-signed; when signing times out, ask the user to unlock the key with a PowerShell one-liner"
metadata:
  node_type: memory
  type: reference
  originSessionId: 03cef582-fb73-40e7-a689-5b054fa56bc7
  modified: 2026-09-28T23:05:37.251Z
---

All of the user's repos (dotfiles-windows, w11dwm-config, Legend.ahk) have `commit.gpgsign=true`. When the gpg-agent passphrase cache has expired, `git commit` fails with `gpg: signing failed: Timeout`, because the pinentry window times out unseen.

Ask the user to run `! 'unlock' | gpg --clearsign | Out-Null` and enter the passphrase. The `!` prefix runs in PowerShell, so `/dev/null` fails. Then retry the commit. Never bypass signing.
