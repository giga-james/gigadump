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
{ "dumpRepoPath": "/abs/path/to/dump", "defaultStatus": "seed", "autoMerge": false }
```

`autoMerge` (default `false`) controls step 5: when `true`, a written idea is
committed and pushed automatically (with a heads-up) instead of prompting.

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
   - `templates/taxonomy-CLAUDE.md`  → `$DUMP/CLAUDE.md`
   - `templates/idea.md`             → `$DUMP/templates/idea.md`
   - `templates/content-README.md`   → `$DUMP/README.md`
   Create `$DUMP/INDEX.md` (only if missing) with:
   ```
   # Index

   _Auto-maintained by gigadump. Do not edit by hand._
   ```

d. Ask two yes/no questions (one at a time):
   1. "Auto-synthesize each Claude Code session into this dump? When on, at the
      end of every substantial session a hook summarizes the work + ideas and
      adds an entry here, to be filed next time you run `/gigadump-organize`. (y/n)"
   2. "Auto-merge captured ideas? When on, after each idea is written it's
      committed and pushed automatically (you'll get a heads-up, not a prompt).
      (y/n)"
   Then write `~/.config/gigadump/config.json` (create `~/.config/gigadump/` if
   needed) with `dumpRepoPath` = `DUMP`, `defaultStatus` = `seed`,
   `autoSynthesize` = answer 1, and `autoMerge` = answer 2 (each defaulting to
   `false` if they decline or are unsure). On a reused repo, preserve any existing
   `autoSynthesize` / `autoMerge` values rather than overwriting them.

e. Confirm the repo is ready: organizing runs in your Claude Code session via
   `/gigadump-organize` — there is **no GitHub Action, OAuth token, or secret to
   set up**. If this is a new repo with no git remote and the user wants off-machine
   backup, mention the optional one-time step: create the repo on GitHub
   (`gh repo create`) and add it as a remote. Pushing is purely backup — it is not
   required for capture or organizing.

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

c. **Add a Mermaid diagram only if complexity necessitates it.** If the idea has
   structure that's genuinely clearer as a picture than prose — a multi-step flow,
   a system with several interacting components, a state machine, a decision tree,
   a data model with relationships, or a sequence between actors — add a
   `## Diagram` section with a fenced ```mermaid block (`flowchart`,
   `sequenceDiagram`, `stateDiagram-v2`, `erDiagram`, etc.) that captures it. Keep
   it faithful to what the user actually said — never invent components just to
   justify a diagram. For seeds, one-liners, or anything a sentence already
   conveys, skip it entirely (don't leave an empty `## Diagram` heading). When in
   doubt, leave it out.

d. Choose a category folder per `CLAUDE.md` (prefer an existing folder; create a
   new kebab-case one only if nothing fits). Derive a kebab-case filename from
   the title. Write to `$DUMP/<category>/<filename>.md`.

e. In `## Related`, add `[[links]]` to any clearly-related existing ideas you
   find by skimming sibling files.

f. Regenerate `$DUMP/INDEX.md` per the format in `CLAUDE.md`.

### 5. Hand off

Tell the user the absolute path written. The idea is already filed into a
category folder and `INDEX.md` is updated — organizing happened in this session.

**Always recommend `/gigadump-organize` and explain how it works.** Print this:

> Run `/gigadump-organize` anytime to tidy your dump. By default it files any
> loose files you dropped in the repo root (e.g. raw notes, or auto-synthesized
> session summaries) into the right category folders and rebuilds `INDEX.md`. As
> your dump grows, say "reorganize everything" to do a full restructure — merging,
> splitting, and renaming categories to keep the whole tree coherent. It all runs
> here in your Claude Code session; nothing is sent to a server.

Then handle backup (optional), branching on `autoMerge` from config and whether
`$DUMP` has a git remote. The commit + push command is:

```
git -C <DUMP> add -A && git -C <DUMP> commit -m "idea: <title>" && git -C <DUMP> push
```

- **`autoMerge` is `true` AND `$DUMP` has a remote** → don't prompt. Announce one
  line — "Auto-backing-up this idea (you enabled `autoMerge` — say so to skip)" —
  then run the command and confirm it pushed. (If the user says to skip in
  response, leave it staged instead.)

- **`autoMerge` is not set / `false` AND `$DUMP` has a remote** → **offer**: "Want
  me to commit and push this to back it up? (y/n)".
  - If **yes** → run the command and confirm it pushed. Then, only if `autoMerge`
    isn't already `true`, ask once: "Make this automatic for future ideas? (y/n)"
    — if yes, set `autoMerge` to `true` in `~/.config/gigadump/config.json`
    (preserving the other keys).
  - If **no** → leave it staged and print the command so they can run it later.
    (Don't ask about making it permanent.)

- **No remote yet** (a freshly-created repo) → ignore `autoMerge`; never suggest a
  `push` that will fail. The idea is safe on disk regardless. If they want backup,
  point them to the optional GitHub step from 2e. You may still offer to
  `git add` + `commit` locally.

## Constraints

- NEVER invent idea content the user didn't express. Empty sections are fine.
- NEVER commit or push unless either the user said yes to the step-5 offer, OR
  `autoMerge` is `true` in config (which is the user's standing yes — still
  announce before doing it).
- ALWAYS file the idea into a folder (never leave it in root).
- If `dumpRepoPath` in config points to a missing directory, re-run Bootstrap.
