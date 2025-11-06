const REDACT_PARAMS = ['token', 'key', 'secret', 'auth', 'session', 'password', 'api_key'];

export function scrubUrl(maybeUrl) {
  if (!maybeUrl) return '';
  try {
    const url = new URL(maybeUrl, window.location.origin);
    REDACT_PARAMS.forEach((param) => {
      if (url.searchParams.has(param)) {
        url.searchParams.set(param, 'REDACTED');
      }
    });
    const query = url.searchParams.toString();
    return `${url.pathname}${query ? `?${query}` : ''}`;
  } catch (_error) {
    try {
      return String(maybeUrl);
    } catch {
      return '';
    }
  }
}

export function publicError(error = {}) {
  const code = error.code || 'unknown';
  const messageRaw = error.message || 'Error';
  const message = String(messageRaw);
  const truncated = message.length > 160 ? `${message.slice(0, 157)}…` : message;
  return {
    code,
    message: truncated,
    recoverable: Boolean(error.recoverable),
    hint: error.hint
  };
}

export function telemetrySafe(event = {}) {
  const safe = {
    type: event.type,
    ts: typeof event.ts === 'number' ? event.ts : Date.now()
  };
  if (event.previewUrl) {
    safe.previewUrl = scrubUrl(event.previewUrl);
  }
  if (event.type === 'present' && event.surveyId) {
    safe.surveyId = String(event.surveyId).slice(0, 64);
  }
  if (event.event) {
    safe.event = String(event.event).slice(0, 80);
  }
  if (event.type === 'error') {
    Object.assign(safe, publicError(event));
  }
  return safe;
}
