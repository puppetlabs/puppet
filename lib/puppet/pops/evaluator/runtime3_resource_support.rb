module Puppet::Pops
module Evaluator

# @api private
module Runtime3ResourceSupport
  CLASS_STRING = 'class'.freeze

  def self.create_resources(file, line, scope, virtual, exported, type_name, resource_titles, evaluated_parameters)

    env = scope.environment
    #    loader = Adapters::LoaderAdapter.loader_for_model_object(o, scope)

    if type_name.is_a?(String) && type_name.casecmp(CLASS_STRING) == 0
      # Resolve a 'class' and its titles
      resource_titles = resource_titles.collect do |a_title|
        hostclass = env.known_resource_types.find_hostclass(a_title)
        hostclass ?  hostclass.name : a_title
      end
      # resolved type is just the string CLASS
      resolved_type = CLASS_STRING
    else
      # resolve a resource type - pcore based, ruby impl, user defined, or application
      resolved_type = find_resource_type(scope, type_name)
    end

    # TODO: Unknown resource causes creation of Resource to fail with ArgumentError, should give
    # a proper Issue. Now the result is "Error while evaluating a Resource Statement" with the message
    # from the raised exception. (It may be good enough).
    unless resolved_type
      # TODO: do this the right way
      raise ArgumentError, _("Unknown resource type: '%{type}'") % { type: type_name }
    end

    # Build a resource for each title - use the resolved *type* as opposed to a reference
    # as this makes the created resource retain the type instance.
    #
    resource_titles.map do |resource_title|
        resource = Puppet::Parser::Resource.new(
          resolved_type, resource_title,
          :parameters => evaluated_parameters,
          :file => file,
          :line => line,
          :exported => exported,
          :virtual => virtual,
          # WTF is this? Which source is this? The file? The name of the context ?
          :source => scope.source,
          :scope => scope,
          :strict => true
        )

        # If this resource type supports inheritance (e.g. 'class') the parent chain must be walked
        # This impl delegates to the resource type to figure out what is needed.
        #
        if resource.resource_type.is_a? Puppet::Resource::Type
          resource.resource_type.instantiate_resource(scope, resource)
        end

        scope.compiler.add_resource(scope, resource)

        # Classes are evaluated immediately
        scope.compiler.evaluate_classes([resource_title], scope, false) if resolved_type == CLASS_STRING

        # Turn the resource into a PTypeType (a reference to a resource type)
        # weed out nil's
        resource_to_ptype(resource)
    end
  end

  def self.find_resource_type(scope, type_name)
    find_builtin_resource_type(scope, type_name) || find_defined_resource_type(scope, type_name)
  end

  def self.find_resource_type_or_class(scope, name)
    find_builtin_resource_type(scope, name) || find_defined_resource_type(scope, name) || find_hostclass(scope, name)
  end

  def self.resource_to_ptype(resource)
    nil if resource.nil?
    # inference returns the meta type since the 3x Resource is an alternate way to describe a type
    Puppet::Pops::Types::TypeCalculator.singleton().infer(resource).type
  end

  def self.find_main_class(scope)
    # Find the main class (known as ''), it does not have to be in the catalog
    scope.environment.known_resource_types.find_hostclass('')
  end

  def self.find_hostclass(scope, class_name)
    scope.environment.known_resource_types.find_hostclass(class_name)
  end

  def self.find_builtin_resource_type(scope, type_name)
    if type_name.include?(':')
      # Skip the search for built in types as they are always in global namespace
      # (At least for now).
      return nil
    end

    loader = scope.compiler.loaders.private_environment_loader
    if loaded = loader.load(:resource_type_pp, type_name)
      return loaded
    end

    # horrible - should be loaded by a "last loader" in 4.x loaders instead.
    Puppet::Type.type(type_name)
  end
  private_class_method :find_builtin_resource_type

  def self.find_defined_resource_type(scope, type_name)
    krt = scope.environment.known_resource_types
    krt.find_definition(type_name) || krt.application(type_name)
  end
  private_class_method :find_defined_resource_type

end
end
end