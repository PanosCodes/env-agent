require 'rubocop'
require 'sorbet-runtime'

module RuboCop::Cop::Spec; end

# The RSpec vocabulary the Spec cops share.
module RuboCop::Cop::Spec::SpecDsl
  extend T::Sig

  EXAMPLES = %i[it specify example scenario its].freeze

  sig { params(node: RuboCop::AST::Node).returns(T::Boolean) }
  def example_block?(node)
    node.block_type? && node.send_node.receiver.nil? && EXAMPLES.include?(node.send_node.method_name)
  end
end
