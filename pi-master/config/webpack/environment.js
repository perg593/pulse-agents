const { environment } = require('@rails/webpacker')

module.exports = environment;

module.exports.config.merge({
  module: {
    rules: [
      {
        test: /\.mjs$/,
        include: /node_modules/,
        type: 'javascript/auto',
      },
    ],
  },
});

// Fixes "React is undefined"(firefox)
// AKA "Cannot read property 'useLayoutEffect' of undefined"(chrome)
// https://github.com/tannerlinsley/react-table/discussions/2048
const nodeModulesLoader = environment.loaders.get('nodeModules');
if (!Array.isArray(nodeModulesLoader.exclude)) {
  nodeModulesLoader.exclude = nodeModulesLoader.exclude == null ? [] : [nodeModulesLoader.exclude];
}

// https://github.com/rails/webpacker/issues/2407
nodeModulesLoader.exclude.push(/react-table/);
nodeModulesLoader.exclude.push(/@projectstorm/);
