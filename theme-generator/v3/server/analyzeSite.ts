import { chromium, type Browser, type Page } from 'playwright';
import type { SiteSnapshot } from '../src/types/siteSnapshot';
import type { ExtractionData, ColorSample } from './colorExtraction';
import { aggregateColors } from './colorExtraction';
import { buildPaletteFromSamples } from './paletteBuilder';
import { crawlPages } from './multiPageCrawler';
import { extractCSSVariables, extractButtonColors, extractLinkColors, extractBackgroundColors } from './pageExtraction';
import { extractLogoColor } from './logoColorExtraction';

/**
 * Analyzes a website and extracts colors, typography, and other design tokens
 * Phase 3.7: Multi-page crawling with improved color extraction
 */
export async function analyzeSite(url: string, maxPages: number = 3): Promise<SiteSnapshot> {
  let browser: Browser | null = null;
  
  try {
    browser = await chromium.launch({ 
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();
    
    // Set desktop viewport
    await page.setViewportSize({ width: 1280, height: 720 });
    
    // Crawl multiple pages
    const pagesToVisit = await crawlPages(page, url, maxPages);
    console.log(`[analyzer] Crawling ${pagesToVisit.length} page(s): ${pagesToVisit.join(', ')}`);
    
    // Aggregate extraction data across all pages
    const extractionData: ExtractionData = {
      cssVariables: {},
      buttonColors: [],
      linkColors: [],
      backgroundCandidates: [],
      surfaceCandidates: []
    };
    
    let screenshotUrl: string | undefined;
    let pageTitle: string | undefined;
    
    // Extract data from each page
    for (let i = 0; i < pagesToVisit.length; i++) {
      const pageUrl = pagesToVisit[i];
      console.log(`[analyzer] Analyzing page ${i + 1}/${pagesToVisit.length}: ${pageUrl}`);
      
      try {
        await page.goto(pageUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(1000);
        
        // Capture screenshot from homepage only
        // Phase 3.95: Playwright returns base64 string (not Buffer), which we wrap in data URL
        // Logo extraction will extract the base64 portion and convert to Buffer for Sharp
        if (i === 0) {
          pageTitle = await page.title();
          try {
            const screenshot = await page.screenshot({ 
              type: 'png',
              fullPage: false,
              encoding: 'base64' // Returns base64 string, not Buffer
            });
            // Wrap in data URL format for storage/display
            screenshotUrl = `data:image/png;base64,${screenshot}`;
            
            // Extract logo color from screenshot (Phase 3.9)
            // extractLogoColor handles data URL extraction and Buffer conversion
            extractionData.logoHint = await extractLogoColor(screenshotUrl);
          } catch (error) {
            console.warn('[analyzer] Failed to capture screenshot:', error);
            // Continue without screenshot - logo extraction will gracefully degrade
          }
        }
        
        // Extract CSS variables
        const cssVars = await extractCSSVariables(page);
        Object.assign(extractionData.cssVariables, cssVars);
        
        // Extract button colors
        const buttonColors = await extractButtonColors(page);
        extractionData.buttonColors.push(...buttonColors);
        
        // Extract link colors
        const linkColors = await extractLinkColors(page);
        extractionData.linkColors.push(...linkColors);
        
        // Extract background/surface colors
        const bgData = await extractBackgroundColors(page);
        extractionData.backgroundCandidates.push(...bgData.backgrounds);
        extractionData.surfaceCandidates.push(...bgData.surfaces);
        
      } catch (error) {
        console.warn(`[analyzer] Failed to analyze page ${pageUrl}:`, error);
        // Continue with other pages
      }
    }
    
    // Aggregate colors by frequency
    extractionData.buttonColors = Array.from(aggregateColors(extractionData.buttonColors).values());
    extractionData.linkColors = Array.from(aggregateColors(extractionData.linkColors).values());
    extractionData.backgroundCandidates = Array.from(aggregateColors(extractionData.backgroundCandidates).values());
    extractionData.surfaceCandidates = Array.from(aggregateColors(extractionData.surfaceCandidates).values());
    
    // Build final palette from all samples (Phase 3.9: Brand Color Priority Model)
    const paletteResult = buildPaletteFromSamples(extractionData);
    
    // Map to SiteSnapshot format
    const detectedColors = {
      background: paletteResult.background,
      surface: paletteResult.surface,
      textPrimary: paletteResult.textPrimary,
      textSecondary: paletteResult.textSecondary,
      brandPrimary: paletteResult.brandPrimary,
      brandSecondary: paletteResult.brandSecondary,
      accent: paletteResult.accent,
      logo: paletteResult.logo // Phase 3.9: Include logo color
    };
    
    // Extract typography from homepage (first page)
    let typography;
    try {
      await page.goto(pagesToVisit[0], { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForTimeout(1000);
      typography = await extractTypography(page);
    } catch (error) {
      console.warn('[analyzer] Failed to extract typography:', error);
      typography = {
        bodyFontFamily: 'system-ui, sans-serif',
        headingFontFamily: 'system-ui, sans-serif',
        baseFontSizePx: 16
      };
    }
    
    return {
      url,
      pageTitle,
      screenshotUrl,
      detectedColors,
      typography
    };
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Site analysis failed: ${error.message}`);
    }
    throw error;
  } finally {
    if (browser) {
      await browser.close().catch(() => {
        // Ignore errors when closing browser
      });
    }
  }
}

/**
 * Extracts typography information from the page
 * Uses string-based evaluation to avoid TypeScript helper injection issues
 */
async function extractTypography(page: Page): Promise<SiteSnapshot['typography']> {
  const typography = await page.evaluate(`
    (function() {
      function extractFontName(fontFamily) {
        return fontFamily.split(',')[0].replace(/['"]/g, '').trim();
      }
      
      const body = document.body;
      const bodyStyle = window.getComputedStyle(body);
      const bodyFontFamily = bodyStyle.fontFamily || 'system-ui, sans-serif';
      const baseFontSizePx = parseFloat(bodyStyle.fontSize) || 16;
      
      let headingFontFamily = bodyFontFamily;
      const headings = document.querySelectorAll('h1, h2');
      const headingArray = Array.from(headings);
      for (let i = 0; i < Math.min(3, headingArray.length); i++) {
        const heading = headingArray[i];
        const style = window.getComputedStyle(heading);
        const fontFamily = style.fontFamily;
        if (fontFamily && fontFamily !== bodyFontFamily) {
          headingFontFamily = fontFamily;
          break;
        }
      }
      
      return {
        bodyFontFamily: extractFontName(bodyFontFamily),
        headingFontFamily: extractFontName(headingFontFamily),
        baseFontSizePx: Math.round(baseFontSizePx)
      };
    })()
  `);
  
  return typography;
}
