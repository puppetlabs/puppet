Puppet::Parser::Functions::newfunction(:search, :doc => "Add another namespace for this class to search.
        This allows you to create classes with sets of definitions and add
        those classes to another class's search path.") do |vals|
        vals.each do |val|
            add_namespace(val)
        end
end
