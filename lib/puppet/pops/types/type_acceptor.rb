module Puppet::Pops
module Types
# Implements a standard visitor patter for the Puppet Type system.

#
# An instance of this module is passed as an argument to the {PAnyType#accept}
# method of a Type instance. That type will then use the {TypeAcceptor#visit} callback
# on the acceptor and then pass the acceptor to the `accept` method of all contained
# type instances so that the it gets a visit from each one recursively.
#
module TypeAcceptor
  # @param type [PAnyType] the type that we accept a visit from
  # @param guard [RecursionGuard] the guard against self recursion
  def visit(type, guard)
  end
end

# An acceptor that does nothing
class NoopTypeAcceptor
  include TypeAcceptor

  INSTANCE = NoopTypeAcceptor.new
end
end
end
