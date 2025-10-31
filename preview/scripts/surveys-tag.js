(function () {
  try {
    console.log('[surveys-tag] shim bootstrap', { buildStamp: '2025-02-15T17:30:00Z' });
  } catch (_error) {
    /* ignore */
  }
  const w = window;
  const d = document;

  if (typeof w.pi !== 'function') {
    const queued = [];
    const stub = function () {
      stub.q.push(arguments);
    };
    stub.q = queued;
    stub.l = Date.now();
    w.pi = stub;
  }

  const config = {
    host: w.PULSE_TAG_HOST || 'survey.pulseinsights.com',
    account: w.PULSE_TAG_ACCOUNT || 'PI-81598442',
    scriptSrc: w.PULSE_TAG_SRC || 'https://js.pulseinsights.com/surveys.js'
  };

  const bootCommands = Array.isArray(w.PULSE_TAG_BOOT_COMMANDS) ? w.PULSE_TAG_BOOT_COMMANDS : [];

  let deferredPresentIds = [];
  try {
    const params = new URLSearchParams(w.location.search);
    deferredPresentIds = deferredPresentIds.concat(params.getAll('pi_present').filter(Boolean));
  } catch (error) {
    // URL parsing failed; ignore and continue booting the tag.
  }

  if (Array.isArray(w.PULSE_TAG_PRESENT_IDS)) {
    deferredPresentIds = deferredPresentIds.concat(w.PULSE_TAG_PRESENT_IDS.filter(Boolean));
  }

  const script = d.createElement('script');
  script.async = true;
  script.src = config.scriptSrc;
  script.referrerPolicy = 'strict-origin-when-cross-origin';
  script.dataset.pulseTag = 'preview';
  script.onload = () => {
    try {
      console.log('[surveys-tag] surveys.js loaded', { src: script.src });
    } catch (_error) {
      /* ignore */
    }
  };
  script.onerror = (event) => {
    try {
      console.error('[surveys-tag] surveys.js failed to load', { src: script.src, event });
    } catch (_error) {
      /* ignore */
    }
  };

  const firstScript = d.getElementsByTagName('script')[0];
  if (firstScript && firstScript.parentNode) {
    firstScript.parentNode.insertBefore(script, firstScript);
  } else {
    d.head.appendChild(script);
  }

  waitForPulseInsightsObject()
    .then(() => {
      try {
        console.log('[surveys-tag] PulseInsightsObject ready');
      } catch (_error) {
        /* ignore */
      }
      const priorPi = w.pi;
      const priorQueue = Array.isArray(priorPi && priorPi.q) ? priorPi.q.slice() : [];
      const priorTimestamp = (priorPi && priorPi.l) || Date.now();

      class PulseInsightsCommands extends Array {
        push(...commands) {
          commands.forEach((command) => {
            try {
              w.PulseInsightsObject.processCommand(command);
            } catch (error) {
              try {
                console.error('[surveys-tag] processCommand failed', command, error);
              } catch (_consoleError) {
                /* ignore console issues */
              }
            }
          });
          return this.length;
        }
      }

      const commandBuffer = new PulseInsightsCommands();
      const forwarder = function () {
        commandBuffer.push(arguments);
      };
      forwarder.commands = commandBuffer;
      forwarder.l = priorTimestamp;
      w.pi = forwarder;

      const invoke = (...args) => {
        try {
          forwarder.apply(null, args);
        } catch (error) {
          try {
            console.error('[surveys-tag] pi invocation failed', args, error);
          } catch (_consoleError) {
            /* ignore */
          }
        }
      };

      if (Array.isArray(bootCommands) && bootCommands.length) {
        bootCommands.forEach((command) => {
          if (Array.isArray(command) && command.length > 0) {
            invoke.apply(null, command);
          }
        });
      }

      priorQueue.forEach((queued) => {
        if (Array.isArray(queued) && queued.length > 0) {
          invoke.apply(null, queued);
        }
      });

      if (config.host) invoke('host', config.host);
      if (config.account) invoke('identify', config.account);
      invoke('pushBeforeGet', true);
      try {
        console.log('[surveys-tag] pushBeforeGetEnabled now', w.PulseInsightsObject.pushBeforeGetEnabled);
      } catch (_error) {
        /* ignore */
      }
      invoke('get', 'surveys');
      deferredPresentIds.forEach((present) => invoke('present', present));
      deferredPresentIds = [];
      w.dispatchEvent(
        new CustomEvent('pulseinsights:ready', {
          detail: {
            account: config.account,
            host: config.host,
            mode: w.PULSE_TAG_MODE || 'overlay'
          }
        })
      );
    })
    .catch(() => {
      try {
        console.warn('[surveys-tag] Pulse Insights object did not initialize within expected time.');
      } catch (_error) {
        /* ignore */
      }
      console.warn('Pulse Insights object did not initialize within expected time.');
    });

  function waitForPulseInsightsObject(timeoutMs = 6000) {
    const start = Date.now();
    return new Promise((resolve, reject) => {
      (function poll() {
        if (typeof w.PulseInsightsObject === 'object' && w.PulseInsightsObject) {
          resolve(w.PulseInsightsObject);
          return;
        }
        if (Date.now() - start >= timeoutMs) {
          reject(new Error('Pulse Insights object not available'));
          return;
        }
        setTimeout(poll, 120);
      })();
    });
  }
})();
