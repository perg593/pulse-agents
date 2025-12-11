## Cloudflare Pages Deployment Reference

This project deploys automatically to Cloudflare Pages. Use this as the single source of truth for how we publish, monitor, and roll back.

### Branches and Environments
- **Production:** `main` (auto-deploys to `pulse-agents-demo.pages.dev`).
- **Preview:** Any pushed branch/PR (auto-deploys to a unique preview URL).

### Normal Production Publish (recommended)
1) Ensure `main` has the desired changes (typically via **Squash and Merge** in PR).
2) Cloudflare Pages auto-builds and deploys from `main` (~2–5 minutes).
3) Verify deployment:
   - GitHub Checks: `Cloudflare Pages` must be ✅.
   - Dashboard: Pages → `pulse-agents-demo` → Deployments → latest commit.
4) Validate production:
   - `https://pulse-agents-demo.pages.dev/`
   - Proxy: `https://pulse-agents-demo.pages.dev/proxy?url=https://example.com`

### Preview Deployments (per branch/PR)
- Trigger: Push to any branch or open/update a PR.
- Access: PR checks include a Pages preview link; also visible in Cloudflare Pages → Deployments (source branch shows).
- Use previews for QA before merging to `main`.

### Manual Redeploy / Rollback
- **Dashboard rollback (preferred):**
  - Cloudflare Pages → `pulse-agents-demo` → Deployments → select a previous successful deployment → “Rollback to this deployment”.
- **CLI (requires `wrangler` configured):**
  - List: `wrangler pages deployment list`
  - Roll back: `wrangler pages deployment rollback <deployment-id>`
  - Tail logs: `wrangler pages deployment tail --project-name pulse-agents-demo`

### Environment / Config
- **Production branch:** `main`.
- **Env vars:** Managed in Cloudflare dashboard; local dev uses `wrangler.toml` (e.g., `PROXY_CF_PASSTHROUGH_DOMAINS`).
- **Build output:** Static build plus Pages Functions under `functions/` (e.g., `proxy.js`, `[[path]].js`).

### Checks Before Publishing
- ✅ All CI checks pass (Build, Tests, CodeQL, Cloudflare Pages).
- ✅ PR merged (squash recommended for clean history).
- ✅ No pending conflicts; branch synced with `main`.

### Troubleshooting
- Deployment not starting: confirm branch is `main` for production, check GitHub Actions permissions, and Cloudflare Pages GitHub connection.
- Deployment failed: review Cloudflare Pages build logs; verify env vars and dependencies.
- Changes not visible: hard refresh, check Cloudflare cache, confirm deployment commit SHA matches expected.

### Quick Commands
- Merge PR with squash: `gh pr merge <num> --squash`
- Pull latest production locally: `git checkout main && git pull origin main`
- View recent deployments: `wrangler pages deployment list`
- Tail deployment logs: `wrangler pages deployment tail --project-name pulse-agents-demo`
# ✅ Successfully Pushed to GitHub!

Your code is now live at: **https://github.com/perg593/pulse-agents**

## Next: Set Up Cloudflare Pages

I'm opening Cloudflare Pages for you now. Here's what to do:

### Step 1: Create New Project
1. Click **"Create a project"** button
2. Click **"Connect to Git"**

### Step 2: Authorize GitHub
1. Click **"GitHub"** (or your Git provider)
2. Authorize Cloudflare to access your GitHub account
3. Select repository: **`pulse-agents`**

### Step 3: Configure Build Settings
Fill in these settings:
- **Project name:** `pulse-agents`
- **Production branch:** `main`
- **Build command:** (leave empty)
- **Build output directory:** `.` (just a dot)
- **Root directory:** (leave empty)
- **Framework preset:** `None`

### Step 4: Set Environment Variables
Click **"Environment variables"** and add:

**Variable 1:**
- Name: `BACKGROUND_PROXY_ALLOWLIST`
- Value: `*`
- Environment: ☑ Production ☑ Preview ☑ Branch Preview

**Variable 2:**
- Name: `BACKGROUND_PROXY_BLOCKLIST`
- Value: `localhost,127.,::1`
- Environment: ☑ Production ☑ Preview ☑ Branch Preview

### Step 5: Deploy!
1. Click **"Save and Deploy"**
2. Wait 2-3 minutes for deployment
3. Your site will be live at: `https://pulse-agents.pages.dev`

### Step 6: Verify Deployment
Test these URLs:
- `https://pulse-agents.pages.dev/` - Main preview
- `https://pulse-agents.pages.dev/preview/v3-prototype/index.html` - V3 prototype
- `https://pulse-agents.pages.dev/proxy?url=https://example.com` - Proxy function

---

**Need help?** Let me know if you get stuck at any step!

