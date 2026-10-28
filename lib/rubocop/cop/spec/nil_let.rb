require_relative 'spec_dsl'

# Writes an empty `let` as `let(:x) { }`, not `let(:x) { nil }`.
#
# @example
#   # bad
#   let(:token) { nil }
#
#   # good
#   let(:token) { }
class RuboCop::Cop::Spec::NilLet < RuboCop::Cop::Base
  extend T::Sig
  extend RuboCop::Cop::AutoCorrector

  MSG = 'Leave the `let` body empty instead of `nil`.'

  sig { params(node: RuboCop::AST::BlockNode).void }
  def on_block(node)
    return unless %i[let let!].include?(node.send_node.method_name) && node.send_node.receiver.nil?
    return unless node.braces? && node.body&.nil_type?

    add_offense(node.body) do |corrector|
      corrector.replace(node.loc.expression, "#{node.send_node.source} { }")
    end
  end
end
