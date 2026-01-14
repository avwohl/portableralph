---
layout: home
title: Home
nav_order: 1
description: "An autonomous AI development loop that works in any repo."
permalink: /
---

# PortableRalph

An autonomous AI development loop that works in **any repo**.
{: .fs-6 .fw-300 }

[Get Started]({{ site.baseurl }}/docs/USAGE){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/aaron777collins/portableralph){: .btn .fs-5 .mb-4 .mb-md-0 }

---

```bash
~/ralph/ralph.sh ./feature-plan.md
```

Ralph reads your plan, breaks it into tasks, and implements them one by one until done.

## Quick Start

```bash
# Install
git clone https://github.com/aaron777collins/portableralph.git ~/ralph
chmod +x ~/ralph/*.sh

# Run (from any repo)
~/ralph/ralph.sh ./my-plan.md
```

## How It Works

```
 Your Plan          Ralph Loop              Progress File
┌──────────┐      ┌─────────────┐         ┌─────────────┐
│ feature  │      │ 1. Read     │         │ - [x] Done  │
│   .md    │ ───► │ 2. Pick task│ ◄─────► │ - [ ] Todo  │
│          │      │ 3. Implement│         │ - [ ] Todo  │
└──────────┘      │ 4. Commit   │         │             │
                  │ 5. Repeat   │         │ RALPH_DONE  │
                  └─────────────┘         └─────────────┘
```

1. **You write** a plan file describing what to build
2. **Ralph breaks it** into discrete tasks
3. **Each iteration**: pick one task → implement → validate → commit
4. **Loop exits** when `RALPH_DONE` appears in progress file

## Usage

```bash
~/ralph/ralph.sh <plan-file> [mode] [max-iterations]
```

| Mode | Description |
|:-----|:------------|
| `build` | Implement tasks (default) |
| `plan` | Analyze and create task list only |

```bash
# Examples
~/ralph/ralph.sh ./feature.md           # Build until done
~/ralph/ralph.sh ./feature.md plan      # Plan only
~/ralph/ralph.sh ./feature.md build 20  # Build, max 20 iterations
```

## Plan File Format

```markdown
# Feature: User Authentication

## Goal
Add JWT-based authentication to the API.

## Requirements
- Login endpoint returns JWT token
- Middleware validates tokens on protected routes
- Tokens expire after 24 hours

## Acceptance Criteria
- POST /auth/login with valid credentials returns token
- Protected endpoints return 401 without valid token
```

[Learn more about writing plans →]({{ site.baseurl }}/docs/WRITING-PLANS)

## Notifications

Get notified on Slack, Discord, Telegram, or custom integrations:

```bash
~/ralph/setup-notifications.sh  # Interactive setup
~/ralph/ralph.sh --test-notify   # Test your config
```

[Set up notifications →]({{ site.baseurl }}/docs/NOTIFICATIONS)

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Bash shell
- Git (optional, for auto-commits)

---

## For AI Agents

Invoke Ralph from another AI agent:

```bash
# Run until RALPH_DONE
~/ralph/ralph.sh /absolute/path/to/plan.md build

# Plan only
~/ralph/ralph.sh /absolute/path/to/plan.md plan
```

Exit signal: Add `RALPH_DONE` to `<plan-name>_PROGRESS.md` when complete.

---

Based on [The Ralph Playbook](https://github.com/ghuntley/how-to-ralph-wiggum) by [@GeoffreyHuntley](https://x.com/GeoffreyHuntley).
