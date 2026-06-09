# gigadump

A self-organizing idea dump for Claude Code. Capture an idea with one command —
Claude files it into a tidy folder tree and keeps an `INDEX.md` up to date for
you. It all runs in your Claude Code session: no GitHub Actions, no API keys,
nothing to wrestle with.

## How it works

```mermaid
flowchart LR
    A(["💡 You have<br/>an idea"]) --> B(["▶️ Run<br/>/gigadump-idea"])
    B --> C(["💬 Answer a couple<br/>quick questions"])
    C --> D(["🗂️ Claude writes & files it,<br/>updates INDEX.md"])
    D --> E(["🧹 /gigadump-organize<br/>tidies the tree"])

    classDef you fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#92400E,rx:8,ry:8;
    classDef claude fill:#EDE9FE,stroke:#8B5CF6,stroke-width:2px,color:#5B21B6,rx:8,ry:8;

    class A,B you
    class C,D,E claude
```

That's it. The **first** time you run it, it also sets up your dump repo once
(just asks where it should live). Every run after that is just the flow above.

In a hurry? Skip the questions entirely — drop any `.md` / `.html` / `.txt` file
in your repo's root, then run `/gigadump-organize` and Claude files it for you.

## Install

```
/plugin marketplace add GigaFlow-AI-Incorporated/gigadump
/plugin install gigadump
```

## Capture an idea

Run `/gigadump-idea`, answer the short interview, and Claude writes the idea,
files it into the right category folder, and refreshes `INDEX.md` — right there
in the session. Your idea is organized the moment it's captured.

## Organize the dump

Run `/gigadump-organize` to tidy up. By default it files any loose files you've
dropped in the repo root (raw notes, auto-synthesized session summaries) into the
right folders and rebuilds `INDEX.md`. Want a full re-shuffle of the tree as it
grows? Say "reorganize everything" for a full restructure — merging, splitting,
and renaming categories to keep the whole collection coherent.

## Backup (optional)

Your dump is just a git repo on disk. For off-machine backup, create it on GitHub
and push — but pushing is purely backup; it is not required for capture or
organizing.

## Config

Per-user state lives in `~/.config/gigadump/config.json`
(`{ "dumpRepoPath": "...", "defaultStatus": "seed", "autoMerge": false }`).

## License

MIT
