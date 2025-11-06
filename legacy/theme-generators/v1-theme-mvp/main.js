const SimpleSiteAnalyzer = require('./analyze-site.js');
const SimpleThemeGenerator = require('./theme-generator.js');

async function main() {
  const url = process.argv[2];
  const clientName = process.argv[3] || 'default';
  
  if (!url) {
    console.log('Usage: node main.js <website-url> [client-name]');
    console.log('Example: node main.js https://example.com example-client');
    process.exit(1);
  }
  
  try {
    console.log('🚀 Starting theme generation...\n');
    
    // Step 1: Analyze the website
    console.log('📊 Analyzing website...');
    const analyzer = new SimpleSiteAnalyzer();
    const analysis = await analyzer.analyze(url);
    console.log('✅ Analysis complete\n');
    
    // Step 2: Generate themes
    console.log('🎨 Generating theme variations...');
    const generator = new SimpleThemeGenerator(analysis);
    const themes = generator.generateThemes();
    console.log('✅ Themes generated\n');
    
    // Step 3: Save everything
    console.log('💾 Saving themes...');
    generator.saveThemes(themes, clientName);
    console.log('✅ All done!\n');
    
    // Step 4: Show summary
    console.log('📋 Generated themes:');
    themes.forEach(theme => {
      console.log(`  • ${theme.name}: ${theme.description}`);
    });
    
    console.log(`\n🎉 Check the ./output/client-themes/${clientName}/ folder for your CSS files!`);
    console.log('🌐 Open index.html in your browser to preview themes!');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

// Run the main function
main().catch(console.error);
