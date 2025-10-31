process.env.NODE_ENV = process.env.NODE_ENV || 'development'

const webpackConfig = require('./base')

// Override dev server configuration for webpack-dev-server 5.x compatibility
webpackConfig.devServer = {
  host: 'localhost',
  port: 3035,
  hot: false,
  compress: true,
  allowedHosts: 'all',
  headers: {
    'Access-Control-Allow-Origin': '*'
  },
  static: {
    watch: {
      ignored: '**/node_modules/**'
    }
  },
  client: {
    overlay: true
  }
}

module.exports = webpackConfig
