# gigadump — repo guide for Claude

This repo is the **open-source plugin** (machinery only — no personal content).
It ships two commands — `/gigadump-idea` (capture) and `/gigadump-organize`
(tidy/restructure) — plus the templates that scaffold a user's private "dump"
repo. Both commands run **in the user's Claude Code session**; there is no
GitHub Action and no CI. The user's ideas live in that separate content repo,
not here.

Key files:

- `skills/gigadump-idea/SKILL.md` — capture command: bootstrap + adaptive
  interview + in-session filing.
- `skills/gigadump-organize/SKILL.md` — organize command: in-session filing of
  loose root dumps (default) and full-tree restructure.
- `templates/` — copied into a user's dump repo on first run:
  `taxonomy-CLAUDE.md` (the filing "brain"), `idea.md`, `content-README.md`.
- `.claude-plugin/` — `marketplace.json` + `plugin.json` (install + manifest).
- `docs/specs/2026-06-07-gigadump-design.md` — the authoritative design.

## Keep the README in sync

The root `README.md` is the front door: install steps, how `/gigadump-idea` and
`/gigadump-organize` behave, the config shape, and a Mermaid **flow diagram** of
an idea's lifecycle. Treat it as documentation that must match the code, not a
one-time artifact.

**When a change alters anything the README documents, update `README.md` in the
same change** — don't leave it stale. Changes that justify a README (and, where
the structure shifts, diagram) update include:

- **Install / distribution** — `.claude-plugin/marketplace.json`,
  `.claude-plugin/plugin.json` (plugin name, version surface, install commands).
- **Command behavior** — `skills/gigadump-idea/SKILL.md` (bootstrap steps, the
  interview, what gets written/filed) and `skills/gigadump-organize/SKILL.md`
  (modes, what gets moved, INDEX rebuild).
- **Templates / scaffolding** — anything in `templates/`, especially
  `taxonomy-CLAUDE.md` (filing rules, root allowlist, `INDEX.md` format).
- **Config** — the path or schema of `~/.config/gigadump/config.json`.
- **Architecture** — any change to the two-repo split, the capture paths, or the
  in-session organize flow. These shift what the **Mermaid diagrams** depict, so
  update the diagrams too; validate them with `mermaid-cli`
  (`npx -p @mermaid-js/mermaid-cli mmdc -i diagram.mmd -o out.svg`) before
  committing.

If a change is purely internal (refactor, comment, test) and changes none of the
above, the README does not need to change — only update it when the change
"justifies it" per the surfaces listed here.
