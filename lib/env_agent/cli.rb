require 'io/console'

# Command-line entry point: runs one command and maps failures to exit statuses. Never prints a saved path.
class EnvAgent::CLI
  USAGE = <<~TEXT.freeze
    Usage: env-agent <command> [arguments]

      set NAME [DIR]   Save DIR as NAME and link it at .env-agent/NAME; asks for DIR, hidden, when omitted
      link [NAME]      Recreate .env-agent/NAME (every saved name when NAME is omitted)
      check [NAME]     Show where each name resolves from, changing nothing
      unset NAME       Forget NAME and remove its link
      init             Add the env-agent agent to this repo
      install-agent    Install the env-agent agent for your user (~/.claude/agents)
      help             Show this message
      version          Show the version

    env-agent never prints a saved path. See the README for details.
  TEXT

  LINK_STATES = {
    ok: 'ok',
    missing: 'missing (run `env-agent link`)',
    stale: 'stale (run `env-agent link`)'
  }.freeze

  # @param [Array<String>] argv
  # @param [IO] stdin
  # @param [IO] stdout
  # @param [IO] stderr
  #
  # @return [Integer] exit status
  def self.start(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
    new(stdin: stdin, stdout: stdout, stderr: stderr).run(argv)
  end

  # @param [IO] stdin
  # @param [IO] stdout
  # @param [IO] stderr
  def initialize(stdin:, stdout:, stderr:)
    @stdin = stdin
    @stdout = stdout
    @stderr = stderr
  end

  # @param [Array<String>] argv
  #
  # @return [Integer] exit status
  def run(argv)
    command, *args = argv
    dispatch(command, args)
  rescue EnvAgent::UsageError => e
    stderr.puts("env-agent: #{e.message}")
    stderr.puts('Run `env-agent help` for usage.')
    2
  rescue EnvAgent::Error => e
    stderr.puts("env-agent: #{e.message}")
    1
  rescue SystemCallError => e
    stderr.puts("env-agent: #{SystemCallError.new(e.errno).message}")
    1
  rescue StandardError => e
    stderr.puts("env-agent: unexpected #{e.class}; details withheld so no path is printed")
    1
  end

  private

  attr_reader :stdin, :stdout, :stderr

  # @param [String, nil] command
  # @param [Array<String>] args
  #
  # @return [Integer]
  def dispatch(command, args)
    case command
    when 'set' then set(*arity!(args, 1, 2))
    when 'link' then link(arity!(args, 0, 1).first)
    when 'check' then check(arity!(args, 0, 1).first)
    when 'unset' then unset(arity!(args, 1, 1).first)
    when 'init' then init(arity!(args, 0, 0))
    when 'install-agent' then install_agent(arity!(args, 0, 0))
    when nil, 'help', '-h', '--help' then say(USAGE)
    when 'version', '-v', '--version' then say(EnvAgent::VERSION)
    else raise EnvAgent::UsageError, "unknown command '#{command}'"
    end
  end

  # @param [String] name
  # @param [String, nil] dir
  #
  # @return [Integer]
  def set(name, dir = nil)
    validate_name!(name)
    path = EnvAgent::Dotenv.absolute(dir || ask_for_dir(name))
    raise EnvAgent::Error, "#{name}: that directory does not exist. Nothing saved." unless File.directory?(path)

    excluder.apply!
    EnvAgent::Dotenv.new(checkout.main_root).set(name, path)
    winner = resolver(name).resolve
    linker(name).link!(winner.path)
    stdout.puts("#{name}: set, linked (#{winner.label})")
    stdout.puts("  note: this worktree's #{EnvAgent::Dotenv::FILE} overrides it here") if winner.source == :worktree
    0
  end

  # @param [String, nil] name
  #
  # @return [Integer]
  def link(name)
    excluder.apply!
    linked = names(name).map { |each_name| link_name(each_name) }
    linked.all? ? 0 : 1
  end

  # @param [String, nil] name
  #
  # @return [Integer]
  def check(name)
    resolved = names(name).map { |each_name| check_name(each_name) }
    warn_outdated_agent
    resolved.all? ? 0 : 1
  end

  # @param [String] name
  #
  # @return [Integer]
  def unset(name)
    validate_name!(name)
    removed = EnvAgent::Dotenv.new(checkout.main_root).delete(name)
    linker(name).remove!
    say("#{name}: #{removed ? 'unset' : 'was not set'}, link removed")
  end

  # @return [Integer]
  def init(_args)
    excluder.apply!
    actions = agent.write_repo!(checkout.root)
    say(actions.empty? ? 'already up to date' : actions)
  end

  # @return [Integer]
  def install_agent(_args)
    changed = agent.write_user!(Dir.home)
    say(changed ? "installed ~/#{EnvAgent::Agent::CLAUDE_COPY}" : 'already up to date')
  end

  # @param [String] name
  #
  # @return [TrueClass, FalseClass] whether it resolved
  def link_name(name)
    winner = resolver(name).resolve
    return not_found(name) unless winner

    linker(name).link!(winner.path)
    stdout.puts("#{name}: linked (#{winner.label})")
    true
  end

  # @param [String] name
  #
  # @return [FalseClass]
  def not_found(name)
    linker(name).remove!
    stderr.puts("#{name}: not linked (#{summary(name)}).")
    stderr.puts(not_found_hint(name))
    false
  end

  # @param [String] name
  #
  # @return [TrueClass, FalseClass] whether it resolved
  def check_name(name)
    winner = resolver(name).resolve
    stdout.puts("#{name}: #{winner ? "ok (#{winner.label})" : 'not found'}")
    resolver(name).candidates.each { |candidate| stdout.puts("  #{candidate.label}: #{candidate.outcome_text}") }
    stdout.puts("  link #{linker(name).relative_path}: #{LINK_STATES.fetch(linker(name).state(winner&.path))}")
    stdout.puts(not_found_hint(name)) unless winner
    !winner.nil?
  end

  # @param [String] name
  #
  # @return [String]
  def summary(name)
    resolver(name).candidates.map { |candidate| "#{candidate.label}: #{candidate.outcome_text}" }.join(', ')
  end

  # @param [String] name
  #
  # @return [String]
  def not_found_hint(name)
    "  Run `env-agent set #{name}` (it asks for the directory), or ask the env-agent agent to set it up."
  end

  # @param [String] name
  #
  # @raise [EnvAgent::UsageError] when nothing was typed
  #
  # @return [String]
  def ask_for_dir(name)
    stderr.print("Directory for #{name} (input hidden): ")
    line = stdin.tty? ? stdin.noecho(&:gets) : stdin.gets
    stderr.puts
    dir = line.to_s.strip
    raise EnvAgent::UsageError, 'no directory given' if dir.empty?

    dir
  end

  def warn_outdated_agent
    version = agent.repo_version(checkout.root)
    latest = EnvAgent::Agent.template_version
    return unless version && version < latest

    stderr.puts("warning: this repo's env-agent agent is version #{version}; this CLI ships version #{latest}. " \
                'Run `env-agent init` to refresh it.')
  end

  # @param [String, nil] name
  #
  # @return [Array<String>] the given name, or every name saved in either .env.agents
  def names(name)
    return [validate_name!(name)] if name

    list = (worktree_dotenv_names + EnvAgent::Dotenv.new(checkout.main_root).names).uniq.sort
    stdout.puts("nothing set in #{EnvAgent::Dotenv::FILE} (use `env-agent set NAME DIR`)") if list.empty?
    list
  end

  # @return [Array<String>]
  def worktree_dotenv_names
    checkout.main? ? [] : EnvAgent::Dotenv.new(checkout.root).names
  end

  # @param [String] name
  #
  # @raise [EnvAgent::UsageError] when the name cannot be stored or linked
  #
  # @return [String]
  def validate_name!(name)
    return name if EnvAgent::Dotenv.valid_name?(name)

    raise EnvAgent::UsageError, "'#{name}' is not a valid name (letters, digits, '_', '.' and '-')"
  end

  # @param [Array<String>] args
  # @param [Integer] min
  # @param [Integer] max
  #
  # @raise [EnvAgent::UsageError] when the count is outside min..max
  #
  # @return [Array<String>]
  def arity!(args, min, max)
    raise EnvAgent::UsageError, 'wrong number of arguments' unless (min..max).cover?(args.size)

    args
  end

  # @param [String, Array<String>] text
  #
  # @return [Integer]
  def say(text)
    stdout.puts(text)
    0
  end

  # @return [EnvAgent::Checkout]
  def checkout
    @checkout ||= EnvAgent::Checkout.new
  end

  # @return [EnvAgent::Excluder]
  def excluder
    @excluder ||= EnvAgent::Excluder.new(checkout.common_dir)
  end

  # @return [EnvAgent::Agent]
  def agent
    @agent ||= EnvAgent::Agent.new
  end

  # @param [String] name
  #
  # @return [EnvAgent::Resolver]
  def resolver(name)
    @resolvers ||= {}
    @resolvers[name] ||= EnvAgent::Resolver.new(name, checkout)
  end

  # @param [String] name
  #
  # @return [EnvAgent::Linker]
  def linker(name)
    EnvAgent::Linker.new(checkout.root, name)
  end
end
