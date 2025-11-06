const SimpleSiteAnalyzer = require('./analyze-site.js');
const SimpleThemeGenerator = require('./theme-generator.js');
const { log, createLogger } = require('../lib/logger.js');
const { ErrorFactory, ErrorHandler } = require('../lib/errors.js');
const { URLValidator, ParameterValidator } = require('../lib/validators.js');

// Create logger for theme generator
const logger = createLogger('ThemeGenerator');

// Parameter validation schema
const ARG_SCHEMA = {
  url: {
    type: 'string',
    required: true,
    minLength: 1,
    maxLength: 2048
  },
  clientName: {
    type: 'string',
    required: false,
    minLength: 1,
    maxLength: 100,
    default: 'default'
  }
};

async function main() {
  const args = process.argv.slice(2);
  
  // Validate command line arguments
  const validation = ParameterValidator.validateArgs(args, ARG_SCHEMA);
  if (!validation.valid) {
    logger.error('Invalid command line arguments', null, { errors: validation.errors });
    console.error('❌ Invalid arguments:');
    validation.errors.forEach(error => console.error(`  - ${error}`));
    console.log('');
    console.log('Usage: node main.js <website-url> [client-name]');
    console.log('Example: node main.js https://example.com my-client');
    process.exit(1);
  }
  
  const { url, clientName } = validation.params;
  
  // Validate URL format
  const urlValidation = URLValidator.isValid(url);
  if (!urlValidation.valid) {
    const error = ErrorFactory.validation(`Invalid URL: ${urlValidation.error}`, 'url', url);
    logger.error('URL validation failed', error, { url });
    console.error('❌ Invalid URL:', urlValidation.error);
    console.log('');
    console.log('Please provide a valid HTTP or HTTPS URL');
    process.exit(1);
  }
  
  if (!url) {
    logger.info('Theme Generator MVP 2.0 - Usage Information');
    console.log('🚀 Theme Generator MVP 2.0');
    console.log('');
    console.log('Usage: node main.js <website-url> [client-name]');
    console.log('Example: node main.js https://example.com my-client');
    console.log('');
    console.log('This will:');
    console.log('  1. Analyze the website for colors and fonts');
    console.log('  2. Generate 4 theme variations');
    console.log('  3. Save CSS files to ./output/client-themes/');
    console.log('  4. Update the web interface index');
    process.exit(1);
  }
  
  try {
    logger.info('Starting theme generation', { url, clientName });
    console.log('🚀 Starting theme generation...\n');
    
    // Step 1: Analyze the website
    logger.info('Step 1: Analyzing website', { url });
    console.log('📊 Step 1: Analyzing website...');
    const analyzer = new SimpleSiteAnalyzer();
    const analysis = await analyzer.analyze(url);
    logger.info('Analysis complete', { url, analysisKeys: Object.keys(analysis) });
    console.log('✅ Analysis complete\n');
    
    // Step 2: Generate themes
    logger.info('Step 2: Generating theme variations');
    console.log('🎨 Step 2: Generating theme variations...');
    const generator = new SimpleThemeGenerator(analysis);
    const themes = generator.generateThemes();
    logger.info('Themes generated', { themeCount: themes.length, themeNames: themes.map(t => t.name) });
    console.log('✅ Themes generated\n');
    
    // Step 3: Save everything
    logger.info('Step 3: Saving themes', { clientName });
    console.log('💾 Step 3: Saving themes...');
    generator.saveThemes(themes, clientName);
    logger.info('Themes saved successfully', { clientName, outputPath: `./output/client-themes/${clientName}/` });
    console.log('✅ All done!\n');
    
    // Step 4: Show summary
    logger.info('Theme generation completed successfully', { 
      clientName, 
      themeCount: themes.length,
      themes: themes.map(t => ({ name: t.name, description: t.description }))
    });
    console.log('📋 Generated themes:');
    themes.forEach((theme, index) => {
      console.log(`   ${index + 1}. ${theme.name}: ${theme.description}`);
    });
    
    console.log(`\n🎉 Success! Check the ./output/client-themes/${clientName}/ folder for your CSS files!`);
    console.log('🌐 Next steps to preview:');
    console.log('');
    console.log('  1. Run "npm run preview:build" (regenerates manifest + default CSS)');
    console.log('  2. Serve the repo root (e.g., python3 -m http.server 8000)');
    console.log('  3. Open http://localhost:8000/preview/index.html (redirects to /preview/basic/) to inspect widgets and themes');

  } catch (error) {
    const userMessage = ErrorHandler.getUserMessage(error);
    logger.error('Theme generation failed', error, { url, clientName });
    console.error('❌ Error:', userMessage);
    console.log('');
    console.log('Troubleshooting:');
    console.log('  - Make sure the URL is accessible');
    console.log('  - Check your internet connection');
    console.log('  - Try a different website URL');
    process.exit(1);
  }
}

// Run the main function
main().catch((error) => {
  logger.error('Unhandled error in main function', error);
  process.exit(1);
});
