# Cloudflare Pages Setup Guide - Step by Step

## ✅ Completed Steps

1. ✅ Fixed deployment issues
2. ✅ Updated `wrangler.toml` with project name "pulse-agents"
3. ✅ Created `.gitignore` file
4. ✅ Initialized Git repository
5. ✅ Created initial commit

## Next Steps

### Step 1: Create GitHub Repository (or use existing)

**Option A: Create new GitHub repository**
1. Go to https://github.com/new
2. Repository name: `pulse-agents` (or your preferred name)
3. Set to **Public** or **Private** (your choice)
4. **DO NOT** initialize with README, .gitignore, or license
5. Click "Create repository"

**Option B: Use existing GitHub repository**
- If you already have a repo, we'll connect to it

### Step 2: Connect Local Repository to GitHub

After creating the GitHub repo, run these commands (I'll help you):

```bash
git remote add origin https://github.com/YOUR_USERNAME/pulse-agents.git
git branch -M main
git push -u origin main
```

### Step 3: Set Up Cloudflare Pages

1. **Log in to Cloudflare Dashboard**
   - Navigate to: https://dash.cloudflare.com
   - Log in with your credentials

2. **Go to Pages**
   - In the left sidebar, click "Workers & Pages"
   - Click "Pages" in the submenu
   - Click "Create a project"

3. **Connect Repository**
   - Click "Connect to Git"
   - Authorize Cloudflare to access your GitHub account
   - Select your repository (`pulse-agents`)

4. **Configure Build Settings**
   - **Project name:** `pulse-agents`
   - **Build command:** (leave empty)
   - **Build output directory:** `.` (just a dot)
   - **Root directory:** (leave empty)
   - **Framework preset:** None

5. **Set Environment Variables**
   - Click "Environment variables"
   - Add:
     - Name: `BACKGROUND_PROXY_ALLOWLIST`
     - Value: `*`
     - Environment: Production, Preview, Branch Preview
   - Add:
     - Name: `BACKGROUND_PROXY_BLOCKLIST`
     - Value: `localhost,127.,::1`
     - Environment: Production, Preview, Branch Preview

6. **Deploy**
   - Click "Save and Deploy"
   - Cloudflare will automatically deploy from your `main` branch
   - Wait for deployment to complete (~2-3 minutes)

7. **Verify Deployment**
   - Once deployed, you'll get a URL like: `https://pulse-agents.pages.dev`
   - Test the following URLs:
     - `https://pulse-agents.pages.dev/` - Main preview
     - `https://pulse-agents.pages.dev/preview/v3/index.html` - V3 prototype
     - `https://pulse-agents.pages.dev/proxy?url=https://example.com` - Proxy function

## Quick Commands Reference

If you need to push updates later:

```bash
# After making changes:
git add .
git commit -m "Your commit message"
git push
```

Cloudflare Pages will automatically deploy after each push to `main`.

## Troubleshooting

**If deployment fails:**
- Check Cloudflare Pages build logs
- Verify environment variables are set
- Ensure `functions/proxy.js` exists
- Check that `wrangler.toml` has correct name

**If proxy doesn't work:**
- Verify `functions/proxy.js` is deployed (check Functions tab in Cloudflare)
- Check environment variables are set correctly

**If modules don't load:**
- Check browser console for errors
- Verify import paths are relative (they should be)

## Need Help?

If you get stuck at any step, let me know and I'll help you through it!

