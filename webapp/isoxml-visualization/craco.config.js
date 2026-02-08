module.exports = {
  webpack: {
    alias: {
        'mapbox-gl': 'maplibre-gl'
    },
    configure: (webpackConfig) => {
      // Add fallbacks for sql.js (browser compatibility)
      webpackConfig.resolve.fallback = {
        ...webpackConfig.resolve.fallback,
        fs: false,
        path: false,
        crypto: false
      }
      return webpackConfig
    }
  }
}