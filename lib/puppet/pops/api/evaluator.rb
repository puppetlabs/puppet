module Puppet; module Pops; end; end;

module Puppet::Pops::API
  # An evaluator evaluates a given object in the given Puppet::Pops::API::Scope scope.
  # @abstract
  #
  class Evaluator
    # Evaluates the given object o in the given scope, optionally passing a block which will be
    # called with the result of the evaluation.
    # @abstract
    # @param o [Object] the object to evaluate
    # @param scope [Puppet::Pops::API::Scope] to scope to evaluate in
    # @yieldparam r {Object] the result of the evaluation
    # @return [Object] the result of the evaluation, or the result of evaluating the optional block
    def evaluate(o, scope, &block)
      raise Puppet::Pops::API::APINotImplementedError.new
    end
  end
end
