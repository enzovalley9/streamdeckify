// Names, links and the domain live here, and only here.

// TODO(domain): streamdeckify.com is registered by someone else (since 2020).
// Pick the final domain before going public and change this one line.
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

// Enzo's own address for now. TODO(contact): once the domain exists, switch to
// hello@<domain> with forwarding, so the personal address isn't published.
export const CONTACT_EMAIL = 'hello@streamdeckify.org';

export const HASHTAG = 'streamdeckify';
export const CREATOR = {
  name: 'Enzo Valley',
  github: 'enzovalley9',
  x: 'enzovalley9',
};
