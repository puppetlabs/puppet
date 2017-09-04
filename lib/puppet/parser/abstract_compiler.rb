
module Puppet::Parser::AbstractCompiler

  # Returns the catalog for a compilation. Must return a Puppet::Resource::Catalog or fail with an 
  # error if the specific compiler does not support catalog operations.
  #
  def catalog
    raise Puppet::DevError("Class '#{self.class}' should have implemented 'catalog'")
  end

  # Returns the environment for the compilation
  #
  def environment
    raise Puppet::DevError("Class '#{self.class}' should have implemented 'environment'")
  end

  # Produces a new scope
  # This method is here if there are functions/logic that will call this for some other purpose than to create
  # a named scope for a class. It may not have to be here. (TODO)
  #
  def newscope(scope, options)
    raise Puppet::DevError("Class '#{self.class}' should have implemented 'newscope'")
  end

  # Returns a hash of all externally referenceable qualified variables
  #
  def qualified_variables
    raise Puppet::DevError("Class '#{self.class}' should have implemented 'qualified_variables'")
  end

  # Returns the top scope instance
  def topscope
    raise Puppet::DevError("Class '#{self.class}' should have implemented 'topscope'")
  end

end
