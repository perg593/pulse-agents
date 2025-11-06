const fs = require('fs');
const path = require('path');

class SimpleThemeGenerator {
  constructor(analysis) {
    this.analysis = analysis;
  }

  generateThemes() {
    const themes = [
      this.generateBrandFaithfulTheme(),
      this.generateHighContrastTheme(),
      this.generateModernTheme(),
      this.generateMinimalistTheme()
    ];

    return themes;
  }

  generateBrandFaithfulTheme() {
    const primaryColor = this.analysis.colors.backgrounds[0] || '#007bff';
    const textColor = this.analysis.colors.textColors[0] || '#333333';
    const fontFamily = this.analysis.fonts[0] || 'Arial, sans-serif';

    return {
      name: 'Brand Faithful',
      description: 'Matches the client\'s brand colors and fonts',
      config: {
        '--pi-primary-color': primaryColor,
        '--pi-secondary-color': this.lightenColor(primaryColor, 20),
        '--pi-text-color': textColor,
        '--pi-background-color': '#ffffff',
        '--pi-border-color': this.lightenColor(primaryColor, 30),
        '--pi-hover-color': this.darkenColor(primaryColor, 10),
        '--pi-font-family': fontFamily,
        '--pi-border-radius': '8px',
        '--pi-box-shadow': '0 4px 12px rgba(0,0,0,0.15)'
      }
    };
  }

  generateHighContrastTheme() {
    return {
      name: 'High Contrast',
      description: 'High contrast for accessibility',
      config: {
        '--pi-primary-color': '#000000',
        '--pi-secondary-color': '#ffffff',
        '--pi-text-color': '#000000',
        '--pi-background-color': '#ffffff',
        '--pi-border-color': '#000000',
        '--pi-hover-color': '#333333',
        '--pi-font-family': 'Arial, sans-serif',
        '--pi-border-radius': '4px',
        '--pi-box-shadow': '0 2px 8px rgba(0,0,0,0.3)'
      }
    };
  }

  generateModernTheme() {
    return {
      name: 'Modern',
      description: 'Contemporary design with modern colors',
      config: {
        '--pi-primary-color': '#6366f1',
        '--pi-secondary-color': '#8b5cf6',
        '--pi-text-color': '#1f2937',
        '--pi-background-color': '#ffffff',
        '--pi-border-color': '#e5e7eb',
        '--pi-hover-color': '#4f46e5',
        '--pi-font-family': 'Inter, -apple-system, BlinkMacSystemFont, sans-serif',
        '--pi-border-radius': '12px',
        '--pi-box-shadow': '0 10px 25px rgba(0,0,0,0.1)'
      }
    };
  }

  generateMinimalistTheme() {
    return {
      name: 'Minimalist',
      description: 'Clean and simple design',
      config: {
        '--pi-primary-color': '#6b7280',
        '--pi-secondary-color': '#9ca3af',
        '--pi-text-color': '#374151',
        '--pi-background-color': '#ffffff',
        '--pi-border-color': '#d1d5db',
        '--pi-hover-color': '#4b5563',
        '--pi-font-family': 'system-ui, -apple-system, sans-serif',
        '--pi-border-radius': '6px',
        '--pi-box-shadow': '0 1px 3px rgba(0,0,0,0.1)'
      }
    };
  }

  generateCSS(config) {
    return `/* Generated Theme CSS */
:root {
${Object.entries(config).map(([key, value]) => `  ${key}: ${value};`).join('\n')}
}

/* Widget Styles */
#_pi_surveyWidget {
  background-color: var(--pi-background-color);
  color: var(--pi-text-color);
  font-family: var(--pi-font-family);
  border-radius: var(--pi-border-radius);
  box-shadow: var(--pi-box-shadow);
  border: 1px solid var(--pi-border-color);
}

._pi_question {
  color: var(--pi-text-color);
  font-weight: 600;
}

._pi_answers_container li a {
  color: var(--pi-text-color);
  border: 1px solid var(--pi-border-color);
  border-radius: var(--pi-border-radius);
}

._pi_answers_container li a:hover {
  background-color: var(--pi-hover-color);
  color: var(--pi-secondary-color);
}

._pi_startButton {
  background-color: var(--pi-primary-color);
  color: var(--pi-secondary-color);
  border: none;
  border-radius: var(--pi-border-radius);
  padding: 10px 20px;
  font-family: var(--pi-font-family);
  cursor: pointer;
}

._pi_startButton:hover {
  background-color: var(--pi-hover-color);
}

._pi_closeButton {
  color: var(--pi-text-color);
  font-size: 20px;
  cursor: pointer;
}`;
  }

  saveThemes(themes, clientName = 'default') {
    // Create client-specific folder
    const clientDir = `./output/client-themes/${clientName}`;
    if (!fs.existsSync(clientDir)) {
      fs.mkdirSync(clientDir, { recursive: true });
    }
    
    // Save individual theme CSS files
    themes.forEach(theme => {
      const css = this.generateCSS(theme.config);
      const filename = theme.name.toLowerCase().replace(/\s+/g, '-') + '.css';
      const filepath = path.join(clientDir, filename);
      
      fs.writeFileSync(filepath, css);
      console.log(`Generated: ${filepath}`);
    });
    
    // Save theme configs for this client
    fs.writeFileSync(
      path.join(clientDir, 'themes.json'),
      JSON.stringify(themes, null, 2)
    );
    
    // Update the master client index
    this.updateClientIndex(clientName, themes);
  }
  
  updateClientIndex(clientName, themes) {
    const indexFile = './output/client-themes/index.json';
    let clients = {};
    
    if (fs.existsSync(indexFile)) {
      clients = JSON.parse(fs.readFileSync(indexFile, 'utf8'));
    }
    
    clients[clientName] = {
      name: clientName,
      themes: themes.map(theme => ({
        id: theme.name.toLowerCase().replace(/\s+/g, '-'),
        name: theme.name,
        description: theme.description,
        file: `${theme.name.toLowerCase().replace(/\s+/g, '-')}.css`
      })),
      lastUpdated: new Date().toISOString()
    };
    
    fs.writeFileSync(indexFile, JSON.stringify(clients, null, 2));
  }

  // Helper functions for color manipulation
  lightenColor(color, percent) {
    // Simple color lightening - in a real implementation you'd use a proper color library
    return color;
  }

  darkenColor(color, percent) {
    // Simple color darkening - in a real implementation you'd use a proper color library
    return color;
  }
}

// Export the class
module.exports = SimpleThemeGenerator;

// Also keep the main function for standalone use
async function main() {
  const analysisFile = process.argv[2];
  const clientName = process.argv[3] || 'default';
  
  if (!analysisFile) {
    console.log('Usage: node theme-generator.js <analysis-file> [client-name]');
    console.log('Example: node theme-generator.js ./output/site-analysis.json my-client');
    process.exit(1);
  }
  
  try {
    const analysis = JSON.parse(fs.readFileSync(analysisFile, 'utf8'));
    const generator = new SimpleThemeGenerator(analysis);
    const themes = generator.generateThemes();
    
    generator.saveThemes(themes, clientName);
    
    console.log('✅ Themes generated successfully!');
    console.log(`📁 Check ./output/client-themes/${clientName}/ for your CSS files`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

// Only run main if this file is executed directly
if (require.main === module) {
  main().catch(console.error);
}
