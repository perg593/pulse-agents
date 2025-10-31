/**
 * Download utilities for Pulse Theme Generator
 * Handles individual CSS downloads and bulk ZIP generation
 */

/**
 * Generate a consistent filename for theme CSS files
 * @param {string} clientName - Optional client name
 * @param {string} themeName - Theme name
 * @param {string} url - Original URL for slug generation
 * @returns {string} Formatted filename
 */
function slugify(value, fallback = 'theme') {
  if (!value) return fallback;
  const slug = value
    .toString()
    .trim()
    .toLowerCase()
    .replace(/https?:\/\//g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-+/g, '-');
  return slug || fallback;
}

export function generateFilename(clientName, themeName, url = '') {
  // Create URL slug if no client name provided
  let slug = clientName ? slugify(clientName) : '';
  if (!slug && url) {
    try {
      const urlObj = new URL(url);
      slug = slugify(urlObj.hostname.replace(/^www\./, ''));
    } catch (e) {
      slug = 'theme';
    }
  }
  if (!slug) {
    slug = 'theme';
  }
  
  // Clean theme name for filename
  const cleanThemeName = slugify(themeName, 'theme');

  return `${slug}-${cleanThemeName}.css`;
}

/**
 * Trigger a browser download for a blob
 * @param {Blob} blob - The blob to download
 * @param {string} filename - The filename for the download
 */
export function triggerDownload(blob, filename) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.style.display = 'none';
  
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  
  // Clean up the blob URL
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/**
 * Download a single theme CSS file
 * @param {Object} theme - Theme object with css and name properties
 * @param {string} clientName - Optional client name
 * @param {string} url - Original URL for slug generation
 */
export function downloadThemeCSS(theme, clientName = '', url = '') {
  if (!theme?.css) {
    throw new Error('Theme CSS content is missing');
  }
  
  const filename = generateFilename(clientName, theme.name, url);
  const blob = new Blob([theme.css], { type: 'text/css' });
  
  triggerDownload(blob, filename);
}

/**
 * Download all themes as a ZIP file
 * @param {Array} themes - Array of theme objects
 * @param {string} clientName - Optional client name
 * @param {string} url - Original URL for slug generation
 */
export async function downloadAllThemes(themes, clientName = '', url = '') {
  if (!Array.isArray(themes) || themes.length === 0) {
    throw new Error('No themes provided for download');
  }
  
  if (typeof JSZip === 'undefined') {
    throw new Error('JSZip library is not loaded');
  }
  
  const zip = new JSZip();
  
  // Add each theme CSS file to the ZIP
  themes.forEach(theme => {
    if (!theme?.css) {
      console.warn(`Skipping theme "${theme?.name || 'unknown'}" - missing CSS content`);
      return;
    }
    
    const filename = generateFilename(clientName, theme.name, url);
    zip.file(filename, theme.css);
  });
  
  // Generate ZIP blob and trigger download
  try {
    const blob = await zip.generateAsync({ 
      type: 'blob',
      compression: 'DEFLATE',
      compressionOptions: { level: 6 }
    });
    
    const zipFilename = `${slugify(clientName, 'pulse')}-themes.zip`;
    triggerDownload(blob, zipFilename);
  } catch (error) {
    throw new Error(`Failed to generate ZIP file: ${error.message}`);
  }
}

/**
 * Save themes to server (optional backend integration)
 * @param {Array} themes - Array of theme objects
 * @param {string} clientName - Client name
 * @param {string} url - Original URL
 * @returns {Promise<Object>} Server response
 */
export async function saveThemesToServer(themes, clientName, url) {
  if (!Array.isArray(themes) || themes.length === 0) {
    throw new Error('No themes provided for server save');
  }
  
  if (!clientName?.trim()) {
    throw new Error('Client name is required for server save');
  }
  
  const payload = {
    clientName: clientName.trim(),
    url: url || '',
    themes: themes.map(theme => ({
      name: theme.name,
      description: theme.description,
      css: theme.css,
      tokens: theme.tokens
    })),
    timestamp: new Date().toISOString()
  };
  
  try {
    const response = await fetch('/api/save-themes', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload)
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Server error: ${response.status} - ${errorText}`);
    }
    
    return await response.json();
  } catch (error) {
    if (error.name === 'TypeError' && error.message.includes('fetch')) {
      throw new Error('Server endpoint not available. Please use individual downloads instead.');
    }
    throw error;
  }
}

/**
 * Copy CSS content to clipboard
 * @param {string} css - CSS content
 * @returns {Promise<void>}
 */
export async function copyCSSToClipboard(css) {
  if (!navigator.clipboard) {
    throw new Error('Clipboard API not supported');
  }
  
  try {
    await navigator.clipboard.writeText(css);
  } catch (error) {
    throw new Error(`Failed to copy to clipboard: ${error.message}`);
  }
}

/**
 * Validate theme object structure
 * @param {Object} theme - Theme object to validate
 * @returns {boolean} True if valid
 */
export function validateTheme(theme) {
  return (
    theme &&
    typeof theme === 'object' &&
    typeof theme.name === 'string' &&
    typeof theme.css === 'string' &&
    theme.name.trim().length > 0 &&
    theme.css.trim().length > 0
  );
}

/**
 * Get download statistics for analytics
 * @param {Array} themes - Array of themes
 * @param {string} clientName - Client name
 * @returns {Object} Download statistics
 */
export function getDownloadStats(themes, clientName) {
  return {
    themeCount: themes?.length || 0,
    clientName: clientName || 'anonymous',
    timestamp: new Date().toISOString(),
    totalCSSSize: themes?.reduce((total, theme) => total + (theme.css?.length || 0), 0) || 0
  };
}
