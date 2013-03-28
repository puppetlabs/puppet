# A loader is responsible for loading "types" (actually "
# instantiable and executable objects in the puppet language" which
# are type, hostclass, definition and function.
#
class Puppet::Pops::API::Loader
  # Produces the value associated with the given name if defined in this loader, or nil if not defined.
  # This lookup does not trigger any loading, or search of the given name.
  # An implementor of this method may not search or look up in any other loader, and it may not
  # define the name.
  #
  def [] (name)
    raise Puppet::Pops::APINotImplementedError.new
  end

  # Produces the value associated with the given name if already loaded, or available for loading
  # by this loader, one of its parents, or other loaders visible to this loader.
  # This is the method an external party should use to "get" the named element.
  #
  # An implementor of this method should first check if the given name is already loaded by self, or a parent
  # loader, and if so return that result. If not, it should call #find to perform the loading.
  def load(name, executor)
    raise Puppet::Pops::APINotImplementedError.new
  end

  # Searches for the given name in this loaders context (parents have already searched their context(s) without
  # producing a result when this method is called).
  #
  def find(name, executor)
    raise Puppet::Pops::APINotImplementedError.new
  end

  # Returns the parent of the loader, or nil, if this is the top most loader.
  def parent
    raise Puppet::Pops::APINotImplementedError.new
  end

  # Binds a value to a name. The name should not start with '::', but may contain multiple segments.
  #
  def set_entry name, value, origin = nil
    raise Puppet::Pops::APINotImplementedError.new
  end

  # Produces a NamedEntry if a value is bound to the given name, or nil if nothing is bound.
  #
  def get_entry name
    raise Puppet::Pops::APINotImplementedError.new
  end
end
