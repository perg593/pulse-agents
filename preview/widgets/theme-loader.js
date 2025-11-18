// Minimal loader used inside preview widget iframes.
// Replaces the placeholder theme style tag with the requested client theme CSS
// so the markup mirrors the production pi-master output.

(async function applyClientTheme() {
  const themePlaceholderToken = '/* CLIENT_THEME_CSS */';
  const overridePlaceholderToken = '/* SURVEY_OVERRIDE_CSS */';

  const styleNodes = Array.from(document.querySelectorAll('style[class^="survey-"]'));
  const themeStyle = styleNodes.find((style) =>
    style.textContent && style.textContent.includes(themePlaceholderToken),
  );
  const overrideStyle = styleNodes.find((style) =>
    style.textContent && style.textContent.includes(overridePlaceholderToken),
  );

  const urlParams = new URLSearchParams(window.location.search);
  const themeParam = urlParams.get('theme');
  const disableTheme = urlParams.get('disableTheme') === '1';

  if (overrideStyle) {
    overrideStyle.textContent = '';
    overrideStyle.dataset.surveyOverride = 'placeholder';
  }

  if (!themeStyle) {
    return;
  }

  if (disableTheme || !themeParam) {
    themeStyle.textContent = '';
    themeStyle.dataset.clientTheme = '';
    return;
  }

  const [clientId, themeId] = themeParam.split('/');
  if (!clientId || !themeId) {
    themeStyle.textContent = '';
    themeStyle.dataset.clientTheme = '';
    return;
  }

  // Theme generator moved to separate repository - CSS files no longer available
  // Use browser-based theme generator instead
  const themeUrl = null;

  try {
    if (!themeUrl) {
      throw new Error('Theme generator moved to separate repository');
    }
    const response = await fetch(themeUrl, {cache: 'no-cache'});
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const cssText = await response.text();
    themeStyle.textContent = cssText;
    themeStyle.dataset.clientTheme = themeParam;
  } catch (error) {
    console.error('Failed to load theme CSS', themeUrl, error);
    themeStyle.textContent = '';
    themeStyle.dataset.clientTheme = '';
  }
})();
