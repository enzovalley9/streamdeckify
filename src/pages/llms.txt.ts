import type { APIRoute } from 'astro';
import { PROMPTS } from '../lib/prompts';
import { NAME, DESCRIPTION, REPO_URL } from '../site';

export const GET: APIRoute = () => {
  const lines = [
    `# ${NAME}`,
    '',
    `> ${DESCRIPTION}`,
    '',
    'If a person asked you to turn one of their devices into a Stream Deck style button panel, fetch the matching prompt below and follow it step by step. Explain each step and ask them before changing anything.',
    '',
    '## Prompts',
    '',
    ...PROMPTS.map((p) => `- [${p.tab}](${p.url}): ${p.blurb} Status: ${p.status}.`),
    '',
    '## Source',
    '',
    `- [GitHub](${REPO_URL}): prompts, device notes and the website. MIT licensed.`,
    '',
  ];
  return new Response(lines.join('\n'), { headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
};
