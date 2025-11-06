# Quick Setup Steps

## Step 1: Create GitHub Repository

1. **Make sure you're logged into GitHub** (in your browser)
2. Go to: https://github.com/new
3. Fill in:
   - **Repository name:** `pulse-agents`
   - **Description:** (optional) "Pulse Preview application with Protocol v1"
   - **Visibility:** Choose **Public** (free Cloudflare Pages) or **Private**
   - **DO NOT** check:
     - ❌ Add a README file
     - ❌ Add .gitignore
     - ❌ Choose a license
4. Click **"Create repository"**

## Step 2: After Creating the Repo

GitHub will show you commands. **Don't use those** - we already have code committed locally.

Instead, tell me when the repo is created, and I'll run these commands for you:

```bash
# Add GitHub as remote
git remote add origin https://github.com/perg593/pulse-agents.git

# Rename branch to main (if needed)
git branch -M main

# Push code to GitHub
git push -u origin main
```

## Step 3: Connect to Cloudflare Pages

After the code is pushed, we'll:
1. Go to Cloudflare Pages
2. Connect your GitHub repo
3. Configure deployment settings
4. Deploy!

---

**Ready?** Once you've created the repo on GitHub, let me know and I'll push the code!

