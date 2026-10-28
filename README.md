# env-agent

Your project's docs, skills and agent instructions sometimes need files from
**another repo** — a design-system demo, a vendored theme, a sibling service.
That repo is cloned somewhere on each developer's machine, but everyone puts
it somewhere different, and every git worktree is in yet another place.

env-agent gives that other repo **one fixed path inside your project**, the
same on every machine and in every worktree:

```
.env-agent/design-system/docs/index.html
```

`.env-agent/design-system` is a link to wherever *your* clone happens to be. Docs
and AI agents use the link, so nobody hardcodes `/Users/someone/Code/...`, and
nobody's home directory ends up in a transcript, a log or a commit.

It comes in two parts:

- **The `env-agent` command** finds each clone and creates the links. It never
  asks questions, never clones anything, and never prints a path.
- **The `env-agent` agent** (for Claude Code) does the parts that need a human:
  it asks where your clone is, or whether to clone it, and then runs the command.

Works on macOS and Linux, in any git repository, with any Ruby 3.3 or newer.
No other dependencies. Windows is not supported.

## Install

env-agent is not published to RubyGems yet. Install it from a clone:

```sh
git clone <this repo> env-agent
cd env-agent
gem build env-agent.gemspec
gem install ./env-agent-0.1.0.gem
```

Then, once per machine, install the agent for Claude Code:

```sh
env-agent install-agent      # writes ~/.claude/agents/env-agent.md
```

## Quick start

### Setting up a clone

From anywhere in the project (main checkout or any worktree), tell env-agent
where your clone is. It asks for the directory without showing what you type:

```sh
env-agent set design-system
```

Or give the directory directly: `env-agent set design-system ~/Code/design-system`.

The name (`design-system`) is yours to choose; it becomes the link
`.env-agent/design-system`. It may contain letters, digits, `_`, `.` and `-`.

You only do this once per machine. Every worktree of the project picks up the
same setting; a new worktree just needs `env-agent link`.

In Claude Code you can also just ask: *"use the env-agent agent to set up the
external repos"*.

### Adding the agent to a project

```sh
env-agent init
```

This creates:

| File | What it is | Commit it? |
|---|---|---|
| `.AGENT/agents/env-agent.md` | The project's copy of the agent | Yes |
| `.claude/agents/env-agent.md` | A link to the copy above, where Claude Code looks for it | Yes |

Then point your docs at the link, e.g. *"copy markup from
`.env-agent/design-system/docs/`; if the link is missing, run `env-agent link`"*.

There is no per-project config file. A project only commits the agent and
mentions the link names in its docs; the paths live on each machine.

## Commands

| Command | What it does |
|---|---|
| `env-agent set NAME [DIR]` | Saves where your clone is, then links it. Without DIR it asks, hiding your input |
| `env-agent link [NAME]` | Creates or refreshes `.env-agent/NAME` (every saved name if NAME is omitted) |
| `env-agent check [NAME]` | Shows where each name was found, or why not. Changes nothing |
| `env-agent unset NAME` | Forgets the saved location and removes the link |
| `env-agent init` | Adds the agent to the current project (see above) |
| `env-agent install-agent` | Installs the agent for your user in `~/.claude/agents/` |
| `env-agent help`, `version` | Usage and version |

Exit status: `0` everything resolved, `1` something did not, `2` a wrong
command, argument or name, or not inside a git checkout.

Example `check` output:

```
design-system: ok (main checkout .env.agents)
  main checkout .env.agents: ok
  link .env-agent/design-system: ok
```

In a linked worktree, `check` also lists `worktree .env.agents` first.

## How a directory is found

For each name, env-agent tries these places in order and uses the first one
whose directory exists:

1. **This worktree's `.env.agents`**: only when you are in a linked worktree.
   Lets one worktree use a different clone.
2. **The main checkout's `.env.agents`**: where `env-agent set` saves things.
   Found from any worktree, which is why one setting covers all of them.

If neither has a directory that exists, the name is reported as not found and
its link is removed. A saved location that no longer exists is skipped, not
trusted.

`.env.agents` is a plain `NAME=value` file:

```sh
design-system=/Users/you/Code/design-system
```

Use `env-agent set` / `unset` rather than editing it by hand; `set` checks the
directory before saving it. Values with spaces or quotes are quoted for you.

Environment variables are deliberately **not** read. A `design-system`
variable exported in your shell never changes where a link points; only
`.env.agents` does.

## Keeping paths private

env-agent never prints a resolved path: not in `link`, `check`, `set`, or any
error. It names the *source* instead ("main checkout .env.agents") and the
outcome ("ok", "not set", "directory missing").

That keeps your home directory and folder layout out of AI agent transcripts,
CI logs, screen shares and commits. It is not a secret store: the path is in
`.env.agents` on your disk, and `ls -l .env-agent/` shows where a link points.

To keep the path out of an agent conversation entirely, run `set` yourself
without a directory. In Claude Code, type `! env-agent set design-system`; the
prompt hides your input.

## Nothing to add to `.gitignore`

The first time `set`, `link` or `init` runs in a project, env-agent adds
`/.env.agents` and `/.env-agent/` to the repository's `.git/info/exclude`. That
file is local to your machine and shared by all worktrees, so the project's
`.gitignore` never needs to change.

## The agent

The agent is a short Claude Code instruction file. It:

1. runs `env-agent link`;
2. for each name that is missing, asks where that directory is on your
   machine, and offers the private `! env-agent set` route;
3. otherwise runs `env-agent set NAME DIR` with the directory you give;
4. runs `env-agent check` and reports it.

It only runs commands; it never reads or edits `.env.agents`, never guesses a
directory and never repeats a path back to you.

There can be two copies, and both come from the same template inside the gem:

- **Project copy** (`env-agent init`): committed, so everyone who clones the
  project has it. Claude Code prefers it when present.
- **User copy** (`env-agent install-agent`): used in projects that have no
  copy of their own.

The template has a version number. When a project's copy is older than your
installed env-agent, `env-agent check` prints a warning; run `env-agent init`
to update it.

## Notes

- **Docker:** run env-agent on your machine, not inside a container. The
  external clones live on the host.
- **Git:** needs git 2.31 or newer (for `rev-parse --path-format`).

## For other tools

The lookup order and the `.env.agents` format above are the whole contract.
Any tool, in any language, can implement them and produce the same result;
this gem is one implementation.

## Development

```sh
bundle install
bundle exec rake        # RuboCop + specs
```

The specs run the CLI against throwaway repositories with real git worktrees,
and check that no output ever contains a path.

[AGENTS.md](AGENTS.md) has the code map, the rules every change must keep, and
how to add a command. It is written for AI agents and people alike.
