import { defineCollection, reference } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

// Every field here is checked by CI on each pull request.
// Templates with comments: docs/templates/device.md and docs/templates/deck.md

const githubUser = z
  .string()
  .regex(/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$/, 'A GitHub username, without the @');

const devices = defineCollection({
  loader: glob({ base: './src/content/devices', pattern: '*.md' }),
  schema: z.object({
    name: z.string().max(60),
    brand: z.string().max(40),
    year: z.number().int().min(1990).max(2100).optional(),
    family: z.enum(['kindle', 'kobo', 'e-reader', 'tablet', 'phone', 'tv', 'console', 'single-board', 'other']),
    screen: z.enum(['e-ink', 'lcd', 'oled', 'other']),
    input: z.array(z.enum(['touch', 'remote', 'd-pad', 'buttons', 'keyboard'])).min(1),
    method: z.enum(['jailbreak', 'browser', 'app', 'other']),
    prompt: z.enum(['kindle', 'kindle-no-jailbreak', 'any-screen']),
    status: z.enum(['verified', 'works', 'experimental']),
    latency_ms: z.number().int().positive().optional(),
    computers: z.array(z.enum(['macos', 'linux', 'windows'])).min(1),
    contributors: z.array(githubUser).min(1),
    summary: z.string().max(160),
    updated: z.coerce.date(),
  }),
});

const decks = defineCollection({
  loader: glob({ base: './src/content/decks', pattern: '*.md' }),
  schema: ({ image }) =>
    z.object({
      title: z.string().max(80),
      device: z.string().max(60),
      recipe: reference('devices').optional(),
      computer: z.enum(['macos', 'linux', 'windows']),
      author: z.string().max(60),
      github: githubUser.optional(),
      link: z.url().optional(),
      photo: image(),
      photo_kind: z.enum(['photo', 'screenshot']).default('photo'),
      photo_alt: z.string().min(10).max(300),
      buttons: z.array(z.string().max(40)).max(40).optional(),
      date: z.coerce.date(),
    }),
});

export const collections = { devices, decks };
