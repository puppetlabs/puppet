# the parent class for all of our syntactical objects

require 'puppet'
require 'puppet/util/autoload'

# The base class for all of the objects that make up the parse trees.
# Handles things like file name, line #, and also does the initialization
# for all of the parameters of all of the child objects.
class Puppet::Parser::AST
  # Do this so I don't have to type the full path in all of the subclasses
  AST = Puppet::Parser::AST

  include Puppet::Util::Errors
  include Puppet::Util::MethodHelper
  include Puppet::Util::Docs

  attr_accessor :parent, :scope, :file, :line, :pos

  def inspect
    "( #{self.class} #{self.to_s} #{@children.inspect} )"
  end

  # Evaluate the current object.  Just a stub method, since the subclass
  # should override this method.
  def evaluate(*options)
  end

  # The version of the evaluate method that should be called, because it
  # correctly handles errors.  It is critical to use this method because
  # it can enable you to catch the error where it happens, rather than
  # much higher up the stack.
  def safeevaluate(*options)
    # We duplicate code here, rather than using exceptwrap, because this
    # is called so many times during parsing.
    begin
      return self.evaluate(*options)
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
  # takes each of the parameters of the hash and calls the settor
  # method for them.  This is probably pretty inefficient and should
  # likely be changed at some point.
  def initialize(args)
    set_options(args)
  end

end

# And include all of the AST subclasses.
require 'puppet/parser/ast/astarray'
require 'puppet/parser/ast/block_expression'
require 'puppet/parser/ast/hostclass' # PUP-3274 cannot remove until environment uses a different representation
require 'puppet/parser/ast/leaf'
require 'puppet/parser/ast/node'
require 'puppet/parser/ast/resource'
require 'puppet/parser/ast/resource_instance'
require 'puppet/parser/ast/resourceparam'
