# Finds the directory saved for a name, trying this worktree's .env.agents, then the main checkout's.
class EnvAgent::Resolver
  LABELS = {
    worktree: 'worktree .env.agents',
    main: 'main checkout .env.agents'
  }.freeze

  OUTCOMES = {
    ok: 'ok',
    unset: 'not set',
    missing: 'directory missing'
  }.freeze

  Candidate = Struct.new(:source, :path, :outcome) do
    # @return [String]
    def label
      LABELS.fetch(source)
    end

    # @return [String]
    def outcome_text
      OUTCOMES.fetch(outcome)
    end

    # @return [String]
    def to_s
      "#{label}: #{outcome_text}"
    end
  end

  # @param [String] name
  # @param [EnvAgent::Checkout] checkout
  def initialize(name, checkout)
    @name = name
    @checkout = checkout
  end

  # @return [Array<EnvAgent::Resolver::Candidate>] every source, in lookup order
  def candidates
    @candidates ||= sources.map { |source, path| Candidate.new(source, path, outcome_of(path)) }
  end

  # @return [EnvAgent::Resolver::Candidate, nil] the first candidate whose directory exists
  def resolve
    candidates.find { |candidate| candidate.outcome == :ok }
  end

  private

  attr_reader :name, :checkout

  # @return [Array<Array(Symbol, String)>]
  def sources
    list = []
    list << [:worktree, checkout.worktree_dotenv[name]] unless checkout.main?
    list << [:main, checkout.main_dotenv[name]]
  end

  # @param [String, nil] path
  #
  # @return [Symbol]
  def outcome_of(path)
    return :unset if path.nil?

    File.directory?(path) ? :ok : :missing
  end
end
