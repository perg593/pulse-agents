export function mountWidget({ container, widgetUrl, inline }) {
  if (!container) return null;
  const iframe = document.createElement('iframe');
  iframe.src = widgetUrl;
  iframe.className = inline ? 'widget-inline' : 'widget-overlay';
  iframe.setAttribute('title', 'Widget Preview');
  iframe.dataset.inline = inline ? '1' : '0';
  container.appendChild(iframe);
  return iframe;
}

export function unmountWidgets({ container }) {
  if (!container) return;
  container.innerHTML = '';
}
