# Design: auto-synthesize each Claude Code session into gigadump

Date: 2026-06-07
Status: approved

## Goal

Automatically synthesize the work done in a Claude Code session and dump it into
the user's gigadump repo, with no manual step. At session end, summarize what was
accomplished plus any ideas/follow-ups that surfaced, write it as a gigadump
entry, and push so the existing CI organizer files it.

## Non-goals

- Splitting a session into multiple separate idea files (one entry per session
  for v1).
- The hook deciding taxonomy/category itself (the CI organizer already owns
  filing).
- Capturing trivial/throwaway sessions (filtered out).
- Working without the gigadump plugin installed and configured.

## Trigger & packaging

- A **`SessionEnd`** command hook, shipped **in the gigadump plugin** at
  `hooks/hooks.json`, invoking `${CLAUDE_PLUGIN_ROOT}/hooks/synthesize-session.sh`.
- `SessionEnd` fires **once per session** (not per turn), and receives JSON on
  stdin including `transcript_path`, `session_id`, and `cwd`. Matcher `*`.
- Auto-registered for every session once the plugin is installed, but the script
  no-ops unless explicitly opted in (see Gates). Installing the plugin must NOT
  silently start dumping sessions.

## Gates (cheap, in order; any miss → silent `exit 0`)

The script must never disrupt or delay the user's session beyond the cheap gates.
Every failure path exits 0.

1. **Reentrancy guard.** If `$GIGADUMP_HOOK_ACTIVE` is set, exit immediately. The
   synthesizer itself runs `claude -p`, whose own `SessionEnd` would otherwise
   re-trigger this hook → infinite loop. The synthesizer launches `claude` with
   `GIGADUMP_HOOK_ACTIVE=1` in its environment so the nested hook short-circuits.
2. **Opt-in.** Read `~/.config/gigadump/config.json`. Exit unless
   `autoSynthesize === true` AND `dumpRepoPath` is a directory that is a git repo.
3. **Substance filter.** Parse the `transcript_path` JSONL with `jq`. Proceed only
   if the session did real work:
   - ≥1 tool call of `Edit` / `Write` / `NotebookEdit`, OR
   - ≥1 `Bash` call whose command contains `git commit`, OR
   - ≥ 6 assistant messages.
   Otherwise exit (skip trivial Q&A / meta sessions). Thresholds are constants at
   the top of the script for easy tuning.

## Synthesis (detached / background)

After the gates pass, the foreground hook spawns the heavy work **detached**
(`setsid`/`nohup … &` then return) so the terminal exits instantly — `SessionEnd`
must not stall session exit (synthesis takes ~30–60s). The hook still declares a
generous `timeout` in `hooks.json` as a backstop.

The background worker:

1. Extracts the salient transcript content with `jq` — assistant text plus concise
   tool-use markers (tool name + first line of input/result). Cap total size
   (e.g. ~60k chars; keep the tail if larger) to bound tokens.
2. Pipes that to headless `claude -p`, with `GIGADUMP_HOOK_ACTIVE=1` in env, and a
   prompt instructing it to emit a **filled `idea.md`-format** markdown file:
   - Frontmatter: `title`, `created` (today), `status` (`seed`), `tags`,
     `category` left blank/seed (organizer assigns).
   - `## Work done` — what changed, files touched, decisions, outcome.
   - `## Ideas / follow-ups` — open questions, TODOs, ideas that surfaced.
   - Leave a section empty rather than inventing content (mirrors the
     `gigadump-idea` constraint).
3. Writes the result to the **gigadump repo root** as `<date>-<slug>.md` (slug
   derived from the synthesized title), where the slug avoids collisions (append a
   short session-id fragment).

## Filing — reuse the CI organizer

The worker then, inside `dumpRepoPath`:

```
git add -A && git commit -m "session: <title>" && git push
```

The file lands **unfiled in root**, so the existing CI organizer (runs on push to
the default branch, `Mode: new`) files it into a category and regenerates
`INDEX.md`. The hook stays taxonomy-agnostic. Push failures (no remote, auth) are
logged and swallowed — never surfaced to the user's already-ended session.

This matches the established gigadump model where guided/raw dumps land in root
and CI organizes them.

## Opt-in wiring

- **Bootstrap.** `skills/gigadump-idea/SKILL.md` step 2 (Bootstrap) gains one
  question: "Auto-synthesize each Claude Code session into this dump? (y/n)". The
  answer is written as `autoSynthesize` (boolean) into
  `~/.config/gigadump/config.json` alongside `dumpRepoPath` / `defaultStatus`.
  Default **false** when declined or on a reused repo where the key is absent.
- **README.** `templates/content-README.md` documents the auto-synthesis feature
  and how to toggle `autoSynthesize`.
- **Debug log.** The worker appends a line per run (skipped/synthesized/pushed +
  any error) to `~/.config/gigadump/synthesize.log`.

## Components & files

| File | Change |
|------|--------|
| `hooks/hooks.json` | New. Registers the `SessionEnd` command hook. |
| `hooks/synthesize-session.sh` | New. Gates + detached spawn + background synth/file/push. |
| `skills/gigadump-idea/SKILL.md` | Add the `autoSynthesize` bootstrap question + config write. |
| `templates/content-README.md` | Document the feature + toggle. |

## Error handling & safety

- Every gate and step is best-effort; all failure paths `exit 0`. The user's
  session is never blocked or broken by this hook.
- Reentrancy guarded by `GIGADUMP_HOOK_ACTIVE`.
- No secrets handled directly; push relies on the user's existing git/remote auth.
- Idempotency: filenames include a session-id fragment so re-runs don't clobber.

## Testing

- **Gate unit checks** (shell): feed crafted stdin + fixture transcript JSONL;
  assert exit 0 / proceed for: missing config, `autoSynthesize:false`,
  reentrancy env set, trivial transcript (skip), substantial transcript (proceed).
- **Substance filter**: fixtures for edit-present, git-commit-present, turn-count
  threshold, and a below-threshold negative.
- **End-to-end (manual)**: real session against a scratch gigadump repo with a
  remote; confirm a root file is written, committed, pushed, and the organizer
  files it.
- **Reentrancy**: confirm the synthesizer's nested `claude` invocation does not
  recurse (guard env present).

## Open questions / future

- Multiple ideas per session as separate organizable files (deferred; one entry
  per session for now).
- Size/cost controls for very long transcripts beyond the simple cap.
