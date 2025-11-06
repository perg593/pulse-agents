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
      
      // Add error handler wrapper for PulseInsightsObject.survey.render
      // This wrapper handles cases where survey might be null at runtime
      function wrapSurveyRender() {
        if (!w.PulseInsightsObject) return;
        
        // Use Object.defineProperty to create a getter that always checks for survey
        const surveyDescriptor = Object.getOwnPropertyDescriptor(w.PulseInsightsObject, 'survey');
        if (surveyDescriptor && surveyDescriptor.get) {
          // Already has a getter, wrap it
          const originalGetter = surveyDescriptor.get;
          Object.defineProperty(w.PulseInsightsObject, 'survey', {
            get: function() {
              const survey = originalGetter.call(this);
              if (survey && typeof survey.render === 'function' && !survey.render._wrapped) {
                wrapRenderFunction(survey);
              }
              return survey;
            },
            configurable: true
          });
        } else {
          // Direct property, wrap it if it exists
          if (w.PulseInsightsObject.survey) {
            wrapRenderFunction(w.PulseInsightsObject.survey);
          }
          
          // Also set up a proxy to catch when survey is accessed later
          let surveyValue = w.PulseInsightsObject.survey;
          Object.defineProperty(w.PulseInsightsObject, 'survey', {
            get: function() {
              return surveyValue;
            },
            set: function(newValue) {
              surveyValue = newValue;
              if (newValue && typeof newValue.render === 'function' && !newValue.render._wrapped) {
                wrapRenderFunction(newValue);
              }
            },
            configurable: true
          });
        }
      }
      
      function wrapRenderFunction(survey) {
        if (!survey || typeof survey.render !== 'function' || survey.render._wrapped) {
          return;
        }
        
        const originalRender = survey.render;
        survey.render = function() {
          try {
            // Runtime check: ensure survey still exists
            if (!w.PulseInsightsObject || !w.PulseInsightsObject.survey) {
              const error = new Error('PulseInsightsObject.survey is null when render() was called');
              error.name = 'SurveyNullError';
              throw error;
            }
            
            if (this && typeof originalRender === 'function') {
              return originalRender.apply(this, arguments);
            }
          } catch (error) {
            try {
              const errorMessage = error.message || String(error);
              const isNullError = errorMessage.includes('null') || errorMessage.includes('Cannot read properties');
              
              console.error('[surveys-tag] survey.render() error caught', {
                error: errorMessage,
                surveyNull: isNullError,
                hasPulseInsightsObject: !!w.PulseInsightsObject,
                hasSurvey: !!(w.PulseInsightsObject && w.PulseInsightsObject.survey)
              });
              
              // Dispatch error event for preview application to handle
              if (typeof w.dispatchEvent === 'function') {
                w.dispatchEvent(new CustomEvent('pulseinsights:error', {
                  detail: {
                    type: isNullError ? 'survey-null-error' : 'render-error',
                    error: errorMessage,
                    stack: error.stack,
                    surveyNull: isNullError
                  }
                }));
              }
            } catch (_consoleError) {
              /* ignore */
            }
            // Re-throw to maintain original error behavior
            throw error;
          }
        };
        survey.render._wrapped = true;
      }
      
      wrapSurveyRender();
      
      const priorPi = w.pi;
      const priorQueue = Array.isArray(priorPi && priorPi.q) ? priorPi.q.slice() : [];
      const priorTimestamp = (priorPi && priorPi.l) || Date.now();

      // Wrap processCommand to catch errors when survey is null
      // Also adds retry logic for present commands when survey isn't ready yet
      const originalProcessCommand = w.PulseInsightsObject.processCommand;
      if (typeof originalProcessCommand === 'function') {
        w.PulseInsightsObject.processCommand = function(command) {
          try {
            // Check if this is a 'present' command and survey might be null
            const isPresentCommand = Array.isArray(command) && command.length > 0 && command[0] === 'present';
            
            if (isPresentCommand) {
              const surveyId = command[1];
              
              // Check if survey exists before processing present command
              if (!w.PulseInsightsObject.survey) {
                // Survey is null - this might be during initialization after iframe reload
                // Try waiting a bit for survey to become available
                const maxWaitMs = 2000; // Max 2 seconds
                const checkInterval = 50; // Check every 50ms
                let waited = 0;
                
                const waitForSurvey = () => {
                  return new Promise((resolve, reject) => {
                    const checkSurvey = () => {
                      if (w.PulseInsightsObject && w.PulseInsightsObject.survey) {
                        resolve();
                        return;
                      }
                      
                      waited += checkInterval;
                      if (waited >= maxWaitMs) {
                        const error = new Error(`Cannot present survey ${surveyId}: PulseInsightsObject.survey is null after ${waited}ms wait. This may indicate the survey data hasn't loaded yet or there's a configuration issue.`);
                        error.name = 'SurveyNullError';
                        error.surveyId = surveyId;
                        reject(error);
                        return;
                      }
                      
                      setTimeout(checkSurvey, checkInterval);
                    };
                    checkSurvey();
                  });
                };
                
                // Wait for survey to become available, then process command
                return waitForSurvey()
                  .then(() => {
                    // Survey is now available, process the command
                    return originalProcessCommand.apply(this, arguments);
                  })
                  .catch((error) => {
                    // Survey never became available
                    try {
                      console.error('[surveys-tag] processCommand failed: survey is null after wait', {
                        command,
                        surveyId,
                        waited,
                        hasPulseInsightsObject: !!w.PulseInsightsObject,
                        hasSurvey: false
                      });
                      
                      // Dispatch error event
                      if (typeof w.dispatchEvent === 'function') {
                        w.dispatchEvent(new CustomEvent('pulseinsights:error', {
                          detail: {
                            type: 'survey-null-error',
                            error: error.message,
                            surveyId,
                            command: command[0],
                            waited
                          }
                        }));
                      }
                    } catch (_consoleError) {
                      /* ignore */
                    }
                    
                    // Still try to process - let surveys.js handle the error
                    // This maintains original behavior while we've logged the issue
                    try {
                      return originalProcessCommand.apply(this, arguments);
                    } catch (innerError) {
                      // Re-throw the original wait error, not the inner error
                      throw error;
                    }
                  });
              }
            }
            
            return originalProcessCommand.apply(this, arguments);
          } catch (error) {
            try {
              const errorMessage = error.message || String(error);
              const isNullError = errorMessage.includes('null') || 
                                 errorMessage.includes('Cannot read properties') ||
                                 error.name === 'SurveyNullError';
              
              console.error('[surveys-tag] processCommand failed', {
                command,
                error: errorMessage,
                surveyNull: isNullError,
                hasPulseInsightsObject: !!w.PulseInsightsObject,
                hasSurvey: !!(w.PulseInsightsObject && w.PulseInsightsObject.survey)
              });
              
              // Dispatch error event
              if (typeof w.dispatchEvent === 'function') {
                w.dispatchEvent(new CustomEvent('pulseinsights:error', {
                  detail: {
                    type: isNullError ? 'survey-null-error' : 'processcommand-error',
                    error: errorMessage,
                    command: Array.isArray(command) ? command[0] : String(command),
                    surveyId: Array.isArray(command) && command.length > 1 ? command[1] : undefined
                  }
                }));
              }
            } catch (_consoleError) {
              /* ignore console issues */
            }
            // Re-throw to maintain original error behavior
            throw error;
          }
        };
      }

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
