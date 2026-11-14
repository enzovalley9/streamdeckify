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
  city: 'Madrid',
};
export const CREATOR_X_URL = `https://x.com/${CREATOR.x}`;

// "Buy me a coffee" on the home page. Public addresses only.
// Ethereum and Hedera share one key, so they share the 0x address.
export const COFFEE = [
  {
    id: 'btc',
    name: 'Bitcoin',
    ticker: 'BTC',
    address: 'bc1qmvs38k59qfs8m5la4jrgulmx897zvdncppwdmv',
    note: 'Bitcoin network only.',
  },
  {
    id: 'eth',
    name: 'Ethereum',
    ticker: 'ETH',
    address: '0x94ac32EdBb54236B3E8A52E9fe49c157315eE645',
    note: 'Ethereum, or any EVM network like Base or Arbitrum.',
  },
  {
    id: 'sol',
    name: 'Solana',
    ticker: 'SOL',
    address: 'Byojjj99pPPbdNEcSYXrkefhiZ2ZhUBtdafrMQAMvaRd',
    note: 'SOL or USDC on Solana.',
  },
  {
    id: 'hbar',
    name: 'Hedera',
    ticker: 'HBAR',
    address: '0x94ac32EdBb54236B3E8A52E9fe49c157315eE645',
    note: 'Hedera reads this EVM address. Send from a Hedera wallet like HashPack.',
  },
] as const;
