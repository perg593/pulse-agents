# Multi-Commit PR Deployment Guide

**Created**: 2025-12-05  
**Purpose**: Guide for properly deploying PRs with multiple commits to production

## Overview

When a Pull Request contains multiple commits (like PR #21 with 5 commits), you need to choose the right merge strategy and verify deployment. This guide covers the complete process.

## Current PR Status

**PR #21**: `fix/proxy-mime-type-errors` → `main`
- **Commits**: 5 commits
- **Status**: ✅ All checks passing
  - CodeQL Security Analysis: ✅ Pass
  - CodeQL: ✅ Pass (after fixes)
  - Build: ✅ Pass
  - Tests: ✅ Pass
  - Cloudflare Pages: ✅ Pass

## Step 1: Choose Merge Strategy

### Option A: Squash and Merge ⭐ **RECOMMENDED FOR PRODUCTION**

**What it does:**
- Combines all 5 commits into a single commit on `main`
- Creates a clean, linear history
- Easier to rollback (one commit to revert)

**When to use:**
- ✅ Production deployments
- ✅ Feature branches with multiple fix commits
- ✅ When you want clean git history

**Command:**
```bash
gh pr merge 21 --squash --delete-branch
```

**Result on `main`:**
```
commit abc1234 (HEAD -> main)
feat: implement defensive proxy hardening

  - Add analytics blocking functionality
  - Fix CodeQL security warnings
  - Merge main branch changes
  - Improve HTML filtering regexp
```

### Option B: Merge Commit

**What it does:**
- Preserves all 5 individual commits
- Creates a merge commit
- Shows full development history

**When to use:**
- ✅ When you want to preserve detailed commit history
- ✅ When commits represent distinct logical changes
- ✅ For documentation/audit purposes

**Command:**
```bash
gh pr merge 21 --merge --delete-branch
```

**Result on `main`:**
```
commit def5678 (HEAD -> main)
Merge pull request #21 from perg593/fix/proxy-mime-type-errors

commit 40f7336
feat: implement defensive proxy hardening

commit 8187633
Merge origin/main into fix/proxy-mime-type-errors

commit be63618
fix: address CodeQL URL sanitization warning in test

commit 4e6c218
fix: address CodeQL HTML filtering regexp warning

commit d7d144f
fix: improve CodeQL HTML filtering regexp to handle all characters
```

### Option C: Rebase and Merge

**What it does:**
- Creates linear history without merge commit
- Preserves individual commits
- Replays commits on top of `main`

**When to use:**
- ✅ When you want linear history without merge commits
- ✅ For small, focused PRs
- ⚠️ Can be complex with many commits

**Command:**
```bash
gh pr merge 21 --rebase --delete-branch
```

## Step 2: Merge the PR

### Via GitHub Web UI (Recommended)

1. **Open PR #21**: https://github.com/perg593/pulse-agents/pull/21
2. **Click "Squash and merge"** (or your preferred option)
3. **Review the commit message** (auto-generated from PR title/description)
4. **Click "Confirm squash and merge"**
5. **Optionally delete the branch** (recommended)

### Via GitHub CLI

```bash
# Squash and merge (recommended)
gh pr merge 21 --squash --delete-branch

# Or regular merge
gh pr merge 21 --merge --delete-branch

# Or rebase and merge
gh pr merge 21 --rebase --delete-branch
```

## Step 3: Verify Merge Success

After merging, verify:

```bash
# Check that main branch is updated
git checkout main
git pull origin main

# Verify the merge commit exists
git log --oneline -5

# Check that branch was deleted (if --delete-branch was used)
gh pr list --state merged
```

## Step 4: Monitor Deployment

### Cloudflare Pages Auto-Deployment

**What happens automatically:**
1. ✅ GitHub push to `main` triggers Cloudflare Pages
2. ✅ Cloudflare detects the push
3. ✅ Cloudflare downloads code from `main` branch
4. ✅ Cloudflare deploys to production
5. ✅ Site goes live at `https://pulse-agents.pages.dev`

**Deployment Time:** Usually 2-5 minutes

### Monitor Deployment Status

**Via Cloudflare Dashboard:**
1. Go to Cloudflare Dashboard → Pages → `pulse-agents-demo`
2. Click "Deployments" tab
3. Look for new deployment with:
   - ✅ Status: "Success"
   - ✅ Source: `main` branch
   - ✅ Commit: Your merge commit SHA

**Via GitHub Actions:**
- Check Actions tab for Cloudflare Pages deployment
- Should show "Cloudflare Pages" check passing

**Via CLI:**
```bash
# Check Cloudflare Pages deployments (requires wrangler)
wrangler pages deployment list
```

## Step 5: Verify Production Deployment

### Test Production URLs

After deployment completes (2-5 minutes), test:

```bash
# Main preview
curl -I https://pulse-agents.pages.dev/

# Proxy function (critical for this PR)
curl -I "https://pulse-agents.pages.dev/proxy?url=https://example.com"

# V3 prototype
curl -I https://pulse-agents.pages.dev/preview/v3-prototype/index.html
```

### Verify Proxy Functionality

Since PR #21 adds proxy hardening features, verify:

1. **Analytics Blocking:**
   ```bash
   # Should block Google Analytics
   curl "https://pulse-agents.pages.dev/proxy?url=https://example.com" | grep -i "googletagmanager"
   # Should return empty or blocked
   ```

2. **JSON-LD Preservation:**
   ```bash
   # Test with a site that has JSON-LD
   curl "https://pulse-agents.pages.dev/proxy?url=https://example.com" | grep -i "application/ld+json"
   # Should preserve JSON-LD blocks
   ```

3. **srcset Handling:**
   ```bash
   # Test image srcset rewriting
   curl "https://pulse-agents.pages.dev/proxy?url=https://example.com" | grep -i "srcset"
   # Should show rewritten URLs
   ```

## Step 6: Post-Deployment Checklist

- [ ] ✅ PR merged successfully
- [ ] ✅ Cloudflare Pages deployment started
- [ ] ✅ Deployment completed (check dashboard)
- [ ] ✅ Production site accessible
- [ ] ✅ Proxy function works
- [ ] ✅ Analytics blocking verified
- [ ] ✅ No console errors in browser
- [ ] ✅ All tests still passing

## Rollback Process (If Needed)

If deployment causes issues:

### Option 1: Cloudflare Dashboard Rollback

1. Go to Cloudflare Dashboard → Pages → Deployments
2. Find previous successful deployment
3. Click "Rollback to this deployment"
4. Confirm rollback

### Option 2: Git Revert

```bash
# Revert the merge commit
git checkout main
git pull origin main
git revert <merge-commit-sha>
git push origin main

# Cloudflare will auto-deploy the revert
```

### Option 3: Wrangler CLI Rollback

```bash
# List deployments
wrangler pages deployment list

# Rollback to specific deployment
wrangler pages deployment rollback <deployment-id>
```

## Best Practices for Multi-Commit PRs

### Before Merging

1. ✅ **All checks passing** (CodeQL, tests, build)
2. ✅ **PR reviewed** (if required)
3. ✅ **Commits are logical** (each commit represents a distinct change)
4. ✅ **No merge conflicts**
5. ✅ **Branch is up to date** with `main`

### During Merge

1. ✅ **Choose appropriate merge strategy** (squash recommended for production)
2. ✅ **Review auto-generated commit message**
3. ✅ **Delete feature branch** after merge (cleanup)

### After Merge

1. ✅ **Monitor deployment** (Cloudflare dashboard)
2. ✅ **Verify production** (test URLs)
3. ✅ **Check logs** (if issues occur)
4. ✅ **Document deployment** (if required)

## Common Issues and Solutions

### Issue: Deployment Not Starting

**Symptoms:**
- No new deployment in Cloudflare dashboard
- GitHub Actions not triggering

**Solutions:**
1. Check Cloudflare Pages connection to GitHub
2. Verify `main` branch is set as production branch
3. Check GitHub Actions permissions
4. Manually trigger deployment via Cloudflare dashboard

### Issue: Deployment Fails

**Symptoms:**
- Deployment shows "Failed" status
- Build errors in logs

**Solutions:**
1. Check Cloudflare Pages build logs
2. Verify environment variables are set
3. Check for missing dependencies
4. Review `.cfignore` exclusions

### Issue: Code Not Reflecting in Production

**Symptoms:**
- Deployment succeeds but changes not visible
- Old code still running

**Solutions:**
1. Clear browser cache
2. Check Cloudflare cache settings
3. Verify correct branch deployed
4. Check deployment commit SHA matches merge commit

## Summary

For PR #21 with 5 commits:

1. **Merge Strategy**: Use **Squash and Merge** for clean production history
2. **Merge Command**: `gh pr merge 21 --squash --delete-branch`
3. **Monitor**: Watch Cloudflare Pages dashboard for deployment
4. **Verify**: Test production URLs after 2-5 minutes
5. **Rollback**: Use Cloudflare dashboard if issues occur

**Expected Timeline:**
- Merge: ~30 seconds
- Cloudflare deployment: 2-5 minutes
- Total: ~5-6 minutes to production

## Related Documentation

- [Cloudflare Pages Deployment Overview](./overview.md)
- [Production Checklist](../proxy/production-checklist.md)
- [Troubleshooting Guide](./troubleshooting.md)
