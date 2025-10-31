(function() {
  var w = window, d = document;
  var s = d.createElement('script'); s.async = 1;
  var DEFAULT_SRC = 'https://js.pulseinsights.com/surveys.js';
  var desiredSrc = (typeof w.PULSE_TAG_SRC === 'string' && w.PULSE_TAG_SRC.trim())
    ? w.PULSE_TAG_SRC
    : DEFAULT_SRC;
  var resolvedSrc = resolveProxiedSrc(desiredSrc);
  s.src = resolvedSrc;
  w.PULSE_TAG_SRC = resolvedSrc;

  var f = d.getElementsByTagName('script')[0];
  f.parentNode.insertBefore(s, f);

  class PulseInsightsCommands extends Array{
    push(...commands) {
      commands.forEach((command) => window.PulseInsightsObject.processCommand(command));
    }
  }

  function waitPulseInsightsObject() {
    const timeoutPromise = new Promise((_, reject) => setTimeout(reject, 5000));
    const waitPromise = new Promise(function (resolve) {
      function wait() {
        if (typeof window.PulseInsightsObject == 'object') {
          resolve();
        } else {
          setTimeout(wait, 100);
        }
      }
      wait();
    });
    return Promise.race([timeoutPromise, waitPromise])
  }

  waitPulseInsightsObject().then(function () {
    w['pi']=function() {
      w['pi'].commands = w['pi'].commands || new PulseInsightsCommands;
      w['pi'].commands.push(arguments);
    };
    const host = w.PULSE_TAG_HOST || 'survey.pulseinsights.com';
    const identifier = w.PULSE_TAG_IDENTIFIER || 'PI-81598442';
    
    pi('host', host);
    pi('identify', identifier);
    pi('pushBeforeGet', true);
    try {
      console.log('[official-tag] pushBeforeGetEnabled', window.PulseInsightsObject && window.PulseInsightsObject.pushBeforeGetEnabled);
    } catch (_error) {
      /* ignore */
    }
    
    pi('get', 'surveys');
  })
  .catch(function() {
    console.error('Failed to initialize window.PulseInsightsObject');
  });

  function resolveProxiedSrc(raw) {
    if (!raw && raw !== '') return DEFAULT_SRC;
    var trimmed = String(raw).trim();
    if (!trimmed) return DEFAULT_SRC;

    if (trimmed.indexOf('//') === 0) {
      var protocol = (w.location && w.location.protocol) || 'https:';
      trimmed = protocol + trimmed;
    }

    var proxyOrigin = '';
    if (typeof w.__PI_PROXY_ORIGIN__ === 'string') {
      proxyOrigin = w.__PI_PROXY_ORIGIN__.trim();
    }

    if (!proxyOrigin) return trimmed;
    if (!/^https?:\/\//i.test(trimmed)) return trimmed;
    if (trimmed.indexOf('/proxy?url=') !== -1) return trimmed;

    var base = proxyOrigin.replace(/\/$/, '');
    return base + '/proxy?url=' + encodeURIComponent(trimmed);
  }
})();
