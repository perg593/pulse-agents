import { Bridge as BridgeV1, derivePlayerOrigin } from './bridgeV1.mjs';

const PLAYER_URL = '/preview/app/survey/player.html';
const PLAYER_VERSION = '2025-10-09-01';

try {
  console.log('[bridge] module bootstrap', { version: PLAYER_VERSION });
} catch (_error) {
  /* ignore */
}

const globalFlags = (() => {
  try {
    const params = new URLSearchParams(window.location.search);
    return {
      useProtocolV1: flagFromParam(params.get('useProtocolV1')),
      playerOrigin: params.get('playerOrigin') || undefined
    };
  } catch (_error) {
    return { useProtocolV1: false };
  }
})();

function handleLinkClick(data) {
  const { href, target } = data;
  if (!href || typeof href !== 'string') {
    try {
      console.warn('[bridge] link-click missing or invalid href', data);
    } catch (_error) {
      /* ignore */
    }
    return;
  }

  // Block dangerous URL schemes
  if (isDangerousUrlScheme(href)) {
    try {
      console.warn('[bridge] link-click blocked - dangerous URL scheme', href);
    } catch (_error) {
      /* ignore */
    }
    return;
  }

  const linkTarget = target || '_self';
  
  try {
    if (linkTarget === '_blank') {
      // Open in new tab/window
      const opened = window.open(href, '_blank', 'noopener');
      if (!opened) {
        try {
          console.warn('[bridge] popup blocked for link', href);
        } catch (_error) {
          /* ignore */
        }
      } else {
        try {
          console.log('[bridge] link opened in new tab', href);
        } catch (_error) {
          /* ignore */
        }
      }
    } else {
      // Default behavior: navigate in same window
      // Check if same origin to use window.location, otherwise use window.open
      try {
        const currentOrigin = window.location.origin;
        const linkUrl = new URL(href, window.location.href);
        if (linkUrl.origin === currentOrigin) {
          window.location.href = href;
        } else {
          // Cross-origin: must use window.open even for _self
          window.open(href, '_self');
        }
      } catch (_error) {
        // Invalid URL or relative URL - try window.location
        try {
          window.location.href = href;
        } catch (__error) {
          try {
            console.error('[bridge] failed to open link', href, __error);
          } catch (___error) {
            /* ignore */
          }
        }
      }
    }
  } catch (error) {
    try {
      console.error('[bridge] error handling link click', { href, target, error });
    } catch (_error) {
      /* ignore */
    }
  }
}

/**
 * Checks if a URL uses a dangerous scheme that should be blocked.
 * 
 * @param {string} url - The URL to check
 * @returns {boolean} True if the URL uses a dangerous scheme
 */
function isDangerousUrlScheme(url) {
  if (!url || typeof url !== 'string') {
    return false;
  }
  const trimmed = url.trim().toLowerCase();
  // Block dangerous URL schemes that could be used for XSS attacks
  return trimmed.startsWith('javascript:') ||
         trimmed.startsWith('data:') ||
         trimmed.startsWith('vbscript:');
}

function handleRedirect(data, sourceFrame = null) {
  const { url } = data;
  if (!url || typeof url !== 'string') {
    try {
      console.warn('[bridge] redirect missing or invalid url', data);
    } catch (_error) {
      /* ignore */
    }
    return;
  }

  // Validate that redirect comes from active iframe
  if (sourceFrame) {
    if (!sourceFrame.parentNode || !document.body.contains(sourceFrame)) {
      try {
        console.warn('[bridge] redirect ignored - iframe has been removed', url);
      } catch (_error) {
        /* ignore */
      }
      return;
    }
  }

  const redirectUrl = url.trim();
  
  // Block dangerous URL schemes
  if (isDangerousUrlScheme(redirectUrl)) {
    try {
      console.warn('[bridge] redirect blocked - dangerous URL scheme', redirectUrl);
    } catch (_error) {
      /* ignore */
    }
    return;
  }
  
  try {
    // Use same logic as handleLinkClick - navigate current window
    const currentOrigin = window.location.origin;
    const targetUrl = new URL(redirectUrl, window.location.href);
    if (targetUrl.origin === currentOrigin) {
      // Same origin: use location.href
      window.location.href = redirectUrl;
    } else {
      // Cross-origin: use window.open with _self (same as link handler)
      window.open(redirectUrl, '_self');
    }
  } catch (_error) {
    // Invalid URL or relative URL - try window.location.href
    try {
      window.location.href = redirectUrl;
    } catch (__error) {
      try {
        console.error('[bridge] failed to redirect', redirectUrl, __error);
      } catch (___error) {
        /* ignore */
      }
    }
  }
}

export function createSurveyBridge(
  {
    container,
    onReady = () => {},
    onStatus = () => {},
    onStateChange = () => {},
    onError = () => {},
    onClose = () => {}
  } = {},
  runtimeOptions = {}
) {
  const host = (() => {
    try {
      if (typeof window === 'undefined' || !window.location) return '';
      return window.location.hostname || '';
    } catch (_error) {
      return '';
    }
  })();

  const flags = {
    useProtocolV1:
      runtimeOptions.useProtocolV1 ??
      globalFlags.useProtocolV1 ??
      false,
    playerOrigin: runtimeOptions.playerOrigin ?? globalFlags.playerOrigin,
    compatImplicitAck: runtimeOptions.compatImplicitAck ?? true,
    debug: runtimeOptions.debug ?? false,
    bridgeOptions: runtimeOptions.bridgeOptions
  };

  if (flags.useProtocolV1) {
    return createProtocolBridge(
      { container, onReady, onStatus, onStateChange, onError, onClose },
      flags
    );
  }
  return createLegacyBridge({ container, onReady, onStatus, onStateChange, onClose });
}

function createLegacyBridge({ container, onReady, onStatus, onStateChange, onClose }) {
  let frame = null;
  let ready = false;
  let pendingMessages = [];
  let currentConfig = null;
  let legacyState = 'UNMOUNTED';
  let playerOrigin = (() => {
    try {
      // Security: Never use '*' as fallback - it's insecure
      // Return null if we can't determine origin, which will cause rejection until origin is set
      return typeof window !== 'undefined' && window.location
        ? window.location.origin || null
        : null;
    } catch (_error) {
      return null;
    }
  })();
  let messageHandler = null;

  function setLegacyState(next, reason, data) {
    if (legacyState === next) return;
    const payload = {
      prev: legacyState,
      next,
      reason,
      data,
      ts: Date.now()
    };
    legacyState = next;
    try {
      onStateChange(payload);
    } catch (_error) {
      /* ignore */
    }
  }

  function teardown() {
    const hadFrame = Boolean(frame);
    
    // Send cleanup message to player before removing iframe
    if (frame && frame.contentWindow && ready) {
      try {
        frame.contentWindow.postMessage({ type: 'cleanup-timers' }, playerOrigin);
      } catch (_error) {
        /* ignore */
      }
    }
    
    if (messageHandler) {
      try {
        window.removeEventListener('message', messageHandler);
      } catch (_error) {
        /* ignore */
      }
      messageHandler = null;
    }
    if (frame && frame.parentNode) {
      frame.parentNode.removeChild(frame);
    }
    frame = null;
    ready = false;
    pendingMessages = [];
    if (hadFrame || legacyState !== 'UNMOUNTED') {
      setLegacyState('UNMOUNTED', 'destroy');
      try {
        onClose();
      } catch (_error) {
        /* ignore */
      }
    }
  }

  function flushQueue() {
    if (!frame || !ready) return;
    const { contentWindow } = frame;
    pendingMessages.splice(0).forEach((message) => {
      try {
        console.log('[bridge] flush message', message);
      } catch (_error) {
        /* ignore */
      }
      contentWindow.postMessage(message, playerOrigin);
    });
  }

  function postMessage(message) {
    if (!frame) return;
    if (!ready) {
      pendingMessages.push(message);
      try {
        console.log('[bridge] queue message', message);
      } catch (_error) {
        /* ignore */
      }
      return;
    }
    try {
      console.log('[bridge] post message', message);
    } catch (_error) {
      /* ignore */
    }
    frame.contentWindow.postMessage(message, playerOrigin);
  }

  function attachListeners() {
    if (messageHandler) {
      try {
        window.removeEventListener('message', messageHandler);
      } catch (_error) {
        /* ignore */
      }
    }
    messageHandler = (event) => {
      if (!frame || event.source !== frame.contentWindow) return;
      // Security: Validate origin - reject messages if origin doesn't match expected playerOrigin
      // Never accept messages when playerOrigin is null or '*' - these are insecure fallbacks
      if (!playerOrigin || playerOrigin === '*') {
        // Reject messages until we can determine the actual origin from iframe src
        try {
          console.warn('[bridge] rejecting message - playerOrigin not set', { playerOrigin, eventOrigin: event.origin });
        } catch (_error) {
          /* ignore */
        }
        return;
      }
      // Strict origin check: must match exactly
      if (!event.origin || event.origin !== playerOrigin) {
        try {
          console.warn('[bridge] rejecting message - origin mismatch', { 
            expected: playerOrigin, 
            received: event.origin,
            iframeSrc: frame?.src 
          });
        } catch (_error) {
          /* ignore */
        }
        return;
      }
      const { data } = event;
      if (!data || typeof data !== 'object') return;

      if (data.type === 'player-ready') {
        ready = true;
        flushQueue();
        try {
          console.log('[bridge] player ready', data);
        } catch (_error) {
          /* ignore */
        }
        setLegacyState('IDLE', 'ready', data);
        onReady(data);
        return;
      }

      if (data.type === 'link-click') {
        handleLinkClick(data);
        return;
      }

      if (data.type === 'redirect') {
        handleRedirect(data, frame);
        return;
      }

      try {
        console.log('[bridge] status', data);
      } catch (_error) {
        /* ignore */
      }
      onStatus(data);
    };
    window.addEventListener('message', messageHandler);
  }

  return {
    destroy() {
      teardown();
    },
    load(config = {}) {
      currentConfig = config;
      teardown();
      if (!container) return null;
      try {
        console.log('[bridge] load player', config);
      } catch (_error) {
        /* ignore */
      }
      const iframe = document.createElement('iframe');
      iframe.src = buildPlayerUrl(config);
      iframe.setAttribute('title', 'Pulse Survey Player');
      iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin');
      iframe.setAttribute('referrerpolicy', 'no-referrer');
      
      // Security: Set playerOrigin BEFORE attaching listeners to prevent race condition
      // Determine origin from iframe src first, fallback to window.location.origin
      try {
        const iframeSrc = iframe.getAttribute('src') || '';
        const baseUrl = typeof window !== 'undefined' && window.location ? window.location.href : 'http://localhost';
        playerOrigin = new URL(iframeSrc, baseUrl).origin;
        try {
          console.log('[bridge] Legacy Bridge: playerOrigin set from iframe src', { 
            iframeSrc, 
            baseUrl, 
            playerOrigin 
          });
        } catch (_error) {
          /* ignore */
        }
      } catch (_error) {
        try {
          // Fallback to window.location.origin (should always be available in browser)
          playerOrigin = window.location.origin;
          try {
            console.log('[bridge] Legacy Bridge: playerOrigin set from window.location.origin fallback', { playerOrigin });
          } catch (__error) {
            /* ignore */
          }
        } catch (__error) {
          // Security: Never use '*' as fallback - reject messages until we can determine origin
          // This prevents accepting messages from any origin
          playerOrigin = null;
          try {
            console.warn('[bridge] Legacy Bridge: playerOrigin set to null - messages will be rejected', { error: __error });
          } catch (___error) {
            /* ignore */
          }
        }
      }
      
      container.appendChild(iframe);
      frame = iframe;
      ready = false;
      pendingMessages = [];
      attachListeners();
      setLegacyState('BOOTING', 'init-start', { config });
      return iframe;
    },
    reload() {
      if (!currentConfig) return;
      this.load(currentConfig);
    },
    openInNewTab() {
      if (!currentConfig) return;
      window.open(buildPlayerUrl(currentConfig), '_blank', 'noopener');
    },
    setInlineMode(active) {
      if (!container) return;
      container.classList.toggle('inline-mode', Boolean(active));
    },
    present(surveyId) {
      if (!surveyId) return;
      postMessage({ type: 'present', surveyId: String(surveyId) });
    },
    dismiss() {
      postMessage({ type: 'dismiss' });
      return Promise.resolve();
    },
    applyTheme(themeCss) {
      if (themeCss) {
        postMessage({ type: 'apply-theme', themeCss });
      }
    },
    clearTheme() {
      postMessage({ type: 'clear-theme' });
    },
    applyManualCss(manualCss) {
      postMessage({ type: 'apply-manual-css', manualCss });
    },
    clearManualCss() {
      postMessage({ type: 'clear-manual-css' });
    },
    sendTrigger(triggerId) {
      if (!triggerId) return;
      postMessage({ type: 'trigger', triggerId });
    },
    sendCommand(command) {
      if (!Array.isArray(command) || command.length === 0) return;
      postMessage({ type: 'command', command });
    },
    getConfig() {
      return currentConfig;
    }
  };
}

function createProtocolBridge({ container, onReady, onStatus, onStateChange, onError, onClose }, flags) {
  let currentConfig = null;
  let iframe = null;
  let bridgeInstance = null;
  let bridgeReady = false;
  const pendingActions = []; // queued entries: { run, reject }
  let legacyMessageHandler = null;
  let playerOrigin = null; // Store playerOrigin in closure for legacy message handler

  function teardown() {
    bridgeReady = false;
    failPending({ code: 'bridge_destroyed', message: 'Bridge destroyed' });
    
    // Send cleanup message to player before removing iframe
    if (iframe && iframe.contentWindow && playerOrigin) {
      try {
        iframe.contentWindow.postMessage({ type: 'cleanup-timers' }, playerOrigin);
      } catch (_error) {
        /* ignore */
      }
    }
    
    if (legacyMessageHandler) {
      window.removeEventListener('message', legacyMessageHandler);
      legacyMessageHandler = null;
    }
    if (bridgeInstance) {
      bridgeInstance.destroy();
      bridgeInstance = null;
    }
    if (iframe && iframe.parentNode) {
      iframe.parentNode.removeChild(iframe);
    }
    iframe = null;
  }

  function runOrQueue(action) {
    if (bridgeReady && bridgeInstance) {
      return action();
    }
    return new Promise((resolve, reject) => {
      pendingActions.push({
        run: () => {
          try {
            const result = action();
            Promise.resolve(result).then(resolve, reject);
          } catch (error) {
            reject(error);
          }
        },
        reject
      });
    });
  }

  function flushPending() {
    if (!bridgeReady || !bridgeInstance) return;
    while (pendingActions.length) {
      const { run } = pendingActions.shift();
      try {
        run();
      } catch (_error) {
        // swallow queued errors; they are surfaced via promise rejections/logs
      }
    }
  }

  function failPending(error) {
    while (pendingActions.length) {
      const entry = pendingActions.shift();
      try {
        entry.reject(error);
      } catch (_error) {
        /* ignore */
      }
    }
  }

  function mapStatus(payload) {
    if (!payload) return;
    if (payload.widget || payload.bounds) {
      onStatus({
        type: 'player-status',
        status: 'widget-geometry',
        widget: payload.widget,
        placement: payload.placement,
        event: payload.event,
        payload
      });
      return;
    }
    onStatus({
      type: 'player-status',
      status: 'player-status',
      event: payload.event,
      payload
    });
  }

  return {
    destroy() {
      teardown();
    },
    load(config = {}) {
      currentConfig = config;
      teardown();
      if (!container) return null;
      iframe = document.createElement('iframe');
      iframe.src = buildPlayerUrl(config);
      iframe.setAttribute('title', 'Pulse Survey Player');
      iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin');
      iframe.setAttribute('referrerpolicy', 'no-referrer');
      container.appendChild(iframe);

      // Security: Set playerOrigin BEFORE creating handlers to prevent race condition
      const originOverride = flags.playerOrigin;
      try {
        playerOrigin = originOverride || derivePlayerOrigin(iframe);
        // Validate playerOrigin - should never be null or '*' in normal operation
        if (!playerOrigin || playerOrigin === '*') {
          // Fallback to window.location.origin if derivePlayerOrigin fails
          try {
            playerOrigin = window.location.origin;
            try {
              console.log('[bridge] Protocol Bridge: playerOrigin set from window.location.origin fallback', { playerOrigin });
            } catch (_logError) {
              /* ignore */
            }
          } catch (_error) {
            // Last resort: this should rarely happen
            playerOrigin = null;
            try {
              console.warn('[bridge] Protocol Bridge: playerOrigin set to null - messages will be rejected', { error: _error });
            } catch (__logError) {
              /* ignore */
            }
          }
        } else {
          try {
            console.log('[bridge] Protocol Bridge: playerOrigin set', { 
              playerOrigin, 
              source: originOverride ? 'override' : 'derivePlayerOrigin',
              iframeSrc: iframe?.src 
            });
          } catch (_logError) {
            /* ignore */
          }
        }
      } catch (_error) {
        // If derivePlayerOrigin throws, fallback to window.location.origin
        try {
          playerOrigin = window.location.origin;
          try {
            console.log('[bridge] Protocol Bridge: playerOrigin set from window.location.origin (exception fallback)', { playerOrigin, error: _error });
          } catch (__logError) {
            /* ignore */
          }
        } catch (__error) {
          playerOrigin = null;
          try {
            console.warn('[bridge] Protocol Bridge: playerOrigin set to null (exception) - messages will be rejected', { error: __error });
          } catch (___logError) {
            /* ignore */
          }
        }
      }

      bridgeInstance = new BridgeV1({
        iframe,
        playerOrigin,
        compatImplicitAck: flags.compatImplicitAck,
        debug: flags.debug,
        ...(flags.bridgeOptions || {})
      });

      bridgeInstance.on('ready', () => {
        bridgeReady = true;
        onReady({
          type: 'player-ready',
          account: config.account,
          host: config.host,
          mode: config.mode
        });
        flushPending();
      });

      bridgeInstance.on('status', (payload) => {
        mapStatus(payload);
      });

      bridgeInstance.on('error', (payload) => {
        try {
          onError(payload);
        } catch (_error) {
          /* ignore */
        }
        onStatus({
          type: 'player-status',
          status: 'present-error',
          message: payload?.message,
          code: payload?.code,
          payload
        });
      });

      bridgeInstance.on('statechange', (payload) => {
        try {
          onStateChange(payload);
        } catch (_error) {
          /* ignore */
        }
      });

      bridgeInstance.on('close', () => {
        try {
          onClose();
        } catch (_error) {
          /* ignore */
        }
      });

      // Handle legacy messages like link-click and redirect
      legacyMessageHandler = (event) => {
        if (!iframe || event.source !== iframe.contentWindow) return;
        // Security: Validate origin - reject messages if origin doesn't match expected playerOrigin
        // Never accept messages when playerOrigin is null or '*' - these are insecure fallbacks
        if (!playerOrigin || playerOrigin === '*') {
          // Reject messages until we can determine the actual origin from iframe src
          try {
            console.warn('[bridge] rejecting legacy message - playerOrigin not set', { playerOrigin, eventOrigin: event.origin });
          } catch (_error) {
            /* ignore */
          }
          return;
        }
        // Strict origin check: must match exactly
        if (!event.origin || event.origin !== playerOrigin) {
          try {
            console.warn('[bridge] rejecting legacy message - origin mismatch', { 
              expected: playerOrigin, 
              received: event.origin,
              iframeSrc: iframe?.src 
            });
          } catch (_error) {
            /* ignore */
          }
          return;
        }
        const { data } = event;
        if (!data || typeof data !== 'object') return;
        
        if (data.type === 'link-click') {
          handleLinkClick(data);
        } else if (data.type === 'redirect') {
          handleRedirect(data, iframe);
        }
      };
      window.addEventListener('message', legacyMessageHandler);

      bridgeInstance.init().catch((error) => {
        try {
          onError({ code: error?.code || 'player_timeout', message: error?.message || String(error), error });
        } catch (_error) {
          /* ignore */
        }
        onStatus({
          type: 'player-status',
          status: 'present-error',
          message: error?.message || String(error),
          code: error?.code || 'player_timeout'
        });
        failPending({
          code: error?.code || 'player_timeout',
          message: error?.message || 'Player did not respond'
        });
      });

      return iframe;
    },
    reload() {
      if (!currentConfig) return;
      this.load(currentConfig);
    },
    openInNewTab() {
      if (!currentConfig) return;
      window.open(buildPlayerUrl(currentConfig), '_blank', 'noopener');
    },
    setInlineMode(active) {
      if (!container) return;
      container.classList.toggle('inline-mode', Boolean(active));
    },
    present(surveyId) {
      if (!surveyId) return Promise.resolve();
      return runOrQueue(() =>
        bridgeInstance
          .present(String(surveyId))
          .then((payload) => {
            onStatus({
              type: 'player-status',
              status: 'present-called',
              surveyId: String(surveyId),
              event: payload?.event,
              payload
            });
            return payload;
          })
          .catch((error) => {
            onStatus({
              type: 'player-status',
              status: 'present-error',
              surveyId: String(surveyId),
              message: error?.message || String(error),
              code: error?.code,
              event: error?.event,
              payload: error
            });
            throw error;
          })
      );
    },
    dismiss() {
      return runOrQueue(() =>
        bridgeInstance
          .dismiss()
          .then((payload) => {
            onStatus({
              type: 'player-status',
              status: 'dismiss-called',
              event: payload?.event,
              payload
            });
            return payload;
          })
          .catch((error) => {
            onStatus({
              type: 'player-status',
              status: 'present-error',
              message: error?.message || String(error),
              code: error?.code,
              event: error?.event,
              payload: error
            });
            throw error;
          })
      );
    },
    applyTheme(themeCss) {
      if (!themeCss && themeCss !== '') return Promise.resolve();
      return runOrQueue(() =>
        bridgeInstance
          .applyTheme({ href: themeCss })
          .then((payload) => {
            mapStatus(payload);
            return payload;
          })
          .catch((error) => {
            onStatus({
              type: 'player-status',
              status: 'present-error',
              message: error?.message || String(error),
              code: error?.code,
              event: error?.event,
              payload: error
            });
            throw error;
          })
      );
    },
    clearTheme() {
      return runOrQueue(() =>
        bridgeInstance
          .applyTheme({})
          .catch((error) => {
            onStatus({
              type: 'player-status',
              status: 'present-error',
              message: error?.message || String(error),
              code: error?.code,
              event: error?.event,
              payload: error
            });
            throw error;
          })
      );
    },
    applyManualCss(manualCss) {
      return runOrQueue(() =>
        bridgeInstance
          .applyTheme({ css: manualCss })
          .catch((error) => {
            onStatus({
              type: 'player-status',
              status: 'present-error',
              message: error?.message || String(error),
              code: error?.code,
              event: error?.event,
              payload: error
            });
            throw error;
          })
      );
    },
    clearManualCss() {
      return runOrQueue(() =>
        bridgeInstance
          .applyTheme({ css: '' })
          .catch((error) => {
            onStatus({
              type: 'player-status',
              status: 'present-error',
              message: error?.message || String(error),
              code: error?.code,
              event: error?.event,
              payload: error
            });
            throw error;
          })
      );
    },
    sendTrigger(triggerId) {
      if (!triggerId) return Promise.resolve();
      return runOrQueue(() =>
        bridgeInstance
          .trigger(triggerId)
          .catch((error) => {
            onStatus({
              type: 'player-status',
              status: 'present-error',
              message: error?.message || String(error),
              code: error?.code,
              event: error?.event,
              payload: error
            });
            throw error;
          })
      );
    },
    sendCommand(command) {
      if (!Array.isArray(command) || command.length === 0) return Promise.resolve();
      const [cmd, ...rest] = command;
      return runOrQueue(() =>
        bridgeInstance
          .trigger(cmd, ...rest)
          .catch((error) => {
            onStatus({
              type: 'player-status',
              status: 'present-error',
              message: error?.message || String(error),
              code: error?.code,
              event: error?.event,
              payload: error
            });
            throw error;
          })
      );
    },
    getConfig() {
      return currentConfig;
    },
    get state() {
      return bridgeInstance?.state;
    },
    waitUntilReady({ timeout } = {}) {
      if (bridgeReady) {
        return Promise.resolve();
      }
      if (!bridgeInstance) {
        return Promise.reject(new Error('bridge not initialized'));
      }
      return new Promise((resolve, reject) => {
        const target = bridgeInstance;
        let timer = null;
        const cleanup = () => {
          if (timer != null) {
            window.clearTimeout(timer);
            timer = null;
          }
          try {
            target.off?.('ready', handleReady);
          } catch (_error) {
            /* ignore */
          }
          try {
            target.off?.('error', handleError);
          } catch (_error) {
            /* ignore */
          }
        };
        const handleReady = () => {
          cleanup();
          resolve();
        };
        const handleError = (error) => {
          cleanup();
          reject(error);
        };
        if (typeof timeout === 'number' && Number.isFinite(timeout) && timeout >= 0) {
          timer = window.setTimeout(() => {
            cleanup();
            reject(new Error('waitUntilReady timeout'));
          }, timeout);
        }
        target.on?.('ready', handleReady);
        target.on?.('error', handleError);
      });
    }
  };
}

function buildPlayerUrl(config = {}) {
  const url = new URL(PLAYER_URL, window.location.origin);
  url.searchParams.set('ver', PLAYER_VERSION);
  if (config.account) url.searchParams.set('account', config.account);
  if (config.host) url.searchParams.set('host', config.host);
  if (Array.isArray(config.present)) {
    config.present.forEach((id) => url.searchParams.append('present', id));
  }
  if (config.inlineSelector) url.searchParams.set('inlineSelector', config.inlineSelector);
  if (config.themeCss) url.searchParams.set('themeCss', config.themeCss);
  if (config.manualCss) url.searchParams.set('manualCss', config.manualCss);
  if (config.tagSrc) url.searchParams.set('tagSrc', config.tagSrc);
  const proxyOrigin =
    (typeof config.proxyOrigin === 'string' && config.proxyOrigin.trim()) ||
    (typeof window.__PI_PROXY_ORIGIN__ === 'string' && window.__PI_PROXY_ORIGIN__.trim()) ||
    '';
  if (proxyOrigin) {
    url.searchParams.set('proxyOrigin', proxyOrigin);
  }
  if (config.mode) url.searchParams.set('mode', config.mode);
  return url.toString();
}

function flagFromParam(value) {
  if (!value) return undefined;
  return value === '1' || value.toLowerCase() === 'true';
}
