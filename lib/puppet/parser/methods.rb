require 'puppet/util/autoload'
require 'puppet/parser/scope'
require 'puppet/parser/functions'
require 'monitor'

# A module for handling finding and invoking methods (functions invokable as a method).
# A method call on the form:
#
#  $a.meth(1,2,3] {|...| ...}
#
# will lookup a function called 'meth' and call it with the arguments ($a, 1, 2, 3, <lambda>)
#
# @see Puppet::Parser::AST::Lambda
# @see Puppet::Parser::AST::MethodCall
#
# @api public
# @since 3.2
#
module Puppet::Parser::Methods
  Environment = Puppet::Node::Environment
  # Represents an invokable method configured to be invoked for a given object.
  #
  class Method
    def initialize(receiver, obj, method_name, rvalue)
      @receiver = receiver
      @o = obj
      @method_name = method_name
      @rvalue = rvalue
    end

    # Invoke this method's function in the given scope with the given arguments and parameterized block.
    # A method call on the form:
    #
    #  $a.meth(1,2,3) {|...| ...}
    #
    # results in the equivalent:
    #
    #  meth($a, 1, 2, 3, {|...| ... })
    #
    # @param scope [Puppet::Parser::Scope] the scope the call takes place in
    # @param args [Array<Object>] arguments 1..n to pass to the function
    # @param pblock [Puppet::Parser::AST::Lambda] optional parameterized block to pass as the last argument
    #   to the called function
    #
    def invoke(scope, args=[], pblock=nil)
      arguments = [@o] + args
      arguments << pblock if pblock
      @receiver.send(@method_name, arguments)
    end

    # @return [Boolean] whether the method function produces an rvalue or not.
    def is_rvalue?
      @rvalue
    end
  end

  class << self
    include Puppet::Util
  end

  # Finds a function and returns an instance of Method configured to perform invocation.
  # @return [Method, nil] configured method or nil if method not found
  def self.find_method(scope, receiver, name)
    fname = Puppet::Parser::Functions.function(name)
    rvalue = Puppet::Parser::Functions.rvalue?(name)
    return Method.new(scope, receiver, fname, rvalue) if fname
    nil
  end
end
