require_relative 'env_agent/version'

# A failure the user can fix; exits with status 1.
class EnvAgent::Error < StandardError; end

# A wrong command, argument or registry; exits with status 2.
class EnvAgent::UsageError < EnvAgent::Error; end

require_relative 'env_agent/checkout'
require_relative 'env_agent/dotenv'
require_relative 'env_agent/resolver'
require_relative 'env_agent/linker'
require_relative 'env_agent/excluder'
require_relative 'env_agent/agent'
require_relative 'env_agent/cli'
