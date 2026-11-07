# Contributing

Thanks for helping. Everything on the website comes from this repo, and every merged pull request goes live by itself a few minutes later.

## Where does my idea go?

| Your idea | Where it goes |
| --- | --- |
| A screen you got working, or tried to | [A device file](#add-a-device), or an issue if Git isn't your thing |
| Your setup, with a photo | [A deck on the wall](#show-your-deck) |
| Something a recipe should know | [A prompt change](#improve-a-prompt), tested on a real device |
| A new client, an app, a hardware build or a fork | Your own repo, then a deck on the wall with `link:` pointing to it. A fork on the wall is a good outcome, not a rejection. |
| A translation of the README | `README.<language>.md` (like `README.es.md`), linked from the top of `README.md` |
| A question or an idea | [Discussions](../../discussions) |
| A security problem | [Report it privately](SECURITY.md), never in a public issue |

## Show your deck

1. Fork the repo and add two files to `src/content/decks/`: your photo (`yourname-device.jpg`, jpg, png or webp, under 1 MB) and a Markdown file with the same name. Start from [docs/templates/deck.md](docs/templates/deck.md).
2. Open a pull request. CI checks every field and tells you if something is off.

Don't feel like dealing with Git? [Open an issue with your photo](../../issues/new?template=share-deck.yml) and we'll put it up for you.

## Add a device

1. Copy [docs/templates/device.md](docs/templates/device.md) to `src/content/devices/<brand-model>.md` (lowercase, words joined with dashes, like `kobo-clara-hd.md`).
2. Fill it in with what you measured: firmware, method, screen, input, speed and the gotchas that cost you time. Facts beat adjectives.
3. Set the status to `works` if you use it, or `experimental` if it only partly works. A maintainer sets `verified` once a second person confirms it, or after a week of daily use.
4. Open a pull request. Don't touch the table in `README.md`: it rewrites itself from your file after the merge.

Tried and failed? That's useful too. [Open an issue](../../issues/new?template=add-device.yml) and tell us where it got stuck.

## Improve a prompt

The prompts in `prompts/` are the product, so changes get a careful review.

- Keep the ground rules: one step at a time, ask before changing anything, local network only, a random token, and a fixed list of actions on the computer. `npm run check` fails if one goes missing.
- Add what you learned on a real device, and link the issue where it happened if there is one. A recipe should only grow from things that went wrong for someone.
- Keep the general prompt general. What only one model needs goes in that model's device file.
- Short sentences, plain English. Write `{{SITE_URL}}` and `{{REPO_URL}}` instead of full links; the site fills them in.

## How pull requests are reviewed

Reviews happen in batches, usually once or twice a day. Each pull request gets one of these answers:

- **Merged.** Thank you.
- **Merged with a small fix.** If something tiny is off (a typo, a field, a photo size), we fix it ourselves while merging, so you don't have to come back for it.
- **One request.** A single, clear change we need before merging.
- **Closed, kindly.** When an idea doesn't fit the core, we say where it fits instead, usually your own repo and a deck on the wall. It's never a judgment of the work.

Changes to the prompts' ground rules, to `.github/` or to the checks are decided by a maintainer. The whole policy is in [docs/MAINTAINING.md](docs/MAINTAINING.md).

## Run the site on your computer

You need Node 24 or newer.

```sh
npm install
npm run dev      # http://localhost:4321
npm run check    # ground rules in the prompts, nothing private, no stray dashes
npm run build    # fails if a device or a deck has a wrong field
```

## A few rules

- Change nothing outside the files your change needs.
- Only photos you took, with nothing private on screen (notifications, names, addresses).
- No tokens, IP addresses, serial numbers or personal paths in any file. `npm run check` looks for them.
- No binaries and no jailbreak files. Link to kindlemodding.org instead.
- No Elgato or Stream Deck logos, or anyone else's. Describing a product by name is fine; borrowing its branding isn't.
- Be kind and assume good intent. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
