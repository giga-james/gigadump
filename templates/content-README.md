# My idea dump

A self-organizing dump of ideas, scaffolded by
[gigadump](https://github.com/GigaFlow-AI-Incorporated/gigadump).

## Capture an idea

- **Guided:** run `/gigadump-idea` in Claude Code — it writes the idea and
  offers to commit + push it for you.
- **Raw dump:** drop any file (`.md`, `.html`, `.txt`, …) in the repo root,
  commit, and push to `main`.

## What happens on push

A GitHub Action organizes new root files into category folders and regenerates
`INDEX.md`. It runs on your Claude subscription (OAuth token) — no API billing.

- Default push → files only new root dumps.
- Commit message containing `[reorg-all]`, or the manual **Run workflow** button
  → full re-organization of the whole tree.

## Auto-synthesize sessions (optional)

When `autoSynthesize` is `true` in `~/.config/gigadump/config.json`, the gigadump
plugin installs a `SessionEnd` hook that, at the end of each **substantial**
Claude Code session (one with file edits, a commit, or several turns), summarizes
the work plus any ideas that surfaced and pushes an entry here — the organizer
then files it like any other dump. Trivial sessions are skipped.

- **Turn it on:** set `"autoSynthesize": true` in the config (the `/gigadump-idea`
  bootstrap asks once).
- **Turn it off:** set it back to `false`.
- **Debugging:** the hook logs each run to `~/.config/gigadump/synthesize.log`.

Synthesis runs in the background on your Claude subscription via the `claude`
CLI; it never blocks or delays your session.

## One-time setup

1. Create this repo on GitHub and push.
2. Run `claude setup-token` to generate a Claude OAuth token.
3. Add it as a repository secret named `CLAUDE_CODE_OAUTH_TOKEN`
   (Settings → Secrets and variables → Actions).
4. Ensure Actions are allowed to write (Settings → Actions → General →
   Workflow permissions → Read and write). The workflow also declares
   `contents: write`.

See `CLAUDE.md` for filing conventions. `INDEX.md` is auto-maintained — don't
edit it by hand.
