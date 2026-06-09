# My idea dump

A self-organizing dump of ideas, scaffolded by
[gigadump](https://github.com/GigaFlow-AI-Incorporated/gigadump).

## Capture an idea

- **Guided:** run `/gigadump-idea` in Claude Code — it writes the idea, files it
  into the right category folder, and updates `INDEX.md`, all in the session. It
  can optionally commit + push to back the repo up; set `"autoMerge": true` in
  `~/.config/gigadump/config.json` to do that automatically (you still get a
  heads-up).
- **Raw dump:** drop any file (`.md`, `.html`, `.txt`, …) in the repo root, then
  run `/gigadump-organize` to file it.

## Organize

Run `/gigadump-organize` in Claude Code to tidy the dump — it all happens in the
session, with nothing sent to a server.

- Default → files any loose files in the repo root into category folders and
  regenerates `INDEX.md`.
- Say "reorganize everything" → full re-organization of the whole tree (merge,
  split, rename categories).

## Auto-synthesize sessions (optional)

When `autoSynthesize` is `true` in `~/.config/gigadump/config.json`, the gigadump
plugin installs a `SessionEnd` hook that, at the end of each **substantial**
Claude Code session (one with file edits, a commit, or several turns), summarizes
the work plus any ideas that surfaced and adds an entry here — run
`/gigadump-organize` to file it like any other dump. Trivial sessions are skipped.

- **Turn it on:** set `"autoSynthesize": true` in the config (the `/gigadump-idea`
  bootstrap asks once).
- **Turn it off:** set it back to `false`.
- **Debugging:** the hook logs each run to `~/.config/gigadump/synthesize.log`.

Synthesis runs in the background on your Claude subscription via the `claude`
CLI; it never blocks or delays your session.

## Update notifications

gigadump checks (at most once a day) whether a newer version has been published
and, if you're behind, prints a one-line notice at session start with the update
command. To silence it, set `"updateNotifications": false` in
`~/.config/gigadump/config.json`.

## Backup (optional)

This dump is just a git repo on disk. For off-machine backup, create it on GitHub
and push — pushing is purely backup; it is not required for capture or organizing.

See `CLAUDE.md` for filing conventions. `INDEX.md` is auto-maintained — don't
edit it by hand.
