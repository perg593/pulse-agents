# Theme Generator MVP 2.0

A clean, improved version of the theme generator for Pulse Widgets with better error handling, professional interface, and robust functionality.

## 🚀 Quick Start

1. **Install dependencies:**
   ```bash
   cd theme-generator
   npm install
   ```

2. **Generate themes for a client (analysis pipeline):**
   ```bash
   node main.js https://example.com my-client
   ```

3. **Generate a CSS override from a JSON token file:**
   ```bash
   npm run generate:v2 -- ../preview/themes/default.json preview/dist/default.css
   ```

4. **Build preview manifest & launch the dashboard:**
   ```bash
   npm run preview:build
   # from repo root
   python3 -m http.server 8000
   open http://localhost:8000/preview/index.html
   ```

   > `/preview/index.html` redirects to `/preview/basic/index.html`. Visit `/preview/v3/index.html` to explore the modular prototype.

## 📁 Project Structure

```
theme-generator/
├── package.json          # Dependencies and scripts
├── main.js               # Entry point - orchestrates everything
├── analyze-site.js       # Website analyzer using Puppeteer
├── theme-generator.js    # Generates 4 theme variations (analysis pipeline)
├── generate-theme-v2.mjs # JSON-driven theme generator (single CSS output)
├── README.md             # This file
└── output/               # Generated themes
    └── client-themes/
        ├── index.json   # Client/theme index
        └── [client-name]/
            ├── brand-faithful.css
            ├── high-contrast.css
            ├── modern.css
            ├── minimalist.css
            └── themes.json
```

## ✨ Features

### **Professional Dashboard**
- **Dual selection methods** - dropdowns AND clickable lists
- **Real-time theme info** display with descriptions
- **CSS variables viewer** showing generated theme variables
- **Professional styling** with gradients and animations

### **Robust Theme Generation**
- **4 theme variations** per client:
  - **Brand Faithful** - Matches client's brand colors and fonts
  - **High Contrast** - Accessibility-focused design
  - **Modern** - Contemporary design with modern colors
  - **Minimalist** - Clean and simple approach

### **Advanced Error Handling**
- **Timeout management** for slow-loading sites
- **Fallback analysis** when sites fail to load
- **Detailed error messages** with troubleshooting tips
- **Console logging** for debugging

### **Smart File Management**
- **Client-specific folders** for organization
- **Master index file** for web interface
- **Automatic CSS generation** with proper variables
- **Clean file structure** for easy maintenance

## 🎨 Generated Themes

Each CSS file includes:
- **Scoped CSS Custom Properties** for typography, colors, spacing, and widget-specific overrides.
- **Desktop + mobile rules**, with optional mobile overrides driven by JSON tokens.
- **Validation hooks** — missing required tokens or low-contrast palettes stop the build before output.
- **Consistent widget coverage** ready to load in the preview dashboard or production widgets.

## 🖥️ Preview Dashboard

The dedicated dashboard under `/preview` lets you:
- Swap clients, themes, and representative widgets instantly.
- Apply a background URL (live site or `/preview/simple-background.html`).
- Inject a manual CSS file (generated or experimental) without touching the index.
- View live contrast checks (target ≥ 4.5:1) sourced from the currently applied CSS.

## 🔧 Usage Examples

### Generate themes for a new client (analysis pipeline):
```bash
node main.js https://www.airsuprahcp.com airsupra
```

### Compile a JSON token file into CSS:
```bash
npm run generate:v2 -- ../preview/themes/default.json preview/dist/default.css
```

### Rebuild preview assets & open the dashboard:
```bash
npm run preview:build
python3 -m http.server 8000
open http://localhost:8000/preview/index.html
```

> `/preview/index.html` redirects to `/preview/basic/index.html`. Visit `/preview/v3/index.html` to explore the modular prototype.


## 🐛 Troubleshooting

### Common Issues:

1. **"No client index found"**
   - Run `node main.js https://example.com test-client` first
   - Check that `output/client-themes/index.json` exists

2. **"Error Loading Theme"**
   - Verify the client name matches exactly
   - Check that CSS files exist in the client folder
   - Look at browser console for detailed error messages

3. **Site analysis fails**
   - Try a different website URL
   - Check your internet connection
   - The system will use fallback colors if the site is too slow

### Debug Mode:
Open browser console (F12) to see detailed logging of:
- Client loading process
- Theme selection
- CSS file loading
- Error details

## 🚀 Next Steps

This MVP provides a solid foundation for:
- **Theme customization** via CSS variables
- **Client management** with organized file structure
- **Web interface** for theme preview and management
- **Scalable architecture** for future enhancements

## 📝 Scripts

- `npm start` - Run the main theme generation
- `npm run analyze` - Analyze a website only
- `npm run generate` - Generate themes from existing analysis
- `npm run test` - Test with example.com
- `npm run generate:v2` - Generate CSS from a JSON token file
- `npm run preview:build` - Regenerate preview manifest + default CSS
- `npm run preview:theme` - Compile a JSON token into `preview/dist/`

## 🎯 Improvements in v2.0

- ✅ **Better error handling** with detailed messages
- ✅ **Professional UI** with gradients and animations
- ✅ **Console logging** for debugging
- ✅ **Improved file organization**
- ✅ **Robust timeout management**
- ✅ **Fallback analysis** for problematic sites
- ✅ **Better user feedback** throughout the process
