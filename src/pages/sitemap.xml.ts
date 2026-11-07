import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';
import { SITE_URL } from '../site';

export const GET: APIRoute = async () => {
  const devices = await getCollection('devices');
  const paths = ['/', '/devices/', '/press/', ...devices.map((d) => `/devices/${d.id}/`)];
  const urls = paths.map((p) => `  <url><loc>${SITE_URL}${p}</loc></url>`).join('\n');
  const body = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`;
  return new Response(body, { headers: { 'Content-Type': 'application/xml; charset=utf-8' } });
};
