# env-agent

Gives a repo cloned elsewhere on your machine one fixed path inside your
project, `.env-agent/NAME`, the same on every machine and in every worktree.
Docs and AI agents use that link instead of hardcoding someone's home
directory. env-agent never prints the path it resolves.

Ruby 3.3+, git 2.31+, macOS or Linux. No other dependencies.

## Install

Install the gem from [RubyGems](https://rubygems.org/gems/env-agent):

```sh
gem install env-agent
env-agent install-agent      # optional: the Claude Code agent, in ~/.claude/agents/
```

## Use

```sh
env-agent set design-system  # asks where your clone is (input hidden), then links it
env-agent link               # in a new worktree: recreate the links
```

Your docs can now point at `.env-agent/design-system/...`. Run
`env-agent init` to commit the agent to a project, so Claude Code can set up
missing links by asking for the directory.

## Commands

| Command | What it does |
|---|---|
| `set NAME [DIR]` | Saves where the clone is and links it. Without DIR it asks, hiding your input |
| `link [NAME]` | Creates or refreshes `.env-agent/NAME` (every saved name if omitted) |
| `check [NAME]` | Reports where each name was found, or why not. Changes nothing |
| `unset NAME` | Forgets the location and removes the link |
| `init` | Adds the agent to the project (`.AGENT/agents/`, linked from `.claude/agents/`) |
| `install-agent` | Installs the agent in `~/.claude/agents/` |
| `help`, `version` | Usage and version |

Exit status: `0` all resolved, `1` something did not, `2` bad usage or not in a
git checkout.

## How it works

Locations live in `.env.agents` (`NAME=/path`), never in environment
variables. env-agent looks in the current worktree's `.env.agents`, then the
main checkout's (where `set` writes), and uses the first directory that
exists. Both files and `.env-agent/` are added to `.git/info/exclude`, so
nothing goes in `.gitignore`.

## Development

```sh
bundle install
bundle exec rake             # RuboCop, then the specs
```

See [AGENTS.md](AGENTS.md) for the code map and the rules every change keeps.
