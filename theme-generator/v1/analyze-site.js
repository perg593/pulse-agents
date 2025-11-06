const puppeteer = require('puppeteer');
const fs = require('fs');

class SimpleSiteAnalyzer {
  async analyze(url) {
    console.log(`🔍 Analyzing ${url}...`);
    
    const browser = await puppeteer.launch({ 
      headless: "new",
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();
    
    // Set longer timeout and more lenient wait conditions
    page.setDefaultTimeout(60000); // 60 seconds
    
    try {
      await page.goto(url, { 
        waitUntil: 'networkidle2',
        timeout: 60000 
      });
    } catch (error) {
      console.log('⚠️  Site loading slowly, trying with DOMContentLoaded fallback...');
      try {
        await page.goto(url, { 
          waitUntil: 'load',
          timeout: 30000 
        });
      } catch (secondError) {
        console.log('⚠️  Using fallback analysis with minimal data...');
        await browser.close();
        return this.getFallbackAnalysis(url);
      }
    }
    
    // Wait a bit for dynamic content and lazy assets
    await new Promise(resolve => setTimeout(resolve, 4000));
    try {
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
      await new Promise(resolve => setTimeout(resolve, 1500));
      await page.evaluate(() => window.scrollTo(0, 0));
    } catch (scrollErr) {
      // Ignore scrolling errors (e.g., short pages)
    }
    
    // Extract comprehensive color information
    const colors = await page.evaluate(() => {
      const body = document.body;
      const computedStyle = window.getComputedStyle(body);
      
      // Find all elements with background colors, focusing on important elements
      const importantSelectors = [
        'header', 'nav', 'main', 'section', 'article', 'aside', 'footer',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'a', 'button', 'input',
        '.header', '.navigation', '.hero', '.banner', '.cta', '.button',
        '[class*="header"]', '[class*="nav"]', '[class*="hero"]', '[class*="banner"]'
      ];
      
      const backgrounds = [];
      const textColors = [];
      const borderColors = [];
      const accentColors = [];
      
      // Analyze important elements first
      importantSelectors.forEach(selector => {
        try {
          const elements = document.querySelectorAll(selector);
          elements.forEach(el => {
            const style = window.getComputedStyle(el);
            const bg = style.backgroundColor;
            const color = style.color;
            const border = style.borderColor;
            
            if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent' && bg !== 'rgb(255, 255, 255)') {
              backgrounds.push(bg);
            }
            if (color && color !== 'rgba(0, 0, 0, 0)' && color !== 'rgb(0, 0, 0)') {
              textColors.push(color);
            }
            if (border && border !== 'rgba(0, 0, 0, 0)' && border !== 'transparent') {
              borderColors.push(border);
            }
          });
        } catch (e) {
          // Ignore invalid selectors
        }
      });
      
      // Also analyze all elements for comprehensive coverage
      const allElements = document.querySelectorAll('*');
      allElements.forEach(el => {
        const style = window.getComputedStyle(el);
        const bg = style.backgroundColor;
        const color = style.color;
        
        if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent' && bg !== 'rgb(255, 255, 255)') {
          backgrounds.push(bg);
        }
        if (color && color !== 'rgba(0, 0, 0, 0)' && color !== 'rgb(0, 0, 0)') {
          textColors.push(color);
        }
      });
      
      // Find accent colors from buttons, links, and interactive elements
      const interactiveElements = document.querySelectorAll('button, a, input[type="button"], input[type="submit"], .btn, [class*="button"], [class*="cta"], [class*="hero"], [class*="banner"]');
      interactiveElements.forEach(el => {
        const style = window.getComputedStyle(el);
        const bg = style.backgroundColor;
        const color = style.color;
        
        if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
          accentColors.push(bg);
        }
        if (color && color !== 'rgba(0, 0, 0, 0)') {
          accentColors.push(color);
        }
      });
      
      // Capture :root custom properties
      const rootStyles = window.getComputedStyle(document.documentElement);
      const rootVariables = {};
      for (let i = 0; i < rootStyles.length; i++) {
        const prop = rootStyles[i];
        if (prop.startsWith('--')) {
          const rawValue = rootStyles.getPropertyValue(prop).trim();
          if (rawValue && rawValue.length) {
            rootVariables[prop] = rawValue;
          }
        }
      }

      try {
        Array.from(document.styleSheets).forEach(sheet => {
          let rules;
          try {
            rules = Array.from(sheet.cssRules || []);
          } catch (cssErr) {
            return;
          }
          rules.forEach(rule => {
            if (rule.selectorText && rule.selectorText.includes(':root') && rule.style) {
              for (let i = 0; i < rule.style.length; i++) {
                const name = rule.style[i];
                if (name.startsWith('--')) {
                  const rawValue = rule.style.getPropertyValue(name).trim();
                  if (rawValue && rawValue.length && !rootVariables[name]) {
                    rootVariables[name] = rawValue;
                  }
                }
              }
            }
          });
        });
      } catch (sheetErr) {
        // Accessing cross-origin stylesheets may fail; ignore gracefully.
      }
      
      // Look for specific brand colors in the page content
      const brandElements = document.querySelectorAll('[style*="background"], [style*="color"]');
      brandElements.forEach(el => {
        const style = el.getAttribute('style');
        if (style) {
          const bgMatch = style.match(/background[^:]*:\s*([^;]+)/);
          const colorMatch = style.match(/color[^:]*:\s*([^;]+)/);
          
          if (bgMatch) {
            const color = bgMatch[1].trim();
            if (color && !color.includes('transparent') && !color.includes('rgba(0,0,0,0)')) {
              accentColors.push(color);
            }
          }
          if (colorMatch) {
            const color = colorMatch[1].trim();
            if (color && !color.includes('transparent') && !color.includes('rgba(0,0,0,0)')) {
              accentColors.push(color);
            }
          }
        }
      });
      
      // Remove duplicates and limit results
      const uniqueBackgrounds = [...new Set(backgrounds)].slice(0, 15);
      const uniqueTextColors = [...new Set(textColors)].slice(0, 15);
      const uniqueBorderColors = [...new Set(borderColors)].slice(0, 10);
      const uniqueAccentColors = [...new Set(accentColors)].slice(0, 10);
      
      return {
        backgrounds: uniqueBackgrounds,
        textColors: uniqueTextColors,
        borderColors: uniqueBorderColors,
        accentColors: uniqueAccentColors,
        primaryBackground: computedStyle.backgroundColor,
        primaryText: computedStyle.color,
        rootVariables
      };
    });
    
    // Extract comprehensive font information
    const fonts = await page.evaluate(() => {
      const importantSelectors = [
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'a', 'button', 'input',
        'header', 'nav', 'main', 'section', 'article', 'aside', 'footer',
        '.header', '.navigation', '.hero', '.banner', '.cta', '.button',
        '[class*="header"]', '[class*="nav"]', '[class*="hero"]', '[class*="banner"]'
      ];
      
      const fontFamilies = [];
      const fontSizes = [];
      const fontWeights = [];
      
      // Analyze important elements first
      importantSelectors.forEach(selector => {
        try {
          const elements = document.querySelectorAll(selector);
          elements.forEach(el => {
            const style = window.getComputedStyle(el);
            const fontFamily = style.fontFamily;
            const fontSize = style.fontSize;
            const fontWeight = style.fontWeight;
            
            if (fontFamily && fontFamily !== 'serif' && fontFamily !== 'sans-serif') {
              fontFamilies.push(fontFamily);
            }
            if (fontSize && fontSize !== '16px') {
              fontSizes.push(fontSize);
            }
            if (fontWeight && fontWeight !== '400') {
              fontWeights.push(fontWeight);
            }
          });
        } catch (e) {
          // Ignore invalid selectors
        }
      });
      
      // Also analyze all elements for comprehensive coverage
      const allElements = document.querySelectorAll('*');
      allElements.forEach(el => {
        const style = window.getComputedStyle(el);
        const fontFamily = style.fontFamily;
        
        if (fontFamily && fontFamily !== 'serif' && fontFamily !== 'sans-serif') {
          fontFamilies.push(fontFamily);
        }
      });
      
      // Clean up font families (remove quotes, get primary font)
      const cleanedFonts = fontFamilies.map(font => {
        // Get the first font in the family
        const firstFont = font.split(',')[0].trim().replace(/['"]/g, '');
        return firstFont;
      }).filter(font => font && font.length > 0);
      
      return {
        families: [...new Set(cleanedFonts)].slice(0, 5),
        sizes: [...new Set(fontSizes)].slice(0, 5),
        weights: [...new Set(fontWeights)].slice(0, 5)
      };
    });
    
    await browser.close();
    
    console.log('✅ Analysis complete');
    console.log(`   Found ${colors.backgrounds.length} background colors`);
    console.log(`   Found ${colors.textColors.length} text colors`);
    console.log(`   Found ${colors.borderColors.length} border colors`);
    console.log(`   Found ${colors.accentColors.length} accent colors`);
    console.log(`   Found ${fonts.families.length} font families`);
    console.log(`   Found ${fonts.sizes.length} font sizes`);
    console.log(`   Found ${fonts.weights.length} font weights`);
    
    // Log some sample colors for debugging
    if (colors.backgrounds.length > 0) {
      console.log(`   Sample backgrounds: ${colors.backgrounds.slice(0, 3).join(', ')}`);
    }
    if (colors.accentColors.length > 0) {
      console.log(`   Sample accents: ${colors.accentColors.slice(0, 3).join(', ')}`);
    }
    if (fonts.families.length > 0) {
      console.log(`   Sample fonts: ${fonts.families.slice(0, 3).join(', ')}`);
    }
    
    return {
      url,
      colors,
      fonts,
      timestamp: new Date().toISOString()
    };
  }

  getFallbackAnalysis(url) {
    console.log('🔄 Using fallback analysis - generating themes with default colors');
    const backgrounds = ['#ffffff', '#f8f9fa', '#e9ecef'];
    const textColors = ['#1f2937', '#4b5563', '#111827'];
    const accentColors = ['#2563eb', '#1d4ed8', '#1e40af'];
    const fontFamilies = ['Arial', 'Helvetica Neue', 'system-ui'];
    return {
      url,
      colors: {
        backgrounds,
        textColors,
        borderColors: ['#d1d5db', '#e5e7eb'],
        accentColors,
        primaryBackground: backgrounds[0],
        primaryText: textColors[0]
      },
      fonts: {
        families: fontFamilies,
        sizes: ['16px', '18px', '14px'],
        weights: ['400', '500', '600']
      },
      timestamp: new Date().toISOString(),
      fallback: true
    };
  }
}

// Export the class
module.exports = SimpleSiteAnalyzer;

// Also keep the main function for standalone use
async function main() {
  const url = process.argv[2];
  if (!url) {
    console.log('Usage: node analyze-site.js <website-url>');
    process.exit(1);
  }
  
  const analyzer = new SimpleSiteAnalyzer();
  const analysis = await analyzer.analyze(url);
  
  // Save analysis
  const outputDir = './output';
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  fs.writeFileSync(
    './output/site-analysis.json', 
    JSON.stringify(analysis, null, 2)
  );
  
  console.log('💾 Analysis saved to ./output/site-analysis.json');
}

// Only run main if this file is executed directly
if (require.main === module) {
  main().catch(console.error);
}
