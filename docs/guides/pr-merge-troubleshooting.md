# Pull Request Merge Troubleshooting Guide

**Created**: 2025-01-27  
**Purpose**: Guide for resolving "merging is blocked" issues on pull requests

## Overview

When a pull request shows "merging is blocked", it typically means one or more of the following requirements are not met:
1. **Required status checks** are not passing
2. **Required reviews** are not completed
3. **Branch is not up to date** with the base branch
4. **Merge conflicts** exist
5. **Conversations** are not resolved

---

## Step 1: Identify What's Blocking

### Check PR Status on GitHub

1. Open your PR on GitHub
2. Scroll to the bottom of the PR page
3. Look for the "Merging is blocked" section
4. Review each requirement listed:
   - ✅ Green checkmark = requirement met
   - ❌ Red X = requirement not met
   - ⏳ Yellow circle = requirement pending/in progress

### Common Blocking Reasons

#### A. Required Status Checks Not Passing

**What to look for:**
- CI workflow failures (tests, builds)
- Security scan failures
- Linting errors

**How to check:**
1. Click the "Checks" tab in your PR
2. Review each workflow run:
   - `CI / test (18.x)` - Unit and integration tests on Node 18
   - `CI / test (20.x)` - Unit and integration tests on Node 20
   - `CI / Build` - Build verification
   - `Security Scan / CodeQL Security Analysis` - Security scanning

**What each check does:**
- **Tests**: Runs `npm run test:unit`, `npm run test:integration`, and `npm run test:generators`
- **Build**: Runs `npm run build` and `npm run build:widgets`
- **Security**: CodeQL analysis for security vulnerabilities

#### B. Required Reviews Not Completed

**What to look for:**
- "Review required" message
- CODEOWNERS file may require specific reviewers

**How to check:**
1. Look at the "Reviewers" section in the PR
2. Check if required reviewers have approved
3. Review the `.github/CODEOWNERS` file to see who needs to review

#### C. Branch Not Up to Date

**What to look for:**
- "This branch is out of date with the base branch" message
- Merge conflicts indicator

**How to fix:**
- Update your branch by merging or rebasing main into your PR branch

#### D. Merge Conflicts

**What to look for:**
- "This branch has conflicts that must be resolved" message
- Red "Conflicting" label

**How to fix:**
- Resolve conflicts locally and push the resolution

---

## Step 2: Fix Status Check Failures

### Run Checks Locally First

Before pushing changes, verify everything works locally:

```bash
# Install dependencies
npm ci

# Install theme-generator dependencies
cd theme-generator/v1 && npm ci && cd ../v2 && npm install && cd ../..

# Run all tests (same as CI)
npm run test:unit
npm run test:integration
npm run test:generators

# Run build (same as CI)
npm run build
npm run build:widgets
```

### Common Test Failures

#### Unit Test Failures

**Check:**
```bash
npm run test:unit
```

**Common issues:**
- Test assertions failing due to code changes
- Missing test updates for new functionality
- Configuration changes breaking tests

**Fix:**
1. Review test output for specific failures
2. Update tests to match new behavior
3. Fix code if tests reveal bugs

#### Integration Test Failures

**Check:**
```bash
npm run test:integration
```

**Common issues:**
- Preview system not running (tests require preview server)
- Network/port conflicts
- Contract changes breaking bridge tests

**Fix:**
1. Ensure preview system can start: `npm run dev` (in separate terminal)
2. Check port availability
3. Update contract tests if API changed

#### Theme Generator Test Failures

**Check:**
```bash
npm run test:generators
```

**Common issues:**
- Missing dependencies in theme-generator subdirectories
- Breaking changes in theme generation logic
- Test data mismatches

**Fix:**
1. Ensure dependencies installed: `cd theme-generator/v1 && npm ci`
2. Review generator test output
3. Update generator code or tests as needed

### Common Build Failures

**Check:**
```bash
npm run build
npm run build:widgets
```

**Common issues:**
- Missing dependencies
- Script errors in build files
- File path issues
- Missing environment variables

**Fix:**
1. Review build script output for errors
2. Check `scripts/build/` directory for issues
3. Ensure all dependencies are installed
4. Verify file paths and permissions

### Security Scan Failures

**What it checks:**
- CodeQL analysis for security vulnerabilities
- JavaScript security patterns

**How to fix:**
1. Review security alerts in the PR
2. Address identified vulnerabilities
3. Update code to follow security best practices
4. Re-run the security scan

---

## Step 3: Fix Review Requirements

### Check Required Reviewers

1. Review `.github/CODEOWNERS` to see who needs to approve
2. Request review from required reviewers
3. Wait for approval

### If You're the Only Reviewer

If you're the code owner and need to approve your own PR:
- Check repository settings → Branch protection rules
- You may need to temporarily adjust rules or get another admin to approve

---

## Step 4: Update Branch with Main

### Option A: Merge Main into Your Branch (Recommended)

```bash
# Checkout your PR branch
git checkout your-pr-branch

# Fetch latest from remote
git fetch origin

# Merge main into your branch
git merge origin/main

# Resolve any conflicts if they occur
# Then push
git push origin your-pr-branch
```

### Option B: Rebase Your Branch on Main

```bash
# Checkout your PR branch
git checkout your-pr-branch

# Fetch latest from remote
git fetch origin

# Rebase on main
git rebase origin/main

# Resolve any conflicts if they occur
# Then force push (be careful!)
git push --force-with-lease origin your-pr-branch
```

**Note**: Only use rebase if you're comfortable with it and the PR hasn't been reviewed yet.

---

## Step 5: Resolve Merge Conflicts

### Identify Conflicts

1. GitHub will show which files have conflicts
2. Files will be marked with conflict markers:
   ```
   <<<<<<< HEAD
   Your changes
   =======
   Changes from main
   >>>>>>> origin/main
   ```

### Resolve Conflicts

1. **Using GitHub UI** (easiest):
   - Click "Resolve conflicts" button in PR
   - Edit files in GitHub's editor
   - Mark as resolved
   - Commit the resolution

2. **Using Git locally**:
   ```bash
   # Merge main into your branch
   git merge origin/main
   
   # Open conflicted files in your editor
   # Remove conflict markers and keep correct code
   
   # Stage resolved files
   git add <resolved-files>
   
   # Complete the merge
   git commit
   
   # Push
   git push origin your-pr-branch
   ```

### Best Practices for Conflict Resolution

- Understand both sets of changes before resolving
- Keep functionality from both branches when possible
- Test after resolving conflicts
- Ask for help if unsure

---

## Step 6: Resolve Conversations

### Check for Unresolved Comments

1. Review all comments in the PR
2. Address any requested changes
3. Mark conversations as resolved when done
4. Reply to comments to acknowledge feedback

---

## Step 7: Re-run Failed Checks

### After Fixing Issues

1. Push your fixes to the PR branch
2. GitHub Actions will automatically re-run checks
3. Wait for checks to complete (usually 5-10 minutes)

### Manually Re-run Checks (if needed)

1. Go to the "Checks" tab
2. Click "Re-run jobs" for failed workflows
3. Wait for completion

---

## Quick Diagnostic Checklist

Use this checklist to quickly identify what's blocking your PR:

- [ ] All CI status checks are passing (green checkmarks)
- [ ] Required reviewers have approved
- [ ] Branch is up to date with main (no "out of date" message)
- [ ] No merge conflicts exist
- [ ] All conversations are resolved
- [ ] Tests pass locally (`npm test`)
- [ ] Build succeeds locally (`npm run build && npm run build:widgets`)

---

## Common Scenarios

### Scenario 1: Tests Failing in CI but Pass Locally

**Possible causes:**
- Node version differences
- Environment variable differences
- Race conditions in tests
- Missing dependencies

**Solutions:**
1. Check CI logs for specific error messages
2. Run tests with same Node version: `nvm use 18` or `nvm use 20`
3. Ensure all dependencies are in `package.json`
4. Check for timing issues in integration tests

### Scenario 2: Build Fails in CI

**Possible causes:**
- Missing build dependencies
- Path issues (CI uses different paths)
- Missing environment variables

**Solutions:**
1. Review build script output in CI logs
2. Ensure all dependencies are installed
3. Check for hardcoded paths (should use `lib/paths.js`)
4. Verify build scripts work with `npm ci` (not `npm install`)

### Scenario 3: Security Scan Fails

**Possible causes:**
- CodeQL identified security vulnerabilities
- Code patterns flagged as risky

**Solutions:**
1. Review security alerts in PR
2. Address identified issues
3. Update code to follow security best practices
4. Check CodeQL documentation for specific patterns

### Scenario 4: All Checks Pass but Still Blocked

**Possible causes:**
- Branch protection rules not configured correctly
- Required checks not listed in branch protection
- Review requirements not met

**Solutions:**
1. Check repository settings → Branch protection rules
2. Verify required checks are listed
3. Ensure reviewers have approved
4. Check if CODEOWNERS file requires specific reviewers

---

## Getting Help

If you're stuck:

1. **Review CI logs**: Check the "Checks" tab for detailed error messages
2. **Check documentation**: Review `.cursorrules` for project conventions
3. **Ask for review**: Request help from code owners
4. **Check similar PRs**: See how other PRs resolved similar issues

---

## Prevention Tips

To avoid merge blocks in the future:

1. **Run tests locally** before pushing
2. **Keep branch updated** with main regularly
3. **Small, focused PRs** are easier to review and merge
4. **Follow project conventions** (see `.cursorrules`)
5. **Address review feedback** promptly
6. **Test thoroughly** before opening PR

---

## Reference

- **CI Workflow**: `.github/workflows/ci.yml`
- **Security Workflow**: `.github/workflows/security.yml`
- **CODEOWNERS**: `.github/CODEOWNERS`
- **Project Conventions**: `.cursorrules`
- **GitHub Branch Protection Docs**: https://docs.github.com/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets

