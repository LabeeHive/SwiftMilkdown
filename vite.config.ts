import { defineConfig } from 'vite'

export default defineConfig({
  base: './',
  build: {
    // Output to SPM Resources directory
    outDir: 'Sources/SwiftMilkdown/Resources/Editor',
    emptyOutDir: true,
    minify: 'esbuild',
    assetsDir: '',
    rollupOptions: {
      output: {
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
        assetFileNames: '[name].[ext]'
      }
    }
  },
  server: {
    port: 3000
  }
})
