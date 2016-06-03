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

  ENDHEREDOC
  raise ArgumentError, ("create_resources(): wrong number of arguments (#{args.length}; must be 2 or 3)") if args.length > 3
  raise ArgumentError, ('create_resources(): second argument must be a hash') unless args[1].is_a?(Hash)
  if args.length == 3
    raise ArgumentError, ('create_resources(): third argument, if provided, must be a hash') unless args[2].is_a?(Hash)
  end


  type, instances, defaults = args
  defaults ||= {}

  resource = Puppet::Parser::AST::Resource.new(:type => type.sub(/^@{1,2}/, '').downcase, :instances =>
    instances.collect do |title, params|
      Puppet::Parser::AST::ResourceInstance.new(
        :title => Puppet::Parser::AST::Leaf.new(:value => title),
        :parameters => defaults.merge(params).collect do |name, value|
          next if (value == :undef || value.nil?)
          Puppet::Parser::AST::ResourceParam.new(
            :param => name,
            :value => Puppet::Parser::AST::Leaf.new(:value => value))
        end.compact)
    end)

  if type.start_with? '@@'
    resource.exported = true
  elsif type.start_with? '@'
    resource.virtual = true
  end

  begin
    resource.safeevaluate(self)
  rescue Puppet::ParseError => internal_error
    if internal_error.original.nil?
      raise internal_error
    else
      raise internal_error.original
    end
  end
end
