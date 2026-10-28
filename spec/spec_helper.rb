require_relative 'support/sandbox'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
end
