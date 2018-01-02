# Tag the current scope with each passed name
Puppet::Parser::Functions::newfunction(:tag, :arity => -2, :doc => "Add the specified tags to the containing class
  or definition.  All contained objects will then acquire that tag, also.
  ") do |vals|
    if Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING,
        {:operation => 'tag'})
    end

    self.resource.tag(*vals)
end
