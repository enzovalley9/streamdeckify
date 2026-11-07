# Contributing

Thanks for helping. Everything on the website comes from this repo, and every merged pull request goes live by itself a minute later.

There are three ways to help, from the quickest to the most useful.

## Show your deck

1. Fork the repo and add two files to `src/content/decks/`: your photo (`yourname-device.jpg`, jpg, png or webp, under 1 MB) and a Markdown file with the same name. Start from [docs/templates/deck.md](docs/templates/deck.md).
2. Open a pull request. CI checks every field and tells you if something is off.

Don't feel like dealing with Git? [Open an issue with your photo](../../issues/new?template=share-deck.yml) and we'll put it up for you.

## Add a device

1. Copy [docs/templates/device.md](docs/templates/device.md) to `src/content/devices/<brand-model>.md` (lowercase, words joined with dashes, like `kobo-clara-hd.md`).
2. Fill it in with what you measured: firmware, method, screen, input, speed and the gotchas that cost you time. Facts beat adjectives.
3. Set the status to `works` if you use it, or `experimental` if it only partly works. A maintainer sets `verified` once a second person confirms it, or after a week of daily use.
4. Open a pull request.

Tried and failed? That's useful too. [Open an issue](../../issues/new?template=add-device.yml) and tell us where it got stuck.

## Improve a prompt

The prompts in `prompts/` are the product, so changes get a careful review.

- Keep the ground rules: one step at a time, ask before changing anything, local network only, and a fixed list of actions on the computer.
- Add what you learned on a real device, and say in the pull request which device and agent you tested with.
- Short sentences, plain English. Write `{{SITE_URL}}` and `{{REPO_URL}}` instead of full links; the site fills them in.

## Run the site on your computer

You need Node 24 or newer.

```sh
npm install
npm run dev      # http://localhost:4321
npm run build    # what CI runs: it fails if a device or a deck has a wrong field
```

## A few rules

- Only photos you took, with nothing private on screen (notifications, names, addresses).
- No Elgato or Stream Deck logos, or anyone else's. Describing a product by name is fine; borrowing its branding isn't.
- Be kind and assume good intent. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
