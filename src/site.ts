// Names, links and the domain live here, and only here.

// The .org, because streamdeckify.com belongs to someone else.
export const DOMAIN = 'streamdeckify.org';
export const SITE_URL = `https://${DOMAIN}`;

export const NAME = 'Streamdeckify';
export const TAGLINE = 'Any screen can be a Stream Deck.';
export const DESCRIPTION =
  'Turn an old Kindle, tablet, phone or TV into a button panel for your computer. Paste one prompt into your AI coding agent. Free, open source, nothing in the cloud.';

export const REPO = 'enzovalley9/streamdeckify';
export const REPO_URL = `https://github.com/${REPO}`;
export const NEW_ISSUE = (template: string, title = '') =>
  `${REPO_URL}/issues/new?template=${template}${title ? `&title=${encodeURIComponent(title)}` : ''}`;

// Forwards to the maintainer, so no personal address is published.
export const CONTACT_EMAIL = `hello@${DOMAIN}`;

export const HASHTAG = 'streamdeckify';
export const CREATOR = {
  name: 'Enzo Valley',
  github: 'enzovalley9',
  x: 'enzovalley9',
};
