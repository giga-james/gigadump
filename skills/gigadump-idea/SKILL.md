---
name: gigadump-idea
description: Capture an idea into your self-organizing gigadump repo. Runs an adaptive interview, writes a structured idea file, files it into the right folder, and updates INDEX.md. On first run, bootstraps your dump repo. Use when the user says "new idea", "capture an idea", "/gigadump-idea", or wants to jot something down to organize later.
---

# /gigadump-idea — capture an idea

One command. Self-bootstraps a dump repo on first run, then captures ideas.

## Procedure

### 1. Load or bootstrap config

Read `~/.config/gigadump/config.json`. It looks like:

```json
{ "dumpRepoPath": "/abs/path/to/dump", "defaultStatus": "seed" }
```

- If it exists AND `dumpRepoPath` is a directory that is a git repo → use it as
  `DUMP`. Skip to step 3.
- Otherwise → run **Bootstrap** (step 2).

### 2. Bootstrap (first run only)

a. Ask the user (one question): "Where should your idea dump live? Give a local
   path to create a new repo, an existing local dump repo to reuse, or a GitHub
   URL / `owner/repo` to clone."

b. Resolve the answer to a local path `DUMP`:
   - A GitHub URL or `owner/repo` → clone it (`git clone <url> <dest>`, or
     `gh repo clone <owner/repo> <dest>`) and set `DUMP` to `<dest>`.
   - An existing local git repo → use it as-is.
   - A path that doesn't exist yet → create and init it:
     `mkdir -p "$DUMP" && git -C "$DUMP" init`.
   Note whether this is a **new** repo (you just created/init'd it) or a
   **reused** repo (it already existed) — step e branches on this.

c. Find the plugin's bundled templates. They live at `"$CLAUDE_PLUGIN_ROOT/templates"`.
   If `$CLAUDE_PLUGIN_ROOT` is unset, locate the dir with:
   `TPL=$(find ~/.claude/plugins -type d -path '*gigadump*/templates' 2>/dev/null | head -1)`
   Copy each template into `DUMP`, **skipping any file that already exists** so a
   reused repo is never overwritten:
   - `templates/organize.yml`        → `$DUMP/.github/workflows/organize.yml`
   - `templates/organize-prompt.md`  → `$DUMP/.github/organize-prompt.md`
   - `templates/taxonomy-CLAUDE.md`  → `$DUMP/CLAUDE.md`
   - `templates/idea.md`             → `$DUMP/templates/idea.md`
   - `templates/content-README.md`   → `$DUMP/README.md`
   Create `$DUMP/INDEX.md` (only if missing) with:
   ```
   # Index

   _Auto-maintained by gigadump. Do not edit by hand._
   ```

d. Write `~/.config/gigadump/config.json` (create `~/.config/gigadump/` if
   needed) with `dumpRepoPath` = `DUMP` and `defaultStatus` = `seed`.

e. Print the one-time GitHub setup checklist (from `$DUMP/README.md`) **only if
   the repo still needs it** — i.e. a new repo, or a reused repo with no git
   remote. The checklist: create the GitHub repo and push, run `claude
   setup-token`, add the `CLAUDE_CODE_OAUTH_TOKEN` secret, allow Actions write.
   If the repo already has a remote and was already scaffolded (reused), skip the
   checklist — just confirm it's wired and remind them the
   `CLAUDE_CODE_OAUTH_TOKEN` secret must exist for the organizer to run.

### 3. Capture the idea (adaptive interview)

Judge how formed the idea is from what the user already said:

- **Seed / throwaway** → ask 0–1 questions, then write.
- **Meatier idea** → ask a few sharpening questions, ONE at a time, drawing out:
  the core idea, why it's interesting / what problem it solves, a rough sketch of
  how it might work, and open questions. Never force structure onto a seed —
  leave sections empty rather than inventing content.

### 4. Write and file the idea

a. Read `$DUMP/CLAUDE.md` for filing conventions (categories, naming, INDEX
   format). Read `$DUMP/templates/idea.md` for the structure.

b. Fill the template: set `title`, `created` (today's date), `status` (use
   `defaultStatus` from config — falling back to `seed` — unless the user
   signals otherwise), `tags`, `category`. Fill the sections from the interview;
   leave any the user didn't address empty.

c. Choose a category folder per `CLAUDE.md` (prefer an existing folder; create a
   new kebab-case one only if nothing fits). Derive a kebab-case filename from
   the title. Write to `$DUMP/<category>/<filename>.md`.

d. In `## Related`, add `[[links]]` to any clearly-related existing ideas you
   find by skimming sibling files.

e. Regenerate `$DUMP/INDEX.md` per the format in `CLAUDE.md`.

### 5. Hand off

Tell the user the path written. Then:

- If `$DUMP` has a git remote → remind them to commit + push (the organizer runs
  on push to the default branch):
  ```
  git -C <DUMP> add -A && git -C <DUMP> commit -m "idea: <title>" && git -C <DUMP> push
  ```
- If there is **no remote yet** (a freshly-created repo) → tell them to finish
  the one-time setup first (create the GitHub repo, add the remote, push) per the
  checklist from step 2e, then commit. Don't suggest a `push` that will fail.

## Constraints

- NEVER invent idea content the user didn't express. Empty sections are fine.
- NEVER commit or push automatically — leave that to the user.
- ALWAYS file the idea into a folder (never leave it in root), so the CI
  organizer no-ops on the resulting push.
- If `dumpRepoPath` in config points to a missing directory, re-run Bootstrap.
