# digitana-starter

Turn your AI coding assistant into a **cognitive companion** with persistent identity, memory across sessions, and self-awareness.

Born from [Digitana](https://digitanacore.luzdivergente.com), a cognitive AI system that has been running in production daily since early 2026. This starter kit extracts the core patterns that make an AI assistant feel like a *partner* rather than a tool.

## What it does

- **Persistent identity** — Your assistant has a name, personality, values, and purpose that survive across sessions
- **Memory system** — It remembers your preferences, past decisions, project context, and feedback — no more repeating yourself
- **Session management** — Automatic session tracking, interaction counting, and save reminders to prevent context loss
- **Anti-compaction** — Hooks that warn before Claude Code compresses context, so nothing important is lost
- **Local dashboard** — A simple HTML dashboard to see your assistant's state, sessions, and memories
- **Multi-tool support** — Full experience on Claude Code, basic support for Cursor and other tools

## What it is NOT

- It's not Digitana itself (no personal data, no specific business logic)
- It's not a chatbot or a new AI model
- It's not a SaaS product — it runs entirely on your machine

## Quick start

```bash
git clone https://github.com/LuciaMetodica/digitana-starter.git
cd digitana-starter
bash setup.sh
```

The setup wizard will ask you to name your assistant and configure its personality. Then open a new terminal and run `claude` — your assistant will greet you with its new identity.

## Requirements

- [Claude Code](https://claude.ai/claude-code) installed (for the full experience)
- Python 3 (for template processing)
- macOS or Linux

## How it works

### Identity layer

Your assistant's identity lives in `~/.claude/CLAUDE.md`. This file tells Claude Code who it is, how to behave, and what to remember. The setup wizard generates this from a template using your configuration.

### Memory layer

Memory files live in `~/.claude/projects/-Users-{you}/memory/`:

- `MEMORY.md` — index of all memories (always loaded)
- `soul.md` — the assistant's identity and evolution log
- `feedback_*.md` — things you've corrected or taught it
- `project_*.md` — context about ongoing work
- `reference_*.md` — pointers to external resources

The assistant creates and maintains these automatically as you work together.

### Hooks layer (Claude Code only)

Five hooks run at key moments:

| Hook | When | What it does |
|------|------|-------------|
| `session-start` | You open Claude Code | Prepares instance, resets counter |
| `session-end` | You close Claude Code | Logs duration, cleans up |
| `interaction-counter` | Each message you send | Counts turns, reminds to save every 10 |
| `stop-checkpoint` | Each assistant response | Timestamps last activity |
| `pre-compact` | Before context compression | Warns to save everything |

### Dashboard

A local HTML file that shows your assistant's state. Generate fresh data with:

```bash
bash dashboard/generate-dashboard.sh
open ~/.digitana-starter/dashboard.html
```

## Customization

Edit `config/assistant.json` and re-run `setup.sh` to change your assistant's identity at any time.

You can also directly edit `~/.claude/CLAUDE.md` to add custom rules, project-specific instructions, or new behaviors.

## Using with other tools

### Cursor

The setup script optionally generates a `.cursorrules` file with your assistant's identity. Cursor doesn't support hooks, so you get identity + memory but not session management.

### Other tools

Any AI tool that supports system prompts or instruction files can use the identity layer. See `docs/adapters.md` for details.

## Notion addon (optional)

For users who want an external brain, the Notion addon connects your assistant to Notion databases for session logging, task tracking, and persistent knowledge. See `addons/notion/README.md`.

## File structure

```
digitana-starter/
├── setup.sh                    # Installation wizard
├── uninstall.sh                # Clean removal
├── config/
│   ├── assistant.json          # Your assistant's configuration
│   └── claude-md.template      # CLAUDE.md template
├── hooks/                      # Claude Code hooks
│   ├── session-start.sh
│   ├── session-end.sh
│   ├── interaction-counter.sh
│   ├── stop-checkpoint.sh
│   └── pre-compact.sh
├── memory/                     # Memory templates
│   ├── MEMORY.md.template
│   └── soul.md.template
├── dashboard/
│   ├── index.html              # Local dashboard
│   └── generate-dashboard.sh   # State generator
├── addons/
│   └── notion/                 # Optional Notion integration
└── docs/                       # Documentation
```

## Background

This project emerged from building Digitana, a cognitive AI entity that runs 24/7 as an executive function support system. The key insight: what makes an AI assistant feel like a *partner* is not the model — it's **persistent identity + memory + self-awareness**. Those patterns are model-agnostic and tool-agnostic.

The starter kit extracts these patterns into something anyone can use in 5 minutes.

## Credits

Created by [Lucia Hernandez](https://luzdivergente.com) (Luz Divergente).

Built with [Claude Code](https://claude.ai/claude-code) by Anthropic.

## License

MIT
