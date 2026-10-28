require 'open3'

# The git checkout env-agent runs in: the current worktree and the main checkout behind it.
class EnvAgent::Checkout
  # @param [String] dir any directory inside the checkout
  def initialize(dir = Dir.pwd)
    @dir = dir
  end

  # @return [String] root of the current worktree, or of the main checkout when run there
  def root
    @root ||= File.realpath(git('rev-parse', '--show-toplevel'))
  end

  # @return [String] the git directory shared by the main checkout and every worktree
  def common_dir
    @common_dir ||= File.realpath(git('rev-parse', '--path-format=absolute', '--git-common-dir'))
  end

  # @return [String] root of the main checkout
  def main_root
    @main_root ||= File.dirname(common_dir)
  end

  # @return [TrueClass, FalseClass] whether the current checkout is the main one
  def main?
    root == main_root
  end

  # @raise [EnvAgent::Error] when git tracks the file
  #
  # @return [EnvAgent::Dotenv] the main checkout's .env.agents
  def main_dotenv
    @main_dotenv ||= untracked_dotenv(main_root, 'the main checkout')
  end

  # @raise [EnvAgent::Error] when git tracks the file
  #
  # @return [EnvAgent::Dotenv] this worktree's .env.agents
  def worktree_dotenv
    @worktree_dotenv ||= untracked_dotenv(root, 'this worktree')
  end

  private

  attr_reader :dir

  # @param [String] checkout_root
  # @param [String] where
  #
  # @raise [EnvAgent::Error] when git tracks the file
  #
  # @return [EnvAgent::Dotenv]
  def untracked_dotenv(checkout_root, where)
    file = EnvAgent::Dotenv::FILE

    if tracked?(checkout_root, file)
      raise EnvAgent::Error, "#{file} is committed in #{where}, so env-agent will not use it. " \
                             "Keep it on this machine only: git rm --cached #{file}"
    end

    EnvAgent::Dotenv.new(checkout_root)
  end

  # @param [String] checkout_root
  # @param [String] relative
  #
  # @return [TrueClass, FalseClass] false also when checkout_root is not a checkout
  def tracked?(checkout_root, relative)
    out, status = capture(checkout_root, 'ls-files', '-z', '--', relative)
    status.success? && !out.empty?
  end

  # @param [Array<String>] args
  #
  # @return [String]
  def git(*args)
    out, status = capture(dir, *args)
    raise EnvAgent::UsageError, 'not inside a git checkout' unless status.success?

    out.strip
  end

  # @param [String] chdir
  # @param [Array<String>] args
  #
  # @return [Array(String, Process::Status)]
  def capture(chdir, *args)
    Open3.capture2('git', *args, chdir: chdir, err: File::NULL)
  end
end
