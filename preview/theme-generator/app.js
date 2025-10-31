/**
 * Pulse Theme Generator - Main Application Logic
 * Handles URL analysis, theme generation, and UI management
 */

import { generateThemesFromUrl } from '../basic/theme-generator-client.js';
import { compileTheme } from '../basic/theme-css.js';
import { 
  downloadThemeCSS, 
  downloadAllThemes, 
  saveThemesToServer,
  copyCSSToClipboard,
  validateTheme,
  getDownloadStats
} from './download.js';

class ThemeGeneratorApp {
  constructor() {
    this.currentThemes = [];
    this.currentAnalysis = null;
    this.currentUrl = '';
    this.currentClientName = '';
    this.history = this.loadHistory();
    this.baseThemes = [];
    this.activeThemeId = 'all';
    this.renderOptions = {
      includeFocusStyles: true,
      includeLegacyLayer: false,
      includeSliderStyles: true,
      includeAllAtOnceStyles: true
    };
    
    this.initializeElements();
    this.bindEvents();
    this.updateUI();
  }

  initializeElements() {
    // Form elements
    this.urlInput = document.getElementById('url-input');
    this.clientInput = document.getElementById('client-input');
    this.analyzeBtn = document.getElementById('analyze-btn');
    
    // Status and results
    this.analysisStatus = document.getElementById('analysis-status');
    this.statusText = document.getElementById('status-text');
    this.analysisResults = document.getElementById('analysis-results');
    this.detectedColors = document.getElementById('detected-colors');
    this.detectedFonts = document.getElementById('detected-fonts');
    this.detectedRootVars = document.getElementById('detected-root-vars');
    this.detectedLogoColors = document.getElementById('detected-logo-colors');
    
    // Themes section
    this.themesSection = document.getElementById('themes-section');
    this.themesGrid = this.themesSection.querySelector('.themes-grid');
    this.presetSelect = document.getElementById('preset-select');
    this.focusToggle = document.getElementById('focus-toggle');
    this.legacyToggle = document.getElementById('legacy-toggle');
    this.sliderToggle = document.getElementById('slider-toggle');
    this.aaoToggle = document.getElementById('aao-toggle');
    
    // Action buttons
    this.downloadAllBtn = document.getElementById('download-all-btn');
    this.saveServerBtn = document.getElementById('save-server-btn');
    this.clearBtn = document.getElementById('clear-btn');
    
    // Error display
    this.errorDisplay = document.getElementById('error-display');
    this.errorMessage = document.getElementById('error-message');
    this.dismissErrorBtn = document.getElementById('dismiss-error-btn');
  }

  bindEvents() {
    // Form submission
    this.analyzeBtn.addEventListener('click', () => this.handleAnalyze());
    this.urlInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        this.handleAnalyze();
      }
    });

    // Action buttons
    this.downloadAllBtn.addEventListener('click', () => this.handleDownloadAll());
    this.saveServerBtn.addEventListener('click', () => this.handleSaveToServer());
    this.clearBtn.addEventListener('click', () => this.handleClear());

    // Theme controls
    this.presetSelect.addEventListener('change', () => this.handlePresetChange());
    this.focusToggle.addEventListener('change', () => this.handleOptionToggle('includeFocusStyles', this.focusToggle.checked));
    this.legacyToggle.addEventListener('change', () => this.handleOptionToggle('includeLegacyLayer', this.legacyToggle.checked));
    this.sliderToggle.addEventListener('change', () => this.handleOptionToggle('includeSliderStyles', this.sliderToggle.checked));
    this.aaoToggle.addEventListener('change', () => this.handleOptionToggle('includeAllAtOnceStyles', this.aaoToggle.checked));

    // Error dismissal
    this.dismissErrorBtn.addEventListener('click', () => this.hideError());
  }

  handleOptionToggle(optionKey, value) {
    this.renderOptions = { ...this.renderOptions, [optionKey]: value };
    this.recompileThemes();
  }

  handlePresetChange() {
    this.activeThemeId = this.presetSelect.value;
    this.highlightActiveTheme(true);
  }

  recompileThemes() {
    if (!Array.isArray(this.baseThemes) || this.baseThemes.length === 0) {
      this.currentThemes = [];
      this.displayThemes();
      this.updateUI();
      return;
    }

    this.currentThemes = this.baseThemes.map((theme) => {
      const { css, theme: normalizedTokens, warnings, errors } = compileTheme(theme.tokens, this.renderOptions);
      if (errors?.length) {
        console.warn(`Theme compile error for ${theme.name}:`, errors.join('; '));
      }
      if (warnings?.length) {
        console.warn(`Theme compile warnings for ${theme.name}:`, warnings.join('; '));
      }
      return {
        ...theme,
        css,
        tokens: normalizedTokens
      };
    });

    this.displayThemes();
    this.updateUI();
  }

  updatePresetOptions() {
    if (!this.presetSelect) return;
    const previouslySelected = this.activeThemeId;

    this.presetSelect.innerHTML = '';
    const allOption = new Option('All themes', 'all', false, previouslySelected === 'all');
    this.presetSelect.appendChild(allOption);

    this.currentThemes.forEach((theme) => {
      const option = new Option(theme.name, theme.id, false, previouslySelected === theme.id);
      this.presetSelect.appendChild(option);
    });

    if (previouslySelected !== 'all') {
      const stillExists = this.currentThemes.some((theme) => theme.id === previouslySelected);
      if (!stillExists) {
        this.activeThemeId = 'all';
      }
    }

    const desired = this.currentThemes.some((theme) => theme.id === this.activeThemeId)
      ? this.activeThemeId
      : 'all';
    this.activeThemeId = desired;
    this.presetSelect.value = desired;
  }

  highlightActiveTheme(scrollIntoView = false) {
    if (!this.themesGrid) return;
    const cards = Array.from(this.themesGrid.querySelectorAll('.theme-card'));
    cards.forEach((card) => card.classList.remove('active'));

    if (this.activeThemeId === 'all') return;
    const activeCard = this.themesGrid.querySelector(`.theme-card[data-theme-id="${this.activeThemeId}"]`);
    if (activeCard) {
      activeCard.classList.add('active');
      if (scrollIntoView) {
        activeCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }
  }

  async handleAnalyze() {
    const url = this.urlInput.value.trim();
    const clientName = this.clientInput.value.trim();

    if (!url || url === 'https://') {
      this.showError('Please enter a valid website URL');
      return;
    }

    this.currentUrl = url;
    this.currentClientName = clientName;
    
    this.setAnalyzingState(true);
    this.hideError();
    this.hideResults();

    try {
      this.updateStatus('Analyzing website...');
      const result = await generateThemesFromUrl(url);
      
      this.currentAnalysis = result.analysis;
      this.baseThemes = result.themes || [];
      this.activeThemeId = 'all';
      
      this.updateStatus('Generating themes...');
      this.recompileThemes();
      this.displayResults();
      
      this.updateStatus('Complete!');
      this.saveToHistory(url, clientName, this.currentThemes);
      
    } catch (error) {
      console.error('Analysis failed:', error);
      let message = error?.message || 'Unknown analysis error';
      if (/fetch|network|blocked|cors/i.test(message)) {
        message +=
          '\n\nTip: Ensure the background proxy is running (./scripts/launch-preview.sh) or configure your deployment to expose /proxy for cross-origin analysis.';
      }
      this.showError(`Analysis failed: ${message}`);
    } finally {
      this.setAnalyzingState(false);
    }
  }

  async displayResults() {
    // Display analysis results
    this.displayAnalysisResults();
    
    if (this.currentThemes.length > 0) {
      this.themesSection.classList.remove('hidden');
    }
  }

  displayAnalysisResults() {
    if (!this.currentAnalysis) return;

    // Display detected colors
    this.detectedColors.innerHTML = '';
    const colors = [
      ...(this.currentAnalysis.colors?.accentColors || []),
      ...(this.currentAnalysis.colors?.backgrounds || []),
      ...(this.currentAnalysis.colors?.textColors || [])
    ].slice(0, 8); // Limit to 8 colors

    colors.forEach(color => {
      const swatch = document.createElement('div');
      swatch.className = 'color-swatch';
      swatch.style.backgroundColor = color;
      swatch.title = color;
      this.detectedColors.appendChild(swatch);
    });

    // Display detected fonts
    this.detectedFonts.innerHTML = '';
    const fonts = this.currentAnalysis.fonts?.families || [];
    fonts.slice(0, 5).forEach(font => {
      const fontItem = document.createElement('div');
      fontItem.className = 'font-item';
      fontItem.textContent = font;
      this.detectedFonts.appendChild(fontItem);
    });

    // Display root variables
    const rootVars = this.currentAnalysis.colors?.rootVariables || {};
    if (this.detectedRootVars) {
      this.renderRootVariables(rootVars);
    }

    // Display logo colors
    const logoColors = this.currentAnalysis.colors?.logoColors || [];
    if (this.detectedLogoColors) {
      this.renderColorPalette(this.detectedLogoColors, logoColors, 'No logo colors detected');
    }

    this.analysisResults.classList.remove('hidden');
  }

  displayThemes() {
    this.themesGrid.innerHTML = '';

    if (!Array.isArray(this.currentThemes) || this.currentThemes.length === 0) {
      this.updatePresetOptions();
      this.highlightActiveTheme();
      this.themesSection.classList.add('hidden');
      return;
    }

    this.currentThemes.forEach(theme => {
      if (!validateTheme(theme)) {
        console.warn(`Invalid theme: ${theme?.name || 'unknown'}`);
        return;
      }

      const card = this.createThemeCard(theme);
      this.themesGrid.appendChild(card);
    });

    this.updatePresetOptions();
    this.highlightActiveTheme();
    this.themesSection.classList.remove('hidden');
  }

  createThemeCard(theme) {
    const card = document.createElement('div');
    card.className = 'theme-card';
    card.dataset.themeId = theme.id;
    if (this.activeThemeId === theme.id) {
      card.classList.add('active');
    }

    // Extract colors from CSS for preview
    const colors = this.extractColorsFromTokens(theme.tokens) || this.extractColorsFromCSS(theme.css);
    const fontFamily = this.extractFontFromTokens(theme.tokens) || this.extractFontFromCSS(theme.css);
    const lineCount = this.countLines(theme.css);

    card.innerHTML = `
      <div class="theme-header">
        <h3 class="theme-name">${this.escapeHtml(theme.name)}</h3>
        <p class="theme-description">${this.escapeHtml(theme.description || '')}</p>
      </div>
      
      <div class="theme-preview">
        <div class="theme-colors">
          ${colors.map(color => 
            `<div class="theme-color" style="background-color: ${color}" title="${color}"></div>`
          ).join('')}
        </div>
        <div class="theme-font">${this.escapeHtml(fontFamily)}</div>
      </div>
      
      <div class="theme-meta">
        <span class="theme-lines">${lineCount.toLocaleString()} lines</span>
      </div>
      
      <div class="theme-actions">
        <button class="theme-btn primary" data-theme-id="${theme.id}">
          Download CSS
        </button>
        <button class="theme-btn" data-theme-id="${theme.id}" data-action="copy">
          Copy CSS
        </button>
      </div>
    `;

    // Bind theme card events
    const downloadBtn = card.querySelector('.theme-btn.primary');
    const copyBtn = card.querySelector('[data-action="copy"]');

    downloadBtn.addEventListener('click', () => {
      this.handleDownloadTheme(theme);
    });

    copyBtn.addEventListener('click', () => {
      this.handleCopyTheme(theme);
    });

    card.addEventListener('click', () => {
      this.activeThemeId = theme.id;
      if (this.presetSelect && !this.presetSelect.disabled) {
        this.presetSelect.value = theme.id;
      }
      this.highlightActiveTheme();
    });

    return card;
  }

  extractColorsFromCSS(css) {
    const colorRegex = /#[0-9a-fA-F]{3,6}\b/g;
    const colors = css.match(colorRegex) || [];
    return [...new Set(colors)].slice(0, 4); // Unique colors, max 4
  }

  extractFontFromCSS(css) {
    const fontMatch = css.match(/--pi-font:\s*([^;]+)/);
    if (fontMatch) {
      return fontMatch[1].replace(/['"]/g, '');
    }
    return 'system-ui, sans-serif';
  }

  extractColorsFromTokens(tokens) {
    if (!tokens || !tokens.colors) return null;
    const { primary, primaryHover, bg, muted, text } = tokens.colors;
    const swatches = [primary, primaryHover, muted, bg, text].filter(Boolean);
    const unique = [];
    swatches.forEach(color => {
      if (color && !unique.includes(color)) unique.push(color);
    });
    return unique.slice(0, 4);
  }

  extractFontFromTokens(tokens) {
    if (!tokens || !tokens.typography) return null;
    return tokens.typography.fontFamily || null;
  }

  countLines(css) {
    if (typeof css !== 'string' || !css.length) {
      return 0;
    }
    return css.split(/\r?\n/).length;
  }

  async handleDownloadTheme(theme) {
    try {
      downloadThemeCSS(theme, this.currentClientName, this.currentUrl);
      this.showSuccess(`Downloaded ${theme.name} theme`);
    } catch (error) {
      this.showError(`Download failed: ${error.message}`);
    }
  }

  async handleCopyTheme(theme) {
    try {
      await copyCSSToClipboard(theme.css);
      this.showSuccess(`Copied ${theme.name} CSS to clipboard`);
    } catch (error) {
      this.showError(`Copy failed: ${error.message}`);
    }
  }

  async handleDownloadAll() {
    if (this.currentThemes.length === 0) {
      this.showError('No themes available to download');
      return;
    }

    try {
      this.downloadAllBtn.disabled = true;
      this.downloadAllBtn.textContent = 'Generating ZIP...';
      
      await downloadAllThemes(this.currentThemes, this.currentClientName, this.currentUrl);
      this.showSuccess(`Downloaded ${this.currentThemes.length} themes as ZIP`);
      
    } catch (error) {
      this.showError(`ZIP download failed: ${error.message}`);
    } finally {
      this.downloadAllBtn.disabled = false;
      this.downloadAllBtn.textContent = 'Download All as ZIP';
    }
  }

  async handleSaveToServer() {
    if (this.currentThemes.length === 0) {
      this.showError('No themes available to save');
      return;
    }

    if (!this.currentClientName.trim()) {
      this.showError('Client name is required for server save');
      return;
    }

    try {
      this.saveServerBtn.disabled = true;
      this.saveServerBtn.textContent = 'Saving...';
      
      const result = await saveThemesToServer(this.currentThemes, this.currentClientName, this.currentUrl);
      this.showSuccess(`Saved ${this.currentThemes.length} themes to server`);
      
    } catch (error) {
      this.showError(`Server save failed: ${error.message}`);
    } finally {
      this.saveServerBtn.disabled = false;
      this.saveServerBtn.textContent = 'Save to Server';
    }
  }

  handleClear() {
    this.currentThemes = [];
    this.baseThemes = [];
    this.currentAnalysis = null;
    this.currentUrl = '';
    this.currentClientName = '';
    this.activeThemeId = 'all';
    this.renderOptions = {
      includeFocusStyles: true,
      includeLegacyLayer: false,
      includeSliderStyles: true,
      includeAllAtOnceStyles: true
    };

    this.urlInput.value = 'https://';
    this.clientInput.value = '';
    this.focusToggle.checked = true;
    this.legacyToggle.checked = false;
    this.sliderToggle.checked = true;
    this.aaoToggle.checked = true;
    this.presetSelect.value = 'all';

    this.hideResults();
    this.hideError();
    this.updateUI();
  }

  setAnalyzingState(analyzing) {
    this.analyzeBtn.disabled = analyzing;
    this.analyzeBtn.textContent = analyzing ? 'Analyzing...' : 'Analyze Site';
    
    if (analyzing) {
      this.analysisStatus.classList.remove('hidden');
    } else {
      this.analysisStatus.classList.add('hidden');
    }
  }

  updateStatus(message) {
    this.statusText.textContent = message;
  }

  showError(message) {
    this.errorMessage.textContent = message;
    this.errorDisplay.classList.remove('hidden');
  }

  hideError() {
    this.errorDisplay.classList.add('hidden');
  }

  showSuccess(message) {
    // Simple success feedback - could be enhanced with toast notifications
    console.log('Success:', message);
    // For now, just log to console. Could add a toast notification system later.
  }

  hideResults() {
    this.analysisResults.classList.add('hidden');
    this.themesSection.classList.add('hidden');
  }

  updateUI() {
    const hasThemes = this.currentThemes.length > 0;
    this.downloadAllBtn.disabled = !hasThemes;
    this.saveServerBtn.disabled = !hasThemes || !this.currentClientName.trim();
    
    if (this.presetSelect) {
      this.presetSelect.disabled = !hasThemes;
      if (!hasThemes) {
        this.presetSelect.value = 'all';
      }
    }

    if (this.focusToggle) {
      this.focusToggle.disabled = !hasThemes;
      this.focusToggle.checked = !!this.renderOptions.includeFocusStyles;
    }

    if (this.legacyToggle) {
      this.legacyToggle.disabled = !hasThemes;
      this.legacyToggle.checked = !!this.renderOptions.includeLegacyLayer;
    }

    if (this.sliderToggle) {
      this.sliderToggle.disabled = !hasThemes;
      this.sliderToggle.checked = !!this.renderOptions.includeSliderStyles;
    }

    if (this.aaoToggle) {
      this.aaoToggle.disabled = !hasThemes;
      this.aaoToggle.checked = !!this.renderOptions.includeAllAtOnceStyles;
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  renderRootVariables(rootVars) {
    this.detectedRootVars.innerHTML = '';
    const entries = Object.entries(rootVars || {});
    if (!entries.length) {
      this.detectedRootVars.innerHTML = '<p class="empty-state">No :root variables detected</p>';
      return;
    }

    entries.forEach(([name, value]) => {
      if (value === undefined || value === null) return;
      const normalizedValue = String(value).replace(/!important/gi, '').trim();
      if (!normalizedValue) return;
      const item = document.createElement('div');
      item.className = 'root-var-item';

      const swatch = document.createElement('span');
      swatch.className = 'root-var-swatch';
      swatch.style.backgroundColor = normalizedValue;

      const nameEl = document.createElement('code');
      nameEl.textContent = name;

      const valueEl = document.createElement('span');
      valueEl.textContent = normalizedValue;

      item.appendChild(swatch);
      item.appendChild(nameEl);
      item.appendChild(valueEl);
      this.detectedRootVars.appendChild(item);
    });
  }

  renderColorPalette(container, colors = [], emptyMessage = 'No colors detected') {
    container.innerHTML = '';
    if (!colors.length) {
      container.innerHTML = `<p class="empty-state">${this.escapeHtml(emptyMessage)}</p>`;
      return;
    }
    colors.slice(0, 8).forEach(color => {
      if (!color) return;
      const swatch = document.createElement('div');
      swatch.className = 'color-swatch';
      swatch.style.backgroundColor = color;
      swatch.title = color;
      container.appendChild(swatch);
    });
  }

  // History management
  loadHistory() {
    try {
      const stored = localStorage.getItem('pulse-theme-generator-history');
      return stored ? JSON.parse(stored) : [];
    } catch (error) {
      console.warn('Failed to load history:', error);
      return [];
    }
  }

  saveToHistory(url, clientName, themes) {
    const entry = {
      url,
      clientName,
      themeCount: themes.length,
      timestamp: new Date().toISOString()
    };

    this.history.unshift(entry);
    this.history = this.history.slice(0, 5); // Keep last 5 entries

    try {
      localStorage.setItem('pulse-theme-generator-history', JSON.stringify(this.history));
    } catch (error) {
      console.warn('Failed to save history:', error);
    }
  }
}

// Initialize the application when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  new ThemeGeneratorApp();
});
