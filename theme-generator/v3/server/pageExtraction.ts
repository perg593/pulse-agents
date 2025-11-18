import type { Page } from 'playwright';
import type { ColorSample } from './colorExtraction';
import { rgbToHex } from './colorExtraction';

/**
 * Extracts CSS custom properties from a page
 * Phase 3.9: Expanded to scan header/theme containers in addition to :root
 */
export async function extractCSSVariables(page: Page): Promise<Record<string, string>> {
  const cssVars = await page.evaluate(`
    (function() {
      const vars = {};
      
      // Helper to extract CSS vars from an element
      function extractFromElement(element, selector) {
        try {
          const styles = window.getComputedStyle(element);
          for (let i = 0; i < styles.length; i++) {
            const prop = styles[i];
            if (prop.startsWith('--')) {
              const value = styles.getPropertyValue(prop).trim();
              if (value && !vars[prop]) {
                vars[prop] = value;
              }
            }
          }
        } catch (e) {
          // Ignore errors
        }
      }
      
      // Extract from :root (document.documentElement)
      extractFromElement(document.documentElement, ':root');
      
      // Extract from header/theme containers (Phase 3.9)
      const containers = [
        document.querySelector('header'),
        document.querySelector('.header'),
        document.querySelector('.global-header'),
        document.querySelector('.site-header'),
        document.querySelector('.theme'),
        document.querySelector('[data-theme]'),
        document.querySelector('.nav'),
        document.querySelector('.navbar'),
        document.querySelector('.top-nav'),
        document.querySelector('.site-branding'),
        document.querySelector('.branding')
      ];
      
      for (const container of containers) {
        if (container) {
          extractFromElement(container, '');
        }
      }
      
      // Also check style sheets for :root and container rules
      const styleSheets = Array.from(document.styleSheets);
      for (const sheet of styleSheets) {
        try {
          const rules = Array.from(sheet.cssRules || []);
          for (const rule of rules) {
            if (rule instanceof CSSStyleRule) {
              const selector = rule.selectorText;
              // Check :root and container selectors
              if (selector === ':root' || 
                  selector.includes('header') || 
                  selector.includes('.theme') ||
                  selector.includes('[data-theme]') ||
                  selector.includes('.branding')) {
                const ruleStyles = rule.style;
                for (let i = 0; i < ruleStyles.length; i++) {
                  const prop = ruleStyles[i];
                  if (prop.startsWith('--')) {
                    const value = ruleStyles.getPropertyValue(prop).trim();
                    if (value && !vars[prop]) {
                      vars[prop] = value;
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          // Cross-origin stylesheets may throw
        }
      }
      
      return vars;
    })()
  `);
  
  // Filter for brand/color-related variables
  const filtered: Record<string, string> = {};
  for (const [key, value] of Object.entries(cssVars)) {
    const lowerKey = key.toLowerCase();
    if (
      lowerKey.includes('brand') ||
      lowerKey.includes('color') ||
      lowerKey.includes('primary') ||
      lowerKey.includes('accent') ||
      lowerKey.includes('theme')
    ) {
      // Convert to hex if it's a color value
      let hexValue = value;
      if (value.startsWith('rgb')) {
        hexValue = rgbToHex(value);
      } else if (!value.startsWith('#')) {
        // Might be a reference to another variable, skip for now
        continue;
      }
      filtered[key] = hexValue;
    }
  }
  
  return filtered;
}

/**
 * Samples button colors from a page
 * Phase 3.9: Enhanced with weighted frequency for CTA/primary buttons
 */
export async function extractButtonColors(page: Page): Promise<ColorSample[]> {
  const samples = await page.evaluate(`
    (function() {
      function rgbToHex(rgb) {
        if (rgb.startsWith('#')) return rgb;
        if (rgb.startsWith('rgb')) {
          const match = rgb.match(/\\d+/g);
          if (match && match.length >= 3) {
            const r = parseInt(match[0]).toString(16).padStart(2, '0');
            const g = parseInt(match[1]).toString(16).padStart(2, '0');
            const b = parseInt(match[2]).toString(16).padStart(2, '0');
            return '#' + r + g + b;
          }
        }
        return rgb;
      }
      
      const samples = [];
      const allButtons = Array.from(document.querySelectorAll('button, .btn, .button, [class*="cta-button"]'));
      
      // Separate important buttons (CTAs, primary) from regular buttons
      const importantButtons = Array.from(document.querySelectorAll(
        '[class*="primary"], [class*="cta"], [class*="primary-button"], [class*="cta-button"], button.primary, .btn-primary'
      ));
      
      const regularButtons = allButtons.filter(btn => !importantButtons.includes(btn));
      
      // Process important buttons with higher weight
      for (let i = 0; i < Math.min(20, importantButtons.length); i++) {
        const btn = importantButtons[i];
        const style = window.getComputedStyle(btn);
        const bgColor = style.backgroundColor;
        const textColor = style.color;
        const borderColor = style.borderColor;
        
        // CTA background colors get 1.5x weight
        if (bgColor && bgColor !== 'rgba(0, 0, 0, 0)' && bgColor !== 'transparent') {
          samples.push({
            color: rgbToHex(bgColor),
            frequency: 1.5,
            source: 'button'
          });
        }
        
        // CTA text colors get 1.2x weight
        if (textColor && textColor !== 'rgba(0, 0, 0, 0)') {
          samples.push({
            color: rgbToHex(textColor),
            frequency: 1.2,
            source: 'button'
          });
        }
        
        if (borderColor && borderColor !== 'rgba(0, 0, 0, 0)' && borderColor !== 'transparent') {
          samples.push({
            color: rgbToHex(borderColor),
            frequency: 0.75, // Borders are less important but still weighted
            source: 'button'
          });
        }
      }
      
      // Process regular buttons with normal weight
      for (let i = 0; i < Math.min(20, regularButtons.length); i++) {
        const btn = regularButtons[i];
        const style = window.getComputedStyle(btn);
        const bgColor = style.backgroundColor;
        const textColor = style.color;
        const borderColor = style.borderColor;
        
        if (bgColor && bgColor !== 'rgba(0, 0, 0, 0)' && bgColor !== 'transparent') {
          samples.push({
            color: rgbToHex(bgColor),
            frequency: 1,
            source: 'button'
          });
        }
        
        if (textColor && textColor !== 'rgba(0, 0, 0, 0)') {
          samples.push({
            color: rgbToHex(textColor),
            frequency: 1,
            source: 'button'
          });
        }
        
        if (borderColor && borderColor !== 'rgba(0, 0, 0, 0)' && borderColor !== 'transparent') {
          samples.push({
            color: rgbToHex(borderColor),
            frequency: 0.5, // Borders are less important
            source: 'button'
          });
        }
      }
      
      return samples;
    })()
  `);
  
  return samples;
}

/**
 * Samples link colors from a page
 * Phase 3.9: Enhanced with weighted frequency for nav/CTA links
 */
export async function extractLinkColors(page: Page): Promise<ColorSample[]> {
  const samples = await page.evaluate(`
    (function() {
      function rgbToHex(rgb) {
        if (rgb.startsWith('#')) return rgb;
        if (rgb.startsWith('rgb')) {
          const match = rgb.match(/\\d+/g);
          if (match && match.length >= 3) {
            const r = parseInt(match[0]).toString(16).padStart(2, '0');
            const g = parseInt(match[1]).toString(16).padStart(2, '0');
            const b = parseInt(match[2]).toString(16).padStart(2, '0');
            return '#' + r + g + b;
          }
        }
        return rgb;
      }
      
      const samples = [];
      
      // Nav links (higher weight: 1.2x)
      const navLinks = Array.from(document.querySelectorAll('nav a, .nav a, .navbar a, .top-nav a, header a'));
      for (let i = 0; i < Math.min(20, navLinks.length); i++) {
        const link = navLinks[i];
        const style = window.getComputedStyle(link);
        const linkColor = style.color;
        
        // Check for active/hover states
        const isActive = link.classList.contains('active') || 
                        link.getAttribute('aria-current') === 'page' ||
                        link.classList.contains('current');
        
        if (linkColor && linkColor !== 'rgba(0, 0, 0, 0)') {
          samples.push({
            color: rgbToHex(linkColor),
            frequency: isActive ? 1.5 : 1.2, // Active nav links get even higher weight
            source: 'link'
          });
        }
      }
      
      // CTA links (highest weight: 1.5x)
      const ctaLinks = Array.from(document.querySelectorAll(
        'a[class*="cta"], a[class*="button"], a[class*="primary"], .hero a'
      ));
      for (let i = 0; i < Math.min(20, ctaLinks.length); i++) {
        const link = ctaLinks[i];
        const style = window.getComputedStyle(link);
        const linkColor = style.color;
        
        if (linkColor && linkColor !== 'rgba(0, 0, 0, 0)') {
          samples.push({
            color: rgbToHex(linkColor),
            frequency: 1.5,
            source: 'link'
          });
        }
      }
      
      // Regular links (normal weight: 1x)
      const allLinks = Array.from(document.querySelectorAll('a'));
      const regularLinks = allLinks.filter(link => 
        !navLinks.includes(link) && !ctaLinks.includes(link)
      );
      
      for (let i = 0; i < Math.min(30, regularLinks.length); i++) {
        const link = regularLinks[i];
        const style = window.getComputedStyle(link);
        const linkColor = style.color;
        
        if (linkColor && linkColor !== 'rgba(0, 0, 0, 0)') {
          samples.push({
            color: rgbToHex(linkColor),
            frequency: 1,
            source: 'link'
          });
        }
      }
      
      return samples;
    })()
  `);
  
  return samples;
}

/**
 * Extracts background and surface color candidates
 */
export async function extractBackgroundColors(page: Page): Promise<{
  backgrounds: ColorSample[];
  surfaces: ColorSample[];
}> {
  const data = await page.evaluate(`
    (function() {
      function rgbToHex(rgb) {
        if (rgb.startsWith('#')) return rgb;
        if (rgb.startsWith('rgb')) {
          const match = rgb.match(/\\d+/g);
          if (match && match.length >= 3) {
            const r = parseInt(match[0]).toString(16).padStart(2, '0');
            const g = parseInt(match[1]).toString(16).padStart(2, '0');
            const b = parseInt(match[2]).toString(16).padStart(2, '0');
            return '#' + r + g + b;
          }
        }
        return rgb;
      }
      
      const backgrounds = [];
      const surfaces = [];
      
      // Body background
      const bodyStyle = window.getComputedStyle(document.body);
      const bodyBg = bodyStyle.backgroundColor;
      if (bodyBg && bodyBg !== 'rgba(0, 0, 0, 0)' && bodyBg !== 'transparent') {
        backgrounds.push({
          color: rgbToHex(bodyBg),
          frequency: 10, // Body is most important
          source: 'background'
        });
      }
      
      // Header, nav, footer backgrounds
      const structural = document.querySelectorAll('header, nav, footer, .header, .nav, .footer');
      for (let i = 0; i < Math.min(5, structural.length); i++) {
        const el = structural[i];
        const style = window.getComputedStyle(el);
        const bg = style.backgroundColor;
        if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
          backgrounds.push({
            color: rgbToHex(bg),
            frequency: 3,
            source: 'background'
          });
        }
      }
      
      // Hero/large container backgrounds
      const hero = document.querySelector('.hero, .banner, [class*="hero"], [class*="banner"], main > section:first-child');
      if (hero) {
        const style = window.getComputedStyle(hero);
        const bg = style.backgroundColor;
        if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
          backgrounds.push({
            color: rgbToHex(bg),
            frequency: 5,
            source: 'background'
          });
        }
      }
      
      // Surface candidates (cards, panels, containers)
      const surfacesEls = document.querySelectorAll(
        '[class*="card"], [class*="panel"], [class*="container"], [class*="surface"], .card, .panel'
      );
      for (let i = 0; i < Math.min(10, surfacesEls.length); i++) {
        const el = surfacesEls[i];
        const style = window.getComputedStyle(el);
        const bg = style.backgroundColor;
        if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
          surfaces.push({
            color: rgbToHex(bg),
            frequency: 1,
            source: 'surface'
          });
        }
      }
      
      return { backgrounds, surfaces };
    })()
  `);
  
  return data;
}

