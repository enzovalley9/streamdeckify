import { SITE_URL, REPO_URL } from '../site';

// The prompts are plain Markdown files in /prompts at the root of the repo.
// The site shows them, and also serves them as text at /prompts/<id>.md
// so an agent can fetch the latest version from a one-line instruction.
const files = import.meta.glob('/prompts/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>;

export type PromptStatus = 'verified' | 'works' | 'experimental';

const META: {
  id: string;
  tab: string;
  status: PromptStatus;
  blurb: string;
  thing: string;
}[] = [
  {
    id: 'kindle',
    tab: 'Kindle',
    status: 'verified',
    blurb:
      'Full screen and instant taps. Your agent walks you through the jailbreak if you need one. Tested on a Paperwhite 2 with macOS and Ubuntu.',
    thing: 'Kindle',
  },
  {
    id: 'kindle-no-jailbreak',
    tab: 'Kindle, no jailbreak',
    status: 'experimental',
    blurb:
      'Uses the Kindle’s own web browser, so nothing gets installed on it. Slower and it may fall asleep. Help us test it.',
    thing: 'Kindle (without jailbreaking it)',
  },
  {
    id: 'any-screen',
    tab: 'Any other screen',
    status: 'experimental',
    blurb:
      'Tablets, phones, TVs, e-readers, anything with a browser or a way to run code. Touchscreen or not.',
    thing: 'old screen',
  },
];

export const PROMPTS = META.map((p) => {
  const source = files[`/prompts/${p.id}.md`];
  if (!source) throw new Error(`Missing prompt file: prompts/${p.id}.md`);
  // The files say {{SITE_URL}} and {{REPO_URL}} so the domain lives only in src/site.ts.
  const text = source.replaceAll('{{SITE_URL}}', SITE_URL).replaceAll('{{REPO_URL}}', REPO_URL);
  const url = `${SITE_URL}/prompts/${p.id}.md`;
  return {
    ...p,
    text,
    url,
    oneLiner: `Turn my ${p.thing} into a Stream Deck for this computer. Fetch ${url} and follow it step by step. Explain each step and ask me before changing anything.`,
  };
});

export const promptById = (id: string) => PROMPTS.find((p) => p.id === id);
