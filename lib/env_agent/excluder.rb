require 'fileutils'

# Keeps env-agent's own files untracked through the shared info/exclude, so no repo edits .gitignore.
class EnvAgent::Excluder
  PATTERNS = ["/#{EnvAgent::Dotenv::FILE}", "/#{EnvAgent::Linker::DIR}/"].freeze

  # @param [String] common_dir the git directory shared by every worktree
  def initialize(common_dir)
    @path = File.join(common_dir, 'info', 'exclude')
  end

  def apply!
    content = File.exist?(path) ? File.read(path) : ''
    missing = PATTERNS - content.split(/\r?\n/)
    return if missing.empty?

    content += "\n" unless content.empty? || content.end_with?("\n")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{content}#{missing.join("\n")}\n")
  end

  private

  attr_reader :path
end
