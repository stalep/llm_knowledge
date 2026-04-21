# Knowledge Tree for Claude Code

A persistent, cross-project learning system for Claude Code. Claude reads accumulated knowledge at session start and writes back insights after completing tasks.

## How it works

Each project gets a domain folder with three files:

| File | Purpose |
|------|---------|
| `knowledge.md` | Confirmed facts, patterns, architecture notes |
| `hypotheses.md` | Observations that need more data |
| `rules.md` | Patterns with 3+ confirmations — applied by default |

Insights follow a lifecycle: new observations start as knowledge or hypotheses. Hypotheses that get confirmed 3+ times are promoted to rules. Rules contradicted by new evidence get demoted back to hypotheses.

Cross-project insights (performance, concurrency, API design, etc.) live in `_shared/<topic>/`.

## Structure

```
~/git/llm_knowledge/
├── index.md                 # Directory of all domains
├── _shared/                 # Cross-project knowledge
│   ├── performance/
│   ├── api-design/
│   ├── concurrency/
│   └── security/
├── <project-name>/          # Per-project domains
│   ├── knowledge.md
│   ├── hypotheses.md
│   └── rules.md
└── claude/                  # Claude Code configuration (see Setup)
    ├── claude.md            # Global instructions (~/.claude/claude.md)
    ├── CLAUDE.md            # Per-project template for CLAUDE.md
    ├── settings.json        # Claude Code settings with hooks and plugins
    ├── hooks/
    │   ├── knowledge-tree-init.sh    # SessionStart: reminds Claude to read knowledge files
    │   └── knowledge-tree-remind.sh  # PostToolUse: reminds Claude to extract insights
    └── skills/
        └── use-analysis/    # Performance analysis skill (symlink to ClaudeFranzBFF)
```

## Setup

### 1. Clone this repo

```bash
git clone https://github.com/stalep/llm_knowledge.git ~/git/llm_knowledge
```

### 2. Install Claude Code configuration

Copy the contents of `claude/` into `~/.claude/`:

```bash
# Global instructions
cp claude/claude.md ~/.claude/claude.md

# Settings (hooks, plugins)
# NOTE: Review and merge with your existing settings.json if you have one
cp claude/settings.json ~/.claude/settings.json

# Hooks
mkdir -p ~/.claude/hooks
cp claude/hooks/knowledge-tree-init.sh ~/.claude/hooks/
cp claude/hooks/knowledge-tree-remind.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/knowledge-tree-*.sh
```

### 3. Wire each project

Add a `CLAUDE.md` to the root of each project you want Claude to learn from. Use `claude/CLAUDE.md` as a template — it tells Claude to read the global instructions and the knowledge tree.

### 4. Optional: Performance engineering skill (ClaudeFranzBFF)

The `use-analysis` skill provides a `/use-analysis` slash command that implements Brendan Gregg's USE method for benchmark analysis. It lives in a separate repo:

```bash
git clone https://github.com/stalep/ClaudeFranzBFF.git ~/git/ClaudeFranzBFF
```

Then symlink the skill into your Claude config:

```bash
mkdir -p ~/.claude/skills/use-analysis
ln -s ~/git/ClaudeFranzBFF/skills/use-analysis/SKILL.md ~/.claude/skills/use-analysis/SKILL.md
```

ClaudeFranzBFF also includes methodology docs (`methodology/`) that the performance rules reference — these are read automatically during performance analysis sessions.

### 5. Optional: Plugins and tools

**claude-mem** — cross-session persistent memory plugin:
- Installed via Claude Code marketplace (`thedotmack/claude-mem`)
- Already configured in `settings.json`

**cachebro** — token-efficient file reads via MCP:
- See [github.com/glommer/cachebro](https://github.com/glommer/cachebro)
- Caches file reads and returns diffs instead of full content on re-reads

## Hooks

Two hooks automate the knowledge tree workflow:

**`knowledge-tree-init.sh`** (SessionStart) — Detects the project name from the git repo root, lists all knowledge files Claude should read (project-specific + shared rules), and injects them as context. If no domain folder exists for the project, it reminds Claude to create one.

**`knowledge-tree-remind.sh`** (PostToolUse on Edit/Write) — After Claude modifies a file, reminds it to consider extracting non-obvious insights to the knowledge tree. Skips for trivial work.

## Customization

- Edit `claude/claude.md` to change the knowledge tree instructions
- Add new `_shared/` topics as cross-project patterns emerge
- The hooks assume the knowledge tree lives at `~/git/llm_knowledge/` — update the `KNOWLEDGE_BASE` variable in both hook scripts if your path differs
