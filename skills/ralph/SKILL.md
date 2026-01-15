# Ralph

Run Ralph - the autonomous AI coding agent that plans and builds features iteratively.

## How to Use

When this skill is invoked, use `run execute` to call Ralph:

```
run execute "plan ./plans/my-feature.md"
run execute "build ./plans/my-feature.md"
run execute "build ./plans/my-feature.md 20"
```

## Commands

### Plan Mode
Analyzes codebase and creates a task list, then exits:
- `plan <plan-file>` - Create task list for a plan file
- `plan ./plans/feature.md` - Example with relative path

### Build Mode
Implements tasks iteratively until completion:
- `build <plan-file>` - Build until RALPH_DONE marker
- `build <plan-file> <max-iterations>` - Build with iteration limit

### Utility Commands
- `status` - Show Ralph version and check notification setup
- `test notifications` - Test notification configuration
- `help` - Show Ralph usage information

## Examples

```
# Plan a new feature (analyzes and creates task list)
run execute "plan ./plans/add-dark-mode.md"

# Build a feature until complete
run execute "build ./plans/add-dark-mode.md"

# Build with max 20 iterations
run execute "build ./plans/add-dark-mode.md 20"

# Check Ralph version
run execute "status"
```

## How Ralph Works

1. **Plan Mode**: Runs once, creates `<plan-name>_PROGRESS.md` with task list
2. **Build Mode**: Iterates until `RALPH_DONE` appears in progress file
3. **Progress Tracking**: Updates progress file after each iteration
4. **Notifications**: Optional Slack/Discord/Telegram alerts (configure via `~/.ralph.env`)

## Progress File

Ralph creates a progress file named `<plan-name>_PROGRESS.md` that tracks:
- Current status (`IN_PROGRESS` or `RALPH_DONE`)
- Task list with completion status
- Notes and blockers

## Notes

- Ralph uses Claude CLI in pipe mode with Sonnet model
- Plan files should be markdown specs describing the feature
- Progress files are created in the current working directory
- Use `--test-notify` to verify notification setup before long builds
