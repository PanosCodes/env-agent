require 'fileutils'

# The env-agent Claude Code agent: one bundled template, written into a repo and into the user's config.
class EnvAgent::Agent
  TEMPLATE = File.expand_path('../../templates/agent.md', __dir__)
  REPO_COPY = '.AGENT/agents/env-agent.md'.freeze
  CLAUDE_COPY = '.claude/agents/env-agent.md'.freeze
  CLAUDE_LINK_TARGET = '../../.AGENT/agents/env-agent.md'.freeze

  # @return [String]
  def self.template
    File.read(TEMPLATE)
  end

  # @return [Integer]
  def self.template_version
    version_of(template)
  end

  # @param [String] text agent markdown
  #
  # @return [Integer, nil] the frontmatter version
  def self.version_of(text)
    version = text[/^version:\s*(\d+)\s*$/, 1]
    version&.to_i
  end

  # @param [String] root checkout root
  #
  # @return [Array<String>] what changed, in repo-relative terms
  def write_repo!(root)
    actions = []
    actions << "wrote #{REPO_COPY}" if write_if_changed(File.join(root, REPO_COPY))
    actions << "linked #{CLAUDE_COPY} -> #{REPO_COPY}" if link_claude_copy(File.join(root, CLAUDE_COPY))
    actions
  end

  # @param [String] home the user's home directory
  #
  # @return [TrueClass, FalseClass] whether the copy changed
  def write_user!(home)
    write_if_changed(File.join(home, CLAUDE_COPY))
  end

  # @param [String] root checkout root
  #
  # @return [Integer, nil] version of the repo's committed copy, nil when it has none
  def repo_version(root)
    copy = [REPO_COPY, CLAUDE_COPY].map { |relative| File.join(root, relative) }.find { |path| File.file?(path) }
    copy && self.class.version_of(File.read(copy))
  end

  private

  # @param [String] path
  #
  # @return [TrueClass, FalseClass]
  def write_if_changed(path)
    return false if File.file?(path) && File.read(path) == self.class.template

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, self.class.template)
    true
  end

  # @param [String] link
  #
  # @return [TrueClass, FalseClass] whether the link changed
  def link_claude_copy(link)
    return false if File.symlink?(link) && File.readlink(link) == CLAUDE_LINK_TARGET

    clear(link)
    FileUtils.mkdir_p(File.dirname(link))
    File.symlink(CLAUDE_LINK_TARGET, link)
    true
  end

  # @param [String] link
  #
  # @raise [EnvAgent::Error] when an unrelated file is in the way
  def clear(link)
    return File.unlink(link) if File.symlink?(link)
    return unless File.exist?(link)
    raise EnvAgent::Error, "#{CLAUDE_COPY} exists and is not the env-agent agent; leaving it" unless agent_file?(link)

    File.unlink(link)
  end

  # @param [String] path
  #
  # @return [TrueClass, FalseClass]
  def agent_file?(path)
    File.read(path).match?(/^name:\s*env-agent\s*$/)
  end
end
