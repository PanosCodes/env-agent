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

  private

  attr_reader :dir

  # @param [Array<String>] args
  #
  # @return [String]
  def git(*args)
    out, status = Open3.capture2('git', *args, chdir: dir, err: File::NULL)
    raise EnvAgent::UsageError, 'not inside a git checkout' unless status.success?

    out.strip
  end
end
