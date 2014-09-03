Puppet::Parser::Functions::newfunction(:search, :arity => -2, :doc => "Add another namespace for this class to search.
    This allows you to create classes with sets of definitions and add
    those classes to another class's search path.

    Deprecated in Puppet 3.7.0, to be removed in Puppet 4.0.0.") do |vals|

    Puppet.deprecation_warning("The 'search' function is deprecated. See http://links.puppetlabs.com/search-function-deprecation")

    vals.each do |val|
      add_namespace(val)
    end
end
