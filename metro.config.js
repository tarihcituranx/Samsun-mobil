if (!Array.prototype.toReversed) {
  Object.defineProperty(Array.prototype, 'toReversed', {
    value: function() {
      return [...this].reverse();
    }
  });
}

const { getDefaultConfig } = require('expo/metro-config');

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

module.exports = config;
