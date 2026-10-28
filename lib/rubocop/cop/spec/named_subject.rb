require_relative 'spec_dsl'

# Forbids `subject(:name)`. Keep the subject anonymous; give the value a name with `let` when it needs one.
#
# @example
#   # bad
#   subject(:result) { described_class.call }
#
#   # good
#   subject { described_class.call }
class RuboCop::Cop::Spec::NamedSubject < RuboCop::Cop::Base
  extend T::Sig

  MSG = 'Use an anonymous `subject`; name the value with `let` if it needs a name.'
  RESTRICT_ON_SEND = %i[subject subject!].freeze

  sig { params(node: RuboCop::AST::SendNode).void }
  def on_send(node)
    return unless node.receiver.nil? && node.first_argument&.sym_type?

    add_offense(node)
  end
end
