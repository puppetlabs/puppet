# The import function raises an error when called to inform the user that import is no longer supported.
#
Puppet::Functions.create_function(:import) do
  def import(*args)
    raise Puppet::Pops::SemanticError.new(Puppet::Pops::Issues::DISCONTINUED_IMPORT)
  end
end
