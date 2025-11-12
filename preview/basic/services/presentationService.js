/**
 * @fileoverview Presentation Service
 * 
 * Main presentation orchestration service that coordinates survey presentations
 * using a state machine, queue, and deduplicator.
 */

const { log } = require('../../lib/logger');
const { StateMachine } = require('../lib/stateMachine');
const { PresentationQueue, PRIORITY } = require('../lib/presentationQueue');
const { PresentationDeduplicator, SOURCE } = require('../lib/presentationDeduplicator');
const { ErrorFactory } = require('../../lib/errors');
const { PRESENTATION } = require('../config/constants');
const { getEventBus } = require('../lib/eventBus');

/**
 * Presentation Service
 * 
 * Orchestrates survey presentations with:
 * - State machine for presentation lifecycle
 * - Queue for request management
 * - Deduplicator for duplicate prevention
 * - Event emission for state changes
 */
class PresentationService {
  /**
   * Create a new PresentationService
   * @param {Object} dependencies - Service dependencies
   * @param {Object} dependencies.bridge - Survey bridge instance
   * @param {Object} dependencies.findRecord - Function to find survey record
   * @param {Object} dependencies.ensureBackground - Function to ensure background
   * @param {Object} dependencies.ensurePlayer - Function to ensure player loaded
   * @param {Object} dependencies.ensureTag - Function to ensure tag ready
   * @param {Object} dependencies.applyIdentifier - Function to apply identifier
   * @param {Object} dependencies.sendPresent - Function to send present command
   * @param {Object} [options] - Configuration options
   */
  constructor(dependencies, options = {}) {
    this.dependencies = dependencies;
    this.options = {
      timeoutMs: options.timeoutMs || PRESENTATION.TIMEOUT_MS,
      cooldownMs: options.cooldownMs || PRESENTATION.COOLDOWN_MS,
      ...options
    };

    // Initialize queue
    this.queue = new PresentationQueue({
      deduplicationWindowMs: PRESENTATION.DEDUPLICATION_WINDOW_MS,
      maxQueueSize: PRESENTATION.MAX_QUEUE_SIZE
    });

    // Initialize deduplicator
    this.deduplicator = new PresentationDeduplicator({
      cooldownMs: this.options.cooldownMs
    });

    // Initialize state machine
    this.stateMachine = this.createStateMachine();

    // Initialize event bus
    this.eventBus = getEventBus();

    // Setup queue event handlers
    this.setupQueueHandlers();

    // Current operation tracking
    this.currentOperation = null;
    this.operationId = 0;
  }

  /**
   * Create state machine for presentation lifecycle
   * @private
   * @returns {StateMachine} State machine instance
   */
  createStateMachine() {
    const states = [
      {
        name: 'idle',
        onEnter: () => {
          this.currentOperation = null;
          this.eventBus.emit('presentation:idle', {});
        }
      },
      {
        name: 'preparing',
        onEnter: (context) => {
          this.eventBus.emit('presentation:preparing', {
            surveyId: context.surveyId,
            operationId: context.operationId
          });
        }
      },
      {
        name: 'presenting',
        onEnter: (context) => {
          this.eventBus.emit('presentation:presenting', {
            surveyId: context.surveyId,
            operationId: context.operationId
          });
        }
      },
      {
        name: 'presented',
        onEnter: (context) => {
          this.eventBus.emit('presentation:presented', {
            surveyId: context.surveyId,
            operationId: context.operationId
          });
          // Transition back to idle after a short delay
          setTimeout(() => {
            if (this.stateMachine.getState() === 'presented') {
              this.stateMachine.transition('idle', {});
            }
          }, 1000);
        }
      },
      {
        name: 'failed',
        onEnter: (context) => {
          this.eventBus.emit('presentation:failed', {
            surveyId: context.surveyId,
            operationId: context.operationId,
            error: context.error
          });
          // Transition back to idle after a short delay
          setTimeout(() => {
            if (this.stateMachine.getState() === 'failed') {
              this.stateMachine.transition('idle', {});
            }
          }, 2000);
        }
      }
    ];

    const transitions = [
      {
        from: 'idle',
        to: 'preparing',
        guard: () => true
      },
      {
        from: 'preparing',
        to: 'presenting',
        guard: () => true
      },
      {
        from: 'preparing',
        to: 'failed',
        guard: (context) => context.error !== undefined
      },
      {
        from: 'presenting',
        to: 'presented',
        guard: () => true
      },
      {
        from: 'presenting',
        to: 'failed',
        guard: (context) => context.error !== undefined
      },
      {
        from: 'presented',
        to: 'idle',
        guard: () => true
      },
      {
        from: 'failed',
        to: 'idle',
        guard: () => true
      }
    ];

    return new StateMachine({
      initialState: 'idle',
      states,
      transitions
    });
  }

  /**
   * Setup queue event handlers
   * @private
   */
  setupQueueHandlers() {
    this.queue.on('queued', (data) => {
      this.eventBus.emit('presentation:queued', data);
    });

    this.queue.on('processing', async (data) => {
      await this.handleQueueProcessing(data);
    });

    this.queue.on('processed', (data) => {
      this.eventBus.emit('presentation:processed', data);
    });

    this.queue.on('rejected', (data) => {
      this.eventBus.emit('presentation:rejected', data);
    });

    this.queue.on('error', (data) => {
      this.eventBus.emit('presentation:error', data);
    });
  }

  /**
   * Handle queue processing
   * @private
   * @param {Object} data - Queue processing data
   */
  async handleQueueProcessing(data) {
    const { surveyId, options, source } = data;
    const operationId = `present-${++this.operationId}`;

    this.currentOperation = {
      id: operationId,
      surveyId,
      source,
      startTime: Date.now()
    };

    try {
      // Check deduplication
      const dedupResult = this.deduplicator.checkDuplicate(surveyId, {
        source: this.mapSourceToDeduplicatorSource(source),
        force: options.force,
        allowDuplicate: options.allowDuplicate
      });

      if (dedupResult.isDuplicate && !options.force && !options.allowDuplicate) {
        throw ErrorFactory.duplicatePresentation(
          `Survey ${surveyId} already presented ${dedupResult.reason}`,
          surveyId,
          dedupResult.lastPresentedAt
        );
      }

      // Transition to preparing
      this.stateMachine.transition('preparing', { surveyId, operationId });

      // Execute presentation
      await this.executePresentation(surveyId, options, operationId);

      // Record presentation
      this.deduplicator.recordPresentation(
        surveyId,
        this.mapSourceToDeduplicatorSource(source)
      );

      // Transition to presented
      this.stateMachine.transition('presented', { surveyId, operationId });

    } catch (error) {
      log.error('Presentation failed', error, {
        surveyId,
        operationId,
        source
      });

      // Transition to failed
      this.stateMachine.transition('failed', {
        surveyId,
        operationId,
        error: error.message
      });

      throw error;
    }
  }

  /**
   * Execute presentation
   * @private
   * @param {string} surveyId - Survey ID
   * @param {Object} options - Presentation options
   * @param {string} operationId - Operation ID
   */
  async executePresentation(surveyId, options, operationId) {
    // Find record
    const record = this.dependencies.findRecord(surveyId);
    if (!record) {
      throw ErrorFactory.presentation(
        `Survey ${surveyId} not found`,
        surveyId,
        operationId
      );
    }

    // Transition to presenting
    this.stateMachine.transition('presenting', { surveyId, operationId });

    // Ensure prerequisites
    if (this.dependencies.ensureBackground) {
      await this.dependencies.ensureBackground(record, options);
    }

    if (this.dependencies.ensurePlayer) {
      await this.dependencies.ensurePlayer(record, {
        excludePresent: true,
        forceReload: options.forceReload || options.force
      });
    }

    if (this.dependencies.ensureTag) {
      await this.dependencies.ensureTag();
    }

    if (this.dependencies.applyIdentifier) {
      this.dependencies.applyIdentifier(record);
    }

    // Send present command
    if (this.dependencies.sendPresent) {
      this.dependencies.sendPresent(record, options);
    }
  }

  /**
   * Map source to deduplicator source
   * @private
   * @param {string} source - Source string
   * @returns {SOURCE} Deduplicator source
   */
  mapSourceToDeduplicatorSource(source) {
    if (source === 'manual' || source === 'button') {
      return SOURCE.MANUAL;
    }
    if (source === 'url_param' || source === 'present') {
      return SOURCE.URL_PARAM;
    }
    if (source === 'behavior' || source === 'trigger') {
      return SOURCE.BEHAVIOR;
    }
    if (source === 'auto') {
      return SOURCE.AUTO;
    }
    return SOURCE.UNKNOWN;
  }

  /**
   * Present a survey
   * @param {string} surveyId - Survey ID to present
   * @param {Object} [options] - Presentation options
   * @param {boolean} [options.force=false] - Force presentation
   * @param {boolean} [options.allowDuplicate=false] - Allow duplicate
   * @param {boolean} [options.forceReload=false] - Force reload
   * @param {string} [options.source='unknown'] - Source of request
   * @returns {Promise<void>} Promise that resolves when presentation is queued
   */
  async present(surveyId, options = {}) {
    const {
      force = false,
      allowDuplicate = false,
      forceReload = false,
      source = 'unknown'
    } = options;

    const priority = source === 'manual' || source === 'button' || source === 'url_param'
      ? PRIORITY.MANUAL
      : PRIORITY.AUTO;

    return this.queue.enqueue(surveyId, {
      priority,
      source,
      force,
      allowDuplicate,
      forceReload
    });
  }

  /**
   * Cancel a presentation
   * @param {string} surveyId - Survey ID to cancel
   * @returns {boolean} True if cancelled
   */
  cancel(surveyId) {
    const cancelled = this.queue.cancel(surveyId);
    if (cancelled) {
      this.eventBus.emit('presentation:cancelled', { surveyId });
    }
    return cancelled;
  }

  /**
   * Get current presentation state
   * @param {string} [surveyId] - Survey ID (optional)
   * @returns {Object} State information
   */
  getState(surveyId = null) {
    return {
      currentState: this.stateMachine.getState(),
      currentOperation: this.currentOperation,
      queueState: this.queue.getState(),
      history: this.deduplicator.getHistory(surveyId)
    };
  }

  /**
   * Clear all state
   */
  clear() {
    this.queue.clear();
    this.deduplicator.clearAll();
    this.stateMachine.reset();
    this.currentOperation = null;
    this.eventBus.emit('presentation:cleared', {});
  }
}

module.exports = {
  PresentationService
};

