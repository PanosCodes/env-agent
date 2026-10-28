require_relative 'spec_dsl'

# A `context` that holds one example and no setup of its own adds nothing: fold the condition into the example's
# description. A context earns its place by sharing setup between examples or overriding a `let`.
#
# @example
#   # bad
#   context 'when a level is given' do
#     it 'writes on that key' do
#       expect(run).to eq(1)
#     end
#   end
#
#   # good
#   it 'writes on the given key' do
#     expect(run).to eq(1)
#   end
class RuboCop::Cop::Spec::SingleExampleContext < RuboCop::Cop::Base
  extend T::Sig

  include RuboCop::Cop::Spec::SpecDsl

  MSG = 'A context with one example and no setup of its own: fold the condition into the example description.'

  sig { params(node: RuboCop::AST::BlockNode).void }
  def on_block(node)
    return unless node.send_node.receiver.nil? && node.send_node.method?(:context)

    statements = statements_of(node.body)
    return unless statements.one? && example_block?(statements.first)

    add_offense(node.send_node)
  end

  private

  sig { params(body: T.nilable(RuboCop::AST::Node)).returns(T::Array[RuboCop::AST::Node]) }
  def statements_of(body)
    return [] if body.nil?

    body.begin_type? ? body.children : [ body ]
  end
end
