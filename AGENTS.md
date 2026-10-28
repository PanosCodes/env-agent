# Working on env-agent

env-agent is a Ruby gem with one executable, `exe/env-agent`. It links repos
cloned outside a git checkout to `.env-agent/NAME` inside it, from any
worktree. The [README](README.md) describes the behaviour users rely on; read
it before changing what a command does.

## Checking your work

```sh
bundle install
bundle exec rake        # RuboCop, then the specs
```

`bundle exec rake` is the only check, and CI runs the same command on Linux and
macOS with Ruby 3.3, 3.4 and 4.0. A change is done when it passes.

## Rules every change must keep

- **Never print a resolved path.** Not in normal output, errors or
  exception messages. Name the source ("main checkout .env.agents") and the
  outcome ("ok", "not set") instead. Unexpected exceptions are reported by
  class only (see `EnvAgent::CLI#run`). Every new command or failure branch gets
  the `prints no path` shared example in its spec.
- **Never read environment variables to find a directory.** Only
  `.env.agents` decides where a link points.
- **Never prompt, except `set` without DIR**, and that prompt hides the input.
  The command must run unattended in scripts and agent sessions.
- **No runtime dependencies.** Only the Ruby standard library and the `git`
  executable (2.31+). Development gems go in the `Gemfile`.
- **Ruby 3.3 or newer**, matching `required_ruby_version` in the gemspec.
- **Exit statuses:** `0` everything resolved, `1` something did not
  (`EnvAgent::Error`), `2` wrong command, argument or name, or not in a git
  checkout (`EnvAgent::UsageError`).

## Code map

| File | Responsibility |
|---|---|
| `exe/env-agent` | Entry point; calls `EnvAgent::CLI.start` |
| `lib/env_agent/cli.rb` | Commands, output and exit statuses |
| `lib/env_agent/checkout.rb` | The current worktree and the main checkout behind it |
| `lib/env_agent/dotenv.rb` | Reading and writing `.env.agents` |
| `lib/env_agent/resolver.rb` | The lookup order |
| `lib/env_agent/linker.rb` | The `.env-agent/NAME` symlinks |
| `lib/env_agent/excluder.rb` | The `.git/info/exclude` entries |
| `lib/env_agent/agent.rb` | Writing the agent copies and comparing versions |
| `templates/agent.md` | The agent template; bump its `version` when its instructions change |
| `lib/rubocop/cop/` | House RuboCop cops; development only, not shipped in the gem |
| `bin/release` | Releases a version to GitHub; development only, not shipped in the gem |
| `spec/env_agent/cli_spec.rb` | Specs for every command |
| `spec/support/sandbox.rb` | Throwaway main checkout, worktree and HOME for the specs |

## Adding or changing a command

1. Add the branch in `EnvAgent::CLI#dispatch` and a private method for it in
   `lib/env_agent/cli.rb`.
2. Add it to `USAGE` in the same file.
3. Add it to the Commands table in the README.
4. Add a `describe` block in `spec/env_agent/cli_spec.rb`.

## Writing specs

- Specs run the real executable as a separate process through `Sandbox#run`,
  against real git repositories and worktrees in a temporary directory. Do not
  stub git or the file system.
- Assert on `stdout`, `stderr`, `exitstatus` and the files left on disk.
- `Sandbox#run` clears the environment and sets its own `HOME`, so a spec
  never touches your real `~/.claude` or git config.

## Style

- RuboCop enforces the style, including the custom cops in
  `lib/rubocop/cop/`. Run `bundle exec rubocop -a` for safe fixes.
- Single quotes, no `frozen_string_literal` comment, compact class names
  (`class EnvAgent::Linker`).
- Comments are YARD only: a one-line description of each class and `@param` /
  `@return` tags on methods.
- The house cops in `lib/rubocop/cop/` are typed with `sorbet-runtime`:
  `extend T::Sig` and a `sig` on every method, instead of `@param` / `@return`
  tags. Keep sorbet out of `lib/env_agent/`; the gem has no runtime
  dependencies.

## Releasing

`bin/release VERSION` bumps `EnvAgent::VERSION` and `Gemfile.lock`, runs
`bundle exec rake`, builds the gem, commits `build: release vVERSION`, tags and
pushes `master`, and creates a GitHub release with the `.gem` attached. Nothing
goes to RubyGems. It refuses a dirty tree, another branch, a `master` behind or
diverged from its remote, and an existing tag.

## Commits

Commit messages use a conventional prefix: `fix:`, `feat:`, `docs:`, `test:`,
`ci:`, `build:`, `refactor:`. Keep each commit to one change, with its specs
and docs in the same commit.
