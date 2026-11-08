# AGENTS.md

Instructions for the AI coding agents that open this repo: Claude Code, Codex, Gemini CLI and the rest.

## First: which job are you doing?

| The person wants to... | Do this |
| --- | --- |
| Turn their own screen into a deck | Open the matching recipe in `prompts/` and follow it on their real device and computer, one step at a time. The Kindle recipe starts from the first deck's code in `reference/kindle/`: copy it out of the repo and adapt the copy. You don't need to change this repo for that. Don't open issues or pull requests unless the person asks you to. |
| Change this repo: add a device, a deck, a prompt fix or a website change | Read the rest of this file first. |

## Map

| Path | What it is |
| --- | --- |
| `prompts/` | The recipes. They are the product. The website serves them as plain text too. |
| `reference/kindle/` | Code for the Kindle recipe, from the first deck: the server, the Kindle client, the deploy script and the services. Agents copy it and adapt it. Its README says how. |
| `src/content/devices/` | One Markdown file per screen model. The schema is in `src/content.config.ts`. |
| `src/content/decks/` | The wall: one Markdown file and one photo per deck. |
| `src/lib/wanted.ts` | Screens nobody has done yet. Remove one when it gets a device file. |
| `src/site.ts` | The domain, names and links. Nothing else hardcodes them. |
| `src/pages/`, `src/components/`, `src/layouts/`, `src/styles/` | The Astro website. |
| `scripts/check.mjs` | The checks CI runs on every pull request. |
| `scripts/readme.mjs` | Writes the devices table in `README.md`. A workflow runs it on main. |
| `docs/templates/` | Starting points for a device file and a deck file. |
| `docs/MAINTAINING.md` | How pull requests are reviewed. |

## Where each change goes

| Change | Files | Notes |
| --- | --- | --- |
| A screen someone got working, or tried | One new file in `src/content/devices/` | Start from `docs/templates/device.md`. Status `works` or `experimental`. Only a maintainer sets `verified`. |
| A deck for the wall | One Markdown file and one photo in `src/content/decks/` | Start from `docs/templates/deck.md`. Photo under 1 MB, taken by the person, nothing private on screen. |
| A lesson for a recipe | The prompt in `prompts/` | Only what was learned on a real device. Name the device and agent in the pull request. |
| A fix to the reference code | `reference/kindle/` | Only what was tested on a real Kindle. Keep it in step with `prompts/kindle.md`, and keep its safety checks. |
| The website | `src/` | Run `npm run build` and look at it at phone width too. |

## Hard rules

- Change nothing outside the files the change needs. Never edit the generated table in `README.md` by hand.
- Never write a count or a measurement by hand when it can come from the data. The website and the README read the device files.
- No secrets, tokens, IP addresses, MAC addresses, serial numbers or personal paths in any file. Use `192.168.1.x` style examples.
- No prebuilt binaries, no jailbreak files and no links to download them. Point to kindlemodding.org instead.
- No agent or editor configuration in the tree (folders like .claude, .codex, .cursor or hooks): they would run commands for anyone who opens the repo.
- Contributions don't touch `.github/`. Open an issue to suggest a change there.
- Every prompt keeps its ground rules: one step at a time, ask before changing anything, local network only, a random token, and a fixed list of actions on the computer. `npm run check` fails if one goes missing.
- Plain English, short sentences, no em or en dashes.

## Before you open a pull request

```sh
npm ci
npm run check
npm run build
```

Start the pull request description with `Tested on:` and the device, firmware, agent and computer. Keep commit subjects short and in the imperative: "Add Kobo Clara HD", "Kindle prompt: wait for Wi-Fi after waking up".
