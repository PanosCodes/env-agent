require_relative 'spec_dsl'

# Forbids `send` and instance-variable reflection in specs. Test through the public interface.
#
# @example
#   # bad
#   expect(object.send(:secret)).to eq(1)
#
#   # good
#   expect(object.public_behaviour).to eq(1)
class RuboCop::Cop::Spec::Reflection < RuboCop::Cop::Base
  extend T::Sig

  MSG = 'Test through the public interface; do not use `%<method>s`.'
  RESTRICT_ON_SEND = %i[send public_send __send__ instance_variable_get instance_variable_set].freeze

  sig { params(node: RuboCop::AST::SendNode).void }
  def on_send(node)
    return if node.receiver.nil?

    add_offense(node.loc.selector, message: format(MSG, method: node.method_name))
  end
end
