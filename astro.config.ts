import { defineConfig } from 'astro/config';
import { SITE_URL } from './src/site';

export default defineConfig({
  site: SITE_URL,
  build: { format: 'directory' },
});
