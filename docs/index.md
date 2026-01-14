# PortableRalph

An autonomous AI development loop that works in **any repo**.

---

## What is PortableRalph?

Ralph reads your plan, breaks it into tasks, and implements them one by one until done.

```bash
~/ralph/ralph.sh ./feature-plan.md
```

```text
 Your Plan          Ralph Loop              Progress File
+-----------+      +--------------+         +--------------+
| feature   |      | 1. Read      |         | - [x] Done   |
|   .md     | ---> | 2. Pick task | <-----> | - [ ] Todo   |
|           |      | 3. Implement |         | - [ ] Todo   |
+-----------+      | 4. Commit    |         |              |
                   | 5. Repeat    |         | RALPH_DONE   |
                   +--------------+         +--------------+
```

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/aaron777collins/portableralph.git ~/ralph
chmod +x ~/ralph/*.sh
```

## Documentation

| Guide | Description |
|:------|:------------|
| [Installation](installation.md) | Get up and running in under a minute |
| [Usage Guide](usage.md) | Complete command reference |
| [Writing Plans](writing-plans.md) | How to write effective plans |
| [Notifications](notifications.md) | Slack, Discord, Telegram setup |
| [How It Works](how-it-works.md) | Technical architecture |

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Bash shell
- Git (optional, for auto-commits)

## How It Works

1. **You write** a plan file describing what to build
2. **Ralph breaks it** into discrete tasks
3. **Each iteration**: pick one task → implement → validate → commit
4. **Loop exits** when `RALPH_DONE` appears in progress file

[Get Started →](installation.md){ .md-button .md-button--primary }
[View on GitHub](https://github.com/aaron777collins/portableralph){ .md-button }
