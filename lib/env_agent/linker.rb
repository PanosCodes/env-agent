require 'fileutils'

# The .env-agent/NAME symlink inside a checkout.
class EnvAgent::Linker
  DIR = '.env-agent'.freeze

  # @param [EnvAgent::Checkout] checkout the checkout the link lives in
  # @param [String] name registry name
  def initialize(checkout, name)
    @checkout = checkout
    @name = name
  end

  # @return [String] the link as consumers reference it
  def relative_path
    "#{DIR}/#{name}"
  end

  # @param [String] target directory the link should point at
  #
  # @raise [EnvAgent::Error] when something other than a link is in the way, or .env-agent is a link
  def link!(target)
    remove!
    raise EnvAgent::Error, "#{relative_path} exists and is not a link; move it away first" if File.exist?(path)

    FileUtils.mkdir_p(own_dir!)
    File.symlink(target, path)
  end

  # @raise [EnvAgent::Error] when .env-agent is a link
  def remove!
    own_dir!
    File.unlink(path) if File.symlink?(path)
  end

  # @param [String, nil] target where the link should point, nil when nothing resolved
  #
  # @return [Symbol] :ok, :missing or :stale
  def state(target)
    return :missing unless File.symlink?(path) || File.exist?(path)
    return :stale if target.nil?

    File.realpath(path) == File.realpath(target) ? :ok : :stale
  rescue Errno::ENOENT
    :stale
  end

  private

  attr_reader :checkout, :name

  # @return [String]
  def path
    File.join(checkout.root, DIR, name)
  end

  # @raise [EnvAgent::Error] when .env-agent is a link
  #
  # @return [String]
  def own_dir!
    checkout.own_path!(DIR)
  end
end
