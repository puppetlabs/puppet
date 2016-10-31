# The base class for the 3x "parse tree", now only used by the top level
# constructs and the compiler.
# Handles things like file name, line #, and also does the initialization
# for all of the parameters of all of the child objects.
#
class Puppet::Parser::AST
  AST = Puppet::Parser::AST

  include Puppet::Util::Errors
  include Puppet::Util::MethodHelper

  attr_accessor :parent, :scope, :file, :line, :pos

  def inspect
    "( #{self.class} #{self.to_s} #{@children.inspect} )"
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
    begin
      return self.evaluate(scope)
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
  end

  # Initialize the object.  Requires a hash as the argument, and
  # takes each of the parameters of the hash and calls the setter
  # method for them.  This is probably pretty inefficient and should
  # likely be changed at some point.
  def initialize(args)
    set_options(args)
  end

end

# And include all of the AST subclasses.
require 'puppet/parser/ast/branch'
require 'puppet/parser/ast/leaf'
require 'puppet/parser/ast/block_expression'
require 'puppet/parser/ast/hostclass'
require 'puppet/parser/ast/node'
require 'puppet/parser/ast/resource'
require 'puppet/parser/ast/resource_instance'
require 'puppet/parser/ast/resourceparam'
