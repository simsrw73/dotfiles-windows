# Global instructions (all projects)

## My profile

@~/.config/claude-profile/profile.md

That's my personal profile. Use it in every session. When you learn something lasting about me
(personal details, preferences, habits, how I like to work, interests, projects), update it:

- Edit `~/.config/claude-profile/profile.md`, then run
  `chezmoi add --encrypt ~/.config/claude-profile/profile.md` to refresh the encrypted copy.
  Encrypting needs no passphrase; leave committing to me or the end of the task.
- Tell me in one line what you added or changed. Never update it silently.
- Update existing lines instead of adding duplicates; remove anything that turns out wrong.
- Never copy profile content into anything that leaves this machine unencrypted (this
  CLAUDE.md, project memory, the dotfiles repo, external services).
- Facts about a single project still go in that project's memory.

## Signed git commits

All of my repos sign commits with GPG (`commit.gpgsign=true`). When the gpg-agent passphrase
cache has expired, `git commit` fails with `gpg: signing failed: Timeout`, because the pinentry
window can't appear from your session.

- Ask me to run `! 'unlock' | gpg --clearsign | Out-Null` and enter my passphrase, then retry.
- Never bypass signing (`-c commit.gpgsign=false`, `--no-gpg-sign`), not even in scratch repos.
- Batch commits toward the end of a task so I only have to unlock once.

# graphify
- **graphify** (`~\.config\claude\skills\graphify\SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.
