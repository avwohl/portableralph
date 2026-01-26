# CI/CD Integration Examples

This guide shows how to integrate PortableRalph into your CI/CD pipelines for automated development workflows.

## Overview

Ralph can be used in CI/CD pipelines to:

- Automatically implement feature requests from issues
- Generate code based on specifications
- Perform automated refactoring
- Update documentation
- Fix bugs based on test failures

**Important:** Ralph requires the Claude Code CLI and valid API credentials. Ensure these are properly configured in your CI environment.

---

## GitHub Actions

### Basic Workflow

Create `.github/workflows/ralph.yml`:

```yaml
name: Ralph Auto-Implementation

on:
  issues:
    types: [labeled]
  workflow_dispatch:
    inputs:
      plan_file:
        description: 'Plan file path'
        required: true
        default: './plan.md'
      max_iterations:
        description: 'Max iterations'
        required: false
        default: '20'

jobs:
  ralph:
    runs-on: ubuntu-latest
    if: github.event.label.name == 'ralph-implement'

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Install Claude CLI
        run: |
          # Install Claude Code CLI
          curl -fsSL https://claude.ai/download/cli/install.sh | bash
          export PATH="$HOME/.local/bin:$PATH"

      - name: Configure Claude API
        env:
          CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
        run: |
          # Configure Claude CLI with API key
          echo "$CLAUDE_API_KEY" | claude auth login

      - name: Install Ralph
        run: |
          curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash -s -- --headless --skip-notifications
          echo "$HOME/ralph" >> $GITHUB_PATH

      - name: Create plan from issue
        if: github.event_name == 'issues'
        run: |
          cat > plan.md << 'EOF'
          # ${{ github.event.issue.title }}

          ${{ github.event.issue.body }}

          ## Acceptance Criteria
          - Implementation matches issue description
          - Tests pass
          - Code follows project conventions
          EOF

      - name: Run Ralph (Plan Mode)
        run: |
          ~/ralph/ralph.sh ./plan.md plan

      - name: Run Ralph (Build Mode)
        run: |
          ~/ralph/ralph.sh ./plan.md build ${{ github.event.inputs.max_iterations || '20' }}

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "Implement: ${{ github.event.issue.title }}"
          branch: ralph/${{ github.event.issue.number }}
          title: "Auto-implementation: ${{ github.event.issue.title }}"
          body: |
            Auto-generated implementation by Ralph

            Closes #${{ github.event.issue.number }}

            ## Changes
            See individual commits for details.

            ## Progress
            ```
            $(cat plan_PROGRESS.md)
            ```
          labels: auto-generated, ralph
```

### Advanced Workflow with Notifications

```yaml
name: Ralph CI/CD Pipeline

on:
  push:
    branches: [main]
    paths:
      - 'plans/*.md'
  schedule:
    - cron: '0 2 * * *'  # Run nightly at 2 AM
  workflow_dispatch:

jobs:
  ralph-automation:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup environment
        run: |
          # Install dependencies
          sudo apt-get update
          sudo apt-get install -y git curl jq

      - name: Install and configure Claude CLI
        env:
          CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
        run: |
          curl -fsSL https://claude.ai/download/cli/install.sh | bash
          export PATH="$HOME/.local/bin:$PATH"
          echo "$CLAUDE_API_KEY" | claude auth login

      - name: Install Ralph
        run: |
          curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash -s -- \
            --headless \
            --slack-webhook "${{ secrets.SLACK_WEBHOOK_URL }}"

      - name: Process all plans
        run: |
          for plan in plans/*.md; do
            echo "Processing $plan"
            ~/ralph/ralph.sh "$plan" build 50
          done

      - name: Run tests
        run: |
          # Run your test suite
          npm test || pytest || cargo test

      - name: Commit changes
        run: |
          git config user.name "Ralph Bot"
          git config user.email "ralph@github-actions"
          git add -A
          git diff-index --quiet HEAD || git commit -m "Auto-implementation by Ralph [skip ci]"
          git push

      - name: Notify on failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
          payload: |
            {
              "text": "❌ Ralph CI/CD failed on ${{ github.repository }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "Workflow: ${{ github.workflow }}\nRun: <${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Details>"
                  }
                }
              ]
            }
```

### Multi-Plan Workflow

```yaml
name: Ralph Multi-Plan Pipeline

on:
  workflow_dispatch:
    inputs:
      plans:
        description: 'Comma-separated plan files'
        required: true
        default: 'feature1.md,feature2.md'

jobs:
  plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        plan_file: ${{ fromJson(format('["{0}"]', github.event.inputs.plans)) }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Ralph
        run: |
          # Install Claude CLI
          curl -fsSL https://claude.ai/download/cli/install.sh | bash
          export PATH="$HOME/.local/bin:$PATH"
          echo "${{ secrets.CLAUDE_API_KEY }}" | claude auth login

          # Install Ralph
          curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash -s -- --headless

      - name: Execute plan
        run: |
          ~/ralph/ralph.sh ./plans/${{ matrix.plan_file }} build 30

      - name: Upload progress
        uses: actions/upload-artifact@v3
        with:
          name: progress-${{ matrix.plan_file }}
          path: |
            *_PROGRESS.md
```

---

## GitLab CI

### Basic Pipeline

Create `.gitlab-ci.yml`:

```yaml
stages:
  - setup
  - plan
  - build
  - test
  - deploy

variables:
  RALPH_AUTO_COMMIT: "false"  # We'll commit manually in CI
  PLAN_FILE: "plan.md"

setup:ralph:
  stage: setup
  image: ubuntu:22.04
  before_script:
    - apt-get update
    - apt-get install -y curl git
  script:
    # Install Claude CLI
    - curl -fsSL https://claude.ai/download/cli/install.sh | bash
    - export PATH="$HOME/.local/bin:$PATH"
    - echo "$CLAUDE_API_KEY" | claude auth login

    # Install Ralph
    - curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash -s -- --headless
    - ~/ralph/ralph.sh --version
  cache:
    paths:
      - $HOME/ralph/
      - $HOME/.local/bin/

ralph:plan:
  stage: plan
  image: ubuntu:22.04
  dependencies:
    - setup:ralph
  script:
    - ~/ralph/ralph.sh $PLAN_FILE plan
  artifacts:
    paths:
      - "*_PROGRESS.md"
    expire_in: 1 week

ralph:build:
  stage: build
  image: ubuntu:22.04
  dependencies:
    - ralph:plan
  script:
    - ~/ralph/ralph.sh $PLAN_FILE build 20
  artifacts:
    paths:
      - "*_PROGRESS.md"
      - "**/*.{js,ts,py,rs,go}"
    expire_in: 1 week
  only:
    - main
    - development

test:validation:
  stage: test
  dependencies:
    - ralph:build
  script:
    - npm test  # or your test command
  allow_failure: false

deploy:commit:
  stage: deploy
  dependencies:
    - ralph:build
    - test:validation
  script:
    - git config user.name "Ralph Bot"
    - git config user.email "ralph@gitlab-ci"
    - git add -A
    - git diff-index --quiet HEAD || git commit -m "Auto-implementation by Ralph [skip ci]"
    - git push https://oauth2:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git HEAD:${CI_COMMIT_REF_NAME}
  only:
    - main
```

### Advanced Pipeline with Parallel Plans

```yaml
stages:
  - setup
  - execute
  - merge
  - notify

variables:
  RALPH_NOTIFY_FREQUENCY: "5"

setup:
  stage: setup
  script:
    - curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash -s -- \
        --headless \
        --slack-webhook "$SLACK_WEBHOOK_URL"
  cache:
    key: ralph-install
    paths:
      - $HOME/ralph/

.ralph_template:
  stage: execute
  dependencies:
    - setup
  before_script:
    - export PATH="$HOME/.local/bin:$PATH"
    - source ~/.ralph.env
  script:
    - ~/ralph/ralph.sh ./plans/$PLAN_FILE build 30
  artifacts:
    paths:
      - "*_PROGRESS.md"
    reports:
      dotenv: plan.env
  after_script:
    - echo "PLAN_STATUS=$(grep -A 1 '## Status' *_PROGRESS.md | tail -1)" >> plan.env

feature1:
  extends: .ralph_template
  variables:
    PLAN_FILE: "feature1.md"

feature2:
  extends: .ralph_template
  variables:
    PLAN_FILE: "feature2.md"

feature3:
  extends: .ralph_template
  variables:
    PLAN_FILE: "feature3.md"

merge:results:
  stage: merge
  script:
    - |
      # Merge all changes
      git config user.name "Ralph Bot"
      git config user.email "ralph@gitlab-ci"
      git add -A
      git commit -m "Implement multiple features via Ralph" || true
      git push

notify:complete:
  stage: notify
  script:
    - |
      curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"✅ Ralph CI/CD completed for ${CI_PROJECT_NAME}\"}" \
        "$SLACK_WEBHOOK_URL"
  when: on_success

notify:failure:
  stage: notify
  script:
    - |
      curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"❌ Ralph CI/CD failed for ${CI_PROJECT_NAME}\"}" \
        "$SLACK_WEBHOOK_URL"
  when: on_failure
```

---

## Jenkins

### Declarative Pipeline

Create `Jenkinsfile`:

```groovy
pipeline {
    agent any

    parameters {
        string(name: 'PLAN_FILE', defaultValue: 'plan.md', description: 'Plan file to execute')
        string(name: 'MAX_ITERATIONS', defaultValue: '20', description: 'Maximum iterations')
        booleanParam(name: 'AUTO_COMMIT', defaultValue: true, description: 'Enable auto-commit')
    }

    environment {
        CLAUDE_API_KEY = credentials('claude-api-key')
        SLACK_WEBHOOK = credentials('slack-webhook-url')
        RALPH_HOME = "${HOME}/ralph"
    }

    stages {
        stage('Setup') {
            steps {
                sh '''
                    # Install Claude CLI if not present
                    if ! command -v claude &> /dev/null; then
                        curl -fsSL https://claude.ai/download/cli/install.sh | bash
                    fi

                    # Install Ralph if not present
                    if [ ! -d "$RALPH_HOME" ]; then
                        curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash -s -- \
                            --headless \
                            --slack-webhook "$SLACK_WEBHOOK"
                    fi

                    # Configure Claude
                    export PATH="$HOME/.local/bin:$PATH"
                    echo "$CLAUDE_API_KEY" | claude auth login
                '''
            }
        }

        stage('Plan') {
            steps {
                sh '''
                    export PATH="$HOME/.local/bin:$PATH"
                    $RALPH_HOME/ralph.sh ${PLAN_FILE} plan
                '''
            }
        }

        stage('Build') {
            steps {
                sh '''
                    export PATH="$HOME/.local/bin:$PATH"
                    export RALPH_AUTO_COMMIT="${AUTO_COMMIT}"
                    $RALPH_HOME/ralph.sh ${PLAN_FILE} build ${MAX_ITERATIONS}
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    # Run your test suite
                    npm test || pytest || cargo test
                '''
            }
        }

        stage('Commit') {
            when {
                expression { params.AUTO_COMMIT == false }
            }
            steps {
                sh '''
                    git config user.name "Ralph Bot"
                    git config user.email "ralph@jenkins"
                    git add -A
                    git diff-index --quiet HEAD || git commit -m "Implementation by Ralph - Build #${BUILD_NUMBER}"
                    git push origin ${GIT_BRANCH}
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '*_PROGRESS.md', allowEmptyArchive: true
        }
        success {
            slackSend(
                color: 'good',
                message: "✅ Ralph completed successfully: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
        }
        failure {
            slackSend(
                color: 'danger',
                message: "❌ Ralph failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
        }
    }
}
```

### Multibranch Pipeline

```groovy
pipeline {
    agent any

    stages {
        stage('Auto-Implement') {
            when {
                branch pattern: "feature/ralph-.*", comparator: "REGEXP"
            }
            steps {
                script {
                    // Extract plan file from branch name
                    def planFile = env.BRANCH_NAME.replaceAll('feature/ralph-', '') + '.md'

                    sh """
                        export PATH="\$HOME/.local/bin:\$PATH"
                        ~/ralph/ralph.sh ./plans/${planFile} build 30
                    """
                }
            }
        }

        stage('Create PR') {
            when {
                branch pattern: "feature/ralph-.*", comparator: "REGEXP"
            }
            steps {
                sh '''
                    git config user.name "Ralph Bot"
                    git config user.email "ralph@jenkins"
                    git add -A
                    git commit -m "Auto-implementation" || true
                    git push origin ${BRANCH_NAME}
                '''
                // Create PR using GitHub CLI or API
            }
        }
    }
}
```

---

## CircleCI

Create `.circleci/config.yml`:

```yaml
version: 2.1

executors:
  ralph-executor:
    docker:
      - image: ubuntu:22.04
    working_directory: ~/project

commands:
  setup-ralph:
    steps:
      - run:
          name: Install dependencies
          command: |
            apt-get update
            apt-get install -y curl git

      - run:
          name: Install Claude CLI
          command: |
            curl -fsSL https://claude.ai/download/cli/install.sh | bash
            export PATH="$HOME/.local/bin:$PATH"
            echo "$CLAUDE_API_KEY" | claude auth login

      - run:
          name: Install Ralph
          command: |
            curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash -s -- --headless

jobs:
  ralph-plan:
    executor: ralph-executor
    steps:
      - checkout
      - setup-ralph
      - run:
          name: Generate plan
          command: ~/ralph/ralph.sh ./plan.md plan
      - persist_to_workspace:
          root: .
          paths:
            - "*_PROGRESS.md"

  ralph-build:
    executor: ralph-executor
    steps:
      - checkout
      - attach_workspace:
          at: .
      - setup-ralph
      - run:
          name: Execute build
          command: ~/ralph/ralph.sh ./plan.md build 20
      - store_artifacts:
          path: "*_PROGRESS.md"
      - persist_to_workspace:
          root: .
          paths:
            - "."

  test:
    executor: ralph-executor
    steps:
      - attach_workspace:
          at: .
      - run:
          name: Run tests
          command: |
            # Your test command
            npm test || pytest

  deploy:
    executor: ralph-executor
    steps:
      - attach_workspace:
          at: .
      - run:
          name: Commit and push
          command: |
            git config user.name "Ralph Bot"
            git config user.email "ralph@circleci"
            git add -A
            git diff-index --quiet HEAD || git commit -m "Auto-implementation [skip ci]"
            git push

workflows:
  version: 2
  ralph-pipeline:
    jobs:
      - ralph-plan
      - ralph-build:
          requires:
            - ralph-plan
      - test:
          requires:
            - ralph-build
      - deploy:
          requires:
            - test
          filters:
            branches:
              only: main
```

---

## Best Practices

### Security

1. **Never commit API keys:**
   ```yaml
   # Use secrets management
   env:
     CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
   ```

2. **Limit permissions:**
   ```yaml
   permissions:
     contents: write
     pull-requests: write
   ```

3. **Use separate credentials for CI:**
   ```bash
   # Don't use personal API keys
   # Create a dedicated service account
   ```

### Resource Management

1. **Set timeouts:**
   ```yaml
   timeout-minutes: 60  # Don't let Ralph run forever
   ```

2. **Limit iterations:**
   ```bash
   ralph ./plan.md build 20  # Maximum 20 tasks
   ```

3. **Cache dependencies:**
   ```yaml
   cache:
     paths:
       - ~/ralph/
       - ~/.local/bin/
   ```

### Error Handling

1. **Always validate results:**
   ```yaml
   - name: Verify output
     run: |
       if ! grep -q "RALPH_DONE" *_PROGRESS.md; then
         echo "Ralph did not complete successfully"
         exit 1
       fi
   ```

2. **Handle failures gracefully:**
   ```yaml
   - name: Rollback on failure
     if: failure()
     run: git reset --hard HEAD^
   ```

3. **Send notifications:**
   ```yaml
   - name: Notify on failure
     if: failure()
     uses: slackapi/slack-github-action@v1
   ```

### Testing

1. **Run plan mode first:**
   ```bash
   # Review task list before building
   ralph ./plan.md plan
   cat plan_PROGRESS.md
   ralph ./plan.md build
   ```

2. **Test in isolated environments:**
   ```yaml
   # Use containers or VMs
   runs-on: ubuntu-latest
   ```

3. **Validate before merging:**
   ```yaml
   - run: npm test
   - run: npm run lint
   - run: npm run build
   ```

---

## Example Use Cases

### Auto-Fix Failed Tests

```yaml
name: Auto-Fix Test Failures

on:
  push:
    branches: [main]

jobs:
  test-and-fix:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        id: test
        continue-on-error: true
        run: npm test

      - name: Auto-fix if tests fail
        if: steps.test.outcome == 'failure'
        run: |
          # Create plan from test failures
          cat > fix-plan.md << 'EOF'
          # Fix Test Failures

          ## Goal
          Fix all failing tests in the test suite.

          ## Context
          Tests failed in previous step. Analyze failures and fix them.

          ## Requirements
          - All tests must pass
          - Don't change test expectations unless clearly wrong
          - Fix root causes, not symptoms
          EOF

          ~/ralph/ralph.sh ./fix-plan.md build 10

      - name: Re-run tests
        run: npm test
```

### Documentation Updates

```yaml
name: Auto-Update Docs

on:
  push:
    paths:
      - 'src/**/*.ts'
      - 'lib/**/*.py'

jobs:
  update-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate documentation plan
        run: |
          cat > docs-plan.md << 'EOF'
          # Update Documentation

          ## Goal
          Ensure all public APIs are documented

          ## Requirements
          - Add JSDoc/docstrings to undocumented functions
          - Update README with new APIs
          - Generate API reference
          EOF

      - name: Run Ralph
        run: ~/ralph/ralph.sh ./docs-plan.md build 15

      - name: Create PR
        uses: peter-evans/create-pull-request@v5
        with:
          title: "docs: Auto-update documentation"
          branch: auto-docs
```

---

## Monitoring and Metrics

### Track Ralph Performance

```yaml
- name: Track metrics
  run: |
    # Count iterations
    ITERATIONS=$(grep -c "Iteration" ralph.log)

    # Measure time
    START_TIME=$(date +%s)
    ~/ralph/ralph.sh ./plan.md build
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    # Report to metrics service
    curl -X POST https://metrics.company.com/ralph \
      -d "iterations=$ITERATIONS&duration=$DURATION"
```

### Progress Monitoring

```yaml
- name: Monitor progress
  run: |
    ~/ralph/start-monitor.sh 60 &
    MONITOR_PID=$!

    ~/ralph/ralph.sh ./plan.md build

    kill $MONITOR_PID
```

---

## See Also

- [Usage Guide](usage.md) - Ralph command reference
- [Notifications](notifications.md) - Setup Slack/Discord/Telegram
- [Security Guide](SECURITY.md) - Best practices for CI/CD
- [Troubleshooting](TROUBLESHOOTING.md) - Common CI/CD issues
