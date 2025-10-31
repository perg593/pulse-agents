# Cloudflare Pages Deployment Guide

This guide covers deploying the Pulse Preview application to Cloudflare Pages.

## Prerequisites

- Cloudflare account with Pages enabled
- Git repository connected to Cloudflare Pages (or Wrangler CLI installed)
- Node.js 16+ installed locally (for build steps)

## Current Configuration

### Wrangler Configuration (`wrangler.toml`)

```toml
name = "pulse-agents-demo"
compatibility_date = "2024-12-01"
pages_build_output_dir = "."

[vars]
BACKGROUND_PROXY_ALLOWLIST = "*"
BACKGROUND_PROXY_BLOCKLIST = "localhost,127.,::1"
```

**Note:** The `pages_build_output_dir = "."` means Cloudflare Pages will deploy the entire repository root (minus exclusions in `.cfignore`).

### Exclusion List (`.cfignore`)

The `.cfignore` file excludes development files from deployment:
- `node_modules/`, `output/`, build artifacts
- `docs/`, `legacy/`, `scripts/`, `theme-generator/` (dev tooling)
- `.env` files, logs, temporary files
- IDE and editor files

### Security Headers (`preview/v3/_headers`)

The application includes Cloudflare Pages headers for:
- Content Security Policy (CSP)
- Frame protection (`frame-ancestors`)
- Cache control for static assets

## Deployment Options

### Option 1: Git Integration (Recommended) ⭐ **BEST FOR NON-GIT USERS**

**Why Git Integration is Better:**
- ✅ Automatic Cloudflare Function detection (`functions/` auto-deploys)
- ✅ No CLI commands needed
- ✅ Preview deployments for every PR
- ✅ Easy rollback via dashboard
- ✅ Better build logs and error visibility

**Setup Steps:**

1. **Connect Repository to Cloudflare Pages**
   - Go to Cloudflare Dashboard → Pages → Create a project
   - Click "Connect to Git"
   - Authorize Cloudflare to access your repository (GitHub/GitLab/Bitbucket)
   - Select your repository

2. **Configure Build Settings:**
   - **Build command**: (leave empty - no build step needed)
   - **Build output directory**: `.` (root)
   - **Root directory**: (leave empty)
   - **Framework preset**: None

3. **Set Environment Variables:**
   - Click "Environment variables" in project settings
   - Add:
     - `BACKGROUND_PROXY_ALLOWLIST` = `*`
     - `BACKGROUND_PROXY_BLOCKLIST` = `localhost,127.,::1`

4. **Deploy**
   - Click "Save and Deploy"
   - Cloudflare will automatically deploy from your default branch
   - Future pushes to `main`/`master` will auto-deploy

**Note:** If you're not comfortable with Git, I can help you commit and push changes. Just tell me what you want to deploy!

### Option 2: Wrangler CLI

1. **Install Wrangler CLI** (if not already installed)
   ```bash
   npm install -g wrangler
   ```

2. **Authenticate**
   ```bash
   wrangler login
   ```

3. **Build Preview Data** (Optional - if you need to regenerate data)
   ```bash
   npm run build
   ```

4. **Deploy**
   ```bash
   wrangler pages deploy .
   ```

   Or deploy a specific directory:
   ```bash
   wrangler pages deploy preview
   ```

## Build Output Structure

After deployment, your site structure will be:

```
/
├── preview/
│   ├── index.html          # Main preview entry point
│   ├── v3/
│   │   ├── index.html      # V3 preview prototype
│   │   ├── _headers        # Cloudflare Pages headers
│   │   └── ...
│   ├── app/                # Preview application code
│   ├── basic/              # Basic preview
│   └── ...
├── functions/              # Cloudflare Functions (if any)
└── wrangler.toml          # Configuration
```

## Important Files for Deployment

### Required Files

- `preview/index.html` - Main entry point
- `preview/v3/_headers` - Security headers
- `preview/app/` - Application code
- `preview/v3/` - V3 preview assets
- `preview/styles/` - CSS files
- `preview/fonts/` - Font assets
- `wrangler.toml` - Cloudflare configuration

### Optional Build Steps

If you need to regenerate preview data before deployment:

```bash
# Build preview manifest and demo data
npm run build

# Or individually:
node scripts/build/preview-data.js
node scripts/build/demo-data.js
```

## Post-Deployment Verification

After deployment, verify:

1. **Main Preview**
   - Navigate to `https://your-project.pages.dev/preview/index.html`
   - Should redirect to basic preview or show v3 prototype

2. **V3 Preview**
   - Navigate to `https://your-project.pages.dev/preview/v3/index.html`
   - Should load the v3 prototype interface

3. **Player iframe**
   - Navigate to `https://your-project.pages.dev/preview/app/survey/player.html`
   - Should load in iframe (check CSP headers)

4. **Security Headers**
   - Use browser DevTools → Network tab
   - Check response headers for CSP and frame-ancestors
   - Main preview should have `frame-ancestors 'none'`
   - Player should have `frame-ancestors 'self'`

5. **Protocol v1**
   - Test with `?useProtocolV1=1` query parameter
   - Verify bridge and player communicate correctly

## Troubleshooting

### Build Failures

- **Check `.cfignore`**: Ensure required files aren't excluded
- **Verify paths**: Check that all imports use relative paths compatible with deployment
- **Review logs**: Check Cloudflare Pages build logs for errors

### Runtime Errors

- **CSP violations**: Check `preview/v3/_headers` and adjust if needed
- **Module not found**: Ensure all ES modules use relative imports
- **Player not loading**: Verify iframe sandbox attributes and CSP `frame-ancestors`

### Missing Assets

- **Fonts**: Ensure `preview/fonts/` is included (not in `.cfignore`)
- **Styles**: Check `preview/styles/` is deployed
- **Themes**: Verify `preview/v3/data/example-themes.json` exists

## Custom Domain Setup

1. In Cloudflare Pages dashboard, go to your project
2. Navigate to "Custom domains"
3. Add your domain
4. Follow DNS setup instructions

## Environment-Specific Configuration

### Development vs Production

The application detects the environment:
- **Localhost**: Uses `http://localhost:3100` for proxy
- **Production**: Uses `window.location.origin` for proxy

### Protocol v1 Defaults

- **Development**: Requires explicit `?useProtocolV1=1` flag
- **Production**: Can be enabled by default (see `bridge.js`)

## Continuous Deployment

Cloudflare Pages supports automatic deployments:
- **Production**: Deploy from `main`/`master` branch
- **Preview**: Deploy from pull requests
- **Custom**: Deploy from specific branches

## Rollback

If deployment issues occur:

1. **Via Cloudflare Dashboard**
   - Go to Pages → Deployments
   - Click on previous successful deployment
   - Click "Retry deployment" or "Rollback to this deployment"

2. **Via Git**
   - Revert commits
   - Push to trigger new deployment

3. **Via Wrangler**
   ```bash
   wrangler pages deployment list
   wrangler pages deployment rollback <deployment-id>
   ```

## Additional Resources

- [Cloudflare Pages Documentation](https://developers.cloudflare.com/pages/)
- [Wrangler CLI Documentation](https://developers.cloudflare.com/workers/wrangler/)
- Security checklist: `docs/planning/2025-10-22_1547 preview v3/06-SECURITY-CHECKLIST.md`

