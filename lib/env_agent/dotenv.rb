require 'fileutils'

# A .env.agents file: NAME=directory lines, optional quotes and # comments, no interpolation.
class EnvAgent::Dotenv
  FILE = '.env.agents'.freeze
  NAME = /[A-Za-z0-9_][A-Za-z0-9_.-]*/.freeze
  LINE = /\A\s*(?:export\s+)?(#{NAME})\s*=\s*(.*)\z/.freeze

  # @param [String] name
  #
  # @return [TrueClass, FalseClass] whether the name can be stored and used as a link name
  def self.valid_name?(name)
    name.match?(/\A#{NAME}\z/)
  end

  # @param [String] dir directory holding the .env.agents file
  def initialize(dir)
    @path = File.join(dir, FILE)
  end

  # @return [Array<String>] every name with a value
  def names
    values.reject { |_name, value| value.empty? }.keys
  end

  # @param [String] key
  #
  # @return [String, nil] the value as an absolute path, relative values resolved against the file's directory
  def [](key)
    value = values[key]
    return if value.nil? || value.empty?

    File.expand_path(value, File.dirname(path))
  end

  # @param [String] key
  # @param [String] value
  def set(key, value)
    replaced = false
    kept = lines.each_with_object([]) do |line, out|
      next out << line unless key_of(line) == key
      next if replaced

      out << "#{key}=#{quote(value)}"
      replaced = true
    end
    kept << "#{key}=#{quote(value)}" unless replaced
    write(kept)
  end

  # @param [String] key
  #
  # @return [TrueClass, FalseClass] whether the key was present
  def delete(key)
    kept = lines.reject { |line| key_of(line) == key }
    return false if kept.size == lines.size

    write(kept)
    true
  end

  private

  attr_reader :path

  # @return [Array<String>]
  def lines
    File.exist?(path) ? File.read(path).split(/\r?\n/) : []
  end

  # @return [Hash{String => String}]
  def values
    lines.each_with_object({}) do |line, out|
      match = LINE.match(line)
      out[match[1]] = unquote(match[2]) if match
    end
  end

  # @param [String] line
  #
  # @return [String, nil]
  def key_of(line)
    match = LINE.match(line)
    match && match[1]
  end

  # @param [String] raw
  #
  # @return [String]
  def unquote(raw)
    raw[/\A"([^"]*)"\s*(?:#.*)?\z/, 1] || raw[/\A'([^']*)'\s*(?:#.*)?\z/, 1] || raw.sub(/\s+#.*\z/, '').strip
  end

  # @param [String] value
  #
  # @raise [EnvAgent::Error] when the value cannot be stored safely
  #
  # @return [String]
  def quote(value)
    raise EnvAgent::Error, 'a directory name with a line break cannot be stored' if value.match?(/[\r\n]/)
    return value unless value.match?(/[\s#'"]/)
    return "\"#{value}\"" unless value.include?('"')
    return "'#{value}'" unless value.include?("'")

    raise EnvAgent::Error, 'a directory name with both kinds of quotes cannot be stored'
  end

  # @param [Array<String>] new_lines
  def write(new_lines)
    FileUtils.mkdir_p(File.dirname(path))
    tmp = "#{path}.tmp-#{Process.pid}"
    File.write(tmp, new_lines.empty? ? '' : "#{new_lines.join("\n")}\n")
    File.rename(tmp, path)
  end
end
