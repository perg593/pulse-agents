# Cloudflare Pages Deployment Issues & Fixes

## Current Problems

### Issue 1: Redirect Loop/Broken Paths
**Problem:** `preview/index.html` redirects to `/index.html`, but the actual entry point structure may not match Cloudflare Pages deployment.

**Root Cause:** When deployed to Cloudflare Pages with `pages_build_output_dir = "."`, the structure should work, but redirects may fail if paths don't resolve correctly.

### Issue 2: Proxy Function Not Deployed
**Problem:** The Cloudflare Function at `functions/proxy.js` exists but may not be deployed correctly with Wrangler CLI.

**Root Cause:** Wrangler CLI deployments need explicit function configuration. Git integration auto-detects functions.

### Issue 3: Path Resolution in Production
**Problem:** ES module imports use relative paths that may break when deployed.

**Root Cause:** Import paths like `./app/main.js` need to be relative to the HTML file location.

## Recommended Solution: Git Integration

**Yes, I recommend using Git integration** — it's much easier for non-Git users and handles Cloudflare Functions automatically.

### Why Git Integration is Better:

1. **Automatic Function Detection:** Cloudflare Pages automatically detects and deploys `functions/` directory
2. **Easier Management:** No need to run Wrangler CLI commands
3. **Preview Deployments:** Every PR gets a preview URL automatically
4. **Rollback:** Easy rollback through dashboard
5. **Build Logs:** Better visibility into build/deploy issues

### Setup Steps (I can help with this):

1. **Connect Repository:**
   - Go to Cloudflare Dashboard → Pages → Create a project
   - Connect your Git repository (GitHub/GitLab/Bitbucket)
   - Cloudflare will guide you through OAuth connection

2. **Configure Build Settings:**
   - **Build command:** (leave empty - no build step needed)
   - **Build output directory:** `.` (root)
   - **Root directory:** (leave empty)

3. **Environment Variables:**
   - Add these in Cloudflare Pages settings:
     - `BACKGROUND_PROXY_ALLOWLIST` = `*`
     - `BACKGROUND_PROXY_BLOCKLIST` = `localhost,127.,::1`

4. **Deploy:**
   - Once connected, just push to your `main` branch
   - Cloudflare will auto-deploy

## Fixes Needed Before Deployment

### Fix 1: Correct Redirect Paths

The `preview/index.html` redirect should work, but let's ensure it's correct:

```javascript
// Current: redirects to /index.html
// Should work if root index.html exists (which it does)
```

**Status:** ✅ Already correct - root `/index.html` exists

### Fix 2: Ensure Proxy Function Works

The proxy function at `functions/proxy.js` should work automatically with Git integration.

**Status:** ✅ Function exists and should auto-deploy

### Fix 3: Verify Import Paths

All ES module imports should use relative paths. Let me verify these are correct.

**Check needed:** Import paths in preview files

## Quick Fix Checklist

Before deploying, verify:

- [ ] Root `/index.html` exists (✅ confirmed)
- [ ] `functions/proxy.js` exists (✅ confirmed)
- [ ] `wrangler.toml` has correct config (✅ confirmed)
- [ ] `.cfignore` excludes dev files (✅ confirmed)
- [ ] `preview/v3-prototype/_headers` exists (✅ confirmed)

## Deployment Test Plan

After deploying via Git:

1. **Test Root URL:**
   ```
   https://your-project.pages.dev/
   ```
   Should load root `index.html` → preview app

2. **Test Preview Redirect:**
   ```
   https://your-project.pages.dev/preview/index.html
   ```
   Should redirect to root `index.html`

3. **Test Proxy Function:**
   ```
   https://your-project.pages.dev/proxy?url=https://example.com
   ```
   Should proxy the external site

4. **Test V3 Preview:**
   ```
   https://your-project.pages.dev/preview/v3-prototype/index.html
   ```
   Should load v3 prototype

5. **Test Player:**
   ```
   https://your-project.pages.dev/preview/app/survey/player.html
   ```
   Should load in iframe

## Troubleshooting Deployment Issues

### If redirects don't work:
- Check browser console for errors
- Verify paths are relative (not absolute)
- Check Cloudflare Pages build logs

### If proxy doesn't work:
- Verify `functions/proxy.js` is deployed
- Check Cloudflare Functions logs
- Verify environment variables are set

### If modules don't load:
- Check import paths are relative
- Verify MIME types (should be `application/javascript` for `.js`)
- Check browser console for 404 errors

## Next Steps

1. **I can help set up Git integration** - Just tell me if you want me to guide you through it
2. **Fix any import path issues** - I can check and fix these
3. **Test locally** - We can simulate the Cloudflare Pages structure locally first

Would you like me to:
- Check and fix any import path issues?
- Create a test script to verify deployment structure?
- Guide you through Git integration setup?

