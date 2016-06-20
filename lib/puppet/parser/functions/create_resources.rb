Puppet::Parser::Functions::newfunction(:create_resources, :arity => -3, :doc => <<-'ENDHEREDOC') do |args|
    Converts a hash into a set of resources and adds them to the catalog.

    This function takes two mandatory arguments: a resource type, and a hash describing
    a set of resources. The hash should be in the form `{title => {parameters} }`:

        # A hash of user resources:
        $myusers = {
          'nick' => { uid    => '1330',
                      gid    => allstaff,
                      groups => ['developers', 'operations', 'release'], },
          'dan'  => { uid    => '1308',
                      gid    => allstaff,
                      groups => ['developers', 'prosvc', 'release'], },
        }

        create_resources(user, $myusers)

    A third, optional parameter may be given, also as a hash:

        $defaults = {
          'ensure'   => present,
          'provider' => 'ldap',
        }

        create_resources(user, $myusers, $defaults)

    The values given on the third argument are added to the parameters of each resource
    present in the set given on the second argument. If a parameter is present on both
    the second and third arguments, the one on the second argument takes precedence.

    This function can be used to create defined resources and classes, as well
    as native resources.

    Virtual and Exported resources may be created by prefixing the type name
    with @ or @@ respectively.  For example, the $myusers hash may be exported
    in the following manner:

        create_resources("@@user", $myusers)

    The $myusers may be declared as virtual resources using:

        create_resources("@user", $myusers)

    Note that `create_resources` will filter out parameter values that are `undef` so that normal
    data binding and puppet default value expressions are considered (in that order) for the
    final value of a parameter (just as when setting a parameter to `undef` in a puppet language
    resource declaration).
  ENDHEREDOC
  raise ArgumentError, ("create_resources(): wrong number of arguments (#{args.length}; must be 2 or 3)") if args.length > 3
  raise ArgumentError, ('create_resources(): second argument must be a hash') unless args[1].is_a?(Hash)
  if args.length == 3
    raise ArgumentError, ('create_resources(): third argument, if provided, must be a hash') unless args[2].is_a?(Hash)
  end

  type, instances, defaults = args
  defaults ||= {}
  type_name = type.sub(/^@{1,2}/, '').downcase

  # Get file/line information from the puppet stack (where call comes from in puppet source)
  # If relayed via other puppet functions in ruby that do not nest their calls, the source position
  # will be in the original puppet source.
  #
  stacktrace = Puppet::Pops::PuppetStack.stacktrace()
  if stacktrace.size > 0
    file, line = stacktrace[0]
  else
    file = nil
    line = nil
  end

  if type.start_with? '@@'
    exported = true
  elsif type.start_with? '@'
    virtual = true
  end

  instances.map do |title, params|
    # Add support for iteration if title is an array
    resource_titles = title.is_a?(Array) ? title  : [title]
    Puppet::Pops::Evaluator::Runtime3ResourceSupport.create_resources(
      file, line,
      self,
      virtual, exported,
      type_name,
      resource_titles,
      defaults.merge(params).map do |name, value|
        next if (value == :undef || value.nil?)
        Puppet::Parser::Resource::Param.new(
          :name   => name,
          :value  => value, # wide open to various data types, must be correct
          :source => self.source, # TODO: support :line => line, :file => file,
          :add    => false
        )
      end.compact
      )
  end.flatten.compact
end
