# Organize prompt

You are organizing an idea-dump repository. Follow `CLAUDE.md` in the repo root
for all filing conventions (category naming, root allowlist, INDEX.md format,
hard rules). Read it first.

You are given a **Mode**:

- `Mode: new` — Only file the currently-unorganized files in the repo root
  (anything in root not on the allowlist). Move each into the correct existing
  or new category folder. Do NOT move files that are already filed inside
  category folders.

- `Mode: full` — Full reorganization. You may restructure the entire tree:
  rename/merge/split categories and move already-filed ideas to keep the
  collection coherent. Still never delete content.

After moving files (either mode), regenerate `INDEX.md` per the format in
`CLAUDE.md`.

IMPORTANT:
- Do NOT run `git commit` or `git push`. Only move files (`mv`/`mkdir`) and
  write `INDEX.md`. A later CI step commits your changes.
- Never delete idea content. Never touch the root allowlist or `.github/`,
  `.claude/`, `docs/`, `templates/`.
- If there is nothing to organize, make no changes.
