# Security

The prompts here tell an AI agent to run a small server on your computer that performs actions when a screen on your network asks for them. That deserves care.

The design every prompt must keep:

- The server only listens on the local network and needs a random token.
- It only runs actions from a fixed list in a config file. The screen sends a button id or coordinates, never a command.
- The agent asks before installing anything, opening a firewall port or creating a background service, and never changes privacy or security settings on its own.

If you find a way around any of this (a prompt that leads to running arbitrary commands, to exposing the server beyond the local network, or to leaking the token), please don't open a public issue. Use GitHub's private vulnerability reporting on this repo, or write to the address in the website footer. We'll answer within a few days and credit you if you want.
