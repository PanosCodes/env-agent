require 'fileutils'
require 'open3'
require 'rbconfig'
require 'yaml'

# A throwaway main checkout, linked worktree, sibling clones and HOME, with the CLI run as a real process.
class Sandbox
  EXE = File.expand_path('../../exe/env-agent', __dir__)

  Result = Struct.new(:stdout, :stderr, :status) do
    # @return [String]
    def output
      stdout + stderr
    end

    # @return [Integer]
    def exitstatus
      status.exitstatus
    end
  end

  attr_reader :root

  # @param [String] root an empty temporary directory
  def initialize(root)
    @root = root
  end

  # @return [String]
  def main
    File.join(root, 'main')
  end

  # @return [String]
  def worktree
    File.join(root, 'worktree')
  end

  # @return [String]
  def home
    File.join(root, 'home')
  end

  # @param [String] name
  #
  # @return [String] where the sibling default looks for a clone
  def sibling(name)
    File.join(root, name)
  end

  # @param [Hash, nil] registry contents of .env-agent.yml, nil to leave it out
  def build_main!(registry)
    FileUtils.mkdir_p([main, home])
    git(main, '-c', 'init.defaultBranch=main', 'init', '-q')
    File.write(File.join(main, '.env-agent.yml'), registry.to_yaml) if registry
    File.write(File.join(main, 'README'), "sandbox\n")
    git(main, 'add', '.')
    git(main, '-c', 'user.name=env-agent', '-c', 'user.email=env-agent@example.com', 'commit', '-q', '-m', 'init')
  end

  def add_worktree!
    git(main, 'worktree', 'add', '-q', '-b', 'wt', worktree)
  end

  # @param [String] dir
  # @param [String] marker
  def clone!(dir, marker)
    FileUtils.mkdir_p(File.dirname(File.join(dir, marker)))
    File.write(File.join(dir, marker), "marker\n")
  end

  # @param [Array<String>] args
  # @param [String] cwd
  # @param [String] stdin
  # @param [Hash{String => String}] env
  #
  # @return [Sandbox::Result]
  def run(*args, cwd: main, stdin: '', env: {})
    out, err, status = Open3.capture3(base_env.merge(env), RbConfig.ruby, EXE, *args,
                                      chdir: cwd, stdin_data: stdin, unsetenv_others: true)
    Result.new(out, err, status)
  end

  # @param [String] checkout
  #
  # @return [String]
  def exclude_file(checkout = main)
    File.join(checkout, '.git', 'info', 'exclude')
  end

  private

  # @return [Hash{String => String}]
  def base_env
    { 'PATH' => ENV.fetch('PATH'), 'HOME' => home, 'GIT_CONFIG_NOSYSTEM' => '1' }
  end

  # @param [String] dir
  # @param [Array<String>] args
  def git(dir, *args)
    _out, err, status = Open3.capture3({ 'HOME' => home, 'GIT_CONFIG_NOSYSTEM' => '1' }, 'git', *args, chdir: dir)
    raise "git #{args.join(' ')} failed: #{err}" unless status.success?
  end
end
