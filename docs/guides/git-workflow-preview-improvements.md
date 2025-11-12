# Git Workflow Guide: Preview System Improvements

## Recommended Approach: Feature Branch

For this large set of changes, we'll use a **feature branch** workflow. This is safer than committing directly to `main` because:

1. ✅ **Isolation**: Changes are isolated from production code
2. ✅ **Review**: Easy to review before merging
3. ✅ **Testing**: Can test the branch without affecting main
4. ✅ **Rollback**: Easy to abandon if needed
5. ✅ **Clean History**: Keeps main branch clean

## Step-by-Step Workflow

### Step 1: Create a Feature Branch

```bash
# Make sure you're on main and it's up to date
git checkout main
git pull origin main

# Create a new feature branch
git checkout -b feature/preview-system-improvements

# Or with a shorter name:
git checkout -b preview-improvements
```

**What this does**: Creates a new branch called `preview-improvements` based on `main` and switches to it.

---

### Step 2: Stage Your Changes

```bash
# Stage all changes (modified and new files)
git add .

# Or stage specific files:
git add preview/basic/preview.js
git add preview/scripts/surveys-tag.js
git add lib/errors.js
# ... etc
```

**What this does**: Tells Git which files you want to include in your commit.

---

### Step 3: Commit Your Changes

```bash
# Commit with a descriptive message
git commit -m "feat: preview system improvements - architecture, reliability, and code quality

- Changed URL parameter from pi_present to present to fix double presentation bug
- Added PresentationQueue for race condition prevention
- Added PresentationDeduplicator for centralized duplicate prevention
- Created PresentationService with state machine
- Added EventBus for event-driven architecture
- Added StateMachine for state management
- Added preview-specific error classes
- Created constants modules to eliminate magic strings
- Added unit test framework
- Added comprehensive documentation
- Added PerformanceMonitor and Debugger utilities

See docs/planning/2025-10/preview-system-improvement-plan.md for details"
```

**What this does**: Creates a commit with all your staged changes and a descriptive message.

**Tip**: The first line should be a short summary (50 chars or less), then a blank line, then detailed description.

---

### Step 4: Push Your Branch to Remote

```bash
# Push your branch to GitHub/GitLab
git push -u origin preview-improvements
```

**What this does**: 
- Creates the branch on the remote repository
- Sets up tracking so future `git push` commands know where to go
- Makes your branch visible to others

---

### Step 5: Create a Pull Request (GitHub) or Merge Request (GitLab)

**On GitHub**:
1. Go to your repository on GitHub
2. You'll see a banner saying "preview-improvements had recent pushes"
3. Click "Compare & pull request"
4. Fill in:
   - **Title**: "Preview System Improvements - Architecture, Reliability, Code Quality"
   - **Description**: Reference the plan: `See docs/planning/2025-10/preview-system-improvement-plan.md`
5. Click "Create pull request"

**On GitLab**:
1. Go to your repository on GitLab
2. Click "Merge requests" → "New merge request"
3. Select `preview-improvements` as source branch
4. Select `main` as target branch
5. Fill in title and description
6. Click "Create merge request"

---

### Step 6: Review and Test

Before merging:
1. ✅ Review the changes in the PR/MR
2. ✅ Test the branch locally or in a staging environment
3. ✅ Get code review from teammates (if applicable)
4. ✅ Check that tests pass

---

### Step 7: Merge to Main

**Option A: Merge via GitHub/GitLab UI** (Recommended for beginners)
- Click "Merge pull request" / "Merge" button
- Choose merge strategy:
  - **Create a merge commit**: Preserves branch history (recommended)
  - **Squash and merge**: Combines all commits into one (cleaner history)
  - **Rebase and merge**: Linear history (advanced)

**Option B: Merge via command line**
```bash
# Switch back to main
git checkout main

# Pull latest changes
git pull origin main

# Merge your feature branch
git merge preview-improvements

# Push to remote
git push origin main
```

---

### Step 8: Clean Up

After merging:
```bash
# Delete local branch (optional)
git branch -d preview-improvements

# Delete remote branch (optional)
git push origin --delete preview-improvements
```

---

## Alternative: Multiple Smaller Commits

Instead of one big commit, you could break it into logical commits:

```bash
# Commit 1: Critical bug fix
git add preview/basic/preview.js preview/scripts/surveys-tag.js
git commit -m "fix: change pi_present to present parameter to prevent double presentations"

# Commit 2: Core services
git add preview/basic/lib/presentationQueue.js preview/basic/lib/presentationDeduplicator.js
git commit -m "feat: add presentation queue and deduplicator for race condition prevention"

# Commit 3: Architecture improvements
git add preview/basic/services/ preview/basic/lib/eventBus.js preview/basic/lib/stateMachine.js
git commit -m "feat: add presentation service, event bus, and state machine"

# Commit 4: Code quality
git add lib/errors.js preview/basic/config/
git commit -m "feat: add error classes and constants modules"

# Commit 5: Tests and docs
git add tests/unit/preview/ docs/
git commit -m "docs: add unit tests and comprehensive documentation"

# Commit 6: Monitoring
git add preview/basic/lib/performanceMonitor.js preview/basic/lib/debugger.js
git commit -m "feat: add performance monitoring and debugging utilities"
```

**Benefits**: 
- Easier to review
- Easier to revert specific changes
- Better commit history

---

## Common Git Commands Reference

```bash
# Check current status
git status

# See what branch you're on
git branch

# See changes in files
git diff

# See staged changes
git diff --staged

# Undo staging (unstage a file)
git restore --staged <file>

# Discard changes to a file (careful!)
git restore <file>

# View commit history
git log --oneline

# View remote branches
git branch -r
```

---

## Troubleshooting

### "I committed to main by mistake!"
```bash
# Create a branch from current position
git branch preview-improvements

# Reset main to before your commits
git checkout main
git reset --hard origin/main

# Switch back to your branch
git checkout preview-improvements
```

### "I want to update my branch with latest main"
```bash
# Switch to main and pull latest
git checkout main
git pull origin main

# Switch back to your branch
git checkout preview-improvements

# Merge main into your branch
git merge main

# Or rebase (cleaner history)
git rebase main
```

### "I want to see what changed"
```bash
# See all changes in your branch vs main
git diff main..preview-improvements

# See file list
git diff --name-only main..preview-improvements
```

---

## Best Practices

1. ✅ **Always create a feature branch** for significant changes
2. ✅ **Write descriptive commit messages** - explain what and why
3. ✅ **Keep commits focused** - one logical change per commit
4. ✅ **Test before merging** - make sure everything works
5. ✅ **Review your own changes** - use `git diff` before committing
6. ✅ **Pull before pushing** - `git pull` before `git push` to avoid conflicts

---

## Quick Reference: Complete Workflow

```bash
# 1. Create branch
git checkout main
git pull origin main
git checkout -b preview-improvements

# 2. Make changes (already done!)

# 3. Stage and commit
git add .
git commit -m "feat: preview system improvements

See docs/planning/2025-10/preview-system-improvement-plan.md"

# 4. Push branch
git push -u origin preview-improvements

# 5. Create PR/MR on GitHub/GitLab

# 6. After review and approval, merge via UI or:
git checkout main
git pull origin main
git merge preview-improvements
git push origin main

# 7. Clean up
git branch -d preview-improvements
git push origin --delete preview-improvements
```

---

## Need Help?

- **Git documentation**: https://git-scm.com/doc
- **GitHub guides**: https://guides.github.com/
- **GitLab guides**: https://docs.gitlab.com/ee/gitlab-basics/

