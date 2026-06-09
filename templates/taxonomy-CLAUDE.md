# gigaideas — filing conventions

This repo is a self-organizing dump of ideas. These conventions are the single
source of truth for how ideas get filed. Both the `/gigadump-idea` and
`/gigadump-organize` commands follow this file.

## What this repo holds

Each idea is one Markdown file. Ideas live in semantically-named category
folders. A root `INDEX.md` is an auto-maintained categorized table of contents.

## Root allowlist (NOT ideas)

Files in the repo root are treated as fresh, unorganized dumps to be filed —
EXCEPT these, which are never moved or treated as ideas:

- `README.md`, `INDEX.md`, `CLAUDE.md`, `LICENSE`, `.gitignore`
- anything under `.github/`, `.claude/`, `docs/`, `templates/`
- any dotfile

## Choosing a category

- Categories are **emergent**: invent folders as themes accumulate; do not force
  a pre-defined taxonomy.
- Prefer an existing folder when an idea clearly fits. Create a new folder only
  when no existing one fits.
- Names are short, lowercase, kebab-case, and meaningful (e.g.
  `developer-tools`, `product-ideas`, `infra`).
- Keep depth sane: at most 3 levels (`category/subcategory/idea.md`). Subdivide
  only when a folder grows past ~8 files.

## Diagrams

- Ideas may include a `## Diagram` section containing a fenced ```mermaid block
  when — and only when — the idea's complexity warrants it (a multi-step flow,
  several interacting components, a state machine, a decision tree, a data model
  with relationships, or a sequence between actors). GitHub renders Mermaid
  inline, so these show up as real diagrams.
- This is added by `/gigadump-idea` at capture time, never forced. Seeds,
  one-liners, and anything a sentence already conveys get no diagram.
  `/gigadump-organize` never adds, edits, or removes diagrams — it only moves
  files and rebuilds `INDEX.md`.

## File naming

- Idea filenames are kebab-case derived from the title, `.md` extension
  (e.g. `auto-organizing-dump.md`). Preserve `.html`/other extensions for raw
  dumps that aren't Markdown.
- On collision, append `-2`, `-3`, …

## INDEX.md format

Regenerate `INDEX.md` after any filing change. Format:

```
# Index

_Auto-maintained by gigadump. Do not edit by hand._

## <Category Title>

- [<Idea title>](relative/path/to/idea.md) — <one-line summary>
```

Group by top-level category (alphabetical). Within a category, list ideas
alphabetically by title. Derive the one-line summary from the idea's
`## The idea` section (or the file's first meaningful line for raw dumps).

## Hard rules

- NEVER delete idea content. Filing only moves/renames files and edits
  `INDEX.md`.
- NEVER touch the root allowlist or anything under `.github/`, `.claude/`,
  `docs/`, `templates/`.
- Status values for structured ideas: `seed`, `exploring`, `shelved`,
  `promoted`.
