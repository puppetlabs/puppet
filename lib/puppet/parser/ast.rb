# frozen_string_literal: true

# The base class for the 3x "parse tree", now only used by the top level
# constructs and the compiler.
# Handles things like file name, line #, and also does the initialization
# for all of the parameters of all of the child objects.
#
class Puppet::Parser::AST
  AST = Puppet::Parser::AST

  include Puppet::Util::Errors

  attr_accessor :parent, :scope, :file, :line, :pos

  def inspect
    "( #{self.class} #{self} #{@children.inspect} )"
  end

  # Evaluate the current object.  Just a stub method, since the subclass
  # should override this method.
  def evaluate(scope)
  end

  # The version of the evaluate method that should be called, because it
  # correctly handles errors.  It is critical to use this method because
  # it can enable you to catch the error where it happens, rather than
  # much higher up the stack.
  def safeevaluate(scope)
    # We duplicate code here, rather than using exceptwrap, because this
    # is called so many times during parsing.

    evaluate(scope)
  rescue Puppet::Pops::Evaluator::PuppetStopIteration => detail
    raise detail
  #      # Only deals with StopIteration from the break() function as a general
  #      # StopIteration is a general runtime problem
  #      raise Puppet::ParseError.new(detail.message, detail.file, detail.line, detail)
  rescue Puppet::Error => detail
    raise adderrorcontext(detail)
  rescue => detail
    error = Puppet::ParseError.new(detail.to_s, nil, nil, detail)
    # We can't use self.fail here because it always expects strings,
    # not exceptions.
    raise adderrorcontext(error, detail)
  end

  def initialize(file: nil, line: nil, pos: nil)
    @file = file
    @line = line
    @pos = pos
  end
end

# And include all of the AST subclasses.
require_relative 'ast/branch'
require_relative 'ast/leaf'
require_relative 'ast/block_expression'
require_relative 'ast/hostclass'
require_relative 'ast/node'
require_relative 'ast/resource'
require_relative 'ast/resource_instance'
require_relative 'ast/resourceparam'
