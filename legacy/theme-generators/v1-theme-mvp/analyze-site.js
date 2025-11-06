const puppeteer = require('puppeteer');
const fs = require('fs');

class SimpleSiteAnalyzer {
  async analyze(url) {
    console.log(`Analyzing ${url}...`);
    
    const browser = await puppeteer.launch({ 
      headless: "new",
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();
    
    // Set longer timeout and more lenient wait conditions
    page.setDefaultTimeout(60000); // 60 seconds
    
    try {
      await page.goto(url, { 
        waitUntil: 'domcontentloaded', // Less strict than networkidle2
        timeout: 60000 
      });
    } catch (error) {
      console.log('⚠️  Site loading slowly, trying with basic load...');
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
    
    // Wait a bit for any dynamic content to load
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Extract basic color information
    const colors = await page.evaluate(() => {
      const body = document.body;
      const computedStyle = window.getComputedStyle(body);
      
      // Find all elements with background colors
      const elements = document.querySelectorAll('*');
      const backgrounds = [];
      const textColors = [];
      
      elements.forEach(el => {
        const bg = window.getComputedStyle(el).backgroundColor;
        const color = window.getComputedStyle(el).color;
        
        if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
          backgrounds.push(bg);
        }
        if (color && color !== 'rgba(0, 0, 0, 0)') {
          textColors.push(color);
        }
      });
      
      return {
        backgrounds: [...new Set(backgrounds)].slice(0, 10),
        textColors: [...new Set(textColors)].slice(0, 10),
        primaryBackground: computedStyle.backgroundColor,
        primaryText: computedStyle.color
      };
    });
    
    // Extract font information
    const fonts = await page.evaluate(() => {
      const elements = document.querySelectorAll('h1, h2, h3, p, a, button');
      const fontFamilies = [];
      
      elements.forEach(el => {
        const font = window.getComputedStyle(el).fontFamily;
        if (font) fontFamilies.push(font);
      });
      
      return [...new Set(fontFamilies)].slice(0, 5);
    });
    
    await browser.close();
    
    return {
      url,
      colors,
      fonts,
      timestamp: new Date().toISOString()
    };
  }

  getFallbackAnalysis(url) {
    console.log('Using fallback analysis - generating themes with default colors');
    return {
      url,
      colors: {
        backgrounds: ['#ffffff', '#f8f9fa', '#e9ecef'],
        textColors: ['#333333', '#666666', '#000000'],
        primaryBackground: '#ffffff',
        primaryText: '#333333'
      },
      fonts: ['Arial, sans-serif', 'Helvetica, sans-serif'],
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
  
  console.log('Analysis saved to ./output/site-analysis.json');
  console.log('Colors found:', analysis.colors.backgrounds.length);
  console.log('Fonts found:', analysis.fonts.length);
}

// Only run main if this file is executed directly
if (require.main === module) {
  main().catch(console.error);
}
