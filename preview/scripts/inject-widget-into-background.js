(function () {
  const PARAM = 'previewWidget';

  function setup() {
    const params = new URLSearchParams(window.location.search);
    const encoded = params.get(PARAM);
    if (!encoded) return;

    let config;
    try {
      config = JSON.parse(decodeURIComponent(encoded));
    } catch (error) {
      console.error('Failed to parse widget preview payload', error);
      return;
    }

    const { widgetUrl, inline } = config;
    if (!widgetUrl) return;

    document.querySelectorAll('.widget-floating, .widget-inline').forEach(node => node.remove());

    const iframe = document.createElement('iframe');
    iframe.src = widgetUrl;
    iframe.className = inline ? 'widget-inline' : 'widget-floating';
    iframe.setAttribute('title', 'Widget Preview');
    iframe.style.border = 'none';

    if (!inline) {
      iframe.style.position = 'fixed';
      iframe.style.zIndex = config.zIndex || '2147483647';
      iframe.style.bottom = config.bottom || '24px';
      iframe.style.right = config.right || '24px';
      iframe.style.width = config.width || '360px';
      iframe.style.height = config.height || '360px';
      iframe.style.background = 'transparent';
      iframe.style.pointerEvents = 'auto';
      document.body.appendChild(iframe);
      return;
    }

    iframe.style.position = 'static';
    iframe.style.display = 'block';
    iframe.style.width = config.width || '100%';
    iframe.style.minHeight = config.height || '360px';

    const selector = config.inlineSelector || 'body';
    const target = document.querySelector(selector);
    if (target) {
      target.appendChild(iframe);
    } else {
      console.warn('Inline target not found for widget preview', selector);
      document.body.insertBefore(iframe, document.body.firstChild);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setup);
  } else {
    setup();
  }
})();
