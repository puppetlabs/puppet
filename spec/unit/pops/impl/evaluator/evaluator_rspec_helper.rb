require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'
require 'puppet/pops/impl/evaluator_impl'
require 'puppet/pops/impl/base_scope'

require 'puppet/pops/impl/top_scope'
require File.join(File.dirname(__FILE__), '/../factory_rspec_helper')

module EvaluatorRspecHelper
  include FactoryRspecHelper

  # Evaluate a Factory wrapper round a model object in top scope + named scope
  # Optionally pass two or three model objects (typically blocks) to be executed
  # in top scope, named scope, and then top scope again. If a named_scope is used, it must
  # be preceded by the name of the scope.
  # The optional block is executed before the result of the last specified model object
  # is evaluated. This block gets the top scope as an argument. The intent is to pass
  # a block that asserts the state of the top scope after the operations.
  #
  def evaluate in_top_scope, scopename="x", in_named_scope = nil, in_top_scope_again = nil, &block
    top_scope = Puppet::Pops::Impl::TopScope.new
    evaluator = Puppet::Pops::Impl::EvaluatorImpl.new
    result = evaluator.evaluate(in_top_scope.current, top_scope)
    if in_named_scope
      result = evaluator.evaluate(in_named_scope.current, top_scope.named_scope(scopename))
    end
    if in_top_scope_again
      result = evaluator.evaluate(in_top_scope_again.current, top_scope)
    end
    if block_given?
      block.call(top_scope)
    end
    result
  end

  # Evaluate a Factory wrapper round a model object in top scope + local scope
  # Optionally pass two or three model objects (typically blocks) to be executed
  # in top scope, local scope, and then top scope again
  # The optional block is executed before the result of the last specified model object
  # is evaluated. This block gets the top scope as an argument. The intent is to pass
  # a block that asserts the state of the top scope after the operations.
  #
  def evaluate_l in_top_scope, in_local_scope = nil, in_top_scope_again = nil, &block
    top_scope = Puppet::Pops::Impl::TopScope.new
    evaluator = Puppet::Pops::Impl::EvaluatorImpl.new
    result = evaluator.evaluate(in_top_scope.current, top_scope)
    if in_local_scope
      result = evaluator.evaluate(in_local_scope.current, top_scope.local_scope)
    end
    if in_top_scope_again
      result = evaluator.evaluate(in_top_scope_again.current, top_scope)
    end
    if block_given?
      block.call(top_scope)
    end
    result
  end
end