require_relative 'spec_dsl'

# Forbids matchers that check a class (`be_a`, `be_an_instance_of`, ...). Test behaviour and values instead.
#
# @example
#   # bad
#   expect(result).to be_a(Hash)
#
#   # good
#   expect(result).to eq(expected_hash)
class RuboCop::Cop::Spec::TypeMatcher < RuboCop::Cop::Base
  extend T::Sig

  MSG = 'Do not check the class of a value; assert on its behaviour or contents.'
  RESTRICT_ON_SEND = %i[
    be_a be_an be_a_kind_of be_kind_of be_an_instance_of be_instance_of an_instance_of a_kind_of
  ].freeze

  sig { params(node: RuboCop::AST::SendNode).void }
  def on_send(node)
    add_offense(node) if node.receiver.nil?
  end
end
