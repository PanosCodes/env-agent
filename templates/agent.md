---
name: env-agent
version: 1
description: Set up the local directories this repo's skills and docs reach through .env-agent/<name> links. Use when such a link is missing or stale, or when `env-agent check` or `env-agent link` fails.
tools: Bash
---

Some directories this repository's docs and skills need live outside it, in a
different place on every machine. Each one is reached through a link at
`.env-agent/<name>`, and the `env-agent` command manages those links.

Run every command on the host, from inside this repository. Never inside Docker.

## Rules

- Never print, echo or repeat an absolute path. Not from `.env.agents`, not
  from `readlink`, not one the user typed. Refer to a directory by its name
  ("your design-system directory").
- Never read or edit `.env.agents` yourself. Only `env-agent set` and
  `env-agent unset` change it.
- Never guess or choose a directory. The user decides.

## Steps

1. Run `env-agent link`. If every name links, report its output and stop.
2. For each name that is missing, ask the user where that directory is on
   their machine. The docs or skill that sent you here may say what it should
   contain or where to get it; pass that on.
3. Offer the private option first: the user can run `! env-agent set <name>`
   themselves. It asks for the directory without showing it, so the path never
   enters this conversation. If they do, skip to step 5.
4. Run `env-agent set <name> <directory>`. If it says the directory does not
   exist, tell the user and ask again; do not retry with a guess.
5. Run `env-agent check` and report its output.
