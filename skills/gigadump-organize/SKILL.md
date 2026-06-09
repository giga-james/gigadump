---
name: gigadump-organize
description: Tidy and restructure your gigadump repo in-session. Files any loose root dumps into category folders, keeps the tree coherent, and regenerates INDEX.md. Default mode files new root dumps; full mode restructures the whole tree. Use when the user says "organize my dump", "/gigadump-organize", "reorganize everything", or after capturing ideas with /gigadump-idea.
---

# /gigadump-organize — organize your idea dump

Runs the organizer in your Claude Code session — no CI, no GitHub Action, no
tokens to set up. Reads your dump repo's filing conventions and files / tidies
ideas, then regenerates `INDEX.md`.

## Procedure

### 1. Load config

Read `~/.config/gigadump/config.json`:

```json
{ "dumpRepoPath": "/abs/path/to/dump", "defaultStatus": "seed" }
```

- If it exists AND `dumpRepoPath` is a directory that is a git repo → use it as
  `DUMP`.
- If config is missing or `dumpRepoPath` points to a missing directory → tell
  the user to run `/gigadump-idea` first (it bootstraps the dump repo), and stop.

### 2. Pick a mode

Default to **new** unless the user clearly asks for a full restructure
(e.g. "reorganize everything", "restructure the whole tree", "clean up the
categories"):

- **new** (default) — File only the currently-unorganized files in the repo
  root: anything in root not on the allowlist (see `CLAUDE.md`). Move each into
  the correct existing or new category folder. Do NOT move files already filed
  inside category folders.
- **full** — Full reorganization. You may restructure the entire tree:
  rename / merge / split categories and move already-filed ideas to keep the
  collection coherent. Still never delete content.

### 3. Organize

a. Read `$DUMP/CLAUDE.md` — it is the single source of truth for filing
   conventions (root allowlist, category naming, depth limits, file naming,
   INDEX format, hard rules). Follow it exactly.

b. Find what needs filing:
   - **new**: list `$DUMP` root entries; ignore everything on the allowlist and
     all dotfiles / `.github/`, `.claude/`, `docs/`, `templates/`. Whatever
     remains is an unfiled dump.
   - **full**: consider the whole tree.

c. Move files with `mv` / `mkdir` (kebab-case category folders, kebab-case
   filenames derived from titles, preserve non-`.md` extensions for raw dumps).
   For full mode you may also rename / merge / split folders. NEVER delete idea
   content.

d. For each idea you file, skim siblings and add `[[links]]` to clearly-related
   ideas in its `## Related` section (structured ideas only; leave raw dumps
   untouched).

### 4. Rebuild the index

Regenerate `$DUMP/INDEX.md` per the format in `CLAUDE.md` (group by top-level
category alphabetically; ideas alphabetical within each; one-line summary from
each idea's `## The idea` section or first meaningful line).

### 5. Hand off

Report what changed (files moved, folders created/renamed, index updated) using
absolute paths. If `$DUMP` has a git remote, remind the user they can commit +
push to back it up (optional — organizing already happened locally):

```
git -C <DUMP> add -A && git -C <DUMP> commit -m "chore: organize ideas" && git -C <DUMP> push
```

If there is nothing to organize, say so and make no changes.

## Constraints

- NEVER delete idea content. Organizing only moves / renames files and edits
  `INDEX.md`.
- NEVER invent idea content. Empty sections stay empty.
- NEVER touch the root allowlist or anything under `.github/`, `.claude/`,
  `docs/`, `templates/`.
- NEVER commit or push automatically — leave that to the user.
