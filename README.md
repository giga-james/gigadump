# gigadump

A self-organizing idea dump for Claude Code. Capture an idea with one command —
Claude files it into a tidy folder tree and keeps an `INDEX.md` up to date for
you. It runs on your **Claude subscription** (no pay-as-you-go API billing).

## How it works

```mermaid
flowchart LR
    A(["💡 You have<br/>an idea"]) --> B(["▶️ Run<br/>/gigadump-idea"])
    B --> C(["💬 Answer a couple<br/>quick questions"])
    C --> D(["🗂️ Claude writes & files it,<br/>updates INDEX.md"])
    D --> E(["⬆️ commit + push"])
    E --> F(["🤖 GitHub auto-tidies<br/>your whole repo"])

    classDef you fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#92400E,rx:8,ry:8;
    classDef claude fill:#EDE9FE,stroke:#8B5CF6,stroke-width:2px,color:#5B21B6,rx:8,ry:8;
    classDef git fill:#DBEAFE,stroke:#3B82F6,stroke-width:2px,color:#1E40AF,rx:8,ry:8;

    class A,B you
    class C,D claude
    class E,F git
```

That's it. The **first** time you run it, it also sets up your dump repo once
(asks where it should live and prints a quick GitHub checklist). Every run after
that is just the flow above.

In a hurry? Skip the questions entirely — drop any `.md` / `.html` / `.txt` file
in your repo's root, push, and Claude files it for you.

## Install

```
/plugin marketplace add GigaFlow-AI-Incorporated/gigadump
/plugin install gigadump
```

## Use

Run `/gigadump-idea`, answer the short interview, then `commit` + `push`. On push
to `main`, a GitHub Action tidies up: it files any new root drops and refreshes
`INDEX.md`. Want a full re-shuffle of the tree? Put `[reorg-all]` in your commit
message or hit the **Run workflow** button.

The Action runs on your subscription via a `CLAUDE_CODE_OAUTH_TOKEN` secret you
generate with `claude setup-token` — the first-run setup walks you through it.

## Config

Per-user state lives in `~/.config/gigadump/config.json`
(`{ "dumpRepoPath": "...", "defaultStatus": "seed" }`).

## License

MIT
