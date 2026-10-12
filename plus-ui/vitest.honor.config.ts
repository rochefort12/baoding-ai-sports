import path from 'node:path';
import { defineConfig } from 'vitest/config';
import vue from '@vitejs/plugin-vue';

// This separate config tests actual Vue display components with synthetic projections.
// It never opens a backend connection or creates a certification record.
export default defineConfig({
  plugins: [vue()],
  resolve: { alias: { '@': path.resolve(__dirname, './src') } },
  test: { environment: 'node', include: ['tests/honor-display.contract.ts'] }
});
