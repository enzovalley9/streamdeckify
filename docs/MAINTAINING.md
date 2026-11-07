# Maintaining

How pull requests and issues are handled here. Written for maintainers and public on purpose, so contributors know what to expect.

## The policy: a small core and a well-indexed wall

The core is the prompts, the device files and the website. Bigger things (new clients, apps, hardware builds, forks) live in their authors' repos and get a deck on the wall with a link. That keeps the core small enough to review and still gives every idea a home.

## Verdicts

| Verdict | When | What to do |
| --- | --- | --- |
| merge | It's right as it is | Merge and thank them for one specific thing. |
| merge with a fix | Something small and mechanical is off | Push the fix on top ("PR #12 follow-up: photo under 1 MB"), then merge. Nobody should iterate over a typo. |
| one request | One thing has to change | Ask for exactly one clear change. |
| wall | It's a project of its own | Thank them and suggest their own repo plus a deck with `link:`. |
| close | It doesn't fit and has no other home | Close kindly, say why in one line, point to what did get in. |
| hold | It touches the prompts' ground rules, `.github/`, `scripts/check.mjs` or security | A maintainer decides, whoever reviews first. |

Comments are short, human and thankful. Name one specific thing that is good about the pull request. Never paste a review from a tool without reading it and agreeing with it.

## Rounds

Review in batches at fixed times (for example 09:00 and 21:00, Madrid time), not one by one as they arrive. Go from the easiest to the hardest: decks, then devices, then prompts, then the website. After each round, write down any decision that will come up again under "Learned from rounds", with the pull request numbers.

## Device status

- `experimental`: someone got part of it working.
- `works`: one person uses it.
- `verified`: a second person confirmed it, or the first one used it every day for a week. Only maintainers set it.

## Numbers

Never type a count or a measurement in prose. The website reads the device files, and `scripts/readme.mjs` rewrites the table in `README.md` after every push to main that touches a device. If a number needs to appear somewhere new, generate it there too.

## Labels

The labeler adds `device`, `wall`, `prompt`, `site` and `needs-maintainer` by path. Issues arrive with `device`, `wall` or `help` from their forms.

## Press

When articles and videos appear, list them in `docs/PRESS.md` by country, with the date, and only if the link opens and says what we claim. Include the critical ones too. Ask writers to open an issue with their link.

## When it gets busy

If pull requests outgrow the rounds (a few hundred open at once), add an automated reviewer that only suggests and never merges, fed with these verdicts and with past decisions. Until then, the forms, the checks and the labeler do the filtering.

## Learned from rounds

Nothing yet.
