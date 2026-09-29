# Global instructions (all projects)

## Signed git commits

All of my repos sign commits with GPG (`commit.gpgsign=true`). When the gpg-agent passphrase
cache has expired, `git commit` fails with `gpg: signing failed: Timeout`, because the pinentry
window can't appear from your session.

- Ask me to run `! 'unlock' | gpg --clearsign | Out-Null` and enter my passphrase, then retry.
- Never bypass signing (`-c commit.gpgsign=false`, `--no-gpg-sign`), not even in scratch repos.
- Batch commits toward the end of a task so I only have to unlock once.
