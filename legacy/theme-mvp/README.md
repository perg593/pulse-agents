// analyze-site.js
const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

class SimpleSiteAnalyzer {
  async analyze(url) {
    console.log(`Analyzing ${url}...`);
    
    const browser = await puppeteer.launch({ headless: true });
    const page = await browser.newPage();
    await page.goto(url, { waitUntil: 'networkidle2' });
    
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
}

// Run the analyzer
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

main().catch(console.error);