# Simple Background for Pulse Widgets Preview

## Overview
The `preview/simple-background.html` file provides a clean, minimal background for testing Pulse Widgets without the complexity of external websites.

## Features
- **Minimal Design**: Simple gray background with no content
- **Ultra-Fast Loading**: Minimal HTML with basic styling only
- **Widget-Friendly**: Completely neutral background for testing widgets
- **No Distractions**: Zero content to interfere with widget previews
- **Universal**: Works on all devices and browsers

## Usage
The simple background ships alongside the preview experiences. The v3 prototype exposes explicit background controls; the basic preview can still load the page directly when you need a neutral host.

1. Run `npm run preview:build` from `theme-generator/`
2. Serve the repository root (e.g., `python3 -m http.server 8000`)
3. Open `http://localhost:8000/preview/v3/index.html` (or browse directly to `/preview/simple-background.html`)
4. In the preview, point the background control to `/preview/simple-background.html`
5. Preview widgets or inline demos against the neutral canvas

## Customization
You can modify `preview/simple-background.html` to:
- Change the background color (currently #808080 gray)
- Add minimal content if needed
- Adjust the styling
- Keep it simple for best widget testing

## Benefits
- **Faster Loading**: No external network requests
- **Consistent**: Same background every time
- **Controlled**: No unexpected content or ads
- **Professional**: Clean appearance for demos
- **Reliable**: Works offline

## File Structure
```
pulse_widgets/
├── preview/
│   ├── simple-background.html    # Clean background page (shared)
│   └── index.html                # Redirect entrypoint (basic preview by default)
└── theme-generator/              # Theme generator + scripts
```

The simple background replaces external websites like `https://www.example.com` to provide a more reliable and fast preview experience. Use it whenever you want a neutral canvas while iterating on widgets and themes.
