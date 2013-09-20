# Tag the current scope with each passed name
Puppet::Parser::Functions::newfunction(:tag, :arity => -2, :doc => "Add the specified tags to the containing class
  or definition.  All contained objects will then acquire that tag, also.
  ") do |vals|
    self.resource.tag(*vals)
end
