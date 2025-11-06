/**
 * Centralized port configuration for all services
 * @fileoverview Port definitions used across the pulse widgets codebase
 */

/**
 * Default port configuration for all services
 * @type {Object}
 */
const PORTS = {
  /** Main preview server port */
  SERVER_PORT: 8000,
  
  /** Stripe demo server port */
  STRIPE_DEMO_PORT: 4242,
  
  /** Background proxy server port */
  BACKGROUND_PROXY_PORT: 3100,
  
  /** Webpack dev server port (legacy - for optional pi-master reference) */
  WEBPACK_DEV_PORT: 3035,
  
  /** Test server port */
  TEST_SERVER_PORT: 9898
};

/**
 * Environment-specific port overrides
 * @type {Object}
 */
const PORT_OVERRIDES = {
  development: {
    // Development can use different ports if needed
  },
  production: {
    // Production port overrides if needed
  },
  test: {
    // Test environment port overrides
    SERVER_PORT: 8001,
    STRIPE_DEMO_PORT: 4243,
    BACKGROUND_PROXY_PORT: 3101
  }
};

/**
 * Get port configuration for current environment
 * @param {string} environment - Environment name (development, production, test)
 * @returns {Object} Port configuration object
 */
function getPorts(environment = 'development') {
  const basePorts = { ...PORTS };
  const overrides = PORT_OVERRIDES[environment] || {};
  
  return {
    ...basePorts,
    ...overrides
  };
}

/**
 * Get a specific port by name
 * @param {string} portName - Name of the port to retrieve
 * @param {string} environment - Environment name
 * @returns {number} Port number
 */
function getPort(portName, environment = 'development') {
  const ports = getPorts(environment);
  return ports[portName] || PORTS[portName];
}

module.exports = {
  PORTS,
  PORT_OVERRIDES,
  getPorts,
  getPort
};
