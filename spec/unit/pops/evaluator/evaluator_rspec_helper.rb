require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'

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
    node = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)

    # compiler creates the top scope if one is not present
    top_scope = compiler.topscope()
    # top_scope = Puppet::Parser::Scope.new(compiler)

    evaluator = Puppet::Pops::Evaluator::EvaluatorImpl.new
    Puppet.override(:loaders => compiler.loaders) do
      result = evaluator.evaluate(in_top_scope.model, top_scope)
      if in_named_scope
        other_scope = Puppet::Parser::Scope.new(compiler)
        result = evaluator.evaluate(in_named_scope.model, other_scope)
      end
      if in_top_scope_again
        result = evaluator.evaluate(in_top_scope_again.model, top_scope)
      end
      if block_given?
        block.call(top_scope)
      end
      result
    end
  end

  # Evaluate a Factory wrapper round a model object in top scope + local scope
  # Optionally pass two or three model objects (typically blocks) to be executed
  # in top scope, local scope, and then top scope again
  # The optional block is executed before the result of the last specified model object
  # is evaluated. This block gets the top scope as an argument. The intent is to pass
  # a block that asserts the state of the top scope after the operations.
  #
  def evaluate_l in_top_scope, in_local_scope = nil, in_top_scope_again = nil, &block
    node = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)

    # compiler creates the top scope if one is not present
    top_scope = compiler.topscope()

    evaluator = Puppet::Pops::Evaluator::EvaluatorImpl.new
    Puppet.override(:loaders => compiler.loaders) do
      result = evaluator.evaluate(in_top_scope.model, top_scope)
      if in_local_scope
        # This is really bad in 3.x scope
        top_scope.with_guarded_scope do
          top_scope.new_ephemeral(true)
          result = evaluator.evaluate(in_local_scope.model, top_scope)
        end
      end
      if in_top_scope_again
        result = evaluator.evaluate(in_top_scope_again.model, top_scope)
      end
      if block_given?
        block.call(top_scope)
      end
      result
    end
  end
end
