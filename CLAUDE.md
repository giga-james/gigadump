# gigadump — repo guide for Claude

This repo is the **open-source plugin** (machinery only — no personal content).
It ships a single `/gigadump-idea` command plus the templates that scaffold a
user's private "dump" repo and its GitHub Action organizer. The user's ideas and
the running Action live in that separate content repo, not here.

Key files:

- `skills/gigadump-idea/SKILL.md` — the one user-facing command and its
  bootstrap + capture flow.
- `templates/` — copied verbatim into a user's dump repo on first run:
  `organize.yml` (the Action), `organize-prompt.md`, `taxonomy-CLAUDE.md` (the
  filing "brain"), `idea.md`, `content-README.md`.
- `.claude-plugin/` — `marketplace.json` + `plugin.json` (install + manifest).
- `docs/specs/2026-06-07-gigadump-design.md` — the authoritative design.

## Keep the README in sync

The root `README.md` is the front door: install steps, how `/gigadump-idea`
behaves, how organizing works, the config shape, and two Mermaid **design
diagrams** (architecture + an idea's lifecycle). Treat it as documentation that
must match the code, not a one-time artifact.

**When a change alters anything the README documents, update `README.md` in the
same change** — don't leave it stale. Changes that justify a README (and, where
the structure shifts, diagram) update include:

- **Install / distribution** — `.claude-plugin/marketplace.json`,
  `.claude-plugin/plugin.json` (plugin name, version surface, install commands).
- **Command behavior** — `skills/gigadump-idea/SKILL.md` (bootstrap steps, the
  interview, what gets written/filed, the GitHub setup checklist).
- **Templates / scaffolding** — anything in `templates/`, especially
  `organize.yml` (Action triggers, modes, the `[skip organize]` / `[reorg-all]`
  guards, auth) and `taxonomy-CLAUDE.md` (filing rules, root allowlist,
  `INDEX.md` format).
- **Config** — the path or schema of `~/.config/gigadump/config.json`.
- **Architecture** — any change to the two-repo split, the capture paths, or the
  CI organizer loop. These shift what the **Mermaid diagrams** depict, so update
  the diagrams too; validate them with `mermaid-cli`
  (`npx -p @mermaid-js/mermaid-cli mmdc -i diagram.mmd -o out.svg`) before
  committing.

If a change is purely internal (refactor, comment, test) and changes none of the
above, the README does not need to change — only update it when the change
"justifies it" per the surfaces listed here.
