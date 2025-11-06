# Pulse Widgets Theme Generation System - Comprehensive Documentation

## 🎯 Project Overview

**Pulse Widgets** is a comprehensive theme generation and preview system for creating branded survey widgets. The system automatically analyzes client websites to extract brand colors and fonts, then generates multiple theme variations that can be applied to various widget types.

### Core Purpose
- **Automated Theme Generation**: Analyze any website to extract brand colors, fonts, and design patterns
- **Multi-Variant Themes**: Generate 4 different theme styles per client (Brand Faithful, High Contrast, Modern, Minimalist)
- **Widget Preview System**: Comprehensive preview interface for testing themes across all widget types
- **Client Management**: Organized theme storage and management system

---

## 📁 Project Architecture

### Directory Structure (Current)
```
pulse_widgets/
├── theme-generator/                   # ✅ Active theme generator
│   ├── main.js                        # Orchestrates analysis → generation
│   ├── analyze-site.js                # Puppeteer-based analyzer
│   ├── theme-generator.js             # Legacy generator (analysis-driven)
│   ├── generate-theme-v2.mjs          # JSON token → CSS pipeline
│   └── output/                        # Generated assets (client-themes/, analysis, etc.)
├── preview/                           # Web preview app + widget fixtures
│   ├── index.html                     # Interactive preview dashboard
│   ├── simple-background.html         # Neutral background for testing
│   ├── widgets/                       # Widget HTML fixtures (desktop & mobile)
│   ├── themes/                        # Example JSON tokens
│   └── scripts/, styles/, dist/       # Preview tooling
├── fonts/                             # Local font assets used during testing
└── legacy/                            # Archived interfaces & deprecated generators
```

---

## 🚀 System Components

### 1. Preview Dashboard (`preview/index.html`)

**Primary Entry Point** – Launch via a static web server (e.g., `python3 -m http.server 8000` and open `/preview/index.html`).

> `/preview/index.html` now redirects to the streamlined basic experience (`/preview/basic/index.html`). The exploratory modular prototype remains available at `/preview/v3/index.html`.

#### Features:
- **Production Tag Bridge**: Boots the live `surveys.js` tag with selectable demo identifiers and updates status badges as the tag progresses.
- **Quick Theme Generator**: Accepts any URL, analyzes colours + typography, and produces four compiled CSS variants ready for download.
- **Curated Theme Library**: Loads curated CSS samples grouped by industry so demos can swap styles instantly.
- **Behavioural Triggers**: Simulates exit intent, rage clicks, scroll depth, timers, and pageview increments to showcase real tag journeys.
- **Survey Dataset Sync**: Pulls the shared Google Sheet of production demos, filters via `?demo=` parameters, and pre-populates the survey dropdown.
- **Status Log & CSS Stack**: Streams runtime events into a log panel and lists the CSS files currently applied to the active survey.

#### Key Technologies:
- **Fetch + CSV Parsing**: Streams the Google Sheet export (`gviz` CSV) to keep the demo survey roster fresh.
- **Pulse Tag Bridge**: Attaches to `window.PulseInsightsObject` / `pi()` when the official tag boots so commands stay in sync.
- **Theme Compiler**: Reuses `preview/basic/theme-generator-client.js` for on-demand Sass compilation and WCAG checks.
- **URLSearchParams**: Handles deep-linking controls (e.g., `demo` filters, `variant` routing between basic and v3).
- **Modular Trigger Simulators**: Generates synthetic DOM events (mouseout, burst clicks, scroll) to mimic behavioural entry points.

#### Interface Layout:
```
┌──────────────────────────────┬──────────────────────────────┐
│ Control Rail                 │ Stage                        │
│ ├─ Survey (dropdown + log)   │ • Pulse Insights agent iframe │
│ ├─ Theme Generator           │ • Live survey overlay        │
│ ├─ Examples (industry)       │                              │
│ ├─ Triggers                  │                              │
│ └─ Tools (status badges/log) │                              │
└──────────────────────────────┴──────────────────────────────┘
```

### 2. Theme Generation System (`theme-generator/`)

#### A. Website Analyzer (`analyze-site.js`)
**Purpose**: Extract brand colors, fonts, and design patterns from any website

**Technology**: Puppeteer for headless browser automation

**Analysis Process**:
1. **Launch Browser**: Headless Chrome via Puppeteer
2. **Navigate to URL**: Wait for network idle (complete page load)
3. **Extract Colors**: 
   - Background colors from all elements
   - Text colors from all elements
   - Primary background and text colors
4. **Extract Fonts**: 
   - Font families from headings, paragraphs, links, buttons
   - Deduplicate and limit to top 5 fonts
5. **Return Analysis**: Structured JSON with colors, fonts, URL, timestamp

**Output Structure**:
```json
{
  "url": "https://example.com",
  "colors": {
    "backgrounds": ["#ffffff", "#f5f5f5", ...],
    "textColors": ["#000000", "#333333", ...],
    "primaryBackground": "#ffffff",
    "primaryText": "#000000"
  },
  "fonts": ["Arial", "Helvetica", ...],
  "timestamp": "2025-10-02T13:26:43.865Z"
}
```

#### B. Theme Generators

The repository supports two complementary pipelines that share the same output folder structure:

1. **`theme-generator.js`** – consumes the live site analysis JSON (from `analyze-site.js`) and produces the standard four themes for a client.
2. **`generate-theme-v2.mjs`** – consumes a JSON “design token” file and emits a single CSS override without re-running Puppeteer. Tokens cover typography stacks, per-widget overrides, spacing, mobile-specific knobs, and color palettes. Required fields and WCAG contrast (text/background, CTA text/background) are validated before CSS is written.

Both generators write their CSS as container-scoped custom properties so the preview tooling and production widgets can swap themes without DOM changes.

**Standard Theme Set**
- **Brand Faithful** – Mirrors detected brand colors/fonts (AirSupra-specific palette baked in).
- **High Contrast** – Black/white UI with brand color accent hover for accessibility.
- **Modern** – Rounded corners, soft shadows, and modernized color pairings.
- **Minimalist** – Neutral palette, typography-first styling.

> Note: color manipulation helpers in the v2 generator intentionally return the supplied values so that the generated CSS reflects the token file exactly; designers control the palette directly in JSON.

#### C. Main Orchestrator (`main.js`)
**Purpose**: Coordinate the entire theme generation process

**Process Flow**:
1. **Parse Arguments**: URL and client name from command line
2. **Analyze Website**: Run site analysis via Puppeteer
3. **Generate Themes**: Create 4 theme variations
4. **Save Files**: Write CSS files and metadata
5. **Update Index**: Update master client index
6. **Report Results**: Display generation summary

**Usage**:
```bash
node main.js https://example.com client-name
```

### 3. Widget Fixtures (`preview/widgets/`)

#### Widget Types:
1. **Docked Widget**: Fixed position, right side of screen
2. **Bottom Bar Widget**: Slides up from bottom
3. **Inline Widget**: Embedded within page content
4. **Overlay Widget**: Modal-style overlay
5. **Top Bar Widget**: Slides down from top

#### Widget Variants:
- **Desktop**: Full-featured desktop experience
- **Mobile**: Optimized for mobile devices

#### Question Types:
- **Single Choice**: Radio buttons or standard buttons
- **Multiple Choice**: Checkboxes
- **Free Text**: Single line or multiple lines
- **Custom Content**: Rich HTML content
- **Thank You**: Completion message

#### CSS Architecture:
- **Default Styles**: Base styling in `preview/widgets/css/styles_default_*.css`
- **Theme Override**: Dynamic theme loading via `preview/widgets/theme-loader.js`
- **CSS Variables**: Theme customization via CSS custom properties
- **Responsive**: Mobile-first responsive design

---

## 🎨 Theme System Architecture

### CSS Custom Properties
All themes use CSS custom properties for easy customization:

Key tokens emitted by `generate-theme-v2.mjs` (rendered inside `#_pi_surveyWidgetContainer`):

```css
#_pi_surveyWidgetContainer {
  --pi-font: "Mulish", system-ui, sans-serif;
  --pi-text: #1f2937;
  --pi-bg: #ffffff;
  --pi-primary: #ff6b35;
  --pi-primary-hover: #dc2626;
  --pi-primary-active: #b91c1c;
  --pi-on-primary: #ffffff;
  --pi-answer-border: #1f2937;
  --pi-input-border: #d1d5db;
  --pi-input-focus: #2563eb;
  --pi-question-size: 28px;
  --pi-answer-size: 16px;
  --pi-btn-pad-desktop: 12px 30px;
  --pi-btn-pad-mobile: 10px 20px;
  /* …additional radius, shadow, and mobile overrides… */
}
```

### Theme Application Process:
1. **URL Parameter**: `?theme=client-name/theme-id`
2. **Theme Loader**: `theme-loader.js` reads URL parameter
3. **CSS Loading**: Dynamically loads theme CSS file
4. **Override Application**: Theme CSS overrides default styles
5. **Real-time Preview**: Changes apply immediately

### File Organization:
```
output/client-themes/
├── index.json                    # Master index of all clients/themes
├── client-name/                  # Individual client folder
│   ├── brand-faithful.css       # Brand faithful theme
│   ├── high-contrast.css        # High contrast theme
│   ├── modern.css               # Modern theme
│   ├── minimalist.css           # Minimalist theme
│   └── themes.json              # Client theme metadata
└── examples/                     # Example themes
```

---

## 🔧 Technical Implementation

### Dependencies
```json
{
  "puppeteer": "^24.23.0",        // Headless browser automation
  "cheerio": "^1.0.0-rc.12"       // HTML parsing (if needed)
}
```

### Font System
- **Google Fonts**: 100+ fonts pre-loaded for comprehensive testing
- **AirSupra Fonts**: Local Montserrat and Barlow families
- **Font Fallbacks**: Proper fallback chains for all fonts
- **Font Loading**: Optimized loading with preconnect

### Browser Compatibility
- **Modern Browsers**: Chrome, Firefox, Safari, Edge
- **CSS Custom Properties**: Full support in modern browsers
- **Puppeteer**: Node.js 14+ required for theme generation
- **Mobile Support**: Responsive design for all screen sizes

### Performance Notes
- **JSON Token Path**: `generate-theme-v2.mjs` avoids repeat Puppeteer runs once analysis is complete.
- **Validation Before Write**: Missing tokens or low contrast stop the build early.
- **Preview Manifest Build**: A single script regenerates theme/asset metadata for the preview UI.
- **Manual Overrides**: The preview accepts ad-hoc CSS without touching the client index.

---

## 🚀 Usage Instructions

### 1. Setup
```bash
# Navigate to theme generation directory
cd theme-generator

# Install dependencies
npm install
```

### 2. Generate Themes
```bash
# Generate themes for a client
node main.js https://example.com client-name

# Example: Generate themes for AirSupra
node main.js https://www.airsuprahcp.com airsupra
```

### 2b. Generate a CSS file from JSON tokens
```bash
# From theme-generator/
npm run generate:v2 -- ../preview/themes/default.json preview/dist/default.css
```

### 3. Build Preview Assets & Launch UI
```bash
# From theme-generator/
npm run preview:build     # regenerates preview manifest + default CSS

# From repo root, serve files however you like
python3 -m http.server 8000

# Visit the new dashboard
open http://localhost:8000/preview/index.html
```

> `/preview/index.html` redirects to `/preview/basic/index.html`. Open `/preview/v3/index.html` to explore the modular prototype.

Inside the preview dashboard you can:
- pick from the live production survey roster (filtered with `?demo=` or `?demo_code=` parameters),
- generate four fresh themes from any URL or load curated examples by industry,
- trigger behavioural events (exit intent, rage clicks, scroll depth, timers, pageview increments),
- review a running status log and see which CSS files are currently applied.

### 4. Theme + Tag Workflow
- **Present Survey**: Choose a survey and press **Present** (auto-queues when the tag finishes booting).
- **Generate Themes**: Enter a URL to produce four variants (Brand Faithful, High Contrast, Modern, Minimalist).
- **Apply Examples**: Browse curated examples, filter by industry, and apply instantly.
- **Monitor Status**: Watch tag + survey badges, inspect the log panel, and review the applied CSS manifest.

---

## 📊 Current Status & Generated Themes

### Active Clients
- **airsuprahcp**: AirSupra brand themes (orange/blue palette)
- **cnn**: CNN website analysis themes
- **npr**: NPR website analysis themes
- **nytimes**: New York Times website analysis themes
- **pulseinsights**: Pulse Insights brand themes

### Theme Statistics
- **Total Clients**: 5 active clients
- **Themes per Client**: 4 theme variations each
- **Total Themes**: 20 generated themes
- **Last Updated**: October 2-3, 2025

---

## 🔄 Development History

### Version Evolution

#### `preview/widgets/` (Widget Fixtures, formerly `proof_of_concept/`)
- **Purpose**: Widget samples and baseline CSS for preview/testing
- **Status**: Active - Used for widget examples
- **Features**: Basic widget HTML and default CSS (desktop + mobile variants)

#### `theme-mvp/` (Version 1)
- **Purpose**: First theme generation attempt
- **Status**: ⚠️ DEPRECATED
- **Issues**: Limited functionality, basic interface
- **Replacement**: Consolidated into main interface

#### `theme-generator/` (Version 2 - Current)
- **Purpose**: Production-ready theme generation
- **Status**: ✅ ACTIVE
- **Features**: 
  - Robust error handling
  - Professional interface
  - Comprehensive theme generation
  - Client management system
  - Mobile simulation
  - Background loading

### Key Improvements in v2:
- ✅ **Better Error Handling**: Detailed error messages and fallbacks
- ✅ **Professional UI**: Modern interface with gradients and animations
- ✅ **Console Logging**: Comprehensive debugging information
- ✅ **File Organization**: Clean client-specific folder structure
- ✅ **Timeout Management**: Robust handling of slow-loading sites
- ✅ **Fallback Analysis**: Graceful degradation for problematic sites
- ✅ **User Feedback**: Clear progress indicators and status messages

---

## 🎯 Future Development Opportunities

### Immediate Enhancements
1. **Color Palette Expansion**: More sophisticated color analysis
2. **Font Detection**: Better font family and weight detection
3. **Theme Customization**: User-editable theme parameters
4. **Export Options**: Export themes in various formats
5. **Batch Processing**: Generate themes for multiple clients

### Advanced Features
1. **AI-Powered Analysis**: Machine learning for better brand detection
2. **Theme Variations**: More theme types (dark mode, seasonal, etc.)
3. **Real-time Preview**: Live theme editing interface
4. **Theme Marketplace**: Share and discover themes
5. **Integration APIs**: Connect with design tools and CMSs

### Technical Improvements
1. **Performance**: Faster theme generation and loading
2. **Scalability**: Handle larger client bases
3. **Testing**: Automated theme testing and validation
4. **Documentation**: API documentation and developer guides
5. **Deployment**: Production deployment and hosting

---

## 🐛 Troubleshooting

### Common Issues

#### Theme Generation Fails
- **Check URL**: Ensure website is accessible
- **Internet Connection**: Verify network connectivity
- **Puppeteer**: Ensure Node.js and Puppeteer are properly installed
- **Timeout**: Some sites may take longer to load

#### Themes Not Loading
- **File Paths**: Verify theme files exist in correct location
- **Client Name**: Ensure client name matches exactly
- **Browser Console**: Check for JavaScript errors
- **CORS**: Some browsers may block local file loading

#### Widget Preview Issues
- **Mobile Simulation**: Toggle mobile view for mobile widgets
- **Theme Application**: Ensure theme is selected and applied
- **Background Loading**: Try `/preview/simple-background.html` for testing
- **Browser Refresh**: Hard refresh (Ctrl+F5) to clear cache

### Debug Mode
- **Console Logging**: Open browser console (F12) for detailed logs
- **Theme Loading**: Check network tab for CSS file loading
- **Error Messages**: Look for specific error messages in console

---

## 📝 API Reference

### Theme Generation API
```bash
# Generate themes for a client
node main.js <website-url> <client-name>

# Examples
node main.js https://example.com my-client
node main.js https://www.airsuprahcp.com airsupra
```

### Theme Loading API
```javascript
// URL parameter format
?theme=client-name/theme-id

// Examples
?theme=airsupra/brand-faithful
?theme=cnn/modern
?theme=nytimes/high-contrast
```

### CSS Custom Properties
```css
/* Available theme variables */
--pi-primary-color      /* Main brand color */
--pi-secondary-color    /* Secondary brand color */
--pi-text-color         /* Text color */
--pi-background-color   /* Background color */
--pi-border-color       /* Border color */
--pi-hover-color        /* Hover state color */
--pi-font-family        /* Font family with fallbacks */
--pi-border-radius      /* Border radius */
--pi-box-shadow         /* Box shadow */
```

---

## 🎉 Conclusion

The Pulse Widgets Theme Generation System represents a comprehensive solution for automated theme creation and widget customization. With its robust architecture, professional interface, and extensive theme generation capabilities, it provides a solid foundation for future development and expansion.

The system successfully demonstrates:
- **Automated Brand Analysis**: Intelligent extraction of brand colors and fonts
- **Multi-Variant Generation**: Four distinct theme styles per client
- **Professional Preview**: Comprehensive testing and preview interface
- **Scalable Architecture**: Clean, maintainable codebase
- **Client Management**: Organized theme storage and management

This documentation provides a complete understanding of the system's architecture, functionality, and usage, enabling effective continuation of development work with ChatGPT Pro or any other development environment.

---

**Last Updated**: October 3, 2025  
**Version**: 2.0 (theme-generator)  
**Status**: Active Development  
**Maintainer**: Pulse Insights Development Team
