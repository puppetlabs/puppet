module Puppet::Pops
module Types

# Interface implemented by a type that has InvocableMembers
module TypeWithMembers
  # @return [InvocableMember,nil] An invocable member if it exists, or `nil`
  def [](member_name)
    raise NotImplementedError, "'#{self.class.name}' should implement #[]"
  end
end

# Interface implemented by attribute and function members
module InvocableMember
  # Performs type checking of arguments and invokes the method that corresponds to this
  # method. The result of the invocation is returned
  #
  # @param receiver [Object] The receiver of the call
  # @param scope [Puppet::Parser::Scope] The caller scope
  # @param args [Array] Array of arguments.
  # @return [Object] The result returned by the member function or attribute
  #
  # @api private
  def invoke(receiver, scope, args, &block)
    raise NotImplementedError, "'#{self.class.name}' should implement #invoke"
  end
end

# Plays the same role as an PAttribute in the PObjectType. Provides
# access to known attr_readers and plain reader methods.
class AttrReader
  include InvocableMember

  def initialize(message)
    @message = message.to_sym
  end

  def invoke(receiver, scope, args, &block)
    receiver.send(@message)
  end
end
end
end

