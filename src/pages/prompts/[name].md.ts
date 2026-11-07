import type { APIRoute } from 'astro';
import { PROMPTS } from '../../lib/prompts';

// Serves each prompt as plain Markdown, e.g. /prompts/kindle.md,
// so the one-line prompt can tell an agent to fetch the full recipe.
export function getStaticPaths() {
  return PROMPTS.map((p) => ({ params: { name: p.id }, props: { text: p.text } }));
}

export const GET: APIRoute = ({ props }) =>
  new Response(props.text as string, {
    headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
  });
