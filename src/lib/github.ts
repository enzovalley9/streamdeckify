import { REPO } from '../site';

// Live numbers from GitHub, read at build time. The deploy workflow rebuilds
// the site every hour. Without network, or while the repo is private, this
// returns null and the site simply doesn't show them.
type Stats = { stars: number; forks: number };
let cached: Promise<Stats | null> | undefined;

export function repoStats(): Promise<Stats | null> {
  cached ??= (async () => {
    try {
      const headers: Record<string, string> = {
        Accept: 'application/vnd.github+json',
        'User-Agent': 'streamdeckify-site',
      };
      const token = process.env.GITHUB_TOKEN;
      if (token) headers.Authorization = `Bearer ${token}`;
      const res = await fetch(`https://api.github.com/repos/${REPO}`, { headers, signal: AbortSignal.timeout(5000) });
      if (!res.ok) return null;
      const repo = (await res.json()) as { stargazers_count: number; forks_count: number; private: boolean };
      return repo.private ? null : { stars: repo.stargazers_count, forks: repo.forks_count };
    } catch {
      return null;
    }
  })();
  return cached;
}

// Social proof only once it is proof.
export const SHOW_STARS_FROM = 100;

export const compact = (n: number) =>
  n >= 1000 ? `${(n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, '')}k` : String(n);
